// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart';
import 'package:nexus_projects_client/infrastructure/inference/inference_backend_factory.dart'
    show backendForServer;
import 'package:nexus_projects_client/infrastructure/inference/routed_server.dart'
    show isRoutedProviderType;
import 'package:nexus_projects_client/infrastructure/inference/inference_client.dart'
    show InferenceBackend;
import 'package:nexus_projects_client/infrastructure/models/ui/inference_server.dart'
    as ui_server;
import 'package:nexus_projects_client/infrastructure/workspace/async_lock.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/git_engine_provider.dart';
import 'package:nexus_projects_client/infrastructure/build/build_models.dart'
    show CiStatus, CiStatusX;
import 'package:nexus_projects_client/infrastructure/build/build_service.dart';
import 'package:nexus_projects_client/infrastructure/build/build_service_provider.dart';
import 'package:nexus_projects_client/features/agents/thinking_mode.dart';
import 'package:nexus_projects_client/features/agents/agent_role.dart';
import 'package:nexus_projects_client/features/agents/agent_role_policy.dart';
import 'package:nexus_projects_client/features/agents/agent_tool_permissions.dart';
import 'package:nexus_projects_client/features/projects/coordinator_session.dart';
import 'package:nexus_projects_client/features/projects/orchestration/orchestrator_prompts.dart';
import 'package:nexus_projects_client/features/projects/orchestration/weighted_scheduler.dart';
import 'package:nexus_projects_client/features/projects/project_working_hours.dart';
import 'package:nexus_projects_client/features/projects/task_workflow.dart';

/// Live driver for a project's autonomous task pipeline.
///
/// It watches the project's `orchestrationState` (Start/Pause/Stop) and the
/// working-hours window. While the project is `running` and inside its hours,
/// it advances tasks through the full pipeline, one unit of work per loop:
///   1. **Implement** — an assigned worker task on the board gets an ephemeral
///      worker session on branch `task/<id>`, driven to `submit_for_completion`.
///   2. **Verify** — a submitted task gets an ephemeral Verification Agent that
///      runs the task's verification and emits a pass/fail verdict.
///   3. **Build** — a verified task that `requiresBuild` is built/CI'd directly
///      by the orchestrator (no LLM); the result advances it to `built` or back
///      to the board. Tasks without a build gate skip straight to merge.
///   4. **Merge** — a merge-ready task (built, or verified without a build gate)
///      gets an ephemeral Coordinator that merges the task's work branch into
///      its integration target (the parent task's branch for a subtask,
///      otherwise main) and approves the task to Done.
///
/// Stages that need an agent degrade gracefully: if no Verification Agent or
/// Coordinator persona exists for the client, the task is left in place.
///
/// One orchestrator exists per project (via [projectOrchestratorProvider]); it
/// processes tasks sequentially to avoid agents fighting over the workspace.
class ProjectOrchestrator {
  final Ref ref;
  final int projectId;

  StreamSubscription<Project?>? _projectSub;
  Timer? _ticker;

  /// True while [_pump] is actively walking the task queue, so overlapping
  /// triggers (state change + ticker) don't spawn concurrent workers.
  bool _pumping = false;
  bool _disposed = false;

  /// Tasks currently being executed in this process, so a re-pump doesn't pick
  /// up a task that's mid-run (its executionStatus is `running`).
  final Set<int> _active = {};

  /// Per-task worker attempt counts, to cap retries on a task that keeps
  /// failing to submit rather than spinning forever.
  final Map<int, int> _attempts = {};

  /// Fair, backlog-weighted scheduler over the pipeline stages, so verify/build/
  /// merge aren't starved by a long implement queue while busier stages still
  /// get proportionally more turns.
  final WeightedRoundRobin<_Stage> _scheduler = WeightedRoundRobin<_Stage>();

  static const int _maxAttemptsPerTask = 2;
  static const int _maxTurnsPerTask = 12;
  static const int _maxTurnsPerStage = 8;
  static const Duration _tickInterval = Duration(seconds: 30);
  static const Duration _buildPollInterval = Duration(seconds: 3);
  static const Duration _buildTimeout = Duration(minutes: 30);

  ProjectOrchestrator(this.ref, this.projectId);

  NexusDatabase get _db => ref.read(nexusDatabaseProvider);

