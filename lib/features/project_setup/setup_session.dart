// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';

import '../../core/agents/loop_guard.dart';
import '../../infrastructure/inference/inference_backend.dart';
import '../../infrastructure/lemonade/services/persona_model_resolver.dart'
    show kDefaultOmniCollection;
import 'config/setup_flow.dart';
import 'setup_tools.dart';

/// Two stages of the setup host: the bounded multiple-choice [interview], and
/// the post-finalize [refine] stage where plans exist and the user enriches
/// them with free-text descriptions that the host folds into the plan files.
enum SetupPhase { interview, refine }

/// Drives the bounded Project Setup interview. The AI hosts the conversation and
/// writes rationale, but every decision flows through [SetupTools]: it asks the
/// user multiple-choice questions, verifies libraries against the registries,
/// proposes tags (always `proposed`), and finalizes by generating /PLANS files.
/// A deterministic resolver — never the AI — computes the stack at finalize.
class SetupSession {
  SetupSession({
    required this.client,
    required this.model,
    required this.projectName,
    required this.executor,
    required this.flow,
    this.maxToolRounds = 12,
    this.enableThinking,
    this.reasoningEffort,
    this.leanContext = true,
  });

  final InferenceBackend client;
  final String model;
  final String projectName;
  final SetupToolExecutor executor;

  /// When true (default), reconstruct state from the board (DB) + a short turn
  /// window instead of replaying the whole transcript, and drop the interview
  /// context at finalize. When false, send the full history every turn.
  final bool leanContext;

  /// The configurable, DB-resolved interview definition (stages + guidance) for
  /// this project's type + sub-category. Drives the interview prompt + the
  /// `propose_tags` categories.
  final SetupFlowDefinition flow;
  final int maxToolRounds;

  /// Effective enable_thinking for this session (null omits the param). Resolved
  /// from the project agent's ThinkingMode.
  final bool? enableThinking;

  /// Effective thinking level (e.g. 'low'), sent verbatim as `reasoning_effort`
  /// on every request. Resolved from the project agent's [ThinkingLevel].
  /// Null omits the parameter.
  final String? reasoningEffort;

  /// Working LLM context — TRIMMED each turn to the recent window and CLEARED at
  /// the interview→refine boundary. The board (DB) is the durable state, so we
  /// never need to replay the whole conversation to the model.
  final List<Map<String, dynamic>> _history = [];

  /// Append-only record of user/assistant TEXT, decoupled from [_history] so the
  /// persisted transcript (and UI restore) survives the working-context trim.
  final List<Map<String, dynamic>> _transcript = [];

  /// Append-only FULL trace for training export: real user/assistant/tool
  /// messages (with tool_calls) PLUS the model's reasoning ('thinking'), in
  /// order. Unlike [_history] it excludes internal anti-stall nudges and is never
  /// trimmed, and unlike [_transcript] it keeps tool calls + thoughts.
  final List<Map<String, dynamic>> _fullTrace = [];

  /// How many recent user-initiated turns of [_history] to send each request.
  /// Older turns are represented by the injected board-state summary.
  static const int _historyWindowTurns = 4;

  /// Set once the interview history has been dropped on entering refine, so the
  /// hard-drop happens exactly at the boundary.
  bool _interviewDropped = false;

  /// Internal nudge injected to unstick a stalled turn; filtered out of the
  /// persisted transcript so it never shows to the user.
  static const String _continueNudge =
      'Continue: take the next step now — ask the next question or call the needed tool.';

  /// Which stage the host is in. Starts in [SetupPhase.interview]; flips to
  /// [SetupPhase.refine] once `finalize_setup` has generated the plan files.
  SetupPhase phase = SetupPhase.interview;

  void enterRefinePhase() => phase = SetupPhase.refine;

