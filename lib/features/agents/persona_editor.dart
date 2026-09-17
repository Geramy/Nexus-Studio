// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show AgentPersonasCompanion, InferenceServer;
import 'package:nexus_projects_client/features/ai_providers/providers/ai_servers_cache_provider.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/api/types/model_info.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/services/persona_model_resolver.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/services/tts_voices.dart';
import 'package:nexus_projects_client/features/agents/agent_tool_permissions.dart';
import 'package:nexus_projects_client/features/agents/agent_role.dart';
import 'package:nexus_projects_client/features/agents/thinking_mode.dart';

import '../../shared/ui/nexus_ui.dart';

class PersonaEditor extends ConsumerStatefulWidget {
  final String personaName;
  final String initialModel;
  final int? personaId;

  const PersonaEditor({
    super.key,
    required this.personaName,
    this.initialModel = 'Claude 4',
    this.personaId,
  });

  @override
  ConsumerState<PersonaEditor> createState() => _PersonaEditorState();
}

class _PersonaEditorState extends ConsumerState<PersonaEditor> {
  late TextEditingController nameCtrl;
  late TextEditingController systemPromptCtrl;

  /// The agent's role (stored in the DB `title` column as [AgentRole.key]). The
  /// rule engine maps this to default skills, tools, and system prompt.
  AgentRole? selectedRole;
  int? selectedAiProviderId;
  bool _loaded = false;
  String? omniCollectionModel;
  String? selectedVoice;
  final Map<String, String?> _mods = {
    'tts': null,
    'stt': null,
    'imageGen': null,
    'vision': null,
    'llm': null,
  };

  /// Effective per-tool permissions for this agent (seeded from catalog defaults,
  /// overridden by the persona's saved configJson).
  final Map<String, ToolPerm> _toolPerms = {};

  /// Existing configJson so we preserve non-permission keys when saving.
  String? _existingConfigJson;

  /// Per-agent model "thinking mode" (enable_thinking). Unset inherits; the
  /// Project Manager defaults to Off, every other agent to Unset.
  ThinkingMode _thinkingMode = ThinkingMode.unset;

