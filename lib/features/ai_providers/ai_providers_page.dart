// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:nexus_projects_client/infrastructure/lemonade/providers/beacon_provider.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/providers/lemonade_servers_provider.dart';
import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show InferenceServersCompanion;
import 'package:nexus_projects_client/infrastructure/lemonade/services/secure_key_store.dart';
import 'package:nexus_projects_client/features/ai_providers/providers/ai_servers_cache_provider.dart';

import 'tabs/discovered_servers_tab.dart';
import 'tabs/configured_servers_tab.dart';
import 'widgets/infrastructure_badge.dart';

/// Dedicated top-level "AI Providers" page shown in the center pane.
/// Displays discovered and configured server lists only — no admin console here.
/// The right panel of the main shell switches to AdminConsoleWidget when a server is selected.
class AiProvidersPage extends ConsumerWidget {
  const AiProvidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovered = ref.watch(discoveredServersProvider);
    final configured = ref.watch(lemonadeServersProvider);
    final selected = ref.watch(selectedLemonadeServerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Flexible(
                child: Text(
                  'AI Providers',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 12),
              InfrastructureBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Authoritative home for local Lemonade servers, beacon discovery, full admin console, and omni collection downloads.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          DiscoveredServersTab(discovered: discovered),
          const SizedBox(height: 24),
          ConfiguredServersTab(
            discovered: discovered,
            configured: configured,
            selected: selected,
            onAddServer: () => _showAddServerDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddServerDialog(BuildContext context, WidgetRef ref) async {
    final db = ref.read(nexusDatabaseProvider);
    final currentClientId = ref.read(currentClientIdProvider);
    final existingServers = await db.getInferenceServersForClient(
      currentClientId,
    );

    String suggestName(String type) {
      final t = type.toLowerCase().trim().isEmpty
          ? 'custom'
          : type.toLowerCase().trim();
      final prefix = 'provider-$t-';
      int maxN = 0;
      for (final s in existingServers) {
        final n = s.name as String? ?? '';
        if (n.startsWith(prefix)) {
          final rest = n.substring(prefix.length);
          final num = int.tryParse(rest);
          if (num != null && num > maxN) maxN = num;
        }
      }
      return '$prefix${maxN + 1}';
    }

    String selectedType = 'lemonade';
    final nameCtrl = TextEditingController(text: suggestName(selectedType));
    final urlCtrl = TextEditingController(text: 'http://localhost:13305');
    final apiKeyCtrl = TextEditingController(text: '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Inference Server'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: const [
                    DropdownMenuItem(
                      value: 'lemonade',
                      child: Text('Lemonade (LAN server)'),
                    ),
                    DropdownMenuItem(
                      value: 'zyphra',
                      child: Text('Zyphra Cloud'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      selectedType = v;
                      nameCtrl.text = suggestName(v);
                      urlCtrl.text = v == 'zyphra'
                          ? 'https://api.zyphracloud.com/api/v1'
                          : 'http://localhost:13305';
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: apiKeyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API Key (optional)',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final baseUrl = urlCtrl.text.trim();
                final apiKey = apiKeyCtrl.text.trim();

                if (name.isEmpty || baseUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and URL are required.')),
                  );
                  return;
                }

                await db.createInferenceServer(
                  InferenceServersCompanion.insert(
                    client_fk: currentClientId,
                    name: name,
                    baseUrl: baseUrl,
                    // Store the key in the DB — that's what the coordinator
                    // client reads. (Also mirrored to SecureKeyStore below.)
                    apiKey: Value(apiKey),
                    providerType: Value(selectedType),
                    maxConcurrency: const Value(4),
                    maxAgents: const Value(8),
                    isEnabled: const Value(true),
                    availableModelsJson: const Value('[]'),
                    extraConfigJson: const Value('{}'),
                    capabilitiesJson: Value(
                      selectedType == 'zyphra'
                          ? '{"isLemonade":false,"zyphra":true}'
                          : '{"isLemonade":true,"fullLemonadeManaged":true}',
                    ),
                  ),
                );

                if (apiKey.isNotEmpty) {
                  try {
                    await SecureKeyStore.writeApiKey(name, apiKey);
                  } catch (_) {}
                }

                ref.invalidate(lemonadeServersProvider);
                // Refresh the centralized AI servers cache so all consumers see new models
                ref.read(aiServersCacheProvider.notifier).refresh();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Server "$name" added successfully.')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