  /// Detects when the interview agent gets stuck re-issuing the same tool call
  /// (e.g. re-asking the same question or re-proposing the same tags). Lives at
  /// session scope so it catches loops that span user turns, not just one turn.
  final LoopGuard _loopGuard = LoopGuard();

  /// Set by [cancel] to abort the current turn between rounds (the user tapped
  /// the thinking indicator because it looped/hung). Reset at the start of [send].
  bool _cancelled = false;

  /// Abort the in-flight turn after the current model round returns.
  void cancel() => _cancelled = true;

  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  String get _effectiveModel =>
      model.trim().isEmpty ? kDefaultOmniCollection : model.trim();

  String _systemPrompt() =>
      phase == SetupPhase.refine ? _refinePrompt() : _interviewPrompt();

  /// Categories the active flow proposes into (its stage keys) — drives the
  /// `propose_tags` schema so each project type proposes its own sections.
  List<String> get tagCategories => flow.stages.map((s) => s.key).toList();

  String _interviewPrompt() {
    final steps = StringBuffer();
    var n = 1;
    for (final s in flow.stages) {
      final opts = s.suggestions.isEmpty
          ? ' Offer a few relevant options.'
          : (s.vocab == SetupVocab.closed
                ? ' Offer ONLY these options: ${s.suggestions.join(', ')}.'
                : ' Suggested options: ${s.suggestions.join(', ')}.');
      steps.writeln(
        '$n. ${s.title} — ask about ${s.guidance.trim()}'
        '${s.required ? '' : ' (optional — skip if it does not apply)'}'
        ' [category: `${s.key}`]$opts',
      );
      n++;
    }
    final stepCount = flow.stages.length;
    return '''
You are the Setup host for "$projectName" (${flow.name}). Your job is to build the project profile by TAGGING it. Keep every reply to 1-2 short sentences.

${flow.intro}

You have $stepCount topics to fill (listed below). FIRST tag ONLY what the user EXPLICITLY stated; then ask the REMAINING topics in the order listed below — exactly ONE topic per question, and NEVER jump ahead to a later topic. A "NEXT TOPIC" line in the board state tells you the single topic to ask next; follow it.

$steps
START FROM WHAT THEY SAID:
- Read the user's description and call `propose_tags` ONLY for what it clearly states or unmistakably requires (e.g. "a website" → platform Web; "log in" → Authentication). Do NOT pre-fill `features` with things the user did not say — those are for the user to choose when you ASK each topic, one at a time.
- Then reflect back in one short sentence what you recorded, and ask the NEXT TOPIC.

HOW TO ASK (for the topics still open):
- Each remaining question goes through the `ask_question` tool — it shows the options as buttons the user taps, so calling it is how you get their answer.
- Put any progress label inside the tool call, e.g. ask_question(question: "Features — anything else it should do?", options: ["…","…"], multi: true).

ONE TOPIC AT A TIME, IN ORDER:
1. Call the `ask_question` tool for the CURRENT topic (the "NEXT TOPIC") with its options, and wait for the answer.
2. Right after the user answers, call `propose_tags` to save EXACTLY their picks under that topic's `category` — record ONLY the options they selected. NEVER add options they left unpicked, and NEVER invent extra values beyond their selection (if you offered 12 and they picked 3, tag those 3 — not the other 9, and not new ones).
3. Move to the NEXT topic in order — never re-ask a topic that already has a tag, and never skip ahead past an unanswered earlier topic. (The only thing you tag WITHOUT asking is the AI-derived stack — languages/frameworks.)

RULES:
- MATCH SCOPE TO THE APP — do NOT over-build. Gauge the real complexity from the description. A TRIVIAL app (dice roller, timer, calculator, unit converter, simple to-do, a single-screen toy) needs NO authentication, NO user accounts, NO cloud, NO database, NO analytics, and NO second language — do not steer the user toward those. If they tap a heavyweight option that clearly mismatches a trivial app (e.g. "User accounts", "Authentication", or "Analytics" on a dice roller), CONFIRM it in ONE short question before tagging it ("A dice roller usually doesn't need logins — keep it simple, or do you actually want accounts?") and only tag it if they confirm. Only genuinely bigger apps (marketplaces, social, dashboards, anything multi-user or with real data) warrant auth/DB/cloud. Aim for the SMALLEST stack that delivers what they asked for.
- Base every tag on what the user picked or said. Use the `category` shown in each question's brackets.
- ANSWER OUTSIDE THE QUESTION: the user can type anything at any time, even when it is not a reply to what you asked. Treat every typed message as authoritative — if it adds facts, `propose_tags` them under the right category; if it corrects something, fix it; then carry on. Never ignore a typed message just because it wasn't the option you offered.
- CORRECTIONS / "you're wrong": if the user says a tag is WRONG ("this isn't a logistics app", "that's not ecommerce", "the Media tag is wrong, it's a game"), call `remove_tags` for EXACTLY the values they disowned, then `propose_tags` the right one if they named it. Only remove what the user explicitly rejected.
- CATEGORY SWAP CASCADE: when the user changes the INDUSTRY (e.g. "it's a game, not media"), remove_tags the wrong industry — its sub-axis (e.g. genre) is cleared automatically — then propose_tags the correct industry and follow the resulting "NEXT:" sub-axis question. Also review features that only made sense for the OLD industry and remove_tags the ones that no longer fit before moving on.
- PICK THE RIGHT INDUSTRY UP FRONT: map the user's product to the closest industry deliberately. A game / gameplay / "make me a game" is the **Gaming** industry (it unlocks the Genre sub-axis) — do NOT file it under Media/Entertainment. Likewise match other products to their actual domain rather than a generic catch-all.
- Each tag VALUE is a SHORT label — a few words (≤5), one idea per tag. Give several items as several tags. Example: "track orders and notify users" → propose_tags([{category:"features", value:"Order tracking"}, {category:"features", value:"User notifications"}]).
- If a tool result says "NEXT: …", do that next (some answers unlock a follow-up question, e.g. Industry → Genre).
- STACK: once platforms are known, `propose_tags` a MINIMAL, COHERENT stack yourself (the user usually won't mention it) — the language(s) the chosen framework ACTUALLY uses and NOTHING else. A framework implies its language: Flutter → Dart ONLY (NEVER TypeScript/JS alongside it); a React/Next web app → TypeScript; do NOT mix languages from different ecosystems or add a second language that doesn't fit. Propose a DATABASE or an AUTH/CLOUD library ONLY if the tagged features genuinely require persistence or accounts — never by default on a simple app. When you do, prefer one that works on ALL the target platforms: for a Flutter web+desktop app avoid heavyweight native-only SDKs (e.g. the Firebase C++ desktop SDK fails to link on Windows, native-only sqlite is blank on web) — pick a lighter cross-platform option.
- When every required question has at least one tag (${_requiredTitles()}), call `finalize_setup`. It refuses and lists what is missing if you call it too early.
- ${flow.finalizeGuidance}
''';
  }

