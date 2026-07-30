// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';

import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart';
// Backward-compat types (InferenceClient = InferenceBackend).
import 'package:nexus_projects_client/infrastructure/inference/inference_client.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/api/exceptions.dart'
    show LemonadeApiException;
import 'package:nexus_projects_client/infrastructure/lemonade/services/persona_model_resolver.dart'
    show kDefaultOmniCollection;
import 'package:nexus_projects_client/features/projects/coordinator_tools.dart';
import 'package:nexus_projects_client/features/projects/project_baseline.dart'
    show buildProjectBaseline;
import 'package:nexus_projects_client/features/agents/agent_tool_permissions.dart';
import 'package:nexus_projects_client/features/project_plans/plan_store.dart';
import 'package:nexus_projects_client/infrastructure/workspace/async_lock.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';
import 'package:nexus_projects_client/infrastructure/build/build_service.dart';
import 'package:nexus_projects_client/core/agents/loop_guard.dart';
import 'package:nexus_projects_client/features/projects/orchestration/orchestrator_prompts.dart';

/// Manages a conversation with a Project's Coordinator AI (the "main brain").
/// Now supports real tool execution against the live DB so the AI can adjust
/// plans and tasks during text or voice conversations.
class ProjectCoordinatorSession {
  /// Concrete inference backend for this session.
  final InferenceBackend client;
  final int projectId;
  final String projectName;
  final NexusDatabase?
  db; // When provided, enables live tool execution + rich context

  /// The chat model to use. When null/empty we fall back to a generic id, but
  /// callers should pass the server's selected model so requests don't 404.
  final String? model;

  /// The image-generation model id (for generate_diagram). Resolved from the
  /// agent's Omni collection / server; threaded into the tool executor so image
  /// requests carry a real model id instead of an empty one (router 502).
  final String? imageModel;

  /// When this conversation is about a specific plan, the AI can read/rewrite it
  /// (view_plan / update_plan) and any tasks it creates record the provenance.
  /// This is the plan's workspace path, e.g. `/PLANS/Roadmap.md`.
  final String? openPlanPath;

  /// Filesystem-backed plan store for the project workspace; enables the plan
  /// tools (plans are real files under /PLANS, not DB rows).
  final PlanStore? planStore;

  /// The persisted chat session this conversation belongs to (for task provenance).
  final int? chatSessionPk;

  /// Tool-safety: the active agent's effective tool permissions and the
  /// human-approval hook for "ask" tools. [agentName] is used in messages.
  final AgentToolPermissions permissions;
  final Future<bool> Function(String tool, String summary)? confirmAsk;
  final String agentName;

  /// Workspace + git + build access for the file/git/build tools. Optional so a
  /// session can run without them (tools just report "unavailable").
  final Workspace? workspace;
  final NxtprjGitEngine? git;
  final BuildService? buildService;

  /// When set, replaces the built-in Coordinator system prompt entirely. The
  /// autonomous worker-spawn loop uses this to give an ephemeral worker its
  /// role-specific prompt (defaultSystemPrompt(role)) plus the task brief.
  final String? systemPromptOverride;

  /// Deep-planning signal hooks (see [CoordinatorToolExecutor]). When set, the
  /// matching planner-only tool is offered: [onPlanningComplete] (planner says
  /// the plan is done) and [onPlanReview] (an engineer reviewer's verdict).
  final void Function()? onPlanningComplete;
  final void Function(bool approved, String gaps)? onPlanReview;

  /// Per-task isolation for an orchestrated worker: [workBranch] is the task's
  /// branch and [gitLane] serializes shared git-DB writes, so `git_commit`
  /// snapshots the isolated [workspace] tree onto its branch concurrency-safely.
  final String? workBranch;
  final AsyncLock? gitLane;

  /// Orchestrator file-claim guard (workers only): true if this task may edit the
  /// given path, false if another task currently holds it. Plumbed to the tool
  /// executor so same-file work is queued instead of producing merge conflicts.
  final bool Function(String path)? fileClaim;

  final List<Map<String, dynamic>> _history = [];

  /// Append-only FULL trace for training export: mirrors the real
  /// user/assistant/tool messages PLUS the model's reasoning ('thinking'), in
  /// order. Separate from [_history] (the wire context) so the model never sees
  /// the 'thinking' entries and the trace keeps tool calls + thoughts.
  final List<Map<String, dynamic>> _fullTrace = [];
  final StringBuffer _reasonBuf = StringBuffer();

  /// Anti-runaway guards for the (often local/GGUF) coordinator + discovery
  /// model. Without a repeat penalty a weak model can loop on its own reasoning
  /// forever ("I'll add the root story. Then I'll ask the question. Let's do
  /// it." repeated for thousands of lines, never emitting a tool call). A mild
  /// [_kRepeatPenalty] breaks that degenerate loop; [_kMaxCompletionTokens] is a
  /// hard backstop that bounds any round that still runs away (the turn then
  /// ends with no tool call and the existing anti-stall nudge re-prompts it).
  static const double _kRepeatPenalty = 1.15;
  static const int _kMaxCompletionTokens = 8192;

  /// Detects when the coordinator agent gets stuck repeating the same tool call
  /// (same name + args) across rounds/turns and escalates warn → block so the
  /// model breaks out instead of burning rounds. The round cap is the backstop.
  final LoopGuard _loopGuard = LoopGuard();

  ProjectCoordinatorSession({
    required this.client,
    required this.projectId,
    required this.projectName,
    this.db,
    this.model,
    this.imageModel,
    this.openPlanPath,
    this.planStore,
    this.chatSessionPk,
    this.permissions = AgentToolPermissions.allDefaults,
    this.confirmAsk,
    this.agentName = 'This agent',
    this.workspace,
    this.git,
    this.buildService,
    this.systemPromptOverride,
    this.enableThinking,
    this.leanTools = true,
    this.onPlanningComplete,
    this.onPlanReview,
    this.workBranch,
    this.gitLane,
    this.fileClaim,
    this.discoveryMode = false,
    this.scaffoldMode = false,
    this.fixMode = false,
    this.editorMode = false,
  });

  /// Post-setup Exploration (discovery) mode: the model is offered ONLY the
  /// user-story tools (build the story tree) — no task/plan-write tools — so it
  /// can't generate work before the user presses "Generate tasks". The
  /// discovery framing is supplied via [systemPromptOverride].
  final bool discoveryMode;

  /// Templater (base-scaffold) mode: the model is offered ONLY file/git/CI tools
  /// — no image/story/task/plan/orchestration tools — so the scaffolder lays down
  /// a compiling base + stubs and nothing else. Framing via [systemPromptOverride].
  final bool scaffoldMode;