  /// Per-agent thinking LEVEL (reasoning_effort), sent to the model verbatim.
  /// Agents without an explicit level run at Low for now.
  ThinkingLevel _thinkingLevel = kDefaultThinkingLevel;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.personaName);
    systemPromptCtrl = TextEditingController(
      text:
          'Senior backend engineer focused on security, clean architecture, and production-grade code.',
    );
    // Seed tool permissions with catalog defaults; overridden on load.
    for (final t in kCoordinatorToolSpecs) {
      _toolPerms[t.name] = t.defaultPerm;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    systemPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPersona() async {
    // Guard against re-entry: build() can run several times before the async
    // fetch resolves. Set _loaded immediately so we only fetch once per persona.
    if (_loaded) return;
    _loaded = true;
    if (widget.personaId == null) return;

    final row = await ref
        .read(nexusDatabaseProvider)
        .resolveAgentPersona(widget.personaId!);
    if (mounted && row != null) {
      setState(() {
        nameCtrl.text = row.name;
        selectedRole = agentRoleFromKey(row.title);
        systemPromptCtrl.text = row.description ?? '';
        selectedAiProviderId = row.provider_fk;
        omniCollectionModel = row.omniCollectionModel;
        selectedVoice = row.ttsVoice;
        _mods['tts'] = row.ttsModel;
        _mods['stt'] = row.sttModel;
        _mods['imageGen'] = row.imageGenModel;
        _mods['vision'] = row.visionModel;
        _mods['llm'] = row.llmModel;
        // Load saved tool permissions over the catalog defaults.
        _existingConfigJson = row.configJson;
        _thinkingMode = personaThinkingMode(
          row.configJson,
          personaName: row.name,
        );
        _thinkingLevel = personaThinkingLevel(row.configJson);
        final saved = AgentToolPermissions.fromConfigJson(row.configJson);
        for (final t in kCoordinatorToolSpecs) {
          _toolPerms[t.name] = saved.permFor(t.name);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentClientId = ref.watch(currentClientIdProvider);
    final serversAsync = ref.watch(
      inferenceServersForClientProvider(currentClientId),
    );
    // Watch the centralized AI servers cache for live models
    ref.watch(aiServersCacheProvider);
    _loadPersona();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Save bar
          SectionHeader(
            title: 'Edit Persona: ${widget.personaName}',
            trailing: GradientButton(onPressed: _save, label: 'Save Changes'),
          ),
          const Divider(height: AppSpacing.xl),

          // Identity
          SectionHeader(title: 'Identity & Core Prompt', dense: true),
          Gap.md,
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Persona Name',
              border: OutlineInputBorder(),
            ),
          ),
          Gap.md,
          DropdownButtonFormField<AgentRole>(
            initialValue: selectedRole,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Job Title / Role',
              helperText:
                  'The orchestrator uses this role to pick the agent for a task and to apply its default skills, tools, and system prompt.',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final r in AgentRole.values)
                DropdownMenuItem(
                  value: r,
                  child: Text(r.displayTitle, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => selectedRole = v),
          ),
          if (selectedRole != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                selectedRole!.description,
                style: TextStyle(fontSize: 12, color: context.nx.textMuted),
              ),
            ),
          Gap.md,
          TextFormField(
            controller: systemPromptCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'System Prompt / Core Instructions',
              border: OutlineInputBorder(),
            ),
          ),
          Gap.md,

          // Thinking level (reasoning_effort): graded per agent, sent as-is.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thinking level',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Reasoning effort sent to the model as-is '
                      '(reasoning_effort — never clamped). Agents without an '
                      'explicit level run at Low.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.nx.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<ThinkingLevel>(
                  initialValue: _thinkingLevel,
                  isExpanded: true,
                  isDense: true,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    for (final l in ThinkingLevel.values)
                      DropdownMenuItem(value: l, child: Text(l.label)),
                  ],
                  onChanged: (v) => setState(
                    () => _thinkingLevel = v ?? kDefaultThinkingLevel,
                  ),
                ),
              ),
            ],
          ),
          Gap.md,

          // Thinking mode (enable_thinking): tri-state per agent.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thinking mode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "Force the model's reasoning on or off for this agent. Unset inherits "
                      '(Project Manager defaults to Off, others to Unset).',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.nx.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SegmentedButton<ThinkingMode>(
                segments: const [
                  ButtonSegment(
                    value: ThinkingMode.unset,
                    label: Text('Unset'),
                  ),
                  ButtonSegment(value: ThinkingMode.on, label: Text('On')),
                  ButtonSegment(value: ThinkingMode.off, label: Text('Off')),
                ],
                selected: {_thinkingMode},
                onSelectionChanged: (s) =>
                    setState(() => _thinkingMode = s.first),
              ),
            ],
          ),
          Gap.xl,

          // AI Provider Selection (global list)
          _aiProviderSection(serversAsync),
          Gap.xl,

          // Models & Modality Routing
          _modelRoutingSection(),
          Gap.xl,

          // Capability Matrix
          SectionHeader(
            title: 'Capability Matrix',
            subtitle: 'Define exactly what this persona is allowed to do.',
            dense: true,
          ),
          Gap.md,
          _capabilityMatrix(),
          Gap.xl,

          // Budget
          SectionHeader(title: 'Budget & Oversight Rules', dense: true),
          Gap.sm,
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '35',
                  decoration: const InputDecoration(
                    labelText: 'Max USD per Task',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Gap.md,
              Expanded(
                child: TextFormField(
                  initialValue: '120',
                  decoration: const InputDecoration(
                    labelText: 'Max USD per Hour',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiProviderSection(AsyncValue<List<InferenceServer>> servers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'AI Provider',
          subtitle: 'Select a provider from the global AI Providers list.',
          dense: true,
        ),
        Gap.sm,
        servers.when(
          data: (srvs) {
            if (srvs.isEmpty)
              return const NexusCard(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No AI Providers configured. Go to the AI Providers page.',
                ),
              );
            final items = <DropdownMenuItem<int?>>[
              const DropdownMenuItem(
                value: null,
                child: Text('Use client / project default'),
              ),
            ];
            for (final s in srvs) {
              items.add(
                DropdownMenuItem(
                  value: s.server_pk,
                  child: Text(
                    '${s.providerType} • ${s.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }
            final valid =
                selectedAiProviderId != null &&
                    srvs.any((s) => s.server_pk == selectedAiProviderId)
                ? selectedAiProviderId
                : null;
            return DropdownButtonFormField<int?>(
              initialValue: valid,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'AI Provider for this Persona',
              ),
              isExpanded: true,
              items: items,
              onChanged: (v) => setState(() {
                selectedAiProviderId = v;
              }),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _modelRoutingSection() {
    final cache = ref.read(aiServersCacheProvider);
    final hasProvider = selectedAiProviderId != null;

    // When no provider is selected, show a prompt — don't leak models from other servers
    if (!hasProvider) {
      return NexusCard(
        child: Text(
          'Select an AI Provider above to see available models.',
          style: TextStyle(fontSize: 13, color: context.nx.textMuted),
        ),
      );
    }

    // Only show models from the selected server
    final entry = cache[selectedAiProviderId!];
    final isLoading = entry == null;
    final omniModels = entry?.omniModels ?? [];
    final individualModels = entry?.individualModels ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _omniSelector(omniModels, isLoading),
        if (omniCollectionModel != null && omniCollectionModel!.isNotEmpty) ...[
          Gap.sm,
          // Show the REAL component models this collection resolves to (not
          // synthetic '<omni>-stt' names), so the user sees what will be used.
          _omniInfoCard(
            resolvePersonaModels(
              omniCollectionModel: omniCollectionModel,
              models: entry?.models ?? const <ApiModelInfo>[],
            ),
          ),
        ] else ...[
          Gap.md,
          Text(
            'Individual Modality Models (all optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.nx.textMuted,
            ),
          ),
          _modPicker(
            'TTS — Text to Voice',
            Icons.record_voice_over_rounded,
            'tts',
            individualModels,
            isLoading,
          ),
          Gap.sm,
          _modPicker(
            'STT — Voice to Text',
            Icons.mic_none_rounded,
            'stt',
            individualModels,
            isLoading,
          ),
          Gap.sm,
          _modPicker(
            'Image Generation',
            Icons.image_outlined,
            'imageGen',
            individualModels,
            isLoading,
          ),
          Gap.sm,
          _modPicker(
            'Vision — Image Reading',
            Icons.visibility_rounded,
            'vision',
            individualModels,
            isLoading,
          ),
          Gap.sm,
          _modPicker(
            'LLM — Text Generation (Primary)',
            Icons.auto_awesome_mosaic,
            'llm',
            individualModels,
            isLoading,
          ),
        ],
        Gap.md,
        _voiceSelector(),
      ],
    );
  }

  /// Speaking-voice picker for TTS replies (Kokoro voices; no list endpoint, so
  /// the standard set is shipped client-side).
  Widget _voiceSelector() {
    final cur =
        (selectedVoice != null &&
            kKokoroVoices.any((v) => v.id == selectedVoice))
        ? selectedVoice
        : null;
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(
        value: null,
        child: Text(
          'Default voice (${ttsVoiceLabel(kDefaultTtsVoice)})',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      for (final v in kKokoroVoices)
        DropdownMenuItem(
          value: v.id,
          child: Text(v.label, overflow: TextOverflow.ellipsis),
        ),
    ];
    return NexusCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 20, color: context.nx.info),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Voice',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The speaking voice for spoken replies (Kokoro TTS).',
            style: TextStyle(fontSize: 12, color: context.nx.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: cur,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'TTS Voice',
              isDense: true,
            ),
            items: items,
            onChanged: (v) => setState(() => selectedVoice = v),
          ),
        ],
      ),
    );
  }

  Widget _omniSelector(List<ApiModelInfo> omniModels, bool isLoading) {
    final content = [
      Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Omni Collection',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Select an Omni model to auto-configure all modalities using its default component models and tool routing.',
        style: TextStyle(fontSize: 12, color: context.nx.textMuted),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (isLoading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: CircularProgressIndicator(),
          ),
        )
      else
        _buildOmniDropdown(omniModels),
    ];
    return NexusCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }

  Widget _buildOmniDropdown(List<ApiModelInfo> omniModels) {
    final seen = <String>{};
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(
        value: null,
        child: Text('No Omni Collection — use individual models below'),
      ),
    ];
    for (final m in omniModels) {
      if (!seen.add(m.id)) continue;
      items.add(
        DropdownMenuItem(
          value: m.id,
          child: Text(m.id, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    if (items.length <= 1)
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          'No Omni Collection models available on this server. Use individual model selection below.',
          style: TextStyle(fontSize: 12, color: context.nx.textMuted),
        ),
      );

    final cur =
        (omniCollectionModel?.isNotEmpty == true &&
            seen.contains(omniCollectionModel))
        ? omniCollectionModel
        : null;
    return DropdownButtonFormField<String?>(
      initialValue: cur,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Omni Collection Model',
        isDense: true,
      ),
      isExpanded: true,
      items: items,
      onChanged: (v) {
        // Just record the chosen collection. The actual per-modality component
        // models are resolved from the collection at display + save time.
        setState(() => omniCollectionModel = v);
      },
    );
  }

  Widget _omniInfoCard(ResolvedModalityModels resolved) {
    final rows = <String, String?>{
      'llm': resolved.llm,
      'tts': resolved.tts,
      'stt': resolved.stt,
      'imageGen': resolved.imageGen,
      'vision': resolved.vision,
    };
    final nx = context.nx;
    return NexusCard(
      accent: nx.success,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: nx.success, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Component models from Omni Collection',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          ...rows.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(_modIcon(e.key), size: 16, color: nx.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${_modLabel(e.key)}:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      e.value ?? '—',
                      style: TextStyle(fontSize: 12, color: nx.textFaint),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modPicker(
    String label,
    IconData icon,
    String key,
    List<ApiModelInfo> models,
    bool isLoading,
  ) {
    return NexusCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.nx.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            flex: 2,
            child: isLoading
                ? const SizedBox.shrink()
                : _buildModDropdown(models, key),
          ),
        ],
      ),
    );
  }

  Widget _buildModDropdown(List<ApiModelInfo> models, String key) {
    if (models.isEmpty)
      return Text(
        'No models',
        style: TextStyle(fontSize: 12, color: context.nx.textMuted),
      );
    // A backend (e.g. the router aggregating multiple servers) can report the
    // same model id more than once; DropdownButton asserts on duplicate values,
    // so collapse to unique ids first.
    final seen = <String>{};
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Use default')),
    ];
    for (final m in models) {
      if (!seen.add(m.id)) continue;
      items.add(
        DropdownMenuItem(
          value: m.id,
          child: Text(m.id, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    final cur = seen.contains(_mods[key]) ? _mods[key] : null;
    return DropdownButtonFormField<String?>(
      initialValue: cur,
      isDense: true,
      isExpanded: true,
      items: items,
      onChanged: (v) {
        setState(() {
          _mods[key] = v;
        });
      },
    );
  }

  /// Tool-safety matrix: every coordinator tool, grouped by category, with a
  /// Grant / Ask / Deny control. Persisted into the persona's configJson and
  /// enforced by the coordinator's tool executor.
  Widget _capabilityMatrix() {
    return NexusCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Controls which tools this agent may call. "Ask" prompts you to approve each call; "Deny" blocks it.',
            style: TextStyle(fontSize: 12, color: context.nx.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              TextButton(
                onPressed: () => _setAllPerms(ToolPerm.grant),
                child: const Text('Grant all'),
              ),
              TextButton(
                onPressed: () => _setAllPerms(ToolPerm.ask),
                child: const Text('Ask all'),
              ),
              TextButton(
                onPressed: () => _setAllPerms(ToolPerm.deny),
                child: const Text('Deny all'),
              ),
            ],
          ),
          // Each category is a collapsible group (collapsed by default) so the
          // long tool list stays scannable; expand the groups you care about.
          for (final category in kToolCategories)
            _toolGroup(context, category),
        ],
      ),
    );
  }

  /// One collapsible tool-permission group with a per-group Grant/Ask/Deny.
  Widget _toolGroup(BuildContext context, String category) {
    final tools = kCoordinatorToolSpecs
        .where((t) => t.category == category)
        .toList();
    if (tools.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '${tools.length} tool${tools.length == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 11, color: context.nx.textMuted),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 4,
              children: [
                for (final p in ToolPerm.values)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _setGroupPerms(category, p),
                    child: Text(
                      switch (p) {
                        ToolPerm.grant => 'Grant all',
                        ToolPerm.ask => 'Ask all',
                        ToolPerm.deny => 'Deny all',
                      },
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          for (final t in tools)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            t.label,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (t.destructive)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: context.nx.warning,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _permChip(t.name),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _setGroupPerms(String category, ToolPerm p) {
    setState(() {
      for (final t in kCoordinatorToolSpecs.where((t) => t.category == category)) {
        _toolPerms[t.name] = p;
      }
    });
  }

  void _setAllPerms(ToolPerm p) {
    setState(() {
      for (final t in kCoordinatorToolSpecs) {
        _toolPerms[t.name] = p;
      }
    });
  }

  Widget _permChip(String tool) {
    final cur = _toolPerms[tool] ?? ToolPerm.grant;
    final intent = cur == ToolPerm.grant
        ? ChipIntent.success
        : (cur == ToolPerm.ask ? ChipIntent.warning : ChipIntent.danger);
    final label = cur == ToolPerm.grant
        ? 'Grant'
        : (cur == ToolPerm.ask ? 'Ask' : 'Deny');
    return PopupMenuButton<ToolPerm>(
      child: StatusChip(label, intent: intent, dense: true),
      itemBuilder: (_) => const [
        PopupMenuItem(value: ToolPerm.grant, child: Text('Grant')),
        PopupMenuItem(value: ToolPerm.ask, child: Text('Ask')),
        PopupMenuItem(value: ToolPerm.deny, child: Text('Deny')),
      ],
      onSelected: (v) => setState(() => _toolPerms[tool] = v),
    );
  }

  Future<void> _save() async {
    if (widget.personaId == null) {
      if (mounted) ref.read(selectedPersonaProvider.notifier).clear();
      return;
    }
    try {
      final db = ref.read(nexusDatabaseProvider);

      // Persist the real per-modality model ids: resolved from the Omni
      // Collection's components when one is selected, otherwise the individually
      // chosen models. Keeps saved data consistent with what the coordinator uses.
      final cache = ref.read(aiServersCacheProvider);
      final entry = selectedAiProviderId != null
          ? cache[selectedAiProviderId!]
          : null;
      final resolved = resolvePersonaModels(
        omniCollectionModel: omniCollectionModel,
        llmModel: _mods['llm'],
        sttModel: _mods['stt'],
        ttsModel: _mods['tts'],
        visionModel: _mods['vision'],
        imageGenModel: _mods['imageGen'],
        models: entry?.models ?? const <ApiModelInfo>[],
      );

      final updated =
          await (db.update(
            db.agentPersonas,
          )..where((p) => p.agent_pk.equals(widget.personaId!))).write(
            AgentPersonasCompanion(
              name: Value(nameCtrl.text.trim()),
              title: Value(selectedRole?.key),
              description: Value(
                systemPromptCtrl.text.trim().isEmpty
                    ? null
                    : systemPromptCtrl.text.trim(),
              ),
              provider_fk: Value(selectedAiProviderId),
              omniCollectionModel: Value(_safeStr(omniCollectionModel)),
              ttsModel: Value(resolved.tts),
              sttModel: Value(resolved.stt),
              imageGenModel: Value(resolved.imageGen),
              visionModel: Value(resolved.vision),
              llmModel: Value(resolved.llm),
              ttsVoice: Value(_safeStr(selectedVoice)),
              // Persist tool-safety permissions + thinking mode/level (merged
              // into existing configJson).
              configJson: Value(
                writeThinkingLevelIntoConfigJson(
                  writeThinkingModeIntoConfigJson(
                    AgentToolPermissions.writeIntoConfigJson(
                      _existingConfigJson,
                      _toolPerms,
                    ),
                    _thinkingMode,
                  ),
                  _thinkingLevel,
                ),
              ),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (!mounted) return;
      if (updated > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Persona saved successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: no rows updated — persona may not exist.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Close the editor panel via the notifier (not Navigator.pop — this isn't a route)
      ref.read(selectedPersonaProvider.notifier).clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String? _safeStr(String? s) => (s != null && s.isNotEmpty) ? s : null;
  IconData _modIcon(String k) => {
    'tts': Icons.record_voice_over_rounded,
    'stt': Icons.mic_none_rounded,
    'imageGen': Icons.image_outlined,
    'vision': Icons.visibility_rounded,
    'llm': Icons.auto_awesome_mosaic,
  }[k]!;
  String _modLabel(String k) => {
    'tts': 'TTS',
    'stt': 'STT',
    'imageGen': 'Image Gen',
    'vision': 'Vision',
    'llm': 'LLM',
  }[k]!;
}