  /// Titles of the flow's required stages, for the "fill these before finalize"
  /// line in the interview prompt (mirrors the executor's hard gate).
  String _requiredTitles() =>
      flow.stages.where((s) => s.required).map((s) => s.title).join(', ');

  String _refinePrompt() {
    return '''
You are the Project Setup host for "$projectName", now in the REFINE stage. The
plan files already exist as Markdown under /PLANS (an Overview plus one file per
architectural layer, e.g. Client.md, Server.md, Database.md). Your job is to help
the user flesh those plans out with detail, in their own words — this is open
conversation, NOT a multiple-choice interview.

How to work:
- Invite the user to DESCRIBE the project in free text — start with the UI:
  the key screens, layout, look & feel, and what each screen does. Then move to
  backend behavior (API endpoints, business rules), then the data model. Ask one
  open, specific prompt at a time; never give multiple-choice options.
- When the user describes something, decide which plan file it belongs in:
  • UI / screens / look & feel / navigation  → the client/UI layer plan.
  • API / endpoints / services / auth / rules → the server plan.
  • entities / tables / relationships / data  → the database plan.
  • cross-cutting goals / scope / milestones  → Overview.
  Use `list_plans` to see the files if unsure.
- ALWAYS `read_plan` the target file first, then `update_plan` with the FULL new
  Markdown that folds their description into the right section. Preserve the
  existing headings and the `- [ ]` checkbox skeleton — ADD detail and new
  checklist items; never delete what is already there. Edits apply immediately.
- After each edit, tell the user in 1-2 sentences what you added and to which
  plan (e.g. "Added a Dashboard + Settings screen spec to Client.md.").
- When the plans look well fleshed out, let the user know they can keep going or
  click "Done refining" to start turning the plans into tasks. Do not finalize
  anything yourself — the user controls when refinement ends.
- Keep spoken replies short and concrete. Be a collaborative product partner.
''';
  }