  void start() {
    // Clear any leftover per-task working-tree disks from a previous crash.
    unawaited(pruneTaskDisks(projectId));
    // Reconcile tasks orphaned mid-run by a crash/quit: our in-memory _active
    // set is empty on a fresh start, so any task still marked `running` in the
    // DB would never be re-picked. Return them to the board.
    unawaited(_reconcileOrphans());
    _projectSub = _db.watchProject(projectId).listen((project) {
      if (project?.orchestrationState == 'running') {
        unawaited(_pump());
      }
    });
    _ticker = Timer.periodic(_tickInterval, (_) => unawaited(_pump()));
  }

  void dispose() {
    _disposed = true;
    _projectSub?.cancel();
    _ticker?.cancel();
  }

  /// Fill up to N agent slots (N = the account's max concurrency) with the next
  /// fair, backlog-weighted pieces of work, launching each on its own isolated
  /// working tree. Returns immediately after dispatching; each stage frees its
  /// slot and re-pumps on completion. [_pumping] guards only the dispatch loop,
  /// not the work, so it never serializes the agents.
  Future<void> _pump() async {
    if (_pumping || _disposed) return;
    _pumping = true;
    try {
      final project = await _db.getProjectById(projectId);
      if (project == null || project.orchestrationState != 'running') return;
      if (!isWithinWorkingHours(project)) return;

      final cap = await _concurrencyCap(project);
      while (!_disposed && _active.length < cap) {
        final (task, stage) = await _nextPipelineWork();
        if (task == null || stage == null) break;
        _active.add(task.task_pk);
        unawaited(_runStage(task, stage));
      }
      await _surfaceStalledTasks();
    } finally {
      _pumping = false;
    }
  }

  /// Return tasks left `running` by a prior crash/quit (not tracked in [_active])
  /// to the board so they get re-picked. Safe to call repeatedly.
  Future<void> _reconcileOrphans() async {
    try {
      final tasks = await _db.getTasksForProject(projectId);
      for (final t in tasks) {
        if (t.executionStatus == TaskExecStatus.running &&
            !_active.contains(t.task_pk)) {
          await _db.markTaskYieldedBack(t.task_pk);
        }
      }
    } catch (e) {
      debugPrint('[Orchestrator p$projectId] orphan reconcile failed: $e');
    }
  }

  /// Surface tasks that have exhausted their retry budget: move them to the
  /// Blocked column so they're visible to the user instead of silently sitting
  /// on Todo and being skipped every pump. Idempotent — a Blocked task is no
  /// longer on Todo, so it isn't re-evaluated here.
  Future<void> _surfaceStalledTasks() async {
    try {
      final tasks = await _db.getTasksForProject(projectId);
      for (final t in tasks) {
        if ((_attempts[t.task_pk] ?? 0) >= _maxAttemptsPerTask &&
            t.status == TaskStatus.todo &&
            !_active.contains(t.task_pk)) {
          debugPrint(
            '[Orchestrator p$projectId] task ${t.task_pk} exhausted '
            '$_maxAttemptsPerTask attempts → Blocked.',
          );
          await _db.markTaskBlocked(t.task_pk);
        }
      }
    } catch (e) {
      debugPrint('[Orchestrator p$projectId] stall surface failed: $e');
    }
  }

