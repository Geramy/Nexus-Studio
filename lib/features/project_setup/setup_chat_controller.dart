// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/lean_context_provider.dart';
import '../../infrastructure/database/nexus_database.dart';
import '../../infrastructure/registry/verification_service.dart';
import '../../infrastructure/workspace/workspace_provider.dart';
import '../../services/audio/audio_recorder_service.dart';
import '../../services/audio/coordinator_duplex_voice_session.dart'
    show VoiceState;
import '../../services/audio/setup_voice_session.dart';
import '../../services/audio/tts_service.dart';
import '../project_plans/plan_store.dart';
import 'config/setup_flow.dart';
import 'config/setup_flow_catalog.dart';
import 'setup_inference.dart';
import 'setup_session.dart';
import 'setup_tools.dart';

/// True while the Setup tab is the active workspace tab, so the MainShell right
/// outer panel can show the interview chat (instead of the Plan explorer).
final projectSetupModeProvider = StateProvider<bool>((ref) => false);

enum SetupMsgKind { user, assistant, thinking, tool, system, question }

/// One entry in the interview transcript. For [SetupMsgKind.question] the extra
/// fields drive the inline picker and carry the [completer] the tool awaits.
class SetupMsg {
  SetupMsg({
    required this.kind,
    required this.text,
    this.options = const [],
    this.multi = false,
    this.completer,
  });

  final SetupMsgKind kind;
  final String text;
  final List<String> options;
  final bool multi;
  final Completer<SetupAnswer>? completer;
  bool answered = false;
  List<String> selected = const [];

  /// Set when the user answered this question by TYPING rather than picking
  /// chips, so the card can show it was handled in chat (the typed words appear
  /// as their own bubble above).
  String? freeText;
}

/// Holds the live Project Setup interview (session + transcript) so the Tag
/// Board (center pane) and the interview chat (right outer panel) share one
/// state. Lives at project scope via [setupChatControllerProvider].
class SetupChatController extends ChangeNotifier {
  SetupChatController(this._ref, this.projectId, this.clientId);

  final Ref _ref;
  final int projectId;
  final int clientId;

  final List<SetupMsg> messages = [];
  bool busy = false;
  String? error;

  /// True once the plans have been generated and the host is helping the user
  /// flesh them out (free-text). Drives the Setup tab's action bar (Finalize →
  /// Done refining) and the composer hint.
  bool refining = false;

  SetupSession? _session;
  bool _restored = false;

  /// Resolved backend + per-modality models, captured by [_ensureSession] so
  /// voice "call mode" reuses the exact server/model the interview talks to.
  ResolvedInference? _resolved;

  SetupVoiceSession? _voice;
  AudioRecorderService? _voiceRecorder;
  StreamSubscription<VoiceState>? _voiceStateSub;
  bool _startingCall = false;

  /// Live voice state for the call-mode UI (idle when not in a call).
  VoiceState voiceState = VoiceState.idle;

  bool get callActive => _voice?.isActive ?? false;

  /// Whether the user has muted their mic during call mode.
  bool get micMuted => _voice?.isMuted ?? false;

  /// Toggle the mic mute (mute button / "m" hotkey). No-op when not in a call.
  void toggleMicMute() {
    final v = _voice;
    if (v == null || !v.isActive) return;
    v.toggleMute();
    notifyListeners();
  }

  /// The recorder backing the active call, so the panel can show live levels.
  AudioRecorderService? get voiceRecorder => _voiceRecorder;

  /// Seed the visible transcript from persisted text turns (display-only; the
  /// LLM history restarts) so reopening setup shows the prior conversation.
  Future<void> restoreOnce() async {
    if (_restored) return;
    _restored = true;
    try {
      final project = await _ref
          .read(nexusDatabaseProvider)
          .getProjectById(projectId);
      // Reopening a project that was mid-refinement resumes that stage.
      if (project?.setupStatus == 'refining') refining = true;
      final raw = project?.setupTranscriptJson;
      if (raw == null || raw.isEmpty) return;
      final turns = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      for (final t in turns) {
        final role = t['role']?.toString();
        final content = t['content']?.toString() ?? '';
        if (content.isEmpty) continue;
        messages.add(
          SetupMsg(
            kind: role == 'user' ? SetupMsgKind.user : SetupMsgKind.assistant,
            text: content,
          ),
        );
      }
      notifyListeners();
    } catch (_) {
      // Malformed/legacy transcript — ignore, start fresh.
    }
  }