  /// Runs one user turn with an internal tool loop. Returns the assistant's
  /// final spoken text. The callbacks surface the live conversation so the UI
  /// can render it inline (mirroring the coordinator chat):
  ///   - [onThinking]      the model's reasoning channel for a round, if any.
  ///   - [onAssistantText] non-empty spoken content the model emits per round.
  ///   - [onToolCall]      a tool the model is about to run (name + args).
  ///   - [onToolResult]    that tool's outcome.
  Future<String> send(
    String userMessage, {
    void Function(String name, String result)? onToolResult,
    void Function(String reasoning)? onThinking,
    void Function(String text)? onAssistantText,
    void Function(String name, Map<String, dynamic> args)? onToolCall,
    void Function(List<Map<String, dynamic>> messages)? onTrace,
  }) async {
    _cancelled = false;
    // Hard-drop the interview working context at the interview→refine boundary:
    // the plans now exist and the refine stage starts fresh (the transcript is
    // preserved separately for restore).
    if (leanContext && phase == SetupPhase.refine && !_interviewDropped) {
      _history.clear();
      _interviewDropped = true;
    }

    _history.add({'role': 'user', 'content': userMessage});
    _transcript.add({'role': 'user', 'content': userMessage});
    _fullTrace.add({'role': 'user', 'content': userMessage});
    final rollbackTo = _history.length - 1;
    // Declared outside the try so the post-catch return can still check it.
    var executedTool = false;

    try {
      // Board-state summary (interview only) lets us trim the transcript without
      // the model losing track of what's already chosen — the DB is the truth.
      final stateSummary = (leanContext && phase == SetupPhase.interview)
          ? await executor.setupStateSummary()
          : '';

      // Counts consecutive rounds that produced neither tool calls nor spoken
      // text — a true stall. We auto-nudge those back into motion. A spoken
      // reply with no tool is a legitimate conversational turn and is NOT a stall.
      var emptyRounds = 0;
      // Bounds how many times per turn we force the model to reconcile a
      // looked-up-but-undecided package before letting the turn end (the pending
      // state persists to the next turn and still blocks finalize, so nothing
      // slips through — this only prevents an in-turn infinite loop).
      var reconcileRounds = 0;
      // Bounds how many times per turn we force the model to RECORD a selection
      // the user just made via ask_question but the model only acknowledged
      // (the common "picked some features → model says 'great!' → stops without
      // propose_tags" stall that leaves a required section empty).
      var selectionNudges = 0;
      // Bounds how many times per turn we push the model to re-ask via the
      // ask_question TOOL after it typed a question (with options) as a plain
      // message — which renders no buttons, so the user can't answer.
      var askToolNudges = 0;
      for (var round = 0; round < maxToolRounds; round++) {
        // The user tapped "stop" — abort before issuing another model round.
        if (_cancelled) return '';
        // The system prompt is kept STATIC (phase-only) and the tool list is
        // deterministic, so the [system + tools] prefix is byte-identical every
        // round and across turns — which is exactly what llama.cpp/Lemonade
        // prefix-caching reuses. The volatile board state is appended at the TAIL
        // (after history) so it never invalidates that cached prefix.
        //
        // NOTE: the tail notes MUST NOT be role "system" — the server only
        // accepts a system message at index 0 and rejects any other system
        // message with 400 "system message must be at the beginning". They are
        // sent as framed user-role notes instead (the model treats a trailing
        // note the same as instructions; it still generates the next step).
        final messages = <Map<String, dynamic>>[
          {'role': 'system', 'content': _systemPrompt()},
          ...(leanContext ? _recentHistory() : _history),
          if (stateSummary.isNotEmpty)
            {
              'role': 'user',
              'content':
                  '(Context note, not a user answer — do not respond to it ' 
                  'directly; just keep it in mind:)$stateSummary',
            },
        ];
        // Deterministic "ask THIS one topic next" instruction (interview only) so
        // the host walks the topics in order instead of jumping ahead / batching.
        // Recomputed each round so it advances as topics get tagged this turn.
        if (phase == SetupPhase.interview) {
          final next = await executor.nextTopicInstruction(flow.stages);
          if (next.isNotEmpty) {
            messages.add({
              'role': 'user',
              'content':
                  '(Instruction for your next step — follow it now: $next)',
            });
          }
        }
        final tools = phase == SetupPhase.refine
            ? SetupTools.buildRefineToolSchemas()
            : SetupTools.buildToolSchemas(
                categories: tagCategories,
                includeLibraryTools: true,
              );

        final resp = await _completeWithRetry(messages, tools);
        // The user tapped "stop" WHILE this round's (blocking) generation was in
        // flight. Discard its output entirely — don't speak the text, record it,
        // or execute its tools — so a runaway/looping answer is genuinely cut
        // short instead of applying one last full round of effects.
        if (_cancelled) return '';
        final msg = resp.choices.isNotEmpty ? resp.choices.first.message : null;
        final content = msg?.content ?? '';
        final toolCalls = msg?.toolCalls ?? const <ToolCall>[];

        final reasoning = msg?.reasoning;
        if (reasoning != null && reasoning.trim().isNotEmpty) {
          onThinking?.call(reasoning.trim());
          _fullTrace.add({'role': 'thinking', 'content': reasoning.trim()});
        }
        if (content.trim().isNotEmpty) {
          onAssistantText?.call(content.trim());
          _transcript.add({'role': 'assistant', 'content': content.trim()});
        }

        final assistantEntry = <String, dynamic>{
          'role': 'assistant',
          'content': (toolCalls.isNotEmpty && content.isEmpty) ? null : content,
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

        if (toolCalls.isEmpty) {
          // A SPOKEN reply with no tool is a normal conversational turn now (an
          // open question or a reaction) — hand it back to the user. Only a truly
          // EMPTY round (no text AND no tool) is a stall worth auto-nudging, so
          // the user never has to type "?" to unstick a silent model.
          final spoke = content.trim().isNotEmpty;
          if (!spoke && phase == SetupPhase.interview && emptyRounds < 2) {
            emptyRounds++;
            _history.add({'role': 'user', 'content': _continueNudge});
            continue;
          }
          // ANTI-STALL: the user just answered an ask_question but the model is
          // about to end the turn without recording it (no propose_tags). That's
          // the "picked features → model acknowledged → stopped" stall that
          // leaves a required section empty and the Generate-plan button stuck.
          // Poke it to save the selection before stopping.
          if (phase == SetupPhase.interview &&
              executor.lastSelection != null &&
              selectionNudges < 2) {
            selectionNudges++;
            final sel = executor.lastSelection!;
            executor.lastSelection = null;
            _history.add({
              'role': 'user',
              'content':
                  'You have NOT recorded the user\'s last answer ($sel). Call '
                  'propose_tags NOW to save those under the matching category, '
                  'then continue with the next topic — do not stop until their '
                  'selections are on the board.',
            });
            continue;
          }
          // ANTI-PROSE-QUESTION: the model wrote a question (with options) as a
          // chat message instead of calling ask_question, so NO selectable
          // buttons rendered and the user cannot answer. Force it through the
          // tool. The tells below ("Options:", "select all", "(select…") are
          // what the model emits when it simulates the picker in prose.
          final low = content.toLowerCase();
          final looksLikeProseQuestion =
              low.contains('options:') ||
              low.contains('select all') ||
              low.contains('(you may select') ||
              low.contains('(select');
          if (phase == SetupPhase.interview &&
              looksLikeProseQuestion &&
              askToolNudges < 2) {
            askToolNudges++;
            _history.add({
              'role': 'user',
              'content':
                  'To collect the user\'s answer, ask that question with the '
                  '`ask_question` tool now (question + options, multi:true) — it '
                  'shows tappable buttons the user can answer.',
            });
            continue;
          }
          // GUARD (we are the hand-holder, not the model): never let a turn end
          // with an item the host looked up or was weighing left undecided. Every
          // lookup_package / consider_items option must resolve to an add
          // (propose_tags) or an explicit skip (dismiss_item). If any dangle,
          // force the model to reconcile them now — that's how an announced
          // "let me think about these…" silently produced nothing.
          if (phase == SetupPhase.interview && reconcileRounds < 2) {
            final pending = executor.pendingDecisions;
            if (pending.isNotEmpty) {
              reconcileRounds++;
              _history.add({
                'role': 'user',
                'content':
                    'Before you stop: you were weighing ${pending.join(', ')} '
                    'but have not decided on ${pending.length == 1 ? 'it' : 'them'}. '
                    'For EACH, either call propose_tags to add it or dismiss_item '
                    'to skip it with a reason. If you are unsure which to keep, '
                    'ask the user with ask_question first.',
              });
              continue;
            }
          }
          if (executedTool) onTrace?.call(_traceMessages());
          return content;
        }
        emptyRounds = 0;
        executedTool = true;

        for (final call in toolCalls) {
          Map<String, dynamic> args = {};
          try {
            final raw = call.function.arguments.trim();
            if (raw.startsWith('{')) {
              args = (jsonDecode(raw) as Map).cast<String, dynamic>();
            }
          } catch (_) {}

          onToolCall?.call(call.function.name, args);

          final action = _loopGuard.observe(call.function.name, args);
          if (action == LoopAction.block) {
            final note = _loopGuard.feedback(call.function.name, action);
            onToolResult?.call(call.function.name, note);
            final blockEntry = <String, dynamic>{
              'role': 'tool',
              'tool_call_id': call.id,
              'content': note,
            };
            _history.add(blockEntry);
            _fullTrace.add(Map<String, dynamic>.from(blockEntry));
            continue; // refuse the looping call; model must change course
          }

          // A tool that THROWS (network drop, registry 5xx, a DB upsert error in
          // propose_tags) must NOT abort the whole turn — that's how an announced
          // action ("let me check a few libraries…") silently produced nothing.
          // Surface the failure to the model as this tool's result with an
          // explicit retry instruction so it self-corrects within the remaining
          // rounds; the LoopGuard still bounds a tool that keeps failing.
          String result;
          var threw = false;
          try {
            result = await executor.execute(call.function.name, args);
          } catch (e) {
            threw = true;
            result =
                'ERROR: ${call.function.name} failed and did NOT take effect: '
                '$e. Retry this tool once now (or take a different step) — do '
                'not tell the user it succeeded.';
          }
          onToolResult?.call(call.function.name, result);
          // Generating the plans flips the host into the refine stage so the
          // rest of this turn (and the next) uses the plan-editing toolset —
          // but ONLY when finalize actually succeeded. A rejected finalize
          // ("Not ready to finalize — …") returns WITHOUT throwing, so gate on
          // the success message too or one premature call would flip the live
          // interview into refine mid-turn (board state stops being injected,
          // the toolset changes) while required sections are still missing.
          if (!threw &&
              call.function.name == 'finalize_setup' &&
              result.startsWith('Setup finalized')) {
            phase = SetupPhase.refine;
          }
          final body = action == LoopAction.warn
              ? '$result\n\n${_loopGuard.feedback(call.function.name, action)}'
              : result;
          final toolEntry = <String, dynamic>{
            'role': 'tool',
            'tool_call_id': call.id,
            'content': body,
          };
          _history.add(toolEntry);
          _fullTrace.add(Map<String, dynamic>.from(toolEntry));
        }
      }
    } catch (e) {
      if (rollbackTo < _history.length) {
        _history.removeRange(rollbackTo, _history.length);
      }
      rethrow;
    }

    if (executedTool) onTrace?.call(_traceMessages());
    return '';
  }

  /// A full OpenAI-shape conversation trace (system + history) for the training
  /// sink — captured at turn end when the model used a tool.
  List<Map<String, dynamic>> _traceMessages() => [
    {'role': 'system', 'content': _systemPrompt()},
    ..._fullTrace,
  ];

  /// Calls the model with a bounded retry so a transient inference failure
  /// (dropped socket, 5xx, throttle) self-heals instead of surfacing an error
  /// the user has to manually nudge past. Re-throws only after all attempts.
  Future<ChatCompletionResponse> _completeWithRetry(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await client.createChatCompletion(
          model: _effectiveModel,
          messages: messages,
          tools: tools,
          temperature: 0.6,
          // Anti-runaway: a mild repeat penalty stops a weak local model from
          // looping on its own reasoning forever, and the token cap is a hard
          // backstop so any runaway round still terminates.
          repeatPenalty: 1.15,
          maxCompletionTokens: 8192,
          enableThinking: enableThinking,
          // Only self-managed Lemonade has an isolated prompt cache. A routed
          // backend may multiplex unrelated sessions onto shared model slots.
          extra: {
            'cache_prompt': client.allowsPromptKvCache,
            // Agent's thinking level, sent as-is (never clamped).
            if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
          },
        );
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? StateError('inference failed');
  }

  /// The recent slice of working [_history] to send: the last
  /// [_historyWindowTurns] user-initiated turns (each with its assistant + tool
  /// messages), sliced at a user-message boundary so tool_call/result pairs stay
  /// intact. Nudges don't count as turns. Older context is carried by the
  /// injected board-state summary, not the raw transcript.
  List<Map<String, dynamic>> _recentHistory() {
    final userIdx = <int>[];
    for (var i = 0; i < _history.length; i++) {
      if (_history[i]['role'] == 'user' &&
          _history[i]['content'] != _continueNudge) {
        userIdx.add(i);
      }
    }
    if (userIdx.length <= _historyWindowTurns) return _history;
    final start = userIdx[userIdx.length - _historyWindowTurns];
    return _history.sublist(start);
  }

  void clearHistory() {
    _history.clear();
    _transcript.clear();
    _fullTrace.clear();
    _interviewDropped = false;
    _loopGuard.reset();
  }

  /// Serialize the transcript (user/assistant text turns) for persistence in
  /// `Projects.setupTranscriptJson`. Sourced from [_transcript], which is
  /// append-only and unaffected by working-context trimming.
  String toTranscriptJson() {
    final turns = _transcript
        .where(
          (m) =>
              (m['content'] is String) && (m['content'] as String).isNotEmpty,
        )
        .map((m) => {'role': m['role'], 'content': m['content']})
        .toList();
    return jsonEncode(turns);
  }
}