  /// End-of-project Testing fix mode: like [scaffoldMode] but file/git ONLY (no
  /// CI/build tools) — the Testing phase re-runs CI itself and the generalist
  /// persona denies the CI tools, so the fixer just reads/edits/commits.
  final bool fixMode;

  /// Post-COMPLETION Editor mode: the user-facing maintenance chat for a project
  /// whose autonomous build has finished (orchestrationState == 'completed').
  /// Offered the file/git/build/CI tool set up front (like the scaffolder) so it
  /// can edit the built app on `main`, verify it still analyzes/builds, and
  /// commit — but none of the story/task-orchestration tools. Framing via
  /// [systemPromptOverride] ([buildEditorPrompt]).
  final bool editorMode;

  /// When true (default), only the core task/plan tools are offered each turn;
  /// the file/git/CI groups are pulled in on demand via `request_tools`, cutting
  /// the per-call tool payload. When false, all tools are offered every turn.
  final bool leanTools;

  /// Tool names gated behind `request_tools`, grouped by capability. Kept out of
  /// the default payload; the model unlocks a group when it needs it.
  static const Map<String, Set<String>> _gatedToolGroups = {
    'files': {
      'list_files',
      'read_file',
      'write_file',
      'create_directory',
      'move_path',
      'delete_path',
      'delete_file',
      'delete_folder',
    },
    'git': {
      'git_status',
      'git_log',
      'git_commit',
      'git_branches',
      'git_create_branch',
      'git_checkout_branch',
    },
    'ci': {'build_docker_image', 'run_workflow', 'list_ci_runs', 'get_ci_run'},
  };

  /// Tool groups unlocked this conversation via `request_tools`.
  final Set<String> _unlockedToolGroups = {};

  /// Effective model "thinking mode" for this session's requests: true/false
  /// forces `enable_thinking`; null omits it (model default). Resolved by the
  /// caller from the agent's (and, later, the task's) ThinkingMode.
  final bool? enableThinking;

  /// The model id actually sent to the backend.
  String get _effectiveModel => (model != null && model!.trim().isNotEmpty)
      ? model!.trim()
      : kDefaultOmniCollection;

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  /// A full OpenAI-shape conversation trace (system + history) for the training
  /// sink. [sys] is the system prompt used this turn.
  List<Map<String, dynamic>> _traceMessages(String sys) => [
        {'role': 'system', 'content': sys},
        ..._fullTrace,
      ];

  /// Drop tools this agent is DENIED so the model only ever sees a schema it may
  /// actually call. Each agent's permissions are unique (worker, verifier, PM,
  /// coordinator each deny a different set), so this shrinks the per-call payload
  /// to that agent's real toolset — the Generalist worker, for instance, sheds
  /// ~20 task/plan/verifier/push tools it can't use. The `_gate` still enforces
  /// `ask`/`deny` at call time; this just stops paying tokens to advertise a tool
  /// the agent can't invoke. No-op for an agent on all-defaults (nothing denied).
  List<Map<String, dynamic>> _permittedTools(List<Map<String, dynamic>> all) {
    return all.where((t) {
      final name = (t['function'] as Map?)?['name']?.toString() ?? '';
      if (name.isEmpty) return true;
      return permissions.permFor(name) != ToolPerm.deny;
    }).toList();
  }

  /// Filter the full tool list to those active right now: every non-gated tool,
  /// plus the tools of any unlocked group, plus the `request_tools` meta-tool.
  /// Denied tools are always removed first (see [_permittedTools]); when
  /// [leanTools] is off, the permitted list is returned as-is.
  List<Map<String, dynamic>> _effectiveTools(List<Map<String, dynamic>> all) {
    final permitted = _permittedTools(all);
    if (!leanTools) return permitted;
    final hidden = <String>{};
    _gatedToolGroups.forEach((group, names) {
      if (!_unlockedToolGroups.contains(group)) hidden.addAll(names);
    });
    final out = permitted.where((t) {
      final name = (t['function'] as Map?)?['name']?.toString() ?? '';
      return !hidden.contains(name);
    }).toList();
    out.add(_requestToolsSchema);
    return out;
  }

  static const Map<String, dynamic> _requestToolsSchema = {
    'type': 'function',
    'function': {
      'name': 'request_tools',
      'description':
          'Unlock an additional group of tools for this conversation when you '
          'need it, then use them on your next step. Groups: "files" '
          '(read/write project files), "git" (repo status/commit/branches), '
          '"ci" (build images, run CI workflows, read CI logs).',
      'parameters': {
        'type': 'object',
        'properties': {
          'group': {
            'type': 'string',
            'enum': ['files', 'git', 'ci'],
          },
        },
        'required': ['group'],
      },
    },
  };

  /// Builds rich live context from the DB when available (tasks + future plan metadata).
  Future<String> getRichProjectContext() async {
    if (db == null) {
      return 'Project "$projectName" (no live DB context available in this session).';
    }
    try {
      final tasks = await db!.getTasksForProject(projectId);
      if (tasks.isEmpty) {
        return 'Project "$projectName": No tasks yet. The user is likely starting planning.';
      }
      final buffer = StringBuffer();
      buffer.writeln('Project: $projectName (id: $projectId)');
      buffer.writeln('Current tasks (${tasks.length} total):');
      for (final t in tasks.take(12)) {
        final parent = t.task_parent_fk != null
            ? ' (sub of ${t.task_parent_fk})'
            : '';
        buffer.writeln('- ${t.title} [${t.priority}] — ${t.status}$parent');
      }
      if (tasks.length > 12)
        buffer.writeln('... and ${tasks.length - 12} more.');
      return buffer.toString();
    } catch (e) {
      return 'Project "$projectName": context temporarily unavailable ($e).';
    }
  }

