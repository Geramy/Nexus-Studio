// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import '../../../infrastructure/database/nexus_database.dart';
import '../../../infrastructure/inference/inference_backend.dart';
import '../../../infrastructure/workspace/git/nxtprj_git_engine.dart';
import '../../../infrastructure/workspace/workspace.dart';
import '../../agents/agent_role.dart';
import '../../project_plans/plan_store.dart';
import '../../project_setup/plan_task_sync.dart';
import '../coordinator_session.dart';
import 'planning_prompts.dart';

/// Outcome summary of a [ProjectPlanningRun], for a closing chat line.
class PlanningRunResult {
  PlanningRunResult({
    required this.planningRounds,
    required this.reviewRounds,
    required this.approvals,
    required this.reviewers,
    required this.tasksCreated,
    required this.started,
  });

  final int planningRounds;
  final int reviewRounds;
  final int approvals;
  final int reviewers;
  final int tasksCreated;
  final bool started;
}

/// The deep planning pass that runs when the PM clicks "Done" (or "Build the
/// plan"): a planning agent expands the brief into a rich, granular `/PLANS`,
/// the engineer (worker) agents review it until a majority sign off, then the
/// outline items are materialized into small tasks and the orchestrator starts.
///
/// Built entirely on the existing headless [ProjectCoordinatorSession] +
/// [PlanTaskSync]; behavior is driven by the planner/reviewer system prompts.
class ProjectPlanningRun {
  ProjectPlanningRun({
    required this.db,
    required this.planStore,
    required this.backend,
    required this.projectId,
    required this.projectName,
    this.model,
    this.enableThinking,
    this.reasoningEffort,
    this.brief = '',
    this.chatSessionPk,
    this.onProgress,
    this.workspace,
    this.git,
    this.scaffold = false,
    this.maxPlanningRounds = 6,
    this.maxReviewRounds = 2,
    this.maxScaffoldRounds = 4,
  });

  final NexusDatabase db;
  final PlanStore planStore;
  final InferenceBackend backend;
  final int projectId;
  final String projectName;
  final String? model;
  final bool? enableThinking;

  /// Effective thinking level (e.g. 'low'), sent verbatim as `reasoning_effort`
  /// on every planning session. Null omits the parameter.
  final String? reasoningEffort;

  /// Workspace + git handles for the scaffolding phase. When [scaffold] is true
  /// and these are present, the run writes a base project skeleton to disk and
  /// commits it to `main` before agents start, so they have files to work in.
  final Workspace? workspace;
  final NxtprjGitEngine? git;

  /// Whether to scaffold a base project structure (Application Development only).
  final bool scaffold;

  /// The PM's brief + current project state, seeded into the planner's first
  /// turn so it expands from everything that was said.
  final String brief;
  final int? chatSessionPk;

  /// Live progress sink — each line is surfaced in the setup/coordinator chat.
  final void Function(String line)? onProgress;

  final int maxPlanningRounds;
  final int maxReviewRounds;
  final int maxScaffoldRounds;

  void _say(String line) => onProgress?.call(line);

  /// Run the full pass. Safe to re-run (PlanTaskSync dedups; the planner only
  /// enriches existing plans).
  Future<PlanningRunResult> run() async {
    var planningRounds = 0;
    var reviewRounds = 0;
    var approvals = 0;
    var reviewers = 0;

    // ── 1. Expand the plan, then review; loop until a majority approve. ──
    _say('⟳ Planning the project — expanding your brief into a detailed plan…');
    planningRounds += await _expand(extraGuidance: brief, kickoff: true);

    while (true) {
      final review = await _review();
      reviewRounds++;
      reviewers = review.total;
      approvals = review.approvals;

      if (review.approved || reviewRounds > maxReviewRounds) {
        if (review.approved) {
          _say(
            '✓ Engineers signed off (${review.approvals}/${review.total}) — building tasks…',
          );
        } else {
          _say(
            '• Proceeding after $reviewRounds review round(s) — building tasks…',
          );
        }
        break;
      }

      _say(
        '• ${review.approvals}/${review.total} engineers approved — addressing flagged gaps…',
      );
      planningRounds += await _expand(
        extraGuidance: review.gaps.join('\n'),
        kickoff: false,
      );
    }

    // ── 2. Materialize outline items into small tasks. ──
    final sync = await PlanTaskSync(
      db: db,
      planStore: planStore,
      projectId: projectId,
      chatSessionPk: chatSessionPk,
    ).sync();
    _say('✓ Built ${sync.created} task(s) from the plan.');

    // ── 2b. Scaffold the base project skeleton (Application Development) so the
    // agents have real files to work in, committed to main before they branch.
    if (scaffold && workspace != null) {
      try {
        await _scaffold();
      } catch (e) {
        _say('• Scaffolding skipped ($e).');
      }
    }

    // ── 3. Start the autonomous agents. ──
    await db.setProjectOrchestrationState(projectId, 'running');
    _say('▶ Agents started — they\'ll work the board now.');

    return PlanningRunResult(
      planningRounds: planningRounds,
      reviewRounds: reviewRounds,
      approvals: approvals,
      reviewers: reviewers,
      tasksCreated: sync.created,
      started: true,
    );
  }

