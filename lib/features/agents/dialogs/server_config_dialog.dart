// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_projects_client/infrastructure/models/ui/inference_server.dart'
    as ui_model;

// Server management (EndpointsTab / AI Providers page) now uses the rich ported
// LemonadeApiClient + ModelsEndpoint for model refresh / probing.
// The old InferenceClient has been fully removed from server management surfaces.
import 'package:nexus_projects_client/infrastructure/lemonade/api/lemonade_client.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/models/server_config.dart';

/// Server configuration dialog (model selection, refresh, limits).
/// Extracted from the monolithic center_agents_view during organization refactor.
/// (Persistence back to DB is still TODO per Phase 1 tracking.)
class ServerConfigDialog extends ConsumerStatefulWidget {
  final ui_model.InferenceServer server; // UI model

  const ServerConfigDialog({required this.server});

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late ui_model.InferenceServer _server;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  bool _isLoadingModels = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server = widget.server;

    _baseUrlController = TextEditingController(text: _server.baseUrl);
    _apiKeyController = TextEditingController(text: _server.apiKey);

    // Auto-load models on open if we don't have any yet
    if (_server.availableModels.isEmpty) {
      // Fire and forget — user can also manually refresh
      Future.microtask(() => _refreshModels(silent: true));
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _refreshModels({bool silent = false}) async {
    setState(() {
      _isLoadingModels = true;
      if (!silent) _error = null;
    });

    try {
      // Read live values from the controllers (they are the source of truth for the
      // editable connection fields). This avoids any desync and works even without
      // onChanged setState spam.
      final currentBaseUrl = _baseUrlController.text.trim();
      final currentApiKey = _apiKeyController.text;

      // Exact match to lemonade_mobile auth + normalization:
      final rawKey = currentApiKey;
      final effectiveKey = rawKey.trim().isNotEmpty
          ? rawKey.trim()
          : 'lemonade';

      // Use the rich ported LemonadeApiClient (ModelsEndpoint) for refresh.
      // This is the replacement for the deprecated InferenceClient in all server
      // management surfaces (EndpointsTab, ServerConfigDialog, AI Providers page).
      // Normalization + auth + ?show_all + "installed" (downloaded) filtering
      // now come from the Lemonade client (exact lemonade_mobile parity).
      final cfg = ServerConfig(
        name: _server.name,
        baseUrl: currentBaseUrl,
        apiKey: effectiveKey,
      );
      final apiClient = LemonadeApiClient(cfg);

      // Probe capabilities (lightweight equivalent of old probeServerCapabilities).
      // Detects /models support + Lemonade-specific fields (downloaded/labels/recipe/components).
      Map<String, dynamic> caps = Map<String, dynamic>.from(
        _server.capabilities,
      );
      if (caps['models'] != true) {
        try {
          final probeList = await apiClient.models.all();
          caps['models'] = true;
          caps['modelsSupportsShowAll'] = true;
          if (probeList.isNotEmpty) {
            final first = probeList.first;
            if (first.downloaded != null ||
                first.labels.isNotEmpty ||
                first.recipe != null ||
                first.compositeModels.isNotEmpty) {
              caps['isLemonade'] = true;
              caps['modelsHaveLemonadeFields'] = true;
            }
          }
        } catch (e) {
          caps['models'] = false;
          caps['modelsError'] = e.toString();
        }
      }

      // Exact equivalent of old listInstalledModels():
      // always uses show_all internally, then filters to downloaded models
      // (ModelsEndpoint.installed() pattern).
      final models = await apiClient.models.installed();
      final modelIds = models.map((m) => m.id).toList();

      // Only force the default "lemonade" into the field if it is still completely empty
      // at the end of the probe. If the user has started typing anything, leave their input alone.
      if (currentApiKey.trim().isEmpty &&
          _apiKeyController.text.trim().isEmpty) {
        _apiKeyController.text = effectiveKey;
      }

      setState(() {
        _server = _server.copyWith(
          // Keep the live baseUrl/apiKey from what the user has in the fields right now
          baseUrl: currentBaseUrl,
          apiKey: effectiveKey,
          availableModels: modelIds,
          // Persist the discovered API capabilities on the server record
          capabilities: caps,
          // Auto-select a sensible default if none chosen yet
          selectedModel:
              _server.selectedModel ??
              (modelIds.isNotEmpty ? modelIds.first : null),
        );
        if (!silent) _error = null;
      });

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${modelIds.length} models from server'),
          ),
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      // Make connection errors much friendlier for the user
      if (errorMsg.contains('Connection failed') ||
          errorMsg.contains('SocketException')) {
        errorMsg =
            'Could not connect to the server. Check the Base URL and make sure the inference server is running.';
      }
      setState(() {
        if (!silent) _error = errorMsg;
      });
      if (!silent) {
        debugPrint('Model refresh error for ${_server.name}: $errorMsg');
      }
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.dns_outlined, size: 20),
          const SizedBox(width: 8),
          Text('Configure ${_server.name}'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Section
              _SectionHeader(title: 'Connection'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        // No onChanged/setState here — the controller is the source of truth.
                        // We read .text directly when we need the value (Refresh or Save).
                        // This prevents a full dialog rebuild on every keystroke, which was
                        // making the fields feel unresponsive or hard to edit.
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key (optional for local servers)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        obscureText: true,
                        style: const TextStyle(fontSize: 13),
                        // Same as above — read from controller on demand.
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Provider: ${_server.providerType}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Model Selection Section
              _SectionHeader(
                title: 'Model Selection',
                trailing: TextButton.icon(
                  onPressed: _isLoadingModels ? null : _refreshModels,
                  icon: _isLoadingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(height: 8),

              if (_server.availableModels.isEmpty &&
                  _server.selectedModel == null)
                const Text(
                  'No models loaded yet. Click "Refresh" to fetch available models from the server.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Builder(
                  builder: (_) {
                    // Dedupe models and make sure the selected one is always a
                    // valid option, otherwise DropdownButton asserts (zero or 2+
                    // items matching the value).
                    final models = <String>{
                      ..._server.availableModels,
                      if (_server.selectedModel != null) _server.selectedModel!,
                    }.toList();
                    final value = models.contains(_server.selectedModel)
                        ? _server.selectedModel
                        : null;
                    return DropdownButtonFormField<String>(
                      initialValue: value,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Active Model',
                      ),
                      items: models
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (newModel) {
                        if (newModel != null) {
                          setState(() {
                            _server = _server.copyWith(selectedModel: newModel);
                          });
                        }
                      },
                    );
                  },
                ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 20),

              // Limits Section
              _SectionHeader(title: 'Resource Limits'),
              Row(
                children: [
                  Expanded(
                    child: _LimitCard(
                      label: 'Max Concurrency',
                      value: _server.maxConcurrency.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LimitCard(
                      label: 'Max Agents',
                      value: _server.maxAgents.toString(),
                    ),
                  ),
                ],
              ),
            ],
          ), // end Column
        ), // end SingleChildScrollView
      ), // end SizedBox
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            // Read the final live values from the controllers (the true source for
            // the editable fields). This is more reliable than relying on onChanged.
            final finalServer = _server.copyWith(
              baseUrl: _baseUrlController.text.trim(),
              apiKey: _apiKeyController.text,
            );
            Navigator.pop(context, finalServer);
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  final String label;
  final String value;

  const _LimitCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