  /// Builds the system prompt with current project context.
  Future<String> _buildSystemPrompt({String? currentPlanContext}) async {
    // An ephemeral worker/verifier session supplies its own complete prompt
    // (role brief + task context); use it verbatim instead of the Coordinator's.
    if (systemPromptOverride != null &&
        systemPromptOverride!.trim().isNotEmpty) {
      return systemPromptOverride!;
    }
    final buffer = StringBuffer();
    // Behavioral preamble: editable via the Prompts tab (coordinatorSystem); the
    // live context + tool catalog below are still generated in code.
    final proj = db != null ? await db!.getProjectById(projectId) : null;
    final preamble = OrchestratorPrompts.fromJson(proj?.orchestratorPromptsJson)
        .raw(OrchestratorPromptField.coordinatorSystem)
        .replaceAll('{projectName}', projectName);
    buffer.writeln(preamble);
    // Inject the authoritative project baseline (the setup tags: platforms,
    // stack, objectives, features, databases, libraries, services) so the
    // Coordinator SEES the project profile and writes concrete, stack-specific
    // tasks from it (e.g. "Create the PostgreSQL tables …", "Write the Dart …").
    if (db != null) {
      buffer.writeln();
      buffer.writeln(await buildProjectBaseline(db!, projectId));
    }

    final live = currentPlanContext ?? await getRichProjectContext();
    if (live.isNotEmpty) {
      buffer.writeln('\nLive project context:\n$live');
    }

    // When focused on a plan, load its current document so the AI can adjust it.
    if (openPlanPath != null && planStore != null) {
      try {
        final content = await planStore!.read(openPlanPath!);
        final name = _basename(openPlanPath!);
        buffer.writeln(
          '\nYou are editing the plan document "$name". Its current contents:\n"""\n$content\n"""',
        );
        buffer.writeln(
          'To change the plan, call update_plan with the full new contents (markdown). To re-read it, call view_plan. Tasks you create from this plan are automatically linked to it.',
        );
      } catch (_) {}
    }

    final planFocus = openPlanPath != null ? 'view_plan, update_plan, ' : '';
    buffer.writeln(
      '\nYou have FULL read/create/update/delete control. Available tools:',
    );
    buffer.writeln(
      '- Tasks: list_tasks, get_task, create_task (use parent_task_id for subtasks), update_task, update_task_status, set_task_dates, delete_task.',
    );
    buffer.writeln(
      '  Thinking mode: when you create_task/update_task you may set `thinking_enabled: true`, but ONLY when the task is a small, very specific, cut-and-dry job (one narrow, well-defined feature). Do NOT enable thinking for large, broad, or open-ended tasks — on long/open-ended context, thinking mode degrades the response and outcome by about 15%, making results worse. Default to leaving thinking_enabled off (omit it) unless the job is narrow and clearly scoped.',
    );
    buffer.writeln(
      '- Agents: list_agents (call this to discover who exists), assign_agent_to_task. ALWAYS list_agents before assigning so you use a real agent id.',
    );
    buffer.writeln(
      'CRITICAL: every task MUST be assigned to a worker agent. When you create_task, pass agent_persona_id (call list_agents first to pick the best-fit specialist). Never leave a task unassigned — an unassigned task is invisible to the orchestrator and never gets worked. If you create a task without naming an agent, a default worker is auto-assigned, but you should choose the right one.',
    );
    buffer.writeln(
      '- Plans→tasks: when the user changes the idea, edit the PLAN first — add/adjust "- [ ] …" outline items in the relevant plan doc (update_plan/write_plan). Every plan write AUTOMATICALLY creates tasks for any new outline items (each line is annotated with its task id, so edits never double-create). Tell the user which tasks were created. sync_plans_to_tasks is also available to run the same pass on demand.',
    );
    buffer.writeln(
      '- Plans: list_plans, create_plan, read_plan, write_plan, rename_plan, delete_plan, link_task_to_plan. ${planFocus.isNotEmpty ? '($planFocus operate on the currently-open plan.) ' : ''}',
    );
    final filesOn = !leanTools || _unlockedToolGroups.contains('files');
    final gitOn = !leanTools || _unlockedToolGroups.contains('git');
    final ciOn = !leanTools || _unlockedToolGroups.contains('ci');
    if (filesOn) {
      buffer.writeln(
        '- Files (project workspace): list_files, read_file, write_file, create_directory, move_path, delete_path.',
      );
    }
    if (gitOn) {
      buffer.writeln(
        '- Git (workspace repo): git_status, git_log, git_commit, git_branches, git_create_branch, git_checkout_branch.',
      );
    }
    if (ciOn) {
      buffer.writeln(
        '- Build/CI: build_docker_image, run_workflow (GitHub-Actions YAML, runs locally), list_ci_runs, get_ci_run (read logs/errors to diagnose failures).',
      );
    }
    if (!filesOn || !gitOn || !ciOn) {
      final locked = [
        if (!filesOn) 'files (read/write project files)',
        if (!gitOn) 'git (repo status/commit/branches)',
        if (!ciOn) 'ci (build/run workflows, read CI logs)',
      ].join(', ');
      buffer.writeln(
        '- On request: $locked — call request_tools(group) to unlock the group, THEN use those tools next.',
      );
    }
    buffer.writeln(
      '- Other: view_current_plan, generate_diagram, propose_plan_adjustment.',
    );
    buffer.writeln(
      'Prefer reading (list_/get_/read_) before mutating. Only delete when the user clearly asks.',
    );
    buffer.writeln(
      'After you call tools, ALWAYS follow up with a short spoken sentence telling the user what you found or did. Never end a turn with only tool calls and no words.',
    );
    return buffer.toString();
  }

  Future<ChatCompletionResponse> sendMessage(
    String userMessage, {
    String? currentPlanContext,
    List<Map<String, dynamic>>? tools,
  }) async {
    final sys = await _buildSystemPrompt(
      currentPlanContext: currentPlanContext,
    );
    final messages = _sanitizeForWire([
      {'role': 'system', 'content': sys},
      ..._history,
      {'role': 'user', 'content': userMessage},
    ]);

    final effectiveTools = tools ?? CoordinatorTools.buildToolSchemas();

    final response = await client.createChatCompletion(
      model: _effectiveModel,
      messages: messages,
      tools: effectiveTools,
      temperature: 0.7,
      enableThinking: enableThinking,
    );

    _history.add({'role': 'user', 'content': userMessage});
    if (response.choices.isNotEmpty) {
      final assistantMsg = response.choices.first.message;
      _history.add({
        'role': 'assistant',
        'content': assistantMsg.content,
        if (assistantMsg.toolCalls != null &&
            assistantMsg.toolCalls!.isNotEmpty)
          'tool_calls': assistantMsg.toolCalls!
              .map(
                (t) => {
                  'id': t.id,
                  'name': t.function.name,
                  'arguments': t.function.arguments,
                },
              )
              .toList(),
      });
    }

    return response;
  }