  Future<SetupSession?>? _sessionFuture;

  /// Lazily builds the setup session ONCE. Memoizes the in-flight future so two
  /// concurrent callers (e.g. finalize() + completeSetup()/send()) can't each
  /// run the full init and orphan a duplicate SetupSession.
  Future<SetupSession?> _ensureSession() {
    if (_session != null) return Future<SetupSession?>.value(_session);
    return _sessionFuture ??= _buildSession();
  }

  Future<SetupSession?> _buildSession() async {
    try {
      return await _buildSessionInner();
    } finally {
      // Let a later attempt rebuild if this one failed to produce a session.
      if (_session == null) _sessionFuture = null;
    }
  }

  Future<SetupSession?> _buildSessionInner() async {
    if (_session != null) return _session;
    final resolved = await _ref.read(
      projectInferenceProvider((
        projectId: projectId,
        clientId: clientId,
      )).future,
    );
    if (resolved == null) {
      error =
          'No inference server configured. Add one in Agents Hub to use the AI interview — you can still edit tags manually.';
      notifyListeners();
      return null;
    }
    _resolved = resolved;
    final db = _ref.read(nexusDatabaseProvider);
    final planStore = await _ref.read(planStoreProvider(projectId).future);
    // Resolve the configurable setup flow FIRST so the executor can enforce its
    // required stages: the host's `finalize_setup` is gated on every required
    // section having a tag (no finalizing a half-filled profile).
    final flow = await _resolveFlow(db);
    final executor = SetupToolExecutor(
      db: db,
      projectPk: projectId,
      verification: _ref.read(verificationServiceProvider),
      planStore: planStore,
      askQuestion: _askQuestion,
      onPlansChanged: _bumpWorkspace,
      requiredCategories: _requiredCategories(flow),
    );
    _session = SetupSession(
      client: resolved.backend,
      model: resolved.model,
      projectName: 'Project',
      executor: executor,
      flow: flow,
      enableThinking: resolved.enableThinking,
      leanContext: _ref.read(leanContextNotifierProvider),
    );
    // If we resumed into refinement (or already finalized), start in refine.
    if (refining) _session!.enterRefinePhase();
    return _session;
  }

  /// Resolve the configurable setup flow for this project's type + sub-category
  /// (DB-stored, falling back to the built-in catalog).
  Future<SetupFlowDefinition> _resolveFlow(NexusDatabase db) async {
    final proj = await db.watchProject(projectId).first;
    final flowType = proj?.projectType ?? 'application-development';
    final flowSub = proj?.subCategory;
    final flowJson = await db.resolveSetupFlowJson(flowType, flowSub);
    if (flowJson != null) {
      try {
        return SetupFlowDefinition.fromJson(
          jsonDecode(flowJson) as Map<String, dynamic>,
        );
      } catch (_) {
        // Malformed stored flow — fall back to the built-in for this type.
      }
    }
    return resolveBuiltinSetupFlow(flowType, flowSub);
  }

  /// Stage key → label for the flow's required stages (drives the finalize gate).
  Map<String, String> _requiredCategories(SetupFlowDefinition flow) => {
    for (final s in flow.stages)
      if (s.required) s.key: s.title,
  };

  /// Required setup sections (and unanswered industry sub-axes like Genre) still
  /// missing a tag, as human labels. Empty ⇒ ready to generate the plan. The
  /// "Generate plan & continue" button calls this to block an early/incomplete
  /// finalize, matching the gate the AI's `finalize_setup` already enforces.
  Future<List<String>> setupCompletenessGaps() async {
    final db = _ref.read(nexusDatabaseProvider);
    final flow = await _resolveFlow(db);
    final executor = SetupToolExecutor(
      db: db,
      projectPk: projectId,
      verification: _ref.read(verificationServiceProvider),
      planStore: null,
      requiredCategories: _requiredCategories(flow),
    );
    return executor.missingRequiredLabels();
  }

  /// Re-walks the project's /PLANS tree so the explorer + open Plan tab reflect
  /// freshly generated or edited plan files.
  void _bumpWorkspace() {
    _ref.read(workspaceRevisionProvider(projectId).notifier).state++;
  }