  /// Run one (task, stage) to completion, then free its slot and re-pump so a
  /// waiting piece of work fills the freed slot.
  Future<void> _runStage(Task task, _Stage stage) async {
    try {
      switch (stage) {
        case _Stage.implement:
          await _runTaskToSubmission(task);
        case _Stage.verify:
          await _runVerifyStage(task);
        case _Stage.build:
          await _runBuildStage(task);
        case _Stage.merge:
          await _runMergeStage(task);
      }
    } catch (e, st) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk} ${stage.name} errored: $e\n$st',
      );
    } finally {
      _active.remove(task.task_pk);
      if (!_disposed) unawaited(_pump());
    }
  }

  /// Pick the single next task + stage to act on. Work is one-at-a-time (all
  /// agents share one git working tree), but instead of strict priority we use a
  /// smooth weighted round-robin across the four stages, weighted by each
  /// stage's backlog — so verify/build/merge are never starved by a long
  /// implement queue, while busier stages ("more to do") still get
  /// proportionally more turns.
  Future<(Task?, _Stage?)> _nextPipelineWork() async {
    final tasks = await _db.getTasksForProject(projectId);
    final review = tasks
        .where(
          (t) => !_active.contains(t.task_pk) && t.status == TaskStatus.review,
        )
        .toList();

    final pools = <_Stage, List<Task>>{};
    void addPool(_Stage s, List<Task> list) {
      if (list.isNotEmpty) pools[s] = _sortByPriority(list);
    }

    addPool(_Stage.implement, _assignableTasks(tasks));
    addPool(
      _Stage.verify,
      review
          .where((t) => t.executionStatus == TaskExecStatus.submitted)
          .toList(),
    );
    addPool(
      _Stage.build,
      review
          .where(
            (t) =>
                t.executionStatus == TaskExecStatus.verified && t.requiresBuild,
          )
          .toList(),
    );
    addPool(
      _Stage.merge,
      review
          .where(
            (t) =>
                t.executionStatus == TaskExecStatus.built ||
                (t.executionStatus == TaskExecStatus.verified &&
                    !t.requiresBuild),
          )
          .toList(),
    );

    final stage = _scheduler.pick({
      for (final e in pools.entries) e.key: e.value.length,
    });
    if (stage == null) return (null, null);
    return (pools[stage]!.first, stage);
  }

  List<Task> _sortByPriority(List<Task> list) {
    list.sort((a, b) {
      final p = _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
      if (p != 0) return p;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  /// Tasks ready for a worker: assigned to a worker-role persona, on the Todo
  /// board, not already running here, and under the retry cap.
  List<Task> _assignableTasks(List<Task> tasks) {
    final out = <Task>[];
    for (final t in tasks) {
      if (t.task_agent_fk == null) continue;
      if (_active.contains(t.task_pk)) continue;
      if ((_attempts[t.task_pk] ?? 0) >= _maxAttemptsPerTask) continue;
      final isStartable =
          t.status == TaskStatus.todo &&
          (t.executionStatus == TaskExecStatus.idle ||
              t.executionStatus == TaskExecStatus.queued ||
              t.executionStatus == TaskExecStatus.failed);
      if (isStartable) out.add(t);
    }
    return out;
  }

  int _priorityRank(String p) => switch (p.toUpperCase()) {
    'HIGH' || 'HI' || 'URGENT' => 3,
    'MED' || 'MEDIUM' => 2,
    'LOW' => 1,
    _ => 2,
  };

  /// Spawn an ephemeral worker for [task] and run it until it submits (or the
  /// turn cap is hit, or the project leaves the running state).
  Future<void> _runTaskToSubmission(Task task) async {
    final agentFk = task.task_agent_fk;
    if (agentFk == null) return;

    final persona = await _db.resolveAgentPersona(agentFk);
    if (persona == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: assigned persona $agentFk not found.',
      );
      return;
    }
    final role = agentRoleFromKey(persona.title);
    if (role == null || !role.isWorker) {
      // Only worker roles are auto-spawned; coordinator/verifier/PM tasks are
      // driven elsewhere. Leave the task untouched.
      return;
    }

    final resolved = await _resolveBackend(persona);
    if (resolved == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no inference server for persona ${persona.name}.',
      );
      return;
    }

    final branch = 'task/${task.task_pk}';

    // This worker runs on its OWN isolated working tree so it can run in
    // parallel with other agents without clobbering their files. Git objects/
    // refs are shared; the lane serializes those writes.
    final th = await _resolveTaskHandles(task.task_pk);
    if (th == null) return;

    // Subtasks branch off their parent's branch so their commits merge back
    // into the parent (not the trunk); top-level tasks branch off main.
    final base = await _integrationTargetBranch(task);
    // Root the task branch on its base and hydrate this task's tree from it,
    // serialized through the lane (shared object/ref DB is single-isolate).
    await th.lane.run(() async {
      await th.git.createBranchAt(branch, base: base);
      await th.git.materializeInto(branch, th.tree);
    });

    try {
      final prompts = await _loadPrompts();
      final vars = _varsFor(task, branch, targetBranch: base);

      // One conversation PER AGENT: reuse this worker's dedicated session so all
      // of its tasks land in a single ongoing thread (the person can follow the
      // agent there) instead of a brand-new session on every task update.
      final workerSessionPk = await _db.getOrCreateAgentChatSession(
        projectId,
        agentFk,
        persona.name,
      );
      _attempts[task.task_pk] = (_attempts[task.task_pk] ?? 0) + 1;
      // Picked up & preparing the workspace — the task stays on the Todo board
      // (exec `queued`). It only flips to "In Progress" once a worker turn truly
      // begins (below), so the column never shows work nobody is doing.
      await _db.markTaskQueued(task.task_pk);

      final session = ProjectCoordinatorSession(
        client: resolved.client,
        projectId: projectId,
        projectName: persona.name,
        db: _db,
        model: resolved.model,
        chatSessionPk: workerSessionPk,
        permissions: AgentToolPermissions.fromConfigJson(persona.configJson),
        // Autonomous: there's no human to approve `ask` tools, so auto-approve.
        // The dangerous ops (push/merge) are *denied* for worker roles by the
        // rule engine, so this can't escalate a worker beyond its branch.
        confirmAsk: (_, _) async => true,
        agentName: persona.name,
        workspace: th.tree,
        git: th.git,
        buildService: th.build,
        // Per-task isolation: the agent edits its own tree and git_commit
        // snapshots it onto its branch under the lane.
        workBranch: branch,
        gitLane: th.lane,
        // Autonomous coders need file/git/build tools directly — no progressive
        // disclosure (that's for the interactive PM chat).
        leanTools: false,
        systemPromptOverride:
            '${defaultSystemPrompt(role)}\n${prompts.render(OrchestratorPromptField.workerFraming, vars)}',
        enableThinking: resolveEnableThinking(
          agent: personaThinkingMode(
            persona.configJson,
            personaName: persona.name,
          ),
          task: ThinkingMode.fromString(task.thinkingMode),
        ),
      );

      var kickoff = prompts.render(OrchestratorPromptField.workerKickoff, vars);
      for (var turn = 0; turn < _maxTurnsPerTask && !_disposed; turn++) {
        // Stop promptly if the human paused/stopped the project mid-task — return
        // the task to the board instead of leaving it parked "In Progress".
        final project = await _db.getProjectById(projectId);
        if (project == null || project.orchestrationState != 'running') {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: project not running, halting worker.',
          );
          await _db.markTaskYieldedBack(task.task_pk);
          return;
        }

        // The task becomes "In Progress" exactly when its agent starts a turn.
        if (turn == 0) {
          await _db.markTaskRunning(
            task.task_pk,
            workerSessionPk: workerSessionPk,
            workBranch: branch,
          );
        }

        try {
          await for (final _ in session.runTurn(kickoff)) {
            // Drain the stream; tool effects are applied inside runTurn.
          }
        } catch (e) {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: turn $turn failed: $e',
          );
          await _db.markTaskYieldedBack(task.task_pk);
          return;
        }

        final fresh = await _db.getTaskById(task.task_pk);
        if (fresh == null) return;
        if (fresh.executionStatus == TaskExecStatus.submitted) {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: submitted for review.',
          );
          return;
        }

        kickoff = prompts.render(OrchestratorPromptField.workerContinue, vars);
      }
      // Ran out of turns without submitting — back to the board (a fresh attempt
      // will re-pick it, up to the retry cap) rather than stuck "In Progress".
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: hit turn cap without submission.',
      );
      await _db.markTaskYieldedBack(task.task_pk);
    } finally {
      // Free this task's isolated working tree (the committed work lives on the
      // task branch in the shared object DB; the scratch tree is disposable).
      await _releaseTaskTree(task.task_pk);
    }
  }

  /// Load this project's effective orchestrator prompt templates (per-project
  /// overrides merged over the built-in defaults).
  Future<OrchestratorPrompts> _loadPrompts() async {
    final project = await _db.getProjectById(projectId);
    return OrchestratorPrompts.fromJson(project?.orchestratorPromptsJson);
  }

  /// The placeholder values for [task]'s prompt templates.
  PromptVars _varsFor(
    Task task,
    String branch, {
    String targetBranch = 'main',
  }) => PromptVars(
    taskId: task.task_pk,
    title: task.title,
    branch: branch,
    targetBranch: targetBranch,
    description: task.description ?? '',
    acceptanceCriteria: task.acceptanceCriteria ?? '',
    verification: task.verification ?? '',
  );

  /// The branch [task] integrates into: the parent task's work branch when it is
  /// a subtask, otherwise the trunk ("main"). Falls back to "main" if the parent
  /// is missing.
  Future<String> _integrationTargetBranch(Task task) async {
    final parentPk = task.task_parent_fk;
    if (parentPk == null) return 'main';
    final parent = await _db.getTaskById(parentPk);
    if (parent == null) return 'main';
    final pb = parent.workBranch?.trim();
    return (pb != null && pb.isNotEmpty) ? pb : 'task/$parentPk';
  }

  // ── Verify stage ──────────────────────────────────────────────────────

  /// Spawn an ephemeral Verification Agent for a submitted [task]. It runs the
  /// task's verification and emits a verdict (run_verification → submit_verdict),
  /// which advances the task to `verified` (awaiting build/merge) or back to the
  /// board on failure. If no Verification Agent persona exists, the task is left
  /// submitted for a human to verify.
  Future<void> _runVerifyStage(Task task) async {
    final persona = await _findPersonaForRole(AgentRole.verificationAgent);
    if (persona == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no Verification Agent persona; leaving submitted.',
      );
      return;
    }
    final resolved = await _resolveBackend(persona);
    if (resolved == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no inference server for verifier ${persona.name}.',
      );
      return;
    }
    final branch = task.workBranch ?? 'task/${task.task_pk}';
    final th = await _resolveTaskHandles(task.task_pk);
    if (th == null) return;
    // Hydrate an isolated tree with the submitted task branch so the verifier
    // reads the work without touching any other agent's tree.
    await th.lane.run(() => th.git.materializeInto(branch, th.tree));

    try {
      final prompts = await _loadPrompts();
      final vars = _varsFor(task, branch);
      // Reuse the Verification Agent's single per-agent session (see worker).
      final sessionPk = await _db.getOrCreateAgentChatSession(
        projectId,
        persona.agent_pk,
        persona.name,
      );

      final session = ProjectCoordinatorSession(
        client: resolved.client,
        projectId: projectId,
        projectName: persona.name,
        db: _db,
        model: resolved.model,
        chatSessionPk: sessionPk,
        permissions: AgentToolPermissions.fromConfigJson(persona.configJson),
        confirmAsk: (_, _) async => true,
        agentName: persona.name,
        workspace: th.tree,
        git: th.git,
        buildService: th.build,
        leanTools: false,
        systemPromptOverride:
            '${defaultSystemPrompt(AgentRole.verificationAgent)}\n${prompts.render(OrchestratorPromptField.verifyFraming, vars)}',
        enableThinking: resolveEnableThinking(
          agent: personaThinkingMode(
            persona.configJson,
            personaName: persona.name,
          ),
          task: ThinkingMode.fromString(task.thinkingMode),
        ),
      );

      var kickoff = prompts.render(OrchestratorPromptField.verifyKickoff, vars);
      for (var turn = 0; turn < _maxTurnsPerStage && !_disposed; turn++) {
        if (!await _stillRunning()) return;
        try {
          await for (final _ in session.runTurn(kickoff)) {}
        } catch (e) {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: verify turn $turn failed: $e',
          );
          return;
        }
        final fresh = await _db.getTaskById(task.task_pk);
        if (fresh == null) return;
        if (fresh.executionStatus != TaskExecStatus.submitted &&
            fresh.executionStatus != TaskExecStatus.verifying) {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: verdict recorded (${fresh.executionStatus}).',
          );
          return;
        }
        kickoff = prompts.render(OrchestratorPromptField.verifyContinue, vars);
      }
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: verify hit turn cap without a verdict.',
      );
    } finally {
      await _releaseTaskTree(task.task_pk);
    }
  }

  // ── Build stage ───────────────────────────────────────────────────────

  /// Drive the build gate for a `verified` task that `requiresBuild`, with no
  /// LLM in the loop: start the configured workflow or Docker build, wait for it
  /// to finish, and advance the task to `built` (awaiting merge) or back to the
  /// board on failure. The run is started with `taskPk: null` so BuildService's
  /// auto-approve-on-green rule doesn't fire — this stage owns the outcome.
  Future<void> _runBuildStage(Task task) async {
    final project = await _db.getProjectById(projectId);
    if (project == null) return;
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    final build = handles.build;
    if (ws == null || build == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: workspace/build unavailable; cannot build.',
      );
      return;
    }
    final branch = task.workBranch ?? 'task/${task.task_pk}';
    final workflowPath = task.workflowPath?.trim();
    final dockerfilePath = task.dockerfilePath?.trim();
    if ((workflowPath == null || workflowPath.isEmpty) &&
        (dockerfilePath == null || dockerfilePath.isEmpty)) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: requiresBuild but no workflow/dockerfile path; treating gate as satisfied.',
      );
      await _db.recordTaskBuildOutcome(task.task_pk, passed: true);
      return;
    }

    await _db.beginTaskBuild(task.task_pk);
    int runPk;
    try {
      if (workflowPath != null && workflowPath.isNotEmpty) {
        final started = await build.startWorkflowRun(
          clientPk: project.client_fk,
          projectPk: projectId,
          ws: ws,
          workflowPath: workflowPath,
          branch: branch,
          triggeredBy: 'orchestrator',
        );
        runPk = started.runPk;
      } else {
        final imageTag = (task.imageTag?.trim().isNotEmpty ?? false)
            ? task.imageTag!.trim()
            : 'task-${task.task_pk}:latest';
        final started = await build.startDockerBuild(
          clientPk: project.client_fk,
          projectPk: projectId,
          ws: ws,
          dockerfilePath: dockerfilePath!,
          imageTag: imageTag,
          branch: branch,
          triggeredBy: 'orchestrator',
        );
        runPk = started.runPk;
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: build failed to start: $e',
      );
      await _db.recordTaskBuildOutcome(task.task_pk, passed: false);
      return;
    }

    final deadline = DateTime.now().add(_buildTimeout);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_buildPollInterval);
      final run = await _db.getCiRun(runPk);
      if (run == null) break;
      final status = CiStatusX.fromWire(run.status);
      if (status.isTerminal) {
        final passed = status == CiStatus.success;
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: build run $runPk → ${status.wire}.',
        );
        await _db.recordTaskBuildOutcome(task.task_pk, passed: passed);
        return;
      }
    }
    debugPrint(
      '[Orchestrator p$projectId] task ${task.task_pk}: build run $runPk did not finish in time; failing the gate.',
    );
    await _db.recordTaskBuildOutcome(task.task_pk, passed: false);
  }

  // ── Merge stage ───────────────────────────────────────────────────────

  /// Spawn an ephemeral Coordinator to integrate a merge-ready [task]: merge
  /// `task/<id>` into its target branch (the parent task's branch for a subtask,
  /// otherwise main) and approve the task to Done. The Coordinator is the only
  /// role allowed to merge. If no Coordinator persona exists, the task is left
  /// awaiting a human merge.
  Future<void> _runMergeStage(Task task) async {
    final handles = await _resolveWorkspaceHandles();
    final git = handles.git;
    final lane = ref.read(gitLaneProvider(projectId));
    // A subtask integrates into its parent's branch; a top-level task into main.
    final targetBranch = await _integrationTargetBranch(task);
    final branch = task.workBranch ?? 'task/${task.task_pk}';

    await _db.beginTaskMerge(task.task_pk);

    // FAST PATH: a clean merge needs no agent — do it deterministically. The git
    // engine is conservative (it only reports a conflict when the SAME files
    // changed on both sides, and commits nothing in that case), so a non-conflict
    // outcome is safe to auto-approve. An agent is only pulled in for a real
    // conflict, exactly as the user expects. Serialized through the lane since it
    // mutates the shared tree/refs while other agents may be committing.
    if (git != null) {
      try {
        final result = await lane.run(() async {
          await _checkout(git, targetBranch, task.task_pk);
          return git.merge(
            branch,
            message: 'Merge task #${task.task_pk}: ${task.title}',
          );
        });
        if (result.outcome != MergeOutcome.conflicts) {
          await _db.approveTask(task.task_pk);
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: auto-merged (${result.outcome.name}) into "$targetBranch".',
          );
          return;
        }
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: merge conflicts on ${result.conflicts.length} file(s) — escalating.',
        );
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: auto-merge errored ($e) — escalating.',
        );
      }
    }

    // CONFLICT PATH: a real conflict needs an agent (the Coordinator) to resolve
    // it or send the task back for rework. If there's no Coordinator persona,
    // don't stall forever — return the task to the board so the worker redoes it
    // against the now-updated target branch.
    final persona = await _findPersonaForRole(AgentRole.coordinator);
    if (persona == null) {
      await _db.reopenTask(task.task_pk);
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: merge conflict, no Coordinator persona; sent back to the board for rework.',
      );
      return;
    }
    final resolved = await _resolveBackend(persona);
    if (resolved == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no inference server for coordinator ${persona.name}.',
      );
      return;
    }
    // Put the worktree on the target so the Coordinator resolves into it.
    await _checkout(handles.git, targetBranch, task.task_pk);

    final prompts = await _loadPrompts();
    final vars = _varsFor(task, branch, targetBranch: targetBranch);

    // Reuse the Coordinator's single per-agent session (see worker stage).
    final sessionPk = await _db.getOrCreateAgentChatSession(
      projectId,
      persona.agent_pk,
      persona.name,
    );

    final session = ProjectCoordinatorSession(
      client: resolved.client,
      projectId: projectId,
      projectName: persona.name,
      db: _db,
      model: resolved.model,
      chatSessionPk: sessionPk,
      permissions: AgentToolPermissions.fromConfigJson(persona.configJson),
      confirmAsk: (_, _) async => true,
      agentName: persona.name,
      workspace: handles.ws,
      git: handles.git,
      buildService: handles.build,
      // Autonomous coders need file/git/build tools directly — no progressive
      // disclosure (that's for the interactive PM chat).
      leanTools: false,
      systemPromptOverride:
          '${defaultSystemPrompt(AgentRole.coordinator)}\n${prompts.render(OrchestratorPromptField.mergeFraming, vars)}',
      enableThinking: resolveEnableThinking(
        agent: personaThinkingMode(
          persona.configJson,
          personaName: persona.name,
        ),
        task: ThinkingMode.fromString(task.thinkingMode),
      ),
    );

    var kickoff = prompts.render(OrchestratorPromptField.mergeKickoff, vars);
    for (var turn = 0; turn < _maxTurnsPerStage && !_disposed; turn++) {
      if (!await _stillRunning()) return;
      try {
        await for (final _ in session.runTurn(kickoff)) {}
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: merge turn $turn failed: $e',
        );
        return;
      }
      final fresh = await _db.getTaskById(task.task_pk);
      if (fresh == null) return;
      if (fresh.executionStatus == TaskExecStatus.done ||
          fresh.status == TaskStatus.todo) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: merge stage resolved (${fresh.executionStatus}).',
        );
        return;
      }
      kickoff = prompts.render(OrchestratorPromptField.mergeContinue, vars);
    }
    debugPrint(
      '[Orchestrator p$projectId] task ${task.task_pk}: merge hit turn cap without resolution.',
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────

  /// First persona for the client whose stored title maps to [role], or null.
  Future<AgentPersona?> _findPersonaForRole(AgentRole role) async {
    final project = await _db.getProjectById(projectId);
    if (project == null) return null;
    final personas = await _db.getAgentPersonasForClient(project.client_fk);
    for (final p in personas) {
      if (agentRoleFromKey(p.title) == role) return p;
    }
    return null;
  }

  /// Resolve the workspace, git engine, and build service for this project.
  /// Any of them may be null if the workspace is unavailable.
  Future<({Workspace? ws, NxtprjGitEngine? git, BuildService? build})>
  _resolveWorkspaceHandles() async {
    Workspace? ws;
    NxtprjGitEngine? git;
    BuildService? build;
    try {
      ws = await ref.read(workspaceFsProvider(projectId).future);
      git = await ref.read(gitEngineProvider(projectId).future);
      build = ref.read(buildServiceProvider);
    } catch (e) {
      debugPrint('[Orchestrator p$projectId] workspace unavailable: $e');
    }
    return (ws: ws, git: git, build: build);
  }

  /// Isolated handles for a CONCURRENT task stage: the task's own working tree,
  /// the shared git engine (objects/refs), and the per-project lane that
  /// serializes shared-DB writes. Null if the workspace can't be opened.
  Future<
    ({
      Workspace tree,
      NxtprjGitEngine git,
      AsyncLock lane,
      BuildService? build,
    })?
  >
  _resolveTaskHandles(int taskPk) async {
    try {
      final tree = await ref.read(
        taskWorkspaceProvider((projectId: projectId, taskPk: taskPk)).future,
      );
      final git = await ref.read(gitEngineProvider(projectId).future);
      final lane = ref.read(gitLaneProvider(projectId));
      final build = ref.read(buildServiceProvider);
      return (tree: tree, git: git, lane: lane, build: build);
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] task $taskPk: task workspace unavailable: $e',
      );
      return null;
    }
  }

  /// Dispose + delete a finished task's isolated working tree. The committed
  /// work lives on the task branch in the shared object DB, so the scratch tree
  /// is disposable.
  Future<void> _releaseTaskTree(int taskPk) async {
    ref.invalidate(
      taskWorkspaceProvider((projectId: projectId, taskPk: taskPk)),
    );
    await deleteTaskDisk(projectId, taskPk);
  }

  /// How many agents may run at once: the routed (subscription) server's
  /// `maxConcurrency` (synced from the account), clamped to a safe range. Falls
  /// back to 1 when no server is configured.
  Future<int> _concurrencyCap(Project project) async {
    try {
      final servers = await _db.getInferenceServersForClient(project.client_fk);
      if (servers.isEmpty) return 1;
      final routed = servers.where((s) => isRoutedProviderType(s.providerType));
      final n =
          (routed.isNotEmpty ? routed.first : servers.first).maxConcurrency;
      return n.clamp(1, 12);
    } catch (_) {
      return 1;
    }
  }

  /// Put the worktree on [branch], creating it if needed. When the branch must
  /// be created and [base] is given (and exists), the worktree is first switched
  /// to [base] so the new branch diverges from it — this is how a subtask branch
  /// is rooted on its parent's branch. No-op when git is null.
  Future<void> _checkout(
    NxtprjGitEngine? git,
    String branch,
    int taskPk, {
    String? base,
  }) async {
    if (git == null) return;
    try {
      final existing = await git.branches();
      if (existing.contains(branch)) {
        await git.checkoutBranch(branch);
        return;
      }
      // New branch: root it on [base] (parent branch / main) when available.
      if (base != null && base != branch && existing.contains(base)) {
        await git.checkoutBranch(base);
      }
      await git.createBranch(branch, checkout: true);
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] task $taskPk: checkout "$branch" failed: $e',
      );
    }
  }

  /// True while the project is still in the running state — used to bail out of
  /// a multi-turn agent stage promptly when the human pauses/stops.
  Future<bool> _stillRunning() async {
    final project = await _db.getProjectById(projectId);
    return project != null && project.orchestrationState == 'running';
  }

  /// Resolve the inference backend + chat model for [persona] from its connected
  /// server (or the client's first server). Returns null when none exist.
  Future<({InferenceBackend client, String? model})?> _resolveBackend(
    AgentPersona persona,
  ) async {
    final project = await _db.getProjectById(projectId);
    if (project == null) return null;
    final servers = await _db.getInferenceServersForClient(project.client_fk);
    if (servers.isEmpty) return null;

    // Default to the Nexus Router (subscription) server when present (signed in),
    // else the first configured server. An explicit agent provider_fk wins.
    var chosen = servers.firstWhere(
      (s) => isRoutedProviderType(s.providerType),
      orElse: () => servers.first,
    );
    if (persona.provider_fk != null) {
      for (final s in servers) {
        if (s.server_pk == persona.provider_fk) {
          chosen = s;
          break;
        }
      }
    }

    final models = (jsonDecode(chosen.availableModelsJson) as List)
        .cast<String>();

    final personaModel = persona.llmModel?.trim();
    final model = (personaModel != null && personaModel.isNotEmpty)
        ? personaModel
        : ((chosen.selectedModel != null &&
                  chosen.selectedModel!.trim().isNotEmpty)
              ? chosen.selectedModel!.trim()
              : (models.isNotEmpty ? models.first : null));

    final uiServer = ui_server.InferenceServer(
      id: chosen.server_pk.toString(),
      name: chosen.name,
      baseUrl: chosen.baseUrl,
      apiKey: chosen.apiKey,
      providerType: chosen.providerType,
      selectedModel: chosen.selectedModel,
      availableModels: models,
    );
    // Per-agent session id → the Router gives each agent its own warm backend and
    // spreads different agents across the fleet (agent 1..N → server 1..N), instead
    // of every agent piling onto one box.
    return (
      client: backendForServer(
        uiServer,
        agentName: persona.name,
        sessionId: 'agent-${persona.agent_pk}',
      ),
      model: model,
    );
  }
}

/// The pipeline stage a task is ready for, in execution order.
enum _Stage { implement, verify, build, merge }

/// One [ProjectOrchestrator] per project. Kept alive while anything (e.g. the
/// project workspace view) watches it; it self-starts on creation.
final projectOrchestratorProvider = Provider.family<ProjectOrchestrator, int>((
  ref,
  projectId,
) {
  final orchestrator = ProjectOrchestrator(ref, projectId)..start();
  ref.onDispose(orchestrator.dispose);
  return orchestrator;
});