  /// Streaming version with automatic tool schema injection.
  /// After the stream yields ChatStreamFinish with toolCalls, the caller (chat screen)
  /// should call executeToolCalls to apply changes live, then optionally continue
  /// the conversation with the tool results appended.
  Stream<ChatStreamEvent> streamMessage(
    String userMessage, {
    String? currentPlanContext,
    List<Map<String, dynamic>>? tools,
  }) async* {
    final sys = await _buildSystemPrompt(
      currentPlanContext: currentPlanContext,
    );
    final messages = _sanitizeForWire([
      {'role': 'system', 'content': sys},
      ..._history,
      {'role': 'user', 'content': userMessage},
    ]);

    final effectiveTools = tools ?? CoordinatorTools.buildToolSchemas();

    yield* client.streamChatCompletion(
      model: _effectiveModel,
      messages: messages,
      tools: effectiveTools,
      temperature: 0.7,
      repeatPenalty: _kRepeatPenalty,
      maxCompletionTokens: _kMaxCompletionTokens,
      enableThinking: enableThinking,
    );
  }

  /// Runs one user turn with an internal tool loop, maintaining history in the
  /// proper OpenAI tool-calling format. Streams content deltas for the answer;
  /// executes any tool calls between rounds (reporting each via [onToolResult]),
  /// then loops so the model can speak a natural-language answer using the
  /// results. Ends when the model returns content with no tool calls (or the
  /// round cap is reached). This is what makes the AI actually reply after it
  /// calls tools like list_open_tasks / view_current_plan.
  Stream<ChatStreamEvent> runTurn(
    String userMessage, {
    void Function(String toolResult)? onToolResult,
    void Function(String b64Png, String caption)? onImage,
    void Function(List<Map<String, dynamic>> messages)? onTrace,
    String? currentPlanContext,
    int maxToolRounds = 4,
  }) async* {
    // Qwen soft-switch: the local Discovery collection ignores the API
    // `enable_thinking:false`, so force thinking OFF via the `/no_think` token on
    // the LATEST user turn (the placement Qwen honors most reliably), on top of
    // the system-prompt `/no_think`. Only for the discovery interview — a
    // decisive tool-calling flow that shouldn't ruminate. Kept out of the
    // training trace so we don't train on the hack.
    final wireUserMessage = discoveryMode
        ? '$userMessage /no_think'
        : userMessage;
    _history.add({'role': 'user', 'content': wireUserMessage});
    _fullTrace.add({'role': 'user', 'content': userMessage});
    _reasonBuf.clear();
    // If this turn fails we roll back to here so a failed/retried send never
    // leaves an orphan `user` message behind. Accumulating consecutive user
    // messages corrupts the chat template and makes the server reject (400) or
    // crash (empty 500) on subsequent turns.
    final rollbackTo = _history.length - 1;
    final traceRollback = _fullTrace.length - 1;

    // Offer the plan tools whenever a plan store is available — not only when a
    // specific plan is open — so the coordinator can list/read/create plans in
    // the general project chat (PLANS/ exists from the start of planning).
    final allTools = discoveryMode
        ? CoordinatorTools.buildToolSchemas(discoveryOnly: true)
        : fixMode
        ? CoordinatorTools.buildToolSchemas(fixOnly: true)
        : scaffoldMode
        ? CoordinatorTools.buildToolSchemas(scaffoldOnly: true)
        : editorMode
        ? CoordinatorTools.buildToolSchemas(editorOnly: true)
        : CoordinatorTools.buildToolSchemas(
            includePlanTools: planStore != null,
            includePlannerComplete: onPlanningComplete != null,
            includePlannerReview: onPlanReview != null,
          );
    final executor = db != null
        ? CoordinatorToolExecutor(
            db: db!,
            projectId: projectId,
            inference: client,
            model: _effectiveModel,
            imageModel: imageModel,
            chatSessionPk: chatSessionPk,
            openPlanPath: openPlanPath,
            planStore: planStore,
            permissions: permissions,
            confirmAsk: confirmAsk,
            agentName: agentName,
            workspace: workspace,
            git: git,
            buildService: buildService,
            onPlanningComplete: onPlanningComplete,
            onPlanReview: onPlanReview,
            onImage: onImage,
            workBranch: workBranch,
            gitLane: gitLane,
            claimFile: fileClaim,
          )
        : null;

    // Whether the model actually used a tool this turn — gates training-trace
    // shipping (keep tool-using turns, skip pure chatter).
    var executedTool = false;
    var lastSys = '';
    // Bounds how many times per turn we poke a DISCOVERY turn that organized/
    // recorded the story tree but is ending WITHOUT asking a question (the empty-
    // reasoning "reorganized then stopped" stall) so the interview keeps moving.
    var discoveryAskNudges = 0;
    // EDITOR anti-stall: the editor model tends to READ the code, ANNOUNCE the
    // change ("I'll create the pipe system now"), and then STOP — never calling
    // an edit tool. `editorActed` tracks whether it actually wrote anything this
    // turn; if not (and it only announced), we poke it to make the change.
    var editorActed = false;
    var editorNudges = 0;
    try {
      for (var round = 0; round < maxToolRounds; round++) {
        // Rebuilt each round so a request_tools unlock takes effect immediately.
        // Discovery mode uses the curated story-tool list verbatim (no lean
        // gating / request_tools — it must not reach task tools).
        // Discovery + scaffold + fix + editor modes use their curated tool list
        // verbatim (no lean gating / request_tools) so they stay inside their
        // narrow job — the editor gets its file/git/build/CI set offered up front
        // so it edits without a "request tools" dance.
        final tools = (discoveryMode || scaffoldMode || fixMode || editorMode)
            ? allTools
            : _effectiveTools(allTools);
        final sys = await _buildSystemPrompt(
          currentPlanContext: currentPlanContext,
        );
        lastSys = sys;
        final messages = _sanitizeForWire([
          {'role': 'system', 'content': sys},
          ..._history,
        ]);

        // Stream the round: content deltas are forwarded live so the UI renders
        // token-by-token; tool calls are captured from the final finish event.
        final buf = StringBuffer();
        var toolCalls = const <ToolCall>[];
        var toolsDropped = false;
        // Once a reply reveals itself as a raw inline tool-call block, stop
        // streaming it to the UI — it's recovered and executed after the round
        // instead of being dumped at the user as XML.
        var inlineToolText = false;
        await for (final ev in _streamRound(
          messages,
          tools,
          onToolsDropped: (d) => toolsDropped = d,
        )) {
          if (ev is ChatContentDelta) {
            buf.write(ev.text);
            if (inlineToolText) continue;
            final lead = buf.toString().trimLeft();
            if (lead.startsWith('<tool_call') || lead.startsWith('<function=')) {
              inlineToolText = true;
              continue;
            }
            yield ev; // forward live (do NOT also re-yield the full content below)
          } else if (ev is ChatReasoningDelta) {
            _reasonBuf.write(ev.text); // capture thoughts for the training trace
            yield ev; // forward thinking tokens live; not part of the answer text
          } else if (ev is ChatStreamFinish) {
            toolCalls = ev.toolCalls;
          }
        }
        var contentStr = buf.toString();
        // Recover tool calls the model emitted as inline text (see above) so the
        // action isn't lost. If the block didn't parse into a call after all,
        // surface the text so the user isn't left with a blank reply.
        if (toolCalls.isEmpty && executor != null) {
          final recovered = _recoverInlineToolCalls(contentStr);
          if (recovered.isNotEmpty) {
            toolCalls = recovered;
            contentStr = _stripInlineToolCalls(contentStr);
          } else if (inlineToolText) {
            yield ChatContentDelta(contentStr);
          }
        }
        // Record this round's reasoning into the export trace (before the
        // assistant message it produced), then reset for the next round.
        if (_reasonBuf.isNotEmpty) {
          _fullTrace.add({
            'role': 'thinking',
            'content': _reasonBuf.toString().trim(),
          });
          _reasonBuf.clear();
        }
        if (toolsDropped && round == 0) {
          onToolResult?.call(
            '(This model rejected tool-calling, so live task/plan actions are off for this reply.)',
          );
        }

        // Record the assistant message in history. When there are tool calls and
        // no text, content must be null (not "") — servers reject empty-string
        // content alongside tool_calls.
        final assistantEntry = <String, dynamic>{
          'role': 'assistant',
          'content': (toolCalls.isNotEmpty && contentStr.isEmpty)
              ? null
              : contentStr,
          if (toolCalls.isNotEmpty)
            'tool_calls': [
              for (final t in toolCalls)
                {
                  'id': t.id,
                  'type': 'function',
                  'function': {
                    'name': t.function.name,
                    'arguments': t.function.arguments,
                  },
                },
            ],
        };
        _history.add(assistantEntry);
        _fullTrace.add(Map<String, dynamic>.from(assistantEntry));

        if (toolCalls.isEmpty || executor == null) {
          // DISCOVERY ANTI-STALL: the model reorganized/recorded the story tree
          // this turn but is ending with NO spoken question (often after an empty
          // reasoning round) — so the interview silently stops while topics are
          // still open. Poke it once or twice to ask its next question first.
          if (discoveryMode &&
              executor != null &&
              executedTool &&
              contentStr.trim().isEmpty &&
              discoveryAskNudges < 2) {
            discoveryAskNudges++;
            _history.add({
              'role': 'user',
              'content':
                  'You updated the story tree but did not ASK anything. Continue '
                  'the interview now: ask your next ONE focused question about a '
                  'part of the project that still lacks detail. Do not stop while '
                  'there is more to learn.',
            });
            continue;
          }
          // EDITOR ANTI-STALL: it ANNOUNCED a change ("I'll create…", "let me
          // add…") but did NOT act this turn — the "narrate then stop" failure.
          // The editor is a pure delegator, so acting means scoping + launching
          // the work. Push it to do that instead of ending on a promise. (Only
          // when it announced an action, so a plain answer is left alone.)
          if (editorMode &&
              executor != null &&
              !editorActed &&
              editorNudges < 2 &&
              _announcesAction(contentStr)) {
            editorNudges++;
            _history.add({
              'role': 'user',
              'content':
                  'You described the change but have NOT delegated it. Do it '
                  'NOW: call create_task with the concrete work (behaviour + '
                  'file/area + acceptance criteria), then start_delegated_build '
                  'to run it. Do not just describe it, and do not try to edit '
                  'code yourself — you have no code tools.',
            });
            continue;
          }
          if (executedTool) onTrace?.call(_traceMessages(lastSys));
          yield ChatStreamFinish(
            finishReason: 'stop',
            toolCalls: const [],
            contentSoFar: contentStr,
          );
          return;
        }

        // Execute each tool call, append results, then loop for the spoken answer.
        executedTool = true;
        for (final call in toolCalls) {
          Map<String, dynamic> args = {};
          try {
            final raw = call.function.arguments.trim();
            if (raw.startsWith('{'))
              args = (jsonDecode(raw) as Map).cast<String, dynamic>();
          } catch (_) {}

          // Progressive tool disclosure: unlock a gated group for the rest of
          // the conversation. Handled here (session state), not the executor.
          if (call.function.name == 'request_tools') {
            final group = args['group']?.toString() ?? '';
            final String note;
            if (_gatedToolGroups.containsKey(group)) {
              _unlockedToolGroups.add(group);
              note =
                  'Unlocked "$group" tools — they are now available; call '
                  'them on your next step.';
            } else {
              note =
                  'Unknown tool group "$group". Valid groups: '
                  '${_gatedToolGroups.keys.join(', ')}.';
            }
            onToolResult?.call(note);
            _history.add({
              'role': 'tool',
              'tool_call_id': call.id,
              'content': note,
            });
            _fullTrace.add({
              'role': 'tool',
              'tool_call_id': call.id,
              'content': note,
            });
            continue;
          }

          final action = _loopGuard.observe(
            call.function.name,
            _guardArgs(call.function.name, args),
          );
          if (action == LoopAction.block) {
            var note = _loopGuard.feedback(call.function.name, action);
            // A blocked call never executes, so it returns no state. For the
            // story-tree tools that means the model is refused mid-reorg with NO
            // view of the tree — exactly what makes it spiral reconstructing the
            // state from memory. Hand it the real tree so it re-grounds and moves
            // on instead of re-deriving what happened.
            if (_isStoryTreeTool(call.function.name)) {
              note += await executor.storyTreeSnapshot();
            }
            onToolResult?.call(note);
            _history.add({
              'role': 'tool',
              'tool_call_id': call.id,
              'content': note,
            });
            _fullTrace.add({
              'role': 'tool',
              'tool_call_id': call.id,
              'content': note,
            });
            continue; // refuse the looping call; model must change course
          }

          // A tool that THROWS must not abort the whole turn (which would roll
          // back and surface a raw error). Feed the failure back to the model as
          // this tool's result with a retry instruction so it self-corrects in
          // the remaining rounds; the LoopGuard bounds a tool that keeps failing.
          String result;
          try {
            result = await executor.execute(
              name: call.function.name,
              args: args,
            );
            // A real write happened this turn → the editor acted (suppresses the
            // "you only described it" nudge).
            if (_isEditWriteTool(call.function.name)) editorActed = true;
          } catch (e) {
            result =
                'ERROR: ${call.function.name} failed and did NOT take effect: '
                '$e. Retry this tool once now (or take a different step) — do '
                'not tell the user it succeeded.';
          }
          // Show only a short summary in the chat — big payloads (a whole plan or
          // file the model read) shouldn't flood the transcript. The MODEL still
          // receives the full result via `body`/history below.
          onToolResult?.call(_summarizeToolResult(result));
          final body = action == LoopAction.warn
              ? '$result\n\n${_loopGuard.feedback(call.function.name, action)}'
              : result;
          _history.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': body,
          });
          _fullTrace.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': body,
          });
        }
      }
    } catch (e) {
      // Drop everything this turn added (user message + any partial assistant/
      // tool messages) so the conversation stays well-formed for the next try.
      if (rollbackTo < _history.length)
        _history.removeRange(rollbackTo, _history.length);
      if (traceRollback >= 0 && traceRollback < _fullTrace.length) {
        _fullTrace.removeRange(traceRollback, _fullTrace.length);
      }
      _reasonBuf.clear();
      rethrow;
    }

    // Hit the round cap with tool work still pending. Don't end the turn on
    // silence (an empty 'length' finish) — make ONE final completion with NO
    // tools so the model must put its findings into words and, in discovery,
    // ask the next question, instead of stopping without a spoken reply.
    try {
      final wrapSys = await _buildSystemPrompt(
        currentPlanContext: currentPlanContext,
      );
      final wrapMessages = _sanitizeForWire([
        {'role': 'system', 'content': wrapSys},
        ..._history,
      ]);
      final wrapBuf = StringBuffer();
      // This forced-speak round is given NO tools, so a model still wanting to
      // act "calls" by writing inline XML. Suppress that from the live stream.
      var wrapInlineText = false;
      await for (final ev in _streamRound(
        wrapMessages,
        const [],
        onToolsDropped: (_) {},
      )) {
        if (ev is ChatContentDelta) {
          wrapBuf.write(ev.text);
          if (wrapInlineText) continue;
          final lead = wrapBuf.toString().trimLeft();
          if (lead.startsWith('<tool_call') || lead.startsWith('<function=')) {
            wrapInlineText = true;
            continue;
          }
          yield ev;
        } else if (ev is ChatReasoningDelta) {
          _reasonBuf.write(ev.text);
          yield ev;
        }
      }
      if (_reasonBuf.isNotEmpty) {
        _fullTrace.add({
          'role': 'thinking',
          'content': _reasonBuf.toString().trim(),
        });
        _reasonBuf.clear();
      }
      var wrapStr = wrapBuf.toString();
      // Recover & run any inline tool call so the action isn't lost, and never
      // show the raw XML. The deltas were suppressed above, so re-yield the
      // cleaned text (or a brief close if nothing readable remains).
      final wrapRecovered = _recoverInlineToolCalls(wrapStr);
      if (wrapRecovered.isNotEmpty) {
        await _runRecoveredCalls(wrapRecovered, executor, onToolResult);
        wrapStr = _stripInlineToolCalls(wrapStr);
        if (wrapStr.isEmpty) {
          wrapStr = discoveryMode ? 'Updated the story tree.' : 'Applied the changes.';
        }
        yield ChatContentDelta(wrapStr);
      } else if (wrapInlineText) {
        yield ChatContentDelta(wrapStr); // looked like a tool block but wasn't
      }
      if (wrapStr.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': wrapStr});
        _fullTrace.add({'role': 'assistant', 'content': wrapStr});
      }
      if (executedTool) onTrace?.call(_traceMessages(wrapSys));
      yield ChatStreamFinish(
        finishReason: 'stop',
        toolCalls: const [],
        contentSoFar: wrapStr,
      );
    } catch (_) {
      // If the wrap-up call itself fails, fall back to the graceful finish.
      yield const ChatStreamFinish(
        finishReason: 'length',
        toolCalls: [],
        contentSoFar: '',
      );
    }
  }

  /// A short, UI-friendly version of a tool result so large payloads (e.g. an
  /// entire plan/file the model read) don't flood the chat transcript. The model
  /// still gets the full result in history; only the on-screen note is summarized.
  static String _summarizeToolResult(String result) {
    final trimmed = result.trim();
    const cap = 200;
    final lineCount = '\n'.allMatches(trimmed).length + 1;
    // Short single-line results are already their own summary — show as-is.
    if (trimmed.length <= cap && lineCount == 1) return trimmed;
    final firstLine = trimmed.split('\n').first.trim();
    final head = firstLine.length > cap
        ? '${firstLine.substring(0, cap).trimRight()}…'
        : firstLine;
    final more = lineCount - 1;
    return more > 0
        ? '$head  (+$more more line${more == 1 ? '' : 's'})'
        : '$head…';
  }

  /// Repairs a message list for the wire. Failed turns can leave a run of
  /// consecutive `user` (or `assistant`) text messages in history; chat
  /// templates expect alternating roles, and this server rejects/crashes on
  /// long same-role runs. We merge consecutive same-role *text* messages into
  /// one. Messages carrying tool_calls and `tool`-role results are left intact
  /// (they must keep their exact structure for tool-calling to work).
  /// Recent tool results kept VERBATIM on the wire; older ones are elided.
  static const int _keepFullToolResults = 6;

  /// Only old tool results bigger than this (chars) get elided — small status
  /// messages are left alone (they're cheap and often still relevant).
  static const int _elideToolResultOver = 1200;

  /// Context compaction. A worker re-sends its ENTIRE history on every tool
  /// round, across up to a dozen turns, so every file it read early is re-billed
  /// dozens of times — token cost grows quadratically and dominates the bill.
  /// Replace the content of OLDER, large `tool` results (keeping the most recent
  /// few verbatim) with a short stub. Message structure — including each tool
  /// result's `tool_call_id` pairing with its assistant `tool_calls` — is
  /// preserved, recent context stays intact, and the model can simply re-read a
  /// file if it needs an elided one again. No-op for short conversations (e.g.
  /// the interactive coordinator chat), which rarely accumulate big tool dumps.
  static List<Map<String, dynamic>> _compactToolResults(
    List<Map<String, dynamic>> msgs,
  ) {
    final toolIdx = <int>[
      for (var i = 0; i < msgs.length; i++)
        if (msgs[i]['role'] == 'tool') i,
    ];
    if (toolIdx.length <= _keepFullToolResults) return msgs;
    // Everything before this index is "old" and eligible for elision.
    final keepFrom = toolIdx[toolIdx.length - _keepFullToolResults];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (m['role'] == 'tool' && i < keepFrom) {
        final content = (m['content'] ?? '').toString();
        if (content.length > _elideToolResultOver) {
          out.add({
            ...m,
            'content':
                '[earlier tool output elided to save context '
                '(${content.length} chars). Re-read the file/resource if you '
                'still need it.]',
          });
          continue;
        }
      }
      out.add(m);
    }
    return out;
  }

  static List<Map<String, dynamic>> _sanitizeForWire(
    List<Map<String, dynamic>> msgs,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final m in _compactToolResults(msgs)) {
      final role = m['role'];
      final hasToolCalls = m['tool_calls'] != null;
      if (out.isNotEmpty &&
          !hasToolCalls &&
          (role == 'user' || role == 'assistant') &&
          out.last['role'] == role &&
          out.last['tool_calls'] == null) {
        final prev = (out.last['content'] ?? '').toString();
        final cur = (m['content'] ?? '').toString();
        out.last['content'] = prev.isEmpty
            ? cur
            : (cur.isEmpty ? prev : '$prev\n$cur');
        continue;
      }
      out.add(Map<String, dynamic>.from(m));
    }
    return out;
  }

  // ── Inline tool-call recovery ─────────────────────────────────────────────
  // Some models emit tool calls as inline TEXT instead of the structured
  // tool_calls field, e.g.
  //   <tool_call><function=add_user_story><parameter=title>…</parameter></function></tool_call>
  // When that happens the action is otherwise lost and the user just sees raw
  // XML. We parse those blocks back into real ToolCalls and run them.
  static final RegExp _inlineFnRe = RegExp(
    r'<function\s*=\s*([A-Za-z0-9_]+)\s*>(.*?)</function\s*>',
    dotAll: true,
  );
  static final RegExp _inlineParamRe = RegExp(
    r'<parameter\s*=\s*([A-Za-z0-9_]+)\s*>(.*?)</parameter\s*>',
    dotAll: true,
  );
  static final RegExp _inlineJsonRe = RegExp(
    r'<tool_call\s*>\s*(\{.*?\})\s*</tool_call\s*>',
    dotAll: true,
  );
  static final RegExp _inlineWrapRe = RegExp(r'</?tool_call\s*>');

  /// Parse inline-text tool calls out of [content]. Returns empty if none.
  List<ToolCall> _recoverInlineToolCalls(String content) {
    if (!content.contains('<function=') && !content.contains('<tool_call')) {
      return const [];
    }
    final calls = <ToolCall>[];
    var i = 0;
    // <function=NAME><parameter=K>V</parameter>…</function>
    for (final m in _inlineFnRe.allMatches(content)) {
      final args = <String, dynamic>{};
      for (final p in _inlineParamRe.allMatches(m.group(2) ?? '')) {
        args[p.group(1)!.trim()] = (p.group(2) ?? '').trim();
      }
      calls.add(
        ToolCall(
          id: 'inline_${i++}',
          type: 'function',
          function: FunctionCall(
            name: m.group(1)!.trim(),
            arguments: jsonEncode(args),
          ),
        ),
      );
    }
    if (calls.isNotEmpty) return calls;
    // Hermes JSON variant: <tool_call>{"name":…,"arguments":{…}}</tool_call>
    for (final m in _inlineJsonRe.allMatches(content)) {
      try {
        final obj = jsonDecode(m.group(1)!) as Map<String, dynamic>;
        final name = (obj['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final raw = obj['arguments'] ?? obj['parameters'] ?? const {};
        calls.add(
          ToolCall(
            id: 'inline_${i++}',
            type: 'function',
            function: FunctionCall(
              name: name,
              arguments: raw is String ? raw : jsonEncode(raw),
            ),
          ),
        );
      } catch (_) {}
    }
    return calls;
  }

  /// Remove recovered tool-call XML, leaving only any real prose.
  String _stripInlineToolCalls(String s) => s
      .replaceAll(_inlineFnRe, '')
      .replaceAll(_inlineJsonRe, '')
      .replaceAll(_inlineWrapRe, '')
      .trim();

  /// The argument view the loop guard fingerprints. For `add_user_story` a
  /// node's IDENTITY is its (title, parent) — the discovery model often
  /// re-issues the SAME story with a reworded narrative, which would dodge a
  /// full-args fingerprint and let it spam the dedup guard. Key on identity so
  /// those repeats still escalate proceed → warn → block.
  Map<String, dynamic> _guardArgs(String tool, Map<String, dynamic> args) {
    if (tool == 'add_user_story') {
      return {
        'title': (args['title'] ?? '').toString().trim().toLowerCase(),
        'parent_story_id': args['parent_story_id'],
      };
    }
    return args;
  }

  /// Execute tool calls recovered from inline TEXT in the forced-speak wrap-up
  /// round (which is given no structured tools, so a model still wanting to act
  /// "calls" by writing XML). Runs each for its side effect — loop-guarded and
  /// surfaced via onToolResult — without touching history (the wrap-up's own
  /// assistant message stands), so the action isn't silently lost.
  Future<void> _runRecoveredCalls(
    List<ToolCall> calls,
    CoordinatorToolExecutor? executor,
    void Function(String toolResult)? onToolResult,
  ) async {
    final ex = executor;
    if (ex == null) return;
    for (final call in calls) {
      Map<String, dynamic> args = {};
      try {
        final raw = call.function.arguments.trim();
        if (raw.startsWith('{')) {
          args = (jsonDecode(raw) as Map).cast<String, dynamic>();
        }
      } catch (_) {}
      final action = _loopGuard.observe(
        call.function.name,
        _guardArgs(call.function.name, args),
      );
      if (action == LoopAction.block) {
        onToolResult?.call(_loopGuard.feedback(call.function.name, action));
        continue;
      }
      String result;
      try {
        result = await ex.execute(name: call.function.name, args: args);
      } catch (e) {
        result = 'ERROR: ${call.function.name} failed: $e';
      }
      onToolResult?.call(_summarizeToolResult(result));
    }
  }

  /// Runs ONE model round, STREAMING as the PRIMARY path so the reply renders
  /// token-by-token. Falls back to a NON-streaming request if streaming errors
  /// before any content was emitted (some llama.cpp/GGUF backends reject
  /// streaming-with-tools), and finally retries WITHOUT tools if the request
  /// itself is rejected so plain chat still works. Yields [ChatContentDelta] as
  /// tokens arrive and a final [ChatStreamFinish] carrying the assembled tool
  /// calls; [onToolsDropped] reports whether tools were dropped.
  Stream<ChatStreamEvent> _streamRound(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools, {
    required void Function(bool dropped) onToolsDropped,
  }) async* {
    // Primary: streaming WITH tools. Retry on the plan's concurrent-connection
    // cap (429 / too_many_connections) with backoff — that's transient pressure
    // (a busy slot frees up shortly), NOT a request-shape problem, so retrying
    // beats both failing the turn AND falling through to the no-tools fallback.
    var emitted = false;
    for (var attempt = 0; attempt <= 3; attempt++) {
      try {
        await for (final ev in client.streamChatCompletion(
          model: _effectiveModel,
          messages: messages,
          tools: tools,
          temperature: 0.7,
          repeatPenalty: _kRepeatPenalty,
          maxCompletionTokens: _kMaxCompletionTokens,
          enableThinking: enableThinking,
        )) {
          emitted = true;
          yield ev;
        }
        onToolsDropped(false);
        return;
      } catch (e) {
        // If partial content already streamed we can't safely retry — rethrow.
        if (emitted) rethrow;
        if (_isConnCap(e) && attempt < 3) {
          await Future<void>.delayed(
            Duration(milliseconds: 1500 * (attempt + 1)),
          );
          continue; // retry streaming once a connection likely frees
        }
        break; // non-429 (or out of retries): try the fallbacks below
      }
    }

    // Fallback 1: non-streaming WITH tools.
    try {
      yield* _nonStreamingRound(messages, tools);
      onToolsDropped(false);
      return;
    } catch (_) {
      // Fall through to no-tools.
    }

    // Fallback 2: non-streaming WITHOUT tools (the request itself was rejected).
    yield* _nonStreamingRound(messages, null);
    onToolsDropped(true);
  }

  /// The structural story-tree tools — a blocked call to one of these leaves the
  /// model with no view of the tree, so its loop-guard feedback gets the current
  /// tree appended (see the block path) to keep it grounded.
  static bool _isStoryTreeTool(String name) => const {
    'add_user_story',
    'move_user_story',
    'delete_user_story',
    'update_user_story',
  }.contains(name);

  /// Tools that actually CHANGE the project (vs. read/list/search) — used to
  /// tell whether the editor really did something this turn or only talked.
  static bool _isEditWriteTool(String name) => const {
    'edit_file',
    'write_file',
    'create_file',
    'create_directory',
    'move_path',
    'delete_path',
    'delete_file',
    'delete_folder',
    'git_commit',
    // Editor (pure delegator) "acts" by scoping + launching work, not editing.
    'create_task',
    'start_delegated_build',
  }.contains(name);

  /// True when [content] is the model PROMISING an edit ("I'll create…", "let me
  /// add…", "I'm going to update…") rather than answering a question. Drives the
  /// editor anti-stall nudge so an announced-but-unmade change gets made.
  static final RegExp _actionIntentRe = RegExp(
    r"\b(i'?ll|i will|i'?m going to|let me|going to|i can|i'?ve identified|next[, ])\b"
    r"[^.\n]*\b(creat|implement|add|writ|updat|chang|fix|wir|build|edit|mak|"
    r"set up|hook|generat|refactor|replac)",
    caseSensitive: false,
  );
  static bool _announcesAction(String content) =>
      _actionIntentRe.hasMatch(content);

  /// True if [e] is the plan's concurrent-connection cap (HTTP 429 /
  /// too_many_connections) — transient backpressure worth retrying, not an error
  /// to surface to the user.
  static bool _isConnCap(Object e) =>
      e is LemonadeApiException &&
      (e.statusCode == 429 ||
          e.message.toLowerCase().contains('too_many_connections'));

  /// One non-streaming round mapped into the same event shape as streaming.
  Stream<ChatStreamEvent> _nonStreamingRound(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
  ) async* {
    final resp = await client.createChatCompletion(
      model: _effectiveModel,
      messages: messages,
      tools: tools,
      temperature: 0.7,
      repeatPenalty: _kRepeatPenalty,
      maxCompletionTokens: _kMaxCompletionTokens,
      enableThinking: enableThinking,
    );
    final msg = resp.choices.isNotEmpty ? resp.choices.first.message : null;
    final content = msg?.content ?? '';
    if (content.isNotEmpty) yield ChatContentDelta(content);
    yield ChatStreamFinish(
      finishReason: 'stop',
      toolCalls: msg?.toolCalls ?? const <ToolCall>[],
      contentSoFar: content,
    );
  }

  /// Executes a batch of tool calls (from ChatStreamFinish) against the live DB.
  /// Returns human-readable results for each. Appends tool messages to history
  /// so subsequent turns see the outcomes.
  Future<List<String>> executeToolCalls(List<ToolCall> toolCalls) async {
    if (db == null || toolCalls.isEmpty) {
      return toolCalls
          .map(
            (c) =>
                'Tool ${c.function.name} not executed (no DB or empty calls).',
          )
          .toList();
    }

    final executor = CoordinatorToolExecutor(
      db: db!,
      projectId: projectId,
      inference: client,
      model: _effectiveModel,
      imageModel: imageModel,
      chatSessionPk: chatSessionPk,
      openPlanPath: openPlanPath,
      planStore: planStore,
      permissions: permissions,
      confirmAsk: confirmAsk,
      agentName: agentName,
      workspace: workspace,
      git: git,
      buildService: buildService,
      workBranch: workBranch,
      gitLane: gitLane,
      claimFile: fileClaim,
    );

    final results = <String>[];
    for (final call in toolCalls) {
      Map<String, dynamic> args = {};
      try {
        final raw = call.function.arguments.trim();
        if (raw.startsWith('{')) {
          args = (jsonDecode(raw) as Map).cast<String, dynamic>();
        }
      } catch (_) {
        args = {};
      }

      final resultText = await executor.execute(
        name: call.function.name,
        args: args,
      );
      results.add(resultText);

      // Append as tool result to history for the model to see on next turn / next voice turn
      _history.add({
        'role': 'tool',
        'tool_call_id': call.id,
        'name': call.function.name,
        'content': resultText,
      });
    }

    return results;
  }

  void clearHistory() {
    _history.clear();
    _fullTrace.clear();
    _reasonBuf.clear();
    _loopGuard.reset();
  }

  /// Seed conversation history when resuming a persisted session, so the model
  /// has prior context. Pass user/assistant text turns in chronological order.
  void restoreHistory(Iterable<({String role, String content})> turns) {
    _history
      ..clear()
      ..addAll(turns.map((t) => {'role': t.role, 'content': t.content}));
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }
}