  /// Presents a bounded question inline and returns the user's pick(s). The
  /// future completes when they answer/skip — nothing is lost by looking away.
  Future<SetupAnswer> _askQuestion(
    String question,
    List<String> options,
    bool multi,
  ) {
    final completer = Completer<SetupAnswer>();
    final msg = SetupMsg(
      kind: SetupMsgKind.question,
      text: question,
      options: options,
      multi: multi,
      completer: completer,
    );
    messages.add(msg);
    notifyListeners();
    // In call mode, speak the question and let the next utterance answer it.
    // The on-screen picker stays live, so a tap still works (whichever first).
    if (_voice?.isActive ?? false) {
      unawaited(
        _voice!.armQuestion(
          question: question,
          options: options,
          multi: multi,
          onResolved: (picks) => answerQuestion(msg, picks),
          isAnswered: () => msg.answered,
        ),
      );
    }
    return completer.future;
  }

  /// The most recent inline question still awaiting an answer, if any. Drives
  /// the composer: while one is pending the user can TYPE a reply (see
  /// [answerQuestionWithText]) instead of being forced to click chips.
  SetupMsg? get pendingQuestion {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.kind == SetupMsgKind.question && !m.answered) return m;
    }
    return null;
  }

  void answerQuestion(SetupMsg msg, List<String> picks) {
    if (msg.answered) return;
    // A tap (or a mapped voice answer) wins; cancel any pending voice capture.
    _voice?.disarmQuestion();
    msg.answered = true;
    msg.selected = picks;
    notifyListeners();
    if (!(msg.completer?.isCompleted ?? true)) {
      msg.completer!.complete(SetupAnswer.picks(picks));
    }
  }

  /// Answers a pending inline question by free text typed in the composer. The
  /// words show as the user's own chat bubble, the card locks (so it stops
  /// blocking), and the host receives the reply verbatim and reacts — this is
  /// the natural, conversation-first path; the chip picker is the fallback.
  void answerQuestionWithText(SetupMsg msg, String text) {
    final trimmed = text.trim();
    if (msg.answered || trimmed.isEmpty) return;
    _voice?.disarmQuestion();
    msg.answered = true;
    msg.freeText = trimmed;
    // Echo the typed answer as a normal user turn in the transcript.
    messages.add(SetupMsg(kind: SetupMsgKind.user, text: trimmed));
    notifyListeners();
    if (!(msg.completer?.isCompleted ?? true)) {
      msg.completer!.complete(SetupAnswer.text(trimmed));
    }
  }

  void _append(SetupMsg msg) {
    messages.add(msg);
    notifyListeners();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || busy) return;
    busy = true;
    error = null;
    messages.add(SetupMsg(kind: SetupMsgKind.user, text: text.trim()));
    notifyListeners();

    await _ref
        .read(nexusDatabaseProvider)
        .setProjectSetupStatus(projectId, 'inProgress');
    try {
      final session = await _ensureSession();
      if (session == null) return;
      final reply = await session.send(
        text.trim(),
        onThinking: (r) =>
            _append(SetupMsg(kind: SetupMsgKind.thinking, text: r)),
        onAssistantText: (t) {
          _append(SetupMsg(kind: SetupMsgKind.assistant, text: t));
          if (_voice?.isActive ?? false) unawaited(_voice!.speak(t));
        },
        onToolCall: (name, args) => _append(
          SetupMsg(
            kind: SetupMsgKind.tool,
            text: _describeToolCall(name, args),
          ),
        ),
        onToolResult: (name, result) =>
            _append(SetupMsg(kind: SetupMsgKind.system, text: '✓ $result')),
      );
      await _ref
          .read(nexusDatabaseProvider)
          .setProjectSetupTranscript(projectId, session.toTranscriptJson());
      // The host may finalize on its own during a turn; surface the refine UI.
      if (!refining && session.phase == SetupPhase.refine) {
        _enterRefineUi();
      }
      if (reply.trim().isEmpty &&
          (messages.isEmpty || messages.last.kind != SetupMsgKind.assistant)) {
        _append(
          SetupMsg(
            kind: SetupMsgKind.system,
            text: 'Updated your tags on the board.',
          ),
        );
      }
    } catch (e) {
      error = 'Interview failed: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Generates the plan files, bumps the workspace revision so the Plan explorer
  /// re-walks, and enters the REFINE stage (the host now helps flesh the plans
  /// out). Returns the human-readable result for a snackbar.
  Future<String> finalize() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final db = _ref.read(nexusDatabaseProvider);
      final planStore = await _ref.read(planStoreProvider(projectId).future);
      final flow = await _resolveFlow(db);
      final executor = SetupToolExecutor(
        db: db,
        projectPk: projectId,
        verification: _ref.read(verificationServiceProvider),
        planStore: planStore,
        requiredCategories: _requiredCategories(flow),
      );
      final result = await executor.execute('finalize_setup', const {});
      _bumpWorkspace();
      // Flip the live session (if any) and surface the refine guidance.
      (await _ensureSession())?.enterRefinePhase();
      _enterRefineUi();
      return result;
    } catch (e) {
      error = 'Finalize failed: $e';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Generate the `/PLANS` files only — NO status flip, NO refine UI. Used by the
  /// "continue to user stories" button path, which has already called
  /// [completeSetup] (setupStatus='complete', explorationStatus='active'). The
  /// old `finalize()` path here would re-write setupStatus to 'refining' and
  /// clobber that, so this variant runs just the plan generation in the
  /// background while the user moves on to the Exploration screen.
  Future<void> finalizePlansOnly() async {
    final db = _ref.read(nexusDatabaseProvider);
    final planStore = await _ref.read(planStoreProvider(projectId).future);
    final executor = SetupToolExecutor(
      db: db,
      projectPk: projectId,
      verification: _ref.read(verificationServiceProvider),
      planStore: planStore,
    );
    await executor.generatePlans();
    _bumpWorkspace();
  }

  /// Posts the in-chat hand-off message that kicks off refinement and flips the
  /// action bar to "Done refining". Idempotent — safe to call from either the
  /// button path or when the host finalizes on its own.
  void _enterRefineUi() {
    if (refining) return;
    refining = true;
    _append(
      SetupMsg(
        kind: SetupMsgKind.assistant,
        text:
            'Your plans are generated — check the Plan tab to see them. '
            "Now let's flesh them out. Tell me how you picture the UI: the key "
            'screens, how they\'re laid out, and what each one does. I\'ll fold '
            'your descriptions into the right plan. When you\'re happy, hit '
            '"Done refining" to start turning the plans into tasks.',
      ),
    );
    notifyListeners();
  }

  /// Ends refinement and kicks off the deep planning run: a planning agent
  /// expands the brief into a granular plan, the engineer agents review it until
  /// a majority sign off, the outline items become small tasks, and the
  /// orchestrator starts. Progress streams into the interview chat. Marks setup
  /// `complete`. Falls back to a plain deterministic plan→task sync when no
  /// inference server is configured (so setup still completes offline).
  /// Finish setup and enter the post-setup **Exploration** phase. Crucially we
  /// NO LONGER generate tasks here — that was "too eager". Instead the project
  /// moves into discovery: the Coordinator interviews the user and builds the
  /// user-story tree, and tasks are only created later when the user presses
  /// "Generate tasks from stories" (see `TaskGenerator` in task_generator.dart).
  Future<void> completeSetup() async {
    refining = false;
    final db = _ref.read(nexusDatabaseProvider);
    busy = true;
    notifyListeners();
    try {
      await db.setProjectSetupStatus(projectId, 'complete');
      await db.setProjectExplorationStatus(projectId, 'active');
      _bumpWorkspace();
      _append(
        SetupMsg(
          kind: SetupMsgKind.system,
          text:
              'Setup complete. Let\'s explore the idea — I\'ll ask a few '
              'questions and build out your user stories before any tasks are '
              'created.',
        ),
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }


  Future<void> skip() async {
    await _ref
        .read(nexusDatabaseProvider)
        .setProjectSetupStatus(projectId, 'skipped');
  }

  /// Starts hands-free "call mode": speaks the interview aloud and answers its
  /// multiple-choice questions by voice (the on-screen picker still works too).
  Future<void> startVoiceCall() async {
    // Guard against re-entrancy: isActive only flips true after startCall()'s
    // awaits, so a second tap (or rebuild) could otherwise spin up a parallel
    // mic + VAD session, multiplying the echo and CPU load.
    if (callActive || _startingCall) return;
    _startingCall = true;
    try {
      await _startVoiceCall();
    } finally {
      _startingCall = false;
    }
  }

  Future<void> _startVoiceCall() async {
    // Tear down any stale session before starting a fresh one.
    if (_voice != null) await endVoiceCall();
    error = null;
    // Resolve the same backend/model the typed interview uses.
    final session = await _ensureSession();
    final resolved = _resolved;
    if (session == null || resolved == null) return;

    _voiceRecorder = AudioRecorderService();
    final tts = TtsService(
      inferenceClient: resolved.backend,
      ttsModel: resolved.ttsModel,
      defaultVoice: resolved.ttsVoice,
    );
    final voice = SetupVoiceSession(
      backend: resolved.backend,
      recorder: _voiceRecorder!,
      tts: tts,
      sttModel: resolved.sttModel,
      onFreeUtterance: (t) => send(t),
      onSystemNote: (n) =>
          _append(SetupMsg(kind: SetupMsgKind.system, text: n)),
    );
    _voice = voice;
    _voiceStateSub = voice.state.listen((s) {
      voiceState = s;
      notifyListeners();
    });

    try {
      await voice.startCall();
    } catch (e) {
      // Only surface/teardown if THIS session is still the active one — a
      // concurrent endVoiceCall()/dispose() may have already replaced it.
      if (_voice == voice) {
        error = 'Could not start the call: $e';
        await endVoiceCall();
        notifyListeners();
      }
      return;
    }
    // startCall() awaited; if the session was torn down meanwhile (hang-up,
    // dispose, or a fresh start), `voice` is now disposed — don't arm a greeting
    // or question on a dead session (use-after-dispose window).
    if (_voice != voice) return;
    notifyListeners();

    // If the interview is parked on an unanswered question, re-arm it; otherwise
    // greet and wait for the user to speak (their first utterance starts a turn).
    SetupMsg? pendingQuestion;
    for (final m in messages.reversed) {
      if (m.kind == SetupMsgKind.question && !m.answered) {
        pendingQuestion = m;
        break;
      }
    }
    if (pendingQuestion != null) {
      final q = pendingQuestion;
      unawaited(
        voice.armQuestion(
          question: q.text,
          options: q.options,
          multi: q.multi,
          onResolved: (picks) => answerQuestion(q, picks),
          isAnswered: () => q.answered,
        ),
      );
    } else {
      final started = messages.any(
        (m) =>
            m.kind == SetupMsgKind.assistant || m.kind == SetupMsgKind.question,
      );
      unawaited(
        voice.speak(
          started
              ? 'Call started. Say "go ahead" to continue, or tell me more about your project.'
              : 'Call started. Tell me about your project and I\'ll start the interview.',
        ),
      );
    }
  }

  Future<void> endVoiceCall() async {
    final voice = _voice;
    _voice = null;
    await _voiceStateSub?.cancel();
    _voiceStateSub = null;
    await voice?.dispose();
    await _voiceRecorder?.dispose();
    _voiceRecorder = null;
    voiceState = VoiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceStateSub?.cancel();
    _voice?.dispose();
    _voiceRecorder?.dispose();
    super.dispose();
  }

  String _describeToolCall(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'ask_question':
        return 'Asking: "${args['question'] ?? ''}"';
      case 'lookup_package':
        return 'Verifying ${args['name'] ?? '?'} (${args['ecosystem'] ?? '?'})…';
      case 'propose_tags':
        final tags = (args['tags'] as List?) ?? const [];
        final names = tags
            .whereType<Map>()
            .map((t) => t['value']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ');
        return 'Proposing tags: $names';
      case 'finalize_setup':
        return 'Finalizing setup & generating plans…';
      case 'list_plans':
        return 'Looking over the plan files…';
      case 'read_plan':
        return 'Reading ${_planName(args['path'])}…';
      case 'update_plan':
        return 'Updating ${_planName(args['path'])}…';
      default:
        return 'Running $name…';
    }
  }

  static String _planName(Object? path) {
    final s = path?.toString() ?? '';
    return s.isEmpty ? 'a plan' : s.split('/').last;
  }
}

/// Project-scoped interview controller, shared by the board and the chat panel.
final setupChatControllerProvider =
    ChangeNotifierProvider.family<
      SetupChatController,
      ({int projectId, int clientId})
    >((ref, key) {
      return SetupChatController(ref, key.projectId, key.clientId);
    });