  /// Drive the planner over up to [maxPlanningRounds] turns until it calls
  /// `mark_planning_complete`. Returns how many turns ran.
  Future<int> _expand({
    required String extraGuidance,
    required bool kickoff,
  }) async {
    var done = false;
    final session = ProjectCoordinatorSession(
      client: backend,
      projectId: projectId,
      projectName: projectName,
      db: db,
      model: model,
      planStore: planStore,
      chatSessionPk: chatSessionPk,
      systemPromptOverride: plannerSystemPrompt(projectName),
      enableThinking: enableThinking,
      reasoningEffort: reasoningEffort,
      onPlanningComplete: () => done = true,
    );

    var rounds = 0;
    for (var i = 0; i < maxPlanningRounds && !done; i++) {
      final prompt = i == 0
          ? (kickoff
                ? 'Project brief and current state:\n\n$extraGuidance\n\n'
                      'Expand the /PLANS now per your instructions — make every layer '
                      'deep and granular, then call mark_planning_complete when done.'
                : 'Engineers reviewed the plan and flagged these gaps:\n\n$extraGuidance\n\n'
                      'Revise the /PLANS to address them, then call mark_planning_complete.')
          : 'Continue expanding the plans. Split any oversized items. Call '
                'mark_planning_complete when every layer is complete and granular.';
      await for (final _ in session.runTurn(prompt, maxToolRounds: 6)) {
        // Drain; plan writes + the completion signal happen inside the stream.
      }
      rounds++;
      if (i == 0) {
        _say('⟳ Planning round $rounds — expanded the plan.');
      }
    }
    return rounds;
  }

  /// Each worker ("engineer") persona reviews the plan and votes. Majority
  /// approval passes. Personas with no worker role are skipped; if there are no
  /// workers at all, the plan auto-passes (nothing to gate on).
  Future<_ReviewOutcome> _review() async {
    final personas = await db.getAgentPersonasForProject(projectId);
    final engineers = personas.where((p) {
      final role = agentRoleFromKey(p.title);
      return role != null && role.isWorker;
    }).toList();

    if (engineers.isEmpty) {
      return _ReviewOutcome(
        approvals: 0,
        total: 0,
        gaps: const [],
        approved: true,
      );
    }

    var approvals = 0;
    final gaps = <String>[];
    for (final eng in engineers) {
      bool? approved;
      var gapText = '';
      final session = ProjectCoordinatorSession(
        client: backend,
        projectId: projectId,
        projectName: projectName,
        db: db,
        model: model,
        planStore: planStore,
        chatSessionPk: chatSessionPk,
        systemPromptOverride: engineerReviewSystemPrompt(projectName, eng.name),
        enableThinking: enableThinking,
        reasoningEffort: reasoningEffort,
        onPlanReview: (ok, g) {
          approved = ok;
          gapText = g;
        },
      );

      // Give the reviewer a few rounds to read the plans and submit a verdict.
      for (var i = 0; i < 3 && approved == null; i++) {
        final prompt = i == 0
            ? 'Review the current /PLANS and submit your verdict with submit_plan_review.'
            : 'Finish your review now and call submit_plan_review.';
        await for (final _ in session.runTurn(prompt, maxToolRounds: 5)) {}
      }

      if (approved == true) {
        approvals++;
        _say('  ✓ ${eng.name} approved the plan.');
      } else {
        if (gapText.trim().isNotEmpty) {
          gaps.add('${eng.name}: ${gapText.trim()}');
        }
        _say('  • ${eng.name} flagged gaps.');
      }
    }

    final total = engineers.length;
    return _ReviewOutcome(
      approvals: approvals,
      total: total,
      gaps: gaps,
      approved: approvals * 2 > total, // strict majority
    );
  }

  /// Write a base project skeleton (directories, manifests, stub source files
  /// with namespace/class outlines) to the workspace and commit it to `main`, so
  /// the engineering agents inherit it on their task branches and the user sees
  /// the project structure immediately. Best-effort; bounded to
  /// [maxScaffoldRounds] turns. Application Development only (gated by [scaffold]).
  Future<void> _scaffold() async {
    final ws = workspace;
    if (ws == null) return;
    _say('🧱 Scaffolding the base project structure…');

    // Scaffold onto main so every task branch (created off main) inherits it.
    try {
      await git?.checkoutBranch('main');
    } catch (_) {
      // No main yet / git not ready — the agent commits on the current branch.
    }

    final session = ProjectCoordinatorSession(
      client: backend,
      projectId: projectId,
      projectName: projectName,
      db: db,
      model: model,
      planStore: planStore,
      workspace: ws,
      git: git,
      // The scaffolder needs the file + git tools directly (no progressive
      // disclosure), and runs autonomously so `ask`-gated ops auto-approve.
      leanTools: false,
      confirmAsk: (_, _) async => true,
      systemPromptOverride: scaffolderSystemPrompt(projectName),
      enableThinking: enableThinking,
      reasoningEffort: reasoningEffort,
    );

    for (var i = 0; i < maxScaffoldRounds; i++) {
      final prompt = i == 0
          ? 'Read /PLANS, then create the base project skeleton now per your '
                'instructions and commit it.'
          : 'Continue creating any remaining base/stub files, then commit. Stop '
                'once the skeleton compiles and every planned component has a stub.';
      await for (final _ in session.runTurn(prompt, maxToolRounds: 8)) {}
    }
    _say('✓ Base project structure created.');
  }
}

class _ReviewOutcome {
  _ReviewOutcome({
    required this.approvals,
    required this.total,
    required this.gaps,
    required this.approved,
  });
  final int approvals;
  final int total;
  final List<String> gaps;
  final bool approved;
}
