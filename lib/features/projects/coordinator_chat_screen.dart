// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show ChatMessagesCompanion, ChatMessage, AgentPersona;
// Backward-compat types (InferenceClient = InferenceBackend).
import 'package:nexus_projects_client/infrastructure/inference/inference_backend_factory.dart'
    show backendForServer;
import 'package:nexus_projects_client/infrastructure/inference/routed_server.dart'
    show isRoutedProviderType;
import 'package:nexus_projects_client/infrastructure/inference/inference_client.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/api/types/model_info.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/services/persona_model_resolver.dart';
import 'package:nexus_projects_client/features/ai_providers/providers/ai_servers_cache_provider.dart';
import 'package:nexus_projects_client/infrastructure/models/ui/inference_server.dart'
    as ui_server;
import 'package:nexus_projects_client/features/projects/coordinator_session.dart';
import 'package:nexus_projects_client/features/project_plans/plan_store.dart';
import 'package:nexus_projects_client/features/agents/agent_tool_permissions.dart';
import 'package:nexus_projects_client/features/agents/agent_role.dart';
import 'package:nexus_projects_client/infrastructure/training/training_sink.dart';
import 'package:nexus_projects_client/infrastructure/training/ai_export.dart'
    show aiMessageRef;
import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/git_engine_provider.dart';
import 'package:nexus_projects_client/infrastructure/build/build_service.dart';
import 'package:nexus_projects_client/infrastructure/build/build_service_provider.dart';
import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/services/audio/audio_recorder_service.dart';
import 'package:nexus_projects_client/services/audio/tts_service.dart';
import 'package:nexus_projects_client/features/agents/thinking_mode.dart';
import 'package:nexus_projects_client/shared/ui/chat_markdown.dart';
import 'package:nexus_projects_client/services/audio/coordinator_duplex_voice_session.dart';
import 'package:nexus_projects_client/widgets/live_mic_visualizer.dart';

import '../../shared/ui/nexus_ui.dart';
import '../../shared/ui/rated_message_bar.dart';
import '../../shared/ui/sticky_scroll.dart';
import '../../shared/ui/submit_on_enter.dart';
import '../../core/providers/lean_context_provider.dart';

/// Main interface for talking to a Project's Coordinator AI (the "Main Brain").
/// Full bidirectional text + voice with live tool execution (the AI can create/update
/// tasks and propose plan changes that immediately persist to the DB and reflect in UI).
class ProjectCoordinatorChatScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String projectName;

  /// When set, the coordinator is focused on this plan (can view/update it) and
  /// tasks it creates are linked to the plan. This is the plan's workspace path,
  /// e.g. `/PLANS/Roadmap.md`.
  final String? openPlanPath;

  /// Post-setup Exploration (discovery) mode: the coordinator gets ONLY the
  /// user-story tools and a discovery [systemPromptOverride], and proactively
  /// opens with [autoOpenPrompt] (the AI speaks first, no visible user bubble).
  final bool discoveryMode;
  final String? systemPromptOverride;
  final String? autoOpenPrompt;

  const ProjectCoordinatorChatScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.openPlanPath,
    this.discoveryMode = false,
    this.systemPromptOverride,
    this.autoOpenPrompt,
  });

  @override
  ConsumerState<ProjectCoordinatorChatScreen> createState() =>
      _ProjectCoordinatorChatScreenState();
}

class _ProjectCoordinatorChatScreenState
    extends ConsumerState<ProjectCoordinatorChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final StickyScrollController _sticky = StickyScrollController();
  final List<_ChatMessage> _messages = [];
  // Dedicated player for replaying a reply's audio from the transcript (separate
  // from the live TTS player so replay can't clash with an active call turn).
  final AudioPlayer _replayPlayer = AudioPlayer();
  bool _isVoiceCallActive =
      false; // Whether we are in voice conversation mode with the Coordinator
  bool _isMicMuted =
      false; // Whether the mic is currently muted while in voice mode
  bool _isSending = false;
  // True while an assistant turn is in flight but no streamed content has
  // arrived yet (drives the "Coordinator is thinking…" indicator).
  bool _isThinking = false;
  // Set when the user taps the thinking indicator to abort a stuck/looping turn.
  bool _stopRequested = false;
  VoiceState _voiceState = VoiceState.idle;

  /// Concrete backend for the selected server (LemonadeBackend via factory).
  InferenceClient? _inferenceClient;
  ProjectCoordinatorSession? _session;

  /// Image-generation model id resolved for the active session (for the manual
  /// "generate diagram" button). Empty model id → router 502.
  String? _imageModel;

  /// Rating-feedback context for the coordinator/stories chat. STABLE across the
  /// discovery → normal-coordinator transition (it's the same chat with the same
  /// persisted messages) so a rating still loads after reopening — the old id
  /// switched from `discovery:<pid>` to `coordinator:<pid>:<sessionId>` once tasks
  /// were generated, orphaning the rating. The exporter matches ratings to
  /// messages by content hash, so this id only needs to be consistent.
  String get _ratingAiKind => 'stories';
  String get _ratingConversationId => 'stories:${widget.projectId}';
  CoordinatorDuplexVoiceSession?
  _duplexVoiceSession; // The one and only voice path for the Coordinator call (duplex VAD-driven, lemonade_mobile style)
  AudioRecorderService?
  _voiceRecorder; // shared so LiveMicVisualizer sees real levels during the call
  bool _clientReady = false;

  /// Active persisted chat session for this project.
  int? _sessionId;
  bool _sessionTitled = false;
  String? _clientError;

  @override
  void initState() {
    super.initState();
    _sticky.attach();
    _initializeCoordinator();
  }

  Future<void> _initializeCoordinator() async {
    try {
      final clientId = ref.read(currentClientIdProvider);
      // One-shot DB read (not the StreamProvider `.future`, which hangs under
      // riverpod 3 with no active stream listener). The reactive provider is
      // still used by the AI-providers UI via ref.watch.
      final servers = await ref
          .read(nexusDatabaseProvider)
          .getInferenceServersForClient(clientId);

      if (servers.isEmpty) {
        setState(() {
          _clientError =
              'No inference servers configured for this client. Go to Agents Hub and add a Lemonade (or OpenAI-compatible) server first.';
          _clientReady = false;
        });
        return;
      }

      final db = ref.read(nexusDatabaseProvider);

      // The project's assigned agent OWNS the server connection + model config.
      // Resolve it first so the coordinator talks to the AGENT's server (not just
      // the first one) — otherwise we'd resolve the agent's models but POST them
      // to a different server and get 500s.
      AgentPersona? persona;
      try {
        // The User-Story (discovery) screen is hosted by the COORDINATOR agent;
        // the normal project chat by the Project Manager. Resolve by role so each
        // screen binds to its agent (and that agent's default Omni collection).
        // Falls back to (and persists) the Project Manager when no role persona
        // is found, so the chat always opens with a sensible default selected.
        final personaId = widget.discoveryMode
            ? (await db.getProjectRolePersonaId(
                    widget.projectId,
                    AgentRole.coordinator.key,
                  ) ??
                  await db.getOrAssignCoordinatorPersonaId(widget.projectId))
            : await db.getOrAssignCoordinatorPersonaId(widget.projectId);
        if (personaId != null)
          persona = await db.resolveAgentPersona(personaId);
      } catch (e) {
        debugPrint('Coordinator: could not load project agent (non-fatal): $e');
      }

      // Pick the server the agent is connected to (provider_fk); else default to
      // the Nexus Router (subscription) server when present (i.e. signed in),
      // else the first configured server.
      var chosen = servers.firstWhere(
        (s) => isRoutedProviderType(s.providerType),
        orElse: () => servers.first,
      );
      if (persona?.provider_fk != null) {
        for (final s in servers) {
          if (s.server_pk == persona!.provider_fk) {
            chosen = s;
            break;
          }
        }
      }
      // Live model list from the chosen (agent's) server.
      final cache = ref.read(aiServersCacheProvider.notifier);
      var entry = cache.entryFor(chosen.server_pk);
      if (entry == null || entry.models.isEmpty) {
        await cache.refreshServer(chosen.server_pk);
        entry = cache.entryFor(chosen.server_pk);
      }

      // Fallback: if the agent's bound server is unreachable (no models came
      // back — e.g. a stopped Local Lemonade → "connection refused localhost"),
      // switch to the routed Nexus Router server when one exists. Otherwise the
      // discovery Coordinator dead-ends on the dead local server and "cuts out
      // instantly", even though the working subscription server (the same one
      // Setup ran on) is right there. Keeps both phases on one backend.
      if (entry == null || entry.models.isEmpty) {
        final routedMatches = servers.where(
          (s) =>
              isRoutedProviderType(s.providerType) &&
              s.server_pk != chosen.server_pk,
        );
        if (routedMatches.isNotEmpty) {
          final routedServer = routedMatches.first;
          debugPrint(
            '[Coordinator] server "${chosen.name}" @ ${chosen.baseUrl} '
            'unreachable — falling back to routed "${routedServer.name}".',
          );
          chosen = routedServer;
          entry = cache.entryFor(chosen.server_pk);
          if (entry == null || entry.models.isEmpty) {
            await cache.refreshServer(chosen.server_pk);
            entry = cache.entryFor(chosen.server_pk);
          }
        }
      }
      final serverModels = entry?.models ?? const <ApiModelInfo>[];

      debugPrint(
        '[Voice] Agent="${persona?.name ?? "(none)"}" → server "${chosen.name}" @ ${chosen.baseUrl}',
      );

      final models =
          (jsonDecode(chosen.availableModelsJson) as List).cast<String>();

      // Per-modality models from the agent (omni components or individual fields),
      // resolved against the agent's own server.
      String? sttModel;
      String? ttsModel;
      String? imageModel;
      String? ttsVoice = persona?.ttsVoice;

      // Each agent uses its OWN default Omni collection: the Coordinator (the
      // discovery / user-story host) → NXS-PJX-Discovery, the Project Manager
      // (normal chat) → NXS-PJX-Interview. Prefer the persona's stored collection,
      // then its role default; this runs even with no persona (role default
      // falls back to the product default), so the per-modality components are
      // always resolved instead of the small "first model" safety nets below.
      final personaCollection = persona?.omniCollectionModel;
      final omniCollection =
          (personaCollection != null && personaCollection.trim().isNotEmpty)
          ? personaCollection.trim()
          : defaultOmniCollectionForTitle(persona?.title);
      if (omniCollection.isNotEmpty) {
        final resolved = resolvePersonaModels(
          omniCollectionModel: omniCollection,
          llmModel: persona?.llmModel,
          sttModel: persona?.sttModel,
          ttsModel: persona?.ttsModel,
          visionModel: persona?.visionModel,
          imageGenModel: persona?.imageGenModel,
          models: serverModels,
        );
        sttModel = resolved.stt;
        ttsModel = resolved.tts;
        imageModel = resolved.imageGen;
        // Default the spoken voice to Bella on the product Omni collection when
        // no explicit voice is set.
        if ((ttsVoice == null || ttsVoice.trim().isEmpty) &&
            omniCollection == kDefaultOmniCollection) {
          ttsVoice = 'af_bella'; // Bella — US Female
        }
      }

      // Safety net (any path): never let voice fall back to the backend's
      // `whisper-1` / empty TTS defaults, which 404 on Lemonade servers.
      sttModel ??= firstAudioModelId(serverModels);
      ttsModel ??= firstTtsModelId(serverModels);
      // Image gen: prefer the collection's image component, else any image model
      // the server advertises. Empty model id makes the router 502 ("All
      // candidate backends failed"); the executor falls back to the chat model.
      imageModel ??= firstImageModelId(serverModels);
      // ignore: avoid_print
      print('[ImageGen] resolved imageModel=${imageModel ?? "NONE — will fall "
          "back to the chat model, which the router 502s on for /images"}; '
          'available models: ${serverModels.map((m) => m.isCollection ? "${m.id}{${m.compositeModels.join("+")}}" : m.id).join(", ")}');

      // Chat model: the routed Nexus Router serves the Omni COLLECTION id directly,
      // so send the agent's collection (or an explicit per-persona model) as-is —
      // do NOT decompose to a raw sub-model (which fell through to a small 4B: the
      // wrong model). Local servers (which 500 on a bare collection) decompose from
      // their live model list. Voice STT/TTS resolved above.
      final pLlm = persona?.llmModel;
      final routed = isRoutedProviderType(chosen.providerType);
      final effectiveChatModel = routed
          ? ((pLlm != null && pLlm.trim().isNotEmpty)
                ? pLlm.trim()
                : omniCollection)
          : resolveAgentChatModel(
              routed: false,
              personaModel: pLlm,
              selectedModel: chosen.selectedModel,
              serverModels: serverModels,
            );
      debugPrint(
        '[Voice] Coordinator models → chat=$effectiveChatModel stt=$sttModel '
        'tts=$ttsModel voice=${ttsVoice ?? "(default)"} '
        'omni=$omniCollection '
        'collectionsSeen=[${serverModels.where((m) => m.isCollection).map((m) => m.id).join(", ")}]',
      );

      final uiServer = ui_server.InferenceServer(
        id: chosen.server_pk.toString(),
        name: chosen.name,
        baseUrl: chosen.baseUrl,
        apiKey: chosen.apiKey,
        providerType: 'lemonade',
        selectedModel: chosen.selectedModel,
        availableModels: models,
      );
      // The backend is created AFTER the chat session is resolved (below) so it
      // can carry the X-Nexus-Session header — the Router pins this conversation
      // to one warm backend while balancing other sessions across the fleet.

      // Resolve (or create) the active chat session FIRST, so the coordinator
      // session can record it on any task it creates (provenance).
      // When chatting about a specific plan, bind to that plan's session so the
      // conversation (and any tasks it spawns) is linked back to the plan.
      // Otherwise use/reuse the general project-level session.
      int sessionId;
      // The plan store is a filesystem store over the project's /PLANS folder, so
      // it must be available in the GENERAL project chat too — not only when a
      // specific plan is open. Otherwise list_plans/read_plan report "Plan storage
      // is unavailable" even though PLANS/ already has files. Load best-effort.
      PlanStore? planStore;
      try {
        planStore = await ref.read(planStoreProvider(widget.projectId).future);
      } catch (_) {}
      if (widget.openPlanPath != null) {
        sessionId = await db.getOrCreateChatSession(
          widget.projectId,
          planPath: widget.openPlanPath,
        );
      } else {
        sessionId =
            ref.read(currentChatSessionProvider(widget.projectId)) ??
            await db.getOrCreateChatSession(widget.projectId);
        ref
            .read(currentChatSessionProvider(widget.projectId).notifier)
            .select(sessionId);
      }
      _sessionId = sessionId;
      _inferenceClient =
          backendForServer(uiServer, sessionId: 'chat-$sessionId');

      // Workspace + git + build access for the file/git/build agent tools.
      // Resolved best-effort; if any fail those tools degrade to "unavailable"
      // rather than breaking the chat session.
      Workspace? workspace;
      NxtprjGitEngine? gitEngine;
      BuildService? buildService;
      try {
        workspace = await ref.read(
          workspaceFsProvider(widget.projectId).future,
        );
        gitEngine = await ref.read(gitEngineProvider(widget.projectId).future);
        buildService = ref.read(buildServiceProvider);
      } catch (_) {}

      _session = ProjectCoordinatorSession(
        client: _inferenceClient!,
        projectId: widget.projectId,
        projectName: widget.projectName,
        db: db,
        model: effectiveChatModel,
        imageModel: imageModel ?? effectiveChatModel,
        openPlanPath: widget.openPlanPath,
        planStore: planStore,
        chatSessionPk: sessionId,
        // Tool safety: enforce the assigned agent's per-tool permissions.
        permissions: AgentToolPermissions.fromConfigJson(persona?.configJson),
        agentName: persona?.name ?? 'The coordinator',
        confirmAsk: _confirmToolUse,
        workspace: workspace,
        git: gitEngine,
        // Serialize this interactive session's git WRITES (commit/branch/merge on
        // the shared HEAD tree) on the project's git lane, so they never
        // interleave with the orchestrator's concurrent lane-serialized commits
        // against the same object DB. No workBranch → not isolated; just shares
        // the lane.
        gitLane: ref.read(gitLaneProvider(widget.projectId)),
        buildService: buildService,
        // DISCOVERY: force thinking OFF. Discovery is a decisive tool-calling
        // interview (ask → add_user_story → ask), and the Coordinator persona is
        // Unset (→ the reasoning model's default ON). On a weak local model that
        // extended-thinking budget makes it dither/loop for pages before acting
        // ("Actually… Wait… Self-Correction… Proceeding…"). The setup interview
        // already runs thinking-off (Project Manager defaults Off), which is why
        // it behaves; mirror that here. Normal Coordinator chat keeps the
        // agent-level resolution (Project Manager Off, others Unset; a task may
        // override in pass-2).
        enableThinking: widget.discoveryMode
            ? false
            : resolveEnableThinking(
                agent: personaThinkingMode(
                  persona?.configJson,
                  personaName: persona?.name,
                ),
              ),
        leanTools: ref.read(leanContextProvider),
        discoveryMode: widget.discoveryMode,
        systemPromptOverride: widget.systemPromptOverride,
      );

      // Load the session's persisted messages + restore the LLM history.
      final restored = await _loadSessionMessages(sessionId);

      _imageModel = imageModel ?? effectiveChatModel;

      _voiceRecorder = AudioRecorderService();
      final ttsSvc = TtsService(
        inferenceClient: _inferenceClient,
        ttsModel: ttsModel,
        defaultVoice: ttsVoice,
      );

      // Duplex (VAD-driven continuous conversation) is now the ONLY voice path for the Coordinator call.
      // This gives the automatic speak → pause (VAD) → AI processes (with tools) → speaks back → auto resume listening behavior.
      _duplexVoiceSession = CoordinatorDuplexVoiceSession(
        coordinatorSession: _session!,
        recorder: _voiceRecorder!,
        tts: ttsSvc,
        sttModel: sttModel,
        // Surface each voice turn in the chat transcript so the conversation is
        // visible even if TTS audio fails.
        onUserTranscript: (t) {
          if (mounted)
            setState(() => _messages.add(_ChatMessage(text: t, isUser: true)));
          unawaited(_persist('user', t));
        },
        onAssistantReply: (t, audioPath) {
          if (mounted)
            setState(
              () => _messages.add(
                _ChatMessage(text: t, isUser: false, audioPath: audioPath),
              ),
            );
          unawaited(_persist('assistant', t, audioPath: audioPath));
        },
        onSystemNote: (t) {
          if (mounted)
            setState(
              () => _messages.add(
                _ChatMessage(text: t, isUser: false, isSystem: true),
              ),
            );
          unawaited(_persist('system', t));
        },
      );

      // Drive UI state from the duplex session (listening / processing / etc.)
      _duplexVoiceSession!.state.listen((state) {
        if (mounted) setState(() => _voiceState = state);
      });

      final ctx = await _session!.getRichProjectContext();

      if (mounted) {
        setState(() {
          _clientReady = true;
          _clientError = null;
          _messages
            ..clear()
            ..addAll(restored);
          if (_messages.isEmpty && !widget.discoveryMode) {
            // Ephemeral greeting (not persisted) shown only for an empty session.
            _messages.add(
              _ChatMessage(
                text:
                    'Coordinator ready for project "${widget.projectName}".\n$ctx\n\nYou can type or use the call button for voice. The AI can create/update tasks live via tools.',
                isUser: false,
              ),
            );
          }
        });
      }

      // Discovery: the coordinator speaks first — proactively kick off the
      // interview (no visible user bubble) when the session is fresh.
      if (mounted &&
          widget.discoveryMode &&
          _messages.isEmpty &&
          (widget.autoOpenPrompt ?? '').isNotEmpty) {
        unawaited(_sendMessage(hiddenPrompt: widget.autoOpenPrompt));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _clientError = 'Failed to initialize coordinator: $e';
          _clientReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _sticky.dispose();
    _duplexVoiceSession?.dispose();
    _voiceRecorder?.dispose();
    _replayPlayer.dispose();
    super.dispose();
  }

  /// Load a session's persisted messages into UI form and restore the LLM
  /// history (so the conversation continues). Updates [_sessionTitled].
  Future<List<_ChatMessage>> _loadSessionMessages(int sessionId) async {
    final db = ref.read(nexusDatabaseProvider);
    final rows = await db.getChatMessagesForSession(sessionId);
    final restored = <_ChatMessage>[];
    final llmTurns = <({String role, String content})>[];
    for (final ChatMessage m in rows) {
      final isUser = m.role == 'user';
      final isSystem = m.role == 'system';
      restored.add(
        _ChatMessage(
          text: m.content,
          isUser: isUser,
          isSystem: isSystem ? true : null,
          audioPath: m.audioPath,
        ),
      );
      if (m.role == 'user' || m.role == 'assistant') {
        llmTurns.add((role: m.role, content: m.content));
      }
    }
    _session?.restoreHistory(llmTurns);
    _sessionTitled = rows.any((m) => m.role == 'user');
    return restored;
  }

  /// Switch the open chat to a different session (selected in the sidebar).
  Future<void> _loadSession(int sessionId) async {
    _sessionId = sessionId;
    final restored = await _loadSessionMessages(sessionId);
    if (mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(restored);
      });
    }
  }

  /// Persist one message to the active session and bump its updatedAt (and set
  /// the title from the first user message).
  /// Human-in-the-loop approval for tools whose permission is "Ask". Returns
  /// true to allow the call. Shown when the coordinator wants to run a gated tool.
  Future<bool> _confirmToolUse(String tool, String summary) async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve agent action?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The coordinator wants to run a tool that requires your approval:',
            ),
            const SizedBox(height: 10),
            Text(summary, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Tool: $tool',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Persists a chat message and returns its message_pk (null if no session).
  Future<int?> _persist(String role, String text, {String? audioPath}) async {
    final sid = _sessionId;
    if (sid == null) return null;
    final db = ref.read(nexusDatabaseProvider);
    final now = DateTime.now();
    final pk = await db.addChatMessage(
      ChatMessagesCompanion.insert(
        session_fk: sid,
        role: role,
        content: Value(text),
        audioPath: Value(audioPath),
        seq: Value(now.millisecondsSinceEpoch),
      ),
    );
    if (role == 'user' && !_sessionTitled) {
      _sessionTitled = true;
      await db.touchChatSession(sid, title: _titleFromText(text));
    } else {
      await db.touchChatSession(sid);
    }
    return pk;
  }

  String _titleFromText(String t) {
    final clean = t.trim().replaceAll('\n', ' ');
    return clean.length <= 40 ? clean : '${clean.substring(0, 40)}…';
  }

  /// Replay a reply's synthesized audio from its transcript bubble.
  Future<void> _replayAudio(String path) async {
    try {
      await _replayPlayer.setAudioSource(AudioSource.file(path));
      await _replayPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not play audio: $e')));
      }
    }
  }

  /// Abort the in-flight turn — the user tapped the thinking indicator because it
  /// looped or hung. Setting [_stopRequested] breaks the stream loop on its next
  /// event (which cancels the underlying request); we drop the spinner right away
  /// so the composer frees up immediately.
  void _stopTurn() {
    if (!_isSending && !_isThinking) return;
    setState(() {
      _stopRequested = true;
      _isSending = false;
      _isThinking = false;
    });
  }

  Future<void> _sendMessage({String? hiddenPrompt}) async {
    // A hidden prompt (the discovery auto-opener) drives a turn WITHOUT showing
    // a user bubble or persisting it — so the coordinator appears to speak first.
    final hidden = hiddenPrompt != null;
    final text = (hiddenPrompt ?? _messageController.text).trim();
    if (text.isEmpty || _isSending || !_clientReady || _session == null) return;

    setState(() {
      if (!hidden) _messages.add(_ChatMessage(text: text, isUser: true));
      if (!hidden) _messageController.clear();
      _isSending = true;
      _isThinking = true;
      _stopRequested = false;
    });
    final userMsgPk = hidden ? null : await _persist('user', text);

    try {
      final assistantBuffer = StringBuffer();
      var needNewBubble =
          true; // start a fresh assistant bubble after tool notes
      final reasoningBuffer = StringBuffer();
      int? reasoningIndex; // index of the live reasoning tile for this round

      // runTurn drives the tool loop and produces the final answer. Tool results
      // arrive via onToolResult (shown as system notes between answer segments).
      final stream = _session!.runTurn(
        text,
        // Discovery drafts + restructures a whole story tree in one turn, which
        // can burn several tool rounds before the agent gets to speak/ask — give
        // it more headroom than the normal chat so it never stops mid-build.
        maxToolRounds: _session!.discoveryMode ? 8 : 4,
        onTrace: (messages) {
          final id = widget.discoveryMode
              ? 'discovery:${widget.projectId}'
              : 'coordinator:${widget.projectId}:${_sessionId ?? 0}';
          ref.read(trainingSinkProvider).post(id, messages);
          // Persist the same rich trace locally for Account → Export Tracking.
          unawaited(
            ref.read(nexusDatabaseProvider).upsertTrainingTrace(
                  projectPk: widget.projectId,
                  aiKind: widget.discoveryMode ? 'stories' : 'coordinator',
                  conversationId: id,
                  messagesJson: jsonEncode(messages),
                ),
          );
        },
        onImage: (b64, caption) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              _ChatMessage(text: caption, isUser: false, imageB64: b64),
            );
            _isThinking = true;
          });
          needNewBubble = true;
          assistantBuffer.clear();
        },
        onToolResult: (r) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              _ChatMessage(text: '✓ $r', isUser: false, isSystem: true),
            );
            _isThinking =
                true; // back to "thinking" until the next content arrives
          });
          unawaited(_persist('system', '✓ $r'));
          needNewBubble = true;
          assistantBuffer.clear();
          // Each tool round gets its own think block.
          reasoningBuffer.clear();
          reasoningIndex = null;
        },
      );

      await for (final event in stream) {
        // Stop consuming ONLY when the widget is genuinely DISPOSED (project
        // switch, app close, re-init) — that cancels the turn and frees its
        // inference connection. When the chat is merely OFFSTAGE (another tab/
        // screen) it stays MOUNTED (the shell keeps the workspace alive via
        // Offstage), so `mounted` is still true here and the turn keeps running
        // in the background as intended. Without this break, a disposed chat's
        // in-flight turn would hold its connection open and pile up across the
        // re-inits that happen during startup/navigation → "too_many_connections"
        // (429), which even broke the live coordinator chat.
        if (!mounted || _stopRequested) break;
        if (event is ChatReasoningDelta) {
          reasoningBuffer.write(event.text);
          if (mounted) {
            setState(() {
              if (reasoningIndex == null) {
                _messages.add(
                  _ChatMessage(
                    text: reasoningBuffer.toString(),
                    isUser: false,
                    isReasoning: true,
                  ),
                );
                reasoningIndex = _messages.length - 1;
              } else {
                _messages[reasoningIndex!] = _ChatMessage(
                  text: reasoningBuffer.toString(),
                  isUser: false,
                  isReasoning: true,
                );
              }
              // Reasoning is streaming — we have live feedback, so drop the
              // opaque "thinking…" spinner.
              _isThinking = false;
            });
          }
        } else if (event is ChatContentDelta) {
          if (needNewBubble) {
            assistantBuffer
              ..clear()
              ..write(event.text);
            needNewBubble = false;
            if (mounted) {
              setState(() {
                _messages.add(
                  _ChatMessage(text: assistantBuffer.toString(), isUser: false),
                );
                _isThinking = false; // content is streaming now
              });
            }
          } else {
            assistantBuffer.write(event.text);
            if (mounted) {
              setState(
                () => _messages.last = _ChatMessage(
                  text: assistantBuffer.toString(),
                  isUser: false,
                ),
              );
            }
          }
        } else if (event is ChatStreamFinish) {
          final assistantText = assistantBuffer.toString().trim();
          if (assistantText.isNotEmpty) {
            await _persist('assistant', assistantText);
          }
          if (mounted) {
            setState(() {
              _isSending = false;
              _isThinking = false;
            });
          }
        }
      }
    } catch (e) {
      // The turn failed — drop the just-saved user message so it can't reload
      // as orphaned, role-breaking history on the next launch.
      if (userMsgPk != null) {
        try {
          await ref.read(nexusDatabaseProvider).deleteChatMessage(userMsgPk);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: "Error talking to coordinator: $e",
              isUser: false,
            ),
          );
          _isSending = false;
          _isThinking = false;
        });
      }
    }
  }

  void _toggleVoiceCall() async {
    if (!_clientReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Coordinator not ready — configure an inference server first.',
          ),
        ),
      );
      return;
    }

    final wasActive = _isVoiceCallActive;

    setState(() {
      _isVoiceCallActive = !_isVoiceCallActive;
      if (!_isVoiceCallActive) {
        _isMicMuted = false;
      }
    });

    if (_duplexVoiceSession != null) {
      if (_isVoiceCallActive && !wasActive) {
        // Start the real duplex call: VAD-driven continuous conversation (lemonade_mobile style).
        // User speaks → VAD detects end → full turn (STT + coordinator tools + TTS) → auto back to listening.
        await _duplexVoiceSession!.startCall();
      } else if (!_isVoiceCallActive && wasActive) {
        await _duplexVoiceSession!.endCall();
      }
    }
  }

  /// Mute / Unmute the microphone while in an active voice call.
  /// Only meaningful during a call. The mic button never starts/ends the call itself.
  void _toggleMicMute() {
    if (!_isVoiceCallActive || _duplexVoiceSession == null) return;

    setState(() {
      _isMicMuted = !_isMicMuted;
    });

    if (_isMicMuted) {
      _duplexVoiceSession!.pauseListening();
    } else {
      _duplexVoiceSession!.resumeListening();
    }
  }

  Future<void> _attachAndAnalyzeImage() async {
    // Vision can be added by sending an image message through the InferenceClient chat with image_url parts.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vision (image understanding) supported via multi-modal models — attach flow coming in next iteration.',
        ),
      ),
    );
  }

  Future<void> _generateImageForPlan() async {
    if (!_clientReady || _inferenceClient == null || _session == null) return;

    try {
      final response = await _session!.client.generateImage(
        prompt:
            'Professional project plan diagram for ${widget.projectName}. Clean, modern infographic style showing key phases and deliverables.',
        size: '1024x1024',
        // Carry the resolved image model — an empty id 502s on the router.
        model: _imageModel,
      );

      if (response.data.isNotEmpty) {
        final imageUrl = response.data.first.url;
        setState(() {
          _messages.add(
            _ChatMessage(
              text: 'Generated diagram for the plan:\n$imageUrl',
              isUser: false,
            ),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image generation failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _clientReady;
    final voiceActive = _isVoiceCallActive;

    // Keep the transcript pinned to the bottom as messages/tokens stream in,
    // unless the user has scrolled up to read history.
    _sticky.stickToBottom();

    // If the active session changes (e.g. picked in the sidebar) while we're
    // open, switch to it. ref.listen runs outside build, so setState is safe.
    ref.listen<int?>(currentChatSessionProvider(widget.projectId), (
      prev,
      next,
    ) {
      if (_clientReady && next != null && next != _sessionId) {
        _loadSession(next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Coordinator — ${widget.projectName}'),
        actions: [
          // Phone icon = Enter / Leave Voice Conversation with the Coordinator
          IconButton(
            icon: Icon(voiceActive ? Icons.call_end : Icons.call),
            onPressed: ready ? _toggleVoiceCall : null,
            tooltip: voiceActive
                ? 'End Voice Conversation'
                : 'Start Voice Conversation with Coordinator',
            color: voiceActive ? context.nx.danger : null,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: ready ? _attachAndAnalyzeImage : null,
            tooltip: 'Attach image for vision analysis',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: ready ? _generateImageForPlan : null,
            tooltip: 'Generate image / diagram for current plan',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: context.nx.glass,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Live project context • text + voice • AI can create/update tasks and propose plan changes in real time.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (_clientError != null)
                  Icon(Icons.warning, color: context.nx.warning, size: 18)
                else if (ready)
                  Icon(Icons.check_circle, color: context.nx.success, size: 18),
              ],
            ),
          ),

          if (_clientError != null)
            Container(
              width: double.infinity,
              color: context.nx.tintOf(context.nx.warning),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _clientError!,
                style: TextStyle(color: context.nx.warning),
              ),
            ),

          Expanded(
            // SelectionArea makes the whole transcript drag-selectable so the
            // user can copy exact quotes — markdown-rendered messages aren't
            // selectable on their own.
            child: SelectionArea(
              child: ListView.builder(
              controller: _sticky.controller,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                // Trailing "thinking" bubble while the assistant turn is in
                // flight but hasn't started streaming text yet.
                if (index >= _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: 'Stop',
                      // Tap the spinner to abort a stuck/looping turn.
                      child: InkWell(
                        borderRadius: AppRadius.lgAll,
                        onTap: _stopTurn,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: context.nx.glass,
                            borderRadius: AppRadius.lgAll,
                            border: Border.all(color: context.nx.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Spinner with a stop glyph centred to signal it's
                              // clickable.
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                    Icon(
                                      Icons.stop,
                                      size: 9,
                                      color: context.nx.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Coordinator is thinking… (tap to stop)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: context.nx.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final msg = _messages[index];
                final isSystem = msg.isSystem == true;
                final nx = context.nx;
                // A rateable assistant reply (text, not a user/system/reasoning
                // line or a bare image). Rated by a content hash so it lines up
                // with the exported trace regardless of position.
                final isAssistant =
                    !msg.isUser && !isSystem && !msg.isReasoning;

                // Reasoning ("thinking") blocks render as a collapsible tile so
                // a long think is visible (and inspectable for debugging) without
                // crowding the answer.
                if (msg.isReasoning) {
                  // "Active" while this reasoning block is the last thing in the
                  // list and the turn is still in flight — i.e. the model is
                  // currently thinking (no answer text after it yet). That drives
                  // the animated ellipsis so the user can tell it isn't stalled.
                  return _ReasoningTile(
                    text: msg.text,
                    active: _isSending && index == _messages.length - 1,
                  );
                }

                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : isSystem
                          ? nx.tintOf(nx.info)
                          : nx.glass,
                      borderRadius: AppRadius.lgAll,
                      border: msg.isUser
                          ? null
                          : Border.all(color: nx.hairline),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Assistant replies render as Markdown (code blocks, lists,
                        // **bold**, etc.); user text and system notes stay plain.
                        if (!msg.isUser && !isSystem)
                          ChatMarkdown(msg.text)
                        else
                          SelectableText(
                            msg.text,
                            style: TextStyle(
                              fontStyle: isSystem
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontSize: isSystem ? 13 : 14,
                            ),
                          ),
                        if (msg.imageB64 != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: AppRadius.mdAll,
                              child: Image.memory(
                                base64Decode(msg.imageB64!),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) =>
                                    const Text('(image failed to render)'),
                              ),
                            ),
                          ),
                        if (msg.audioPath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: InkWell(
                              onTap: () => _replayAudio(msg.audioPath!),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_circle_outline, size: 18),
                                  SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Play reply',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Star rating (training feedback) under each assistant
                        // reply. Image-only cards aren't rateable text replies.
                        if (isAssistant &&
                            msg.imageB64 == null &&
                            msg.text.trim().isNotEmpty)
                          RatedMessageBar(
                            projectId: widget.projectId,
                            aiKind: _ratingAiKind,
                            conversationId: _ratingConversationId,
                            messageRef: aiMessageRef(msg.text),
                          ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: voiceActive
                  // Voice message bar: waveform + status live in the composer area
                  // (instead of a big banner at the top of the screen)
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  // Status reflects the live voice state (not just
                                  // mute), so it never says "Listening" while the
                                  // assistant is thinking or speaking back.
                                  final primary = Theme.of(
                                    context,
                                  ).colorScheme.primary;
                                  IconData icon;
                                  String label;
                                  Color color;
                                  if (_isMicMuted) {
                                    icon = Icons.mic_off;
                                    label = 'Microphone muted';
                                    color = context.nx.danger;
                                  } else {
                                    switch (_voiceState) {
                                      case VoiceState.processing:
                                        icon = Icons.hourglass_top;
                                        label = 'Thinking…';
                                        color = primary;
                                      case VoiceState.speaking:
                                        icon = Icons.volume_up_rounded;
                                        label = 'Speaking…';
                                        color = primary;
                                      case VoiceState.listening:
                                        icon = Icons.mic;
                                        label = 'Listening… speak now';
                                        color = primary;
                                      default:
                                        icon = Icons.mic_none;
                                        label = 'Connecting…';
                                        color = context.nx.textMuted;
                                    }
                                  }
                                  return Row(
                                    children: [
                                      Icon(icon, size: 16, color: color),
                                      const SizedBox(width: 6),
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 2),
                              LiveMicVisualizer(
                                recorder: _voiceRecorder,
                                color: _isMicMuted
                                    ? context.nx.textMuted
                                    : Theme.of(context).colorScheme.primary,
                                height: 26,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isMicMuted ? Icons.mic_off : Icons.mic),
                          onPressed: _toggleMicMute,
                          tooltip: _isMicMuted
                              ? 'Unmute microphone'
                              : 'Mute microphone',
                          color: _isMicMuted ? context.nx.danger : null,
                        ),
                        // Convenient end-call button right in the message bar
                        IconButton(
                          icon: const Icon(Icons.call_end),
                          onPressed: _toggleVoiceCall,
                          tooltip: 'End voice conversation',
                          color: context.nx.danger,
                        ),
                      ],
                    )
                  // Normal text input bar when not in voice call
                  : Row(
                      children: [
                        Expanded(
                          child: SubmitOnEnter(
                            onSubmit: _sendMessage,
                            enabled: ready && !_isSending,
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: ready
                                    ? 'Tell the Coordinator what to do — Enter to send, Shift+Enter for a new line'
                                    : 'Configure an inference server in Agents Hub to enable the Coordinator',
                                border: const OutlineInputBorder(),
                              ),
                              enabled: ready && !_isSending,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          // While the AI is responding the send button becomes a
                          // STOP control — clickable the whole time (thinking AND
                          // while the answer streams), so an infinite/runaway
                          // stream can always be cut short. The stop glyph inside
                          // the wheel signals it's tappable.
                          tooltip: _isSending ? 'Stop' : 'Send',
                          icon: _isSending
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                      Icon(
                                        Icons.stop,
                                        size: 12,
                                        color: context.nx.danger,
                                      ),
                                    ],
                                  ),
                                )
                              : const Icon(Icons.send),
                          onPressed: _isSending
                              ? _stopTurn
                              : (ready ? _sendMessage : null),
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic),
                          onPressed: ready ? _toggleVoiceCall : null,
                          tooltip: 'Start Voice Conversation',
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A collapsible "Thinking…" block for a reasoning model's streamed reasoning
/// tokens. Default-expanded so a long think shows live progress (and is there to
/// inspect for debugging); tap the header to collapse.
class _ReasoningTile extends StatefulWidget {
  const _ReasoningTile({required this.text, this.active = false});
  final String text;

  /// True while the model is still emitting this reasoning block — drives the
  /// animated "Thinking…" ellipsis so the user can tell it isn't stalled.
  final bool active;

  @override
  State<_ReasoningTile> createState() => _ReasoningTileState();
}

class _ReasoningTileState extends State<_ReasoningTile> {
  // Collapsed by default so a long think doesn't crowd the chat — tap to expand.
  bool _open = false;
  Timer? _dotTimer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _startDots();
  }

  @override
  void didUpdateWidget(_ReasoningTile old) {
    super.didUpdateWidget(old);
    if (widget.active && _dotTimer == null) _startDots();
    if (!widget.active && _dotTimer != null) _stopDots();
  }

  void _startDots() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
  }

  void _stopDots() {
    _dotTimer?.cancel();
    _dotTimer = null;
    if (mounted) setState(() => _dots = 0);
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nx = context.nx;
    // "Thinking" + 0-3 trailing dots while active; plain "Thinking" once done.
    final label = widget.active ? 'Thinking${'.' * _dots}' : 'Thinking';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: nx.glass,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: nx.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: nx.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.psychology_outlined, size: 14, color: nx.textMuted),
                const SizedBox(width: AppSpacing.xs),
                // Fixed width so the animating dots don't shift the layout.
                SizedBox(
                  width: 64,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: nx.textMuted,
                    ),
                  ),
                ),
                Text(
                  _open ? 'hide' : 'show',
                  style: TextStyle(fontSize: 11, color: nx.textFaint),
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              widget.text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: nx.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool? isSystem;

  /// A reasoning ("thinking") block from a reasoning model — rendered as a
  /// collapsible tile, not a normal answer bubble. Ephemeral (not persisted).
  final bool isReasoning;

  /// Path to the synthesized reply audio (assistant voice turns only).
  final String? audioPath;

  /// Base64 PNG of an image the agent generated/edited — rendered inline.
  final String? imageB64;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isSystem,
    this.isReasoning = false,
    this.audioPath,
    this.imageB64,
  });
}
