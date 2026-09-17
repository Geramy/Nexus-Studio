// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/core/providers/worker_capture_provider.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart';
import 'package:nexus_projects_client/infrastructure/build/web_preview.dart'
    show captureProjectWebScreenshot;
import 'package:nexus_projects_client/infrastructure/inference/inference_backend.dart'
    show ChatContentDelta, ChatStreamEvent;
import 'package:nexus_projects_client/infrastructure/inference/inference_backend_factory.dart'
    show backendForServer, resetInferenceConnections;
import 'package:nexus_projects_client/infrastructure/inference/routed_server.dart'
    show isRoutedProviderType;
import 'package:nexus_projects_client/infrastructure/inference/inference_client.dart'
    show InferenceBackend;
import 'package:nexus_projects_client/infrastructure/models/ui/inference_server.dart'
    as ui_server;
import 'package:nexus_projects_client/infrastructure/lemonade/api/types/model_info.dart'
    show ApiModelInfo;
import 'package:nexus_projects_client/infrastructure/lemonade/services/persona_model_resolver.dart'
    show resolveAgentChatModel, defaultOmniCollectionForTitle;
import 'package:nexus_projects_client/infrastructure/lemonade/api/exceptions.dart'
    show LemonadeApiException;
import 'package:nexus_projects_client/features/ai_providers/providers/ai_servers_cache_provider.dart'
    show aiServersCacheProvider;
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
import 'package:nexus_projects_client/features/projects/orchestration/milestone_planner.dart';
import 'package:nexus_projects_client/features/projects/orchestration/finalize_progress.dart';
import 'package:nexus_projects_client/features/projects/project_baseline.dart'
    show buildProjectBaseline;
import 'package:nexus_projects_client/features/projects/project_working_hours.dart';
import 'package:nexus_projects_client/features/projects/task_workflow.dart';

/// Deterministic review guard for edits that erase an existing implementation.
/// A task may simplify code, but replacing a real source file with nothing or a
/// tiny shell is almost always a failed worker response and must not be merged.
@visibleForTesting
String? taskReviewStructuralProblem({
  required String path,
  required String? baseContent,
  required String taskContent,
}) {
  final after = taskContent.trim();
  if (after.isEmpty) return '$path: file was emptied';

  final before = baseContent?.trim() ?? '';
  if (before.length >= 240 &&
      after.length < 160 &&
      after.length * 100 < before.length * 45) {
    return '$path: implementation collapsed from ${before.length} to '
        '${after.length} non-whitespace characters';
  }
  return null;
}

/// Dependency rank used by the deterministic Flutter Templater. Foundations
/// and independent leaf features intentionally share a rank so worker slots can
/// run them concurrently; the persisted milestone indices compress unused ranks.
@visibleForTesting
int flutterTaskDependencyRankForTitle(String title) {
  final text = title.toLowerCase();
  bool has(List<String> terms) => terms.any(text.contains);
  if (has([
    'physics',
    'input',
    'foundation',
    'contract',
    'schema',
    'setup',
    'pipe',
    'generation',
    'engine',
    'service',
    'repository',
  ])) {
    return 0;
  }
  if (has(['core', 'game loop', 'runtime'])) return 1;
  if (has([
    'select',
    'navigation',
    'settings',
    'screen',
    'level',
    'difficulty',
    'tier',
    'progression',
  ])) {
    return 0;
  }
  if (has(['ui', 'view', 'page'])) {
    return 2;
  }
  if (has(['menu', 'flow'])) return 3;
  return 1;
}

/// A settled task releases its milestone barrier. Blocked remains an unresolved
/// final result, but it must not prevent unrelated later tasks from running.
@visibleForTesting
bool taskStatusSettlesMilestone(String status) =>
    status == TaskStatus.done || status == TaskStatus.blocked;

/// A saved task commit may bypass the worker only when it belongs to an
/// interrupted FIRST implementation that has never failed a review/build gate.
/// Once feedback exists, the old commit is the thing that failed and must be
/// repaired even if a timeout temporarily returned the task to `queued`.
@visibleForTesting
bool taskCanRecoverCommittedSubmission({
  required String executionStatus,
  required String? description,
  required bool branchAheadOfBase,
}) {
  if (executionStatus != TaskExecStatus.queued || !branchAheadOfBase) {
    return false;
  }
  final detail = description ?? '';
  return !detail.contains('[Verification FAILED') &&
      !detail.contains(NexusDatabase.buildFailureMarker);
}

/// Live driver for a project's autonomous task pipeline.
///
/// It watches the project's `orchestrationState` (Start/Pause/Stop) and the
/// working-hours window. While the project is `running` and inside its hours,
/// it advances tasks through the full pipeline, one unit of work per loop:
///   1. **Implement** — an assigned worker task on the board gets an ephemeral
///      worker session on branch `task/<id>`, driven to `submit_for_completion`.
///   2. **Verify (lightweight review)** — per-task review runs NO build. A task
///      with a functional `verification` gets a short Verification Agent that
///      reads the changed code to confirm the behavior; everything else passes
///      immediately. The project's CI/test runs ONCE at the end (see
///      [_maybeFinalizeProject]) rather than per task.
///   3. **Build** — legacy/explicit per-task build gate for a verified task that
///      still carries `requiresBuild`; stage 2 advances such tasks straight to
///      `built`, so this effectively never runs in the default pipeline.
///   4. **Merge** — a merge-ready task (built, or verified without a build gate)
///      gets an ephemeral Coordinator that merges the task's work branch into
///      its integration target (the parent task's branch for a subtask,
///      otherwise main) and approves the task to Done.
///
/// Stages that need an agent degrade gracefully: if no Verification Agent or
/// Coordinator persona exists for the client, the task is left in place.
///
/// One orchestrator exists per project (via [projectOrchestratorProvider]); it
/// runs independent tasks concurrently in isolated worktrees and serializes the
/// shared git operations that join their results.
class ProjectOrchestrator {
  final Ref ref;
  final int projectId;

  StreamSubscription<Project?>? _projectSub;
  Timer? _ticker;

  /// True while [_pump] is actively walking the task queue, so overlapping
  /// triggers (state change + ticker) don't spawn concurrent workers.
  bool _pumping = false;
  bool _disposed = false;

  /// True while the one-shot Templater (base-project scaffold) is running this
  /// session, so repeated pumps don't launch a second scaffolder concurrently.
  bool _templating = false;

  /// Tasks currently being executed in this process, so a re-pump doesn't pick
  /// up a task that's mid-run (its executionStatus is `running`).
  final Set<int> _active = {};

  /// Per-task worker attempt counts, to cap retries on a task that keeps
  /// failing to submit rather than spinning forever.
  final Map<int, int> _attempts = {};

  /// Review retries are counted separately from implementation attempts. A
  /// normal implement -> verify -> merge path must consume one implementation
  /// attempt, while a verifier that never returns a verdict remains bounded.
  final Map<int, int> _reviewFailures = {};

  /// Before final project testing, tasks that exhausted their first worker
  /// budget get one automatic fresh retry sweep. A second Blocked result remains
  /// visible for manual review, preventing an infinite retry loop.
  bool _blockedRecoverySweepDone = false;

  /// Fresh Router namespace for this orchestrator process. A task id is stable
  /// forever, so it cannot also identify a new inference dispatch safely.
  final String _routingRunId = DateTime.now().microsecondsSinceEpoch
      .toRadixString(36);
  int _routingDispatch = 0;

  /// Cooldown after a task PARKS (it wanted a file another task holds). A park
  /// deliberately does NOT count as an attempt (it's waiting, not failing), so
  /// without this the task re-dispatches instantly — and when several tasks
  /// contend for the same files they thrash in a tight busy-loop (grab → the
  /// others park → yield → re-grab …), churning thousands of no-op dispatches and
  /// flickering the board. A short cooldown turns that busy-loop into a calm
  /// retry, giving the file's owner time to make progress / merge first.
  final Map<int, DateTime> _parkedUntil = {};
  static const Duration _parkCooldown = Duration(seconds: 12);

  /// Tasks being REDONE after a merge conflict → a short hint (their prior
  /// submission summary). Presence means "re-apply, don't rediscover": the redo
  /// worker gets its previous plan plus a smaller turn budget ([_maxRedoTurns]),
  /// because main already contains the sibling work it collided with, so it
  /// should converge quickly rather than pay a full from-scratch implementation
  /// again. Cleared once the redo submits.
  final Map<int, String> _redoHint = {};
  static const int _maxRedoTurns = 6;

  /// File-claim table for the same-file queue: normalized workspace path → the
  /// task_pk that currently OWNS it. A worker claims a file the first time it
  /// edits it and holds it until the task merges, so two tasks never submit
  /// conflicting changes to the same file in parallel; a second task that needs
  /// the file is parked and retried. Reset whenever the orchestrator is disposed
  /// (project swap / app close), and swept every pump so a lock is never held by
  /// a task that isn't actively running or awaiting integration (no indefinite
  /// hogging — the exact failure mode we hit with agent slots).
  final Map<String, int> _fileOwners = {};

  /// Release every file lock held by [taskPk].
  void _releaseLocks(int taskPk) =>
      _fileOwners.removeWhere((_, owner) => owner == taskPk);

  /// LEARNED file footprint per task: every workspace path a task has touched —
  /// claimed OR been denied — accumulated across ALL its attempts (unlike
  /// [_fileOwners], which is dropped the moment a non-submitting run releases).
  /// This is what makes scheduling PREDICTIVE instead of reactive: once we know
  /// two tasks edit overlapping files, the dispatcher refuses to run them at the
  /// same time (see [_scopeConflict]) so the second waits cleanly on the board
  /// instead of starting, colliding mid-edit, and throwing away its exploration.
  /// Reset on dispose; an entry is dropped once its task reaches Done/Blocked.
  final Map<int, Set<String>> _taskFootprint = {};

  /// True if dispatching [taskPk] now would collide with work already in flight,
  /// based on its LEARNED footprint: a file it is known to touch is currently
  /// locked by another task (active or awaiting merge), OR its footprint overlaps
  /// the footprint of a currently-active task. A task whose footprint is still
  /// unknown (never run) returns false — first run is unconstrained, and the
  /// collision it may hit teaches us the overlap for next time.
  bool _scopeConflict(int taskPk) {
    final mine = _taskFootprint[taskPk];
    if (mine == null || mine.isEmpty) return false;
    for (final f in mine) {
      final owner = _fileOwners[f];
      if (owner != null && owner != taskPk) return true; // file held by another
    }
    for (final other in _active) {
      if (other == taskPk) continue;
      final theirs = _taskFootprint[other];
      if (theirs != null && mine.any(theirs.contains)) return true; // overlap
    }
    return false;
  }

  /// Normalize a workspace path for lock identity (case-insensitive FS, ignore a
  /// leading slash) so "/Assets/X.cs" and "assets/x.cs" are the same lock.
  static String _normFile(String path) {
    var p = path.trim().replaceAll('\\', '/').toLowerCase();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  /// File paths a task DECLARES it will touch, mined from its title/description
  /// (which the templater writes to name the file/area). A relative path with a
  /// slash + extension (`prisma/schema.prisma`, `src/pages/api/x.ts`) or a
  /// well-known root config file. Used to SEED [_taskFootprint] so the scope gate
  /// serialises tasks that edit the same hot file (e.g. everyone adding models to
  /// prisma/schema.prisma) from the very first pump — before any of them run and
  /// collide — instead of only after they've each conflicted once. Prevents the
  /// merge conflicts that drive the expensive resolve/redo cycle.
  static final RegExp _declaredPathRe = RegExp(
    r'\b([A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+\.[A-Za-z]{1,6}'
    r'|package\.json|tsconfig\.json|schema\.prisma|Dockerfile|pubspec\.yaml'
    r'|next\.config\.[jt]s|tailwind\.config\.[jt]s)\b',
  );

  /// Seed [taskPk]'s footprint with the files its text declares (idempotent —
  /// unions into any already-learned set). No-op if nothing parses.
  void _seedDeclaredFootprint(Task t) {
    // Failure notes name files the task only READS, especially shared contracts.
    // Treating those paths as declared writes serializes unrelated retry work.
    var description = t.description ?? '';
    for (final marker in const [
      '[Verification FAILED',
      NexusDatabase.buildFailureMarker,
    ]) {
      final at = description.indexOf(marker);
      if (at >= 0) description = description.substring(0, at);
    }
    final text = '${t.title}\n$description';
    Set<String>? fp;
    for (final m in _declaredPathRe.allMatches(text)) {
      (fp ??= (_taskFootprint[t.task_pk] ??= <String>{})).add(
        _normFile(m.group(1)!),
      );
    }
  }

  /// Record that [t] is being REDONE after a merge conflict, stashing its prior
  /// submission summary as a re-apply hint for the redo worker (see [_redoHint]).
  /// Call BEFORE reopenTask, which clears the submission.
  void _markRedo(Task t) {
    var hint =
        'This task is being REDONE because your previous attempt merge-conflicted '
        'with a sibling task. main NOW INCLUDES that sibling work. Re-apply the '
        'SAME change against the CURRENT code — build on what is already there, do '
        'not assume a blank slate — and keep it tight.';
    final s = t.submissionJson;
    if (s != null && s.trim().isNotEmpty) {
      try {
        final summary =
            (jsonDecode(s) as Map)['summary']?.toString().trim() ?? '';
        if (summary.isNotEmpty) {
          hint = '$hint\n\nWhat you built last time: $summary';
        }
      } catch (_) {}
    }
    _redoHint[t.task_pk] = hint;
  }

  /// After hitting the plan's concurrent-connection cap (HTTP 429), pause NEW
  /// agent dispatch until this time so we stop piling past the cap — in-flight
  /// stages keep running, and the task that 429'd goes back to the board (it is
  /// NOT counted as a failure or Blocked; it's pure backpressure).
  DateTime? _connBackoffUntil;
  DateTime? _lastConnCapAt;
  int _consecutiveConnCaps = 0;
  DateTime? _lastHungCancelAt;
  int _consecutiveHungCancels = 0;

  /// Signature of the completed-task set the last GREEN end-of-project scan ran
  /// against, so a passed project isn't re-scanned every tick — only when the
  /// done set actually changes (a task reopened+refixed, or new work completed).
  String? _finalScanPassedSig;

  // ── End-of-project TESTING phase ────────────────────────────────────────
  // Once every task is done, the project enters a dedicated TESTING phase (like
  // the yellow Templating stage — NOT a task): it repeatedly runs CI on main and,
  // on RED, drives ONE focused fix agent (the strongest model, given ALL the
  // failpoints at once) to fix the WHOLE project before the next CI run, then
  // re-scans — looping until green. This replaces the old "reopen one task
  // forever" thrash, which only used a single connection (one task = one conn).
  //
  // It keeps going as long as it's making PROGRESS (fewer failpoints each CI
  // run); it only gives up after the failure count fails to drop for
  // [_maxStagnantRounds] consecutive rounds — so the user doesn't have to step in
  // while it's still improving. [_absoluteMaxTestingRounds] is a hard backstop
  // against a pathological infinite loop.
  static const int _maxStagnantRounds = 6;
  static const int _absoluteMaxTestingRounds = 40;

  /// After CI goes green, the FINAL PASS verifies every requested feature is
  /// actually implemented + hooked up. It keeps fixing+re-verifying as long as
  /// it's making PROGRESS (fewer unwired features each pass); it only gives up
  /// after the count fails to drop for [_maxFinalPassStagnant] consecutive
  /// passes (same philosophy as the CI loop — not a hard cap). The outer
  /// [_absoluteMaxTestingRounds] is the ultimate backstop.
  static const int _maxFinalPassStagnant = 5;

  /// Turn budget for the read-only Final Pass reviewer that traces each feature's
  /// wiring in the code before giving its verdict.
  static const int _maxFinalPassTurns = 14;

  /// Per-CI-run failpoint payload cap handed to the fixer — generous so e.g. 100
  /// failures all go in ONE pass (fix them all, THEN re-run CI; don't test after
  /// every point).
  static const int _maxFixErrorChars = 24000;

  /// The fix agent's per-invocation turn budget — high enough to work across many
  /// files in a single pass before the next CI run.
  static const int _maxFixAgentTurns = 24;

  /// Running guard so only one TESTING phase runs at a time (mirrors _templating).
  bool _testing = false;

  /// Live phase flag + detail mirrored into [orchestratorStatusProvider] so the
  /// top-bar shows a yellow "Testing" stage while it runs.
  bool _testingActive = false;
  String? _testingDetail;

  /// Done-set signature the testing loop exhausted its rounds on, so we don't
  /// immediately re-enter the (slow) loop for the same unchanged red state.
  String? _testingExhaustedSig;

  /// FINAL PASS progress tracking (persists across testing re-entries): the
  /// unwired-feature count from the previous pass, and how many consecutive
  /// passes have FAILED to reduce it. Keep going while the count drops; give up
  /// after [_maxFinalPassStagnant] non-improving passes. Reset on a clean pass /
  /// new run.
  int? _finalPassPrevCount;
  int _finalPassStagnant = 0;

  // Per-task retry budget within ONE run before a task is surfaced as Blocked.
  // Kept generous so a couple of transient hiccups (a flaky worker turn, a
  // momentary backend blip) don't strand otherwise-workable tasks — blocking is
  // a "needs a human look" signal, not a hair-trigger. Restarting clears the
  // in-memory budget; a persisted Blocked task still requires an explicit retry.
  static const int _maxAttemptsPerTask = 5;

  /// Connections kept free for the interactive Coordinator (the story-maker you
  /// talk to during/after setup to add & adjust user stories). Without this, a
  /// burst of worker agents (e.g. the generalist) can claim every connection the
  /// plan allows, starving the Coordinator so you can't edit stories while work
  /// is running. We hold this many slots back from the worker pool — but never so
  /// many that no worker can run (a 1-connection plan still does work, just
  /// shared with the Coordinator).
  static const int _reservedCoordinatorSlots = 1;

  static const int _maxTurnsPerTask = 12;
  static const int _maxTurnsPerStage = 8;

  /// Functional review is a quick spot-check (the build gate already proved it
  /// compiles), so the Verification Agent gets only a few turns — not the full
  /// stage budget — keeping review the fastest step.
  static const int _maxFunctionalVerifyTurns = 3;

  /// The project's default deterministic CI gate, scaffolded once by the Templater
  /// (see [_ensureDefaultCiWorkflow]) and run with NO LLM by both per-task review
  /// and the end-of-project scan.
  static const String _defaultCiPath = '/.github/workflows/ci.yml';
  static const Duration _connBackoff = Duration(seconds: 20);
  static const Duration _connCapRecoveryWindow = Duration(minutes: 2);

  /// Idle-timeout watchdog for a single agent turn: if the model/stream produces
  /// NO event for this long, the turn is considered stalled (a backend that
  /// accepted the connection but never streams — the "hung worker that never
  /// frees its slot, so the loop stops" failure) and is aborted. The task yields
  /// back (NOT penalized — a stall isn't its fault), the slot frees, and the pump
  /// moves on. Generous so a slow-but-working turn under load is never killed.
  static const Duration _turnIdleTimeout = Duration(minutes: 4);

  /// HARD wall-clock cap on a single agent turn, regardless of stream activity.
  /// The idle timeout resets on every SSE event, so a backend that dribbles
  /// keep-alives (or streams token-by-token forever on a bloated context) can
  /// hang a turn indefinitely without ever tripping the idle guard — observed as
  /// the Final Pass fixer freezing for 18min. This cap fires no matter what, so a
  /// stuck turn is aborted (and retried) instead of wedging the phase.
  static const Duration _turnWallClock = Duration(minutes: 5);

  /// Code-writing turns emit complete source files inside tool arguments, and a
  /// routed round can legitimately take 3-5min of pure generation (observed on
  /// the NXS-PJX-Chat pool). A read → edit → (re-edit) → commit → submit worker
  /// needs FOUR such rounds per dispatch, so 10m was cutting every turn off
  /// right before submission — the task then re-dispatched, re-read, and lost
  /// the cycle (task 776 spun on this for two days). 20m fits a full slow cycle
  /// while the 4-min idle guard still catches dead streams early.
  static const Duration _workerTurnWallClock = Duration(minutes: 20);

  /// Safety valve for the shared git lane: a single materialize/commit/merge
  /// that hangs would wedge the lane (and so freeze EVERY task's git step) until
  /// the app restarts. Cap how long any one lane op may hold the mutex so the
  /// lane self-heals. Generous — a real merge under load finishes in seconds.
  static const Duration _laneOpTimeout = Duration(minutes: 4);
  static const Duration _tickInterval = Duration(seconds: 30);
  static const Duration _buildPollInterval = Duration(seconds: 3);
  static const Duration _buildTimeout = Duration(minutes: 30);

  /// Lines from a CI log worth handing the worker on a red gate: analyzer/
  /// compiler diagnostics (`error -`, `warning -`, `info -`), `file.dart:line`
  /// references, the analyze summary, and test/exception failures.
  static final RegExp _diagLineRe = RegExp(
    r'(\b(error|warning|info)\b\s*[-:]|\.dart:\d+|\bissues? found\b|\bError:|\bFAILED\b|\bException\b)',
    caseSensitive: false,
  );

  /// A STACK-TRACE frame — NOT a distinct failure. A single failing test can dump
  /// thousands of these (`#2674  Foo.bar (package:…/x.dart:442:11)`, `(elided 212
  /// frames …)`), and each contains a `.dart:line` so [_diagLineRe] would count it
  /// as its own failpoint — inflating one test failure into "100 → 363 failpoints"
  /// (which fooled the progress gate and flooded the fix agent). Excluded from the
  /// failpoint set so the count reflects REAL failures.
  static final RegExp _stackFrameRe = RegExp(
    r'^\s*#\d+\s|\belided\s+\d+\s+frame|^\s*(package:|dart:)\S+\.dart:\d+',
    caseSensitive: false,
  );

  /// A REAL blocker line — an `error`/`warning` analyzer diagnostic (severity is
  /// the FIRST token, so we anchor to line start to avoid matching the word
  /// mid-message) or a test/runtime failure. CI runs `flutter analyze
  /// --no-fatal-infos`, so `info -` lints (e.g. `withOpacity` deprecations) do
  /// NOT fail the build. Counting them as failpoints inflates the number (2 real
  /// errors + 21 deprecation infos → "23 failpoints"), floods the fix agent with
  /// cosmetic noise instead of the errors that actually break CI, and flatlines
  /// the progress gate (fixing a real error only nudges 23→21). Info lines are
  /// dropped from the failpoint set whenever ANY genuine blocker is present.
  static final RegExp _blockerLineRe = RegExp(
    r'^\s*(error|warning)\b\s*[-:•]|\bError:|\bFAILED\b|\bException\b',
    caseSensitive: false,
  );

  /// Keep only genuine blockers (errors/warnings/test failures) from matched
  /// diagnostic [hits] when any exist; fall back to all hits for an info-only red
  /// (the info-only finalize gate treats that as green anyway) so the fixer still
  /// sees context rather than an empty list.
  static List<String> _preferBlockers(List<String> hits) {
    final blockers = hits.where(_blockerLineRe.hasMatch).toList();
    return blockers.isNotEmpty ? blockers : hits;
  }

  ProjectOrchestrator(this.ref, this.projectId);

  NexusDatabase get _db => ref.read(nexusDatabaseProvider);

  void start() {
    // Clear any leftover per-task working-tree disks from a previous crash.
    unawaited(pruneTaskDisks(projectId));
    // Retry budgets belong to this process run. Blocked tasks stay visible until
    // the final pre-test recovery sweep (or an explicit retry) gives them one
    // fresh budget; they are never silently retried on an ordinary project load.
    _attempts.clear();
    _reviewFailures.clear();
    _parkedUntil.clear();
    _redoHint.clear();
    _finalPassPrevCount = null;
    _finalPassStagnant = 0;
    // Reconcile tasks orphaned mid-run by a crash/quit: our in-memory _active
    // set is empty on a fresh start, so any task still marked `running` in the
    // DB would never be re-picked. Return them to the board.
    unawaited(_reconcileOrphans());
    _projectSub = _db.watchProject(projectId).listen((project) {
      if (_isActiveState(project?.orchestrationState)) {
        unawaited(_pump());
      }
    });
    _ticker = Timer.periodic(_tickInterval, (_) => unawaited(_pump()));
    // AUTO-START TESTING: if a project is loaded with every task already done but
    // not yet CI-validated, the only work left is the end-of-project Testing gate
    // — begin it automatically on load instead of making the user press Start.
    unawaited(_maybeAutoStartTesting());
  }

  /// Auto-resume a loaded project straight into the TESTING phase when all its
  /// tasks are done but CI hasn't passed (it isn't `completed`). The sole
  /// remaining work is the CI/fix gate, so there's nothing for the user to
  /// "Start" — flip it to `running` and let the normal pump drive testing.
  Future<void> _maybeAutoStartTesting() async {
    try {
      if (_disposed) return;
      final project = await _db.getProjectById(projectId);
      if (project == null) return;
      // Already finished, or already active (the pump handles running/editing) —
      // nothing to auto-start. (Editing is the Editor's fast lane; it drives its
      // own light finalize, never the heavy Testing phase.)
      final state = project.orchestrationState;
      if (state == 'completed' || _isActiveState(state)) return;
      // Only when the backlog is fully done AND we're on the last milestone — i.e.
      // the project is genuinely at the end-of-project gate, not mid-build (we
      // must NOT auto-resume an in-progress build the user deliberately paused).
      if (project.currentMilestone < project.milestoneCount - 1) return;
      final tasks = await _db.getTasksForProject(projectId);
      if (tasks.isEmpty) return;
      final allDone = tasks.every((t) => t.status == TaskStatus.done);
      if (!allDone) return;
      debugPrint(
        '[Orchestrator p$projectId] all tasks done but CI not validated → '
        'auto-starting the Testing phase on load.',
      );
      await _db.setProjectOrchestrationState(projectId, 'running');
      if (!_disposed) unawaited(_pump());
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] auto-start testing check failed: $e',
      );
    }
  }

  void dispose() {
    _disposed = true;
    _projectSub?.cancel();
    _ticker?.cancel();
    // Drop all file claims so a fresh orchestrator (e.g. after a project swap)
    // never inherits a stale lock — the anti-hog reset.
    _fileOwners.clear();
    _taskFootprint.clear();
  }

  /// Fill up to N agent slots (N = the account's max concurrency) with the next
  /// fair, backlog-weighted pieces of work, launching each on its own isolated
  /// working tree. Returns immediately after dispatching; each stage frees its
  /// slot and re-pumps on completion. [_pumping] guards only the dispatch loop,
  /// not the work, so it never serializes the agents.
  Future<void> _pump() async {
    if (_pumping || _disposed) return;
    _pumping = true;
    var advancedMilestone = false;
    var spawnedFixWork = false;
    try {
      final project = await _db.getProjectById(projectId);
      if (project == null || !_isActiveState(project.orchestrationState))
        return;
      if (!isWithinWorkingHours(project)) return;

      // Honour the connection-cap backoff: a recent 429 means every slot the plan
      // allows is in use (often by the interactive Coordinator chat too), so don't
      // launch MORE agents — let in-flight work finish and free a connection.
      if (_connBackoffUntil != null &&
          DateTime.now().isBefore(_connBackoffUntil!)) {
        return;
      }

      // Templater gate: before any worker runs, the base project must be
      // scaffolded ONCE (committed to main). Until then no task work dispatches,
      // so the agents don't all race to create the project from an empty main.
      if (!await _ensureTemplated(project)) return;

      final cap = await _concurrencyCap(project);
      // Hold a connection back for the interactive Coordinator so worker agents
      // can't claim every slot and starve story editing. Never drop below 1, so
      // a single-connection plan still makes progress.
      final workerCap = (cap - _reservedCoordinatorSlots).clamp(1, cap);
      while (!_disposed && _active.length < workerCap) {
        final (task, stage) = await _nextPipelineWork();
        if (task == null || stage == null) break;
        _active.add(task.task_pk);
        unawaited(_runStage(task, stage));
      }
      await _surfaceStalledTasks();
      advancedMilestone = await _maybeAdvanceMilestone(project);
      spawnedFixWork = await _maybeFinalizeProject(project);
      await _publishSlotStatus(workerCap);
    } finally {
      _pumping = false;
    }
    // A just-opened milestone OR a freshly-spawned fix batch has new assignable
    // work — re-pump now to fill the idle slots immediately instead of waiting
    // for the next 30s tick.
    if ((advancedMilestone || spawnedFixWork) && !_disposed) {
      unawaited(_pump());
    }
  }

  /// Publish a live snapshot of worker-slot usage so the UI can show WHY a slot is
  /// idle — most often a startable task HELD BACK because its files overlap work
  /// in flight (the predictive scope gate) — instead of silently showing fewer
  /// agents than the plan allows. [workerSlots] is the worker pool (cap minus the
  /// reserved Coordinator slot).
  Future<void> _publishSlotStatus(int workerSlots) async {
    if (_disposed) return;
    try {
      final tasks = await _db.getTasksForProject(projectId);
      final currentMilestone =
          (await _db.getProjectById(projectId))?.currentMilestone ?? 0;
      final waiting = <OrchestratorWait>[];
      for (final t in tasks) {
        if (t.task_agent_fk == null) continue;
        if (_active.contains(t.task_pk)) continue;
        if ((t.milestoneOrder ?? 0) > currentMilestone) continue;
        if ((_attempts[t.task_pk] ?? 0) >= _maxAttemptsPerTask) continue;
        final startable =
            t.status == TaskStatus.todo &&
            (t.executionStatus == TaskExecStatus.idle ||
                t.executionStatus == TaskExecStatus.queued ||
                t.executionStatus == TaskExecStatus.failed);
        if (!startable) continue;
        // Only report tasks that are ready but BLOCKED by file-scope overlap — a
        // plain queued task that simply hasn't been reached yet isn't "held".
        if (!_scopeConflict(t.task_pk)) continue;
        final mine = _taskFootprint[t.task_pk] ?? const <String>{};
        String? heldFile;
        int? owner;
        for (final f in mine) {
          final o = _fileOwners[f];
          if (o != null && o != t.task_pk) {
            heldFile = f;
            owner = o;
            break;
          }
        }
        waiting.add(
          OrchestratorWait(
            taskPk: t.task_pk,
            agentFk: t.task_agent_fk,
            reason: heldFile != null
                ? 'needs "${heldFile.split('/').last}" held by task #$owner'
                : 'its files overlap a task in flight',
          ),
        );
      }
      ref
          .read(orchestratorStatusProvider(projectId).notifier)
          .state = OrchestratorStatus(
        workerSlots: workerSlots,
        activeStages: _active.length,
        waiting: waiting,
        testing: _testingActive,
        testingDetail: _testingDetail,
      );
    } catch (_) {
      // Status is best-effort telemetry; never let it disturb the pump.
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
        // Block any task that has burned its retry budget and isn't actively
        // being worked — whether it's stalled on Todo (never started) OR stuck
        // in Review (a verify/merge that never resolves). The latter is what
        // left tasks frozen in Review holding a slot; now they go Blocked (red)
        // so they're visible and stop consuming the connection pool.
        // A task that has PASSED review (verified / built) is NOT stalled — it
        // just needs the deterministic merge, which must never be blocked by the
        // retry budget (that's what wrongly Blocked a passed task at the finish
        // line). Only block tasks still TRYING to pass: on the board (todo), or
        // stuck getting a verdict / re-driving a conflict (submitted / verifying
        // / merging).
        final implementationStalled =
            t.status == TaskStatus.todo &&
            (_attempts[t.task_pk] ?? 0) >= _maxAttemptsPerTask;
        final reviewStalled =
            t.status == TaskStatus.review &&
            (t.executionStatus == TaskExecStatus.submitted ||
                t.executionStatus == TaskExecStatus.verifying ||
                t.executionStatus == TaskExecStatus.merging) &&
            (_reviewFailures[t.task_pk] ?? 0) >= _maxAttemptsPerTask;
        if ((implementationStalled || reviewStalled) &&
            !_active.contains(t.task_pk)) {
          debugPrint(
            '[Orchestrator p$projectId] task ${t.task_pk} (${t.status}/'
            '${t.executionStatus}) exhausted $_maxAttemptsPerTask attempts → '
            'Blocked.',
          );
          await _db.markTaskBlocked(t.task_pk);
          // Wipe the in-memory retry count so a human who later moves this task
          // Blocked → Todo gets a FRESH budget. Without this the stale count
          // (already ≥ cap) makes it re-block on the very next pump without ever
          // running again.
          _attempts.remove(t.task_pk);
          _reviewFailures.remove(t.task_pk);
        }
      }

      // File-claim safety sweep (the anti-hog guarantee): a file may only stay
      // locked by a task that is either actively running a stage (in _active) or
      // sitting in Review awaiting integration (submitted → … → merging). Any
      // other owner — Done, Blocked, or a task that fell back to the Todo board —
      // has its claims dropped here, so no lock can be held indefinitely even if
      // an explicit release was somehow missed.
      if (_fileOwners.isNotEmpty) {
        final holding = <int>{..._active};
        for (final t in tasks) {
          if (t.status == TaskStatus.review) holding.add(t.task_pk);
        }
        _fileOwners.removeWhere((_, owner) => !holding.contains(owner));
      }

      // Forget the footprint of any task that's finished for good (Done/Blocked
      // and not running) — it can never collide again, so its scope shouldn't
      // keep gating others, and the map stays bounded over a long project.
      if (_taskFootprint.isNotEmpty) {
        for (final t in tasks) {
          if ((t.status == TaskStatus.done || t.status == TaskStatus.blocked) &&
              !_active.contains(t.task_pk)) {
            _taskFootprint.remove(t.task_pk);
          }
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

  /// Pick the next task + stage for one available worker slot. Separate tasks
  /// use isolated working trees, so [_pump] may call this repeatedly and run
  /// several agents at once up to the server's concurrency cap.
  Future<(Task?, _Stage?)> _nextPipelineWork() async {
    final tasks = await _db.getTasksForProject(projectId);
    // Only the currently-open milestone batch is assignable for fresh implement
    // work; in-flight (Review) tasks always belong to it already.
    final project = await _db.getProjectById(projectId);
    final currentMilestone = project?.currentMilestone ?? 0;
    // FAST LANE: while the Editor is driving (state == 'editing'), tasks skip the
    // per-task verify + build gates and go straight to merge the moment the
    // worker submits — the whole point is snappy edits. A single quick analyze at
    // finalize (see _maybeFinalizeProject) is the safety net, and a real breakage
    // there falls back to the full Testing phase.
    final editing = project?.orchestrationState == 'editing';
    final review = tasks
        .where(
          (t) => !_active.contains(t.task_pk) && t.status == TaskStatus.review,
        )
        .toList();

    final pools = <_Stage, List<Task>>{};
    void addPool(_Stage s, List<Task> list) {
      if (list.isNotEmpty) pools[s] = _sortByPriority(list);
    }

    // A Review task whose retry budget is spent is NOT re-picked here — it's
    // surfaced to Blocked by _surfaceStalledTasks instead of looping forever.
    bool live(Task t) {
      if ((_reviewFailures[t.task_pk] ?? 0) >= _maxAttemptsPerTask) {
        return false;
      }
      final until = _parkedUntil[t.task_pk];
      return until == null || !DateTime.now().isBefore(until);
    }

    addPool(_Stage.implement, _assignableTasks(tasks, currentMilestone));
    // The verify + build gates are SKIPPED entirely in the Editor fast lane; a
    // submitted task routes straight to merge below.
    if (!editing) {
      addPool(
        _Stage.verify,
        review
            // `verifying` is included so a verify stage that was interrupted
            // (turn cap / crash / app restart) AFTER run_verification set the task
            // to `verifying` is RE-PICKED rather than stranded — that strand was
            // the "stuck in Review forever, holding a slot" bug.
            .where(
              (t) =>
                  (t.executionStatus == TaskExecStatus.submitted ||
                      t.executionStatus == TaskExecStatus.verifying) &&
                  live(t),
            )
            .toList(),
      );
      addPool(
        _Stage.build,
        review
            .where(
              (t) =>
                  ((t.executionStatus == TaskExecStatus.verified &&
                          t.requiresBuild) ||
                      t.executionStatus == TaskExecStatus.building) &&
                  live(t),
            )
            .toList(),
      );
    }
    addPool(
      _Stage.merge,
      review
          .where(
            (t) =>
                // A task that PASSED review (built, or verified without a build
                // gate) ALWAYS gets its merge — the deterministic fast-path is
                // quick, so it's never gated by the retry budget (gating it there
                // stranded passed tasks at the finish line). Only the conflict
                // re-drive (`merging`, an interrupted/escalated coordinator merge)
                // stays budget-bounded so a stuck merge can't loop forever.
                t.executionStatus == TaskExecStatus.built ||
                (t.executionStatus == TaskExecStatus.verified &&
                    !t.requiresBuild) ||
                (t.executionStatus == TaskExecStatus.merging && live(t)) ||
                // FAST LANE: a just-submitted (or mid-verify) editor task is
                // merge-ready immediately — its work branch is already committed,
                // and we deliberately skip verify/build for snappy edits.
                (editing &&
                    (t.executionStatus == TaskExecStatus.submitted ||
                        t.executionStatus == TaskExecStatus.verifying ||
                        t.executionStatus == TaskExecStatus.verified)),
          )
          .toList(),
    );

    // DRAIN-FIRST priority: always advance work that's already in flight before
    // starting anything new, so a task's file locks (held from first edit until
    // merge) are released as soon as possible instead of many tasks piling into
    // Review holding locks and starving the Todo queue behind them. Order:
    // merge → build → verify → implement. A new Todo is only picked up when
    // there's no in-flight task left to push toward Done.
    for (final stage in const [
      _Stage.merge,
      _Stage.build,
      _Stage.verify,
      _Stage.implement,
    ]) {
      final pool = pools[stage];
      if (pool != null && pool.isNotEmpty) return (pool.first, stage);
    }
    return (null, null);
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
  /// board, not already running here, under the retry cap, AND within the
  /// currently-open milestone batch ([currentMilestone]). The milestone filter is
  /// what makes work proceed one batch at a time: a later milestone's tasks stay
  /// on the board until the project advances to them.
  List<Task> _assignableTasks(List<Task> tasks, int currentMilestone) {
    final out = <Task>[];
    for (final t in tasks) {
      if (t.task_agent_fk == null) continue;
      if (_active.contains(t.task_pk)) continue;
      if ((_attempts[t.task_pk] ?? 0) >= _maxAttemptsPerTask) continue;
      if ((t.milestoneOrder ?? 0) > currentMilestone) continue;
      // Park cooldown: a task that just parked on a held file waits a beat before
      // it's eligible again, so contending tasks don't thrash in a busy-loop.
      final until = _parkedUntil[t.task_pk];
      if (until != null && DateTime.now().isBefore(until)) continue;
      // Seed this task's footprint from the files it DECLARES (title/description)
      // so the scope gate can serialise same-hot-file tasks from the first pump,
      // before any of them run and collide — the cheapest way to cut merge
      // conflicts (and the resolve/redo cost they cause) is to not create them.
      _seedDeclaredFootprint(t);
      // Predictive scope gate: don't start a task that's known to edit files
      // another in-flight task holds — it would only collide and park. Leave it
      // on the board; it dispatches cleanly once the conflicting task merges.
      if (_scopeConflict(t.task_pk)) {
        debugPrint(
          '[Orchestrator p$projectId] task ${t.task_pk}: held back — its file '
          'scope overlaps work in flight; waiting for a clean slot.',
        );
        continue;
      }
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

    final resolved = await _resolveBackend(persona, taskPk: task.task_pk);
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
    // PRESERVE WORK ON RESUME: a task that was parked/yielded mid-build (exec
    // `queued`) and already has commits on its branch keeps them — we just rebuild
    // its scratch tree from the branch and continue, instead of tossing the work
    // and redoing from scratch. (Staleness vs the latest base is reconciled at
    // merge time, which escalates only real same-file conflicts.) A fresh task
    // (no branch yet) is rooted on its base; a rework after a real merge conflict
    // or failed gate (exec idle/failed) re-roots onto the CURRENT target so the
    // redo rebases cleanly.
    var preserveWork = false;
    // Root the task branch / hydrate its tree, serialized through the lane (the
    // shared object/ref DB is single-isolate). This runs OUTSIDE the turn loop,
    // so the SSE watchdog doesn't cover it — guard it with the lane timeout so a
    // hung git step yields the task back instead of wedging the lane (and every
    // other task's git op) until restart.
    try {
      await th.lane.run(() async {
        final branchExists = (await th.git.branches()).contains(branch);
        final branchHasTaskCommits =
            branchExists && await th.git.branchHasCommitsNotIn(branch, base);
        // Keep real task commits after interruption, failed review, or an
        // automatic Blocked retry. A merge-conflict redo deliberately starts on
        // the latest target. A pre-created branch merely behind main contains no
        // recoverable task work and must not be submitted as if it did.
        preserveWork =
            branchHasTaskCommits && !_redoHint.containsKey(task.task_pk);
        if (preserveWork) {
          await th.git.materializeInto(branch, th.tree);
        } else {
          await th.git.deleteBranch(branch);
          await th.git.createBranchAt(branch, base: base);
          await th.git.materializeInto(branch, th.tree);
        }
      }, timeout: _laneOpTimeout);
    } catch (e) {
      // A hang (TimeoutException) or transient git error here isn't the task's
      // fault — release locks/tree and yield back so the pump moves on.
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: branch setup '
        '${e is TimeoutException ? 'timed out' : 'failed'} ($e) — yielding back.',
      );
      _releaseLocks(task.task_pk);
      await _releaseTaskTree(task.task_pk);
      await _db.markTaskYieldedBack(task.task_pk);
      return;
    }
    if (preserveWork) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: resuming on its '
        'existing branch — prior work preserved.',
      );
    }

    // File-claim queue: claim a file the first time this worker edits it; if
    // another task holds it, deny (the tool returns a "queued" message) and flag
    // the task to PARK. Locks are kept past submission (until merge) so no two
    // tasks submit conflicting edits to the same file; a non-submitting run
    // releases them in the finally below. Declared OUTSIDE the try so the finally
    // can read `submitted`.
    var parked = false;
    var submitted = false;
    // Successful task-owned writes must survive a later Router stall. This is
    // set only after the mutation succeeds; every non-submitting exit saves it
    // to the task branch as a WIP commit.
    var uncheckpointedEdit = false;
    bool claim(String path) {
      final p = _normFile(path);
      // Learn this task's footprint whether the claim is granted or denied — a
      // denied file is one it WANTS, so it counts toward future scope conflicts.
      (_taskFootprint[task.task_pk] ??= <String>{}).add(p);
      final owner = _fileOwners[p];
      if (owner == null || owner == task.task_pk) {
        _fileOwners[p] = task.task_pk;
        return true;
      }
      parked = true;
      return false;
    }

    Future<void> checkpointUncommitted(String reason) async {
      if (!uncheckpointedEdit) return;
      try {
        final oid = await th.lane.run(
          () => th.git.commitFrom(
            th.tree,
            branch: branch,
            message: 'wip: checkpoint $reason (task #${task.task_pk})',
          ),
          timeout: _laneOpTimeout,
        );
        uncheckpointedEdit = false;
        final shortOid = oid.length >= 8 ? oid.substring(0, 8) : oid;
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: preserved '
          'uncommitted worker edits as WIP $shortOid ($reason).',
        );
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: could not '
          'checkpoint worker edits after $reason: $e',
        );
      }
    }

    try {
      final prompts = await _loadPrompts();
      final vars = _varsFor(task, branch, targetBranch: base);
      // Give the worker PROJECT-WIDE CONTEXT (the task decomposition + the current
      // file tree + stay-in-your-lane rules) so parallel tasks build on each other
      // instead of each silo re-creating and overwriting shared files.
      final projectContext = await _buildWorkerProjectContext(task, th.tree);
      final workerScope = await _workerTemplateScope(task, th.tree);
      if (workerScope.writeRoots.isNotEmpty) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: write scope '
          '${workerScope.writeRoots.join(', ')}; required '
          '${workerScope.requiredFiles.join(', ')}.',
        );
      }
      final scopeInstruction = workerScope.writeRoots.isEmpty
          ? ''
          : '''

=== AUTHORITATIVE FILE SCOPE ===
Write ONLY inside: ${workerScope.writeRoots.join(', ')}
You MUST implement this starter before committing: ${workerScope.requiredFiles.join(', ')}
Paths from any other repository, operating system, task, or prior conversation are invalid. When a write tool is offered, use the exact required starter path above and supply complete Dart implementation content for THIS task.''';

      // A worker may have written useful code and then lost the Router before
      // commit/submit. Both its own commit and our WIP safety checkpoint are
      // durable task-owned work. Submit either one to the normal structural and
      // functional review gates instead of forcing another generation round;
      // incomplete WIP is rejected there with concrete evidence and regenerated.
      final branchLog = preserveWork
          ? await th.git.log(limit: 1, from: branch)
          : const <
              ({String oid, String message, DateTime when, String author})
            >[];
      final baseLog = preserveWork
          ? await th.git.log(limit: 1, from: base)
          : const <
              ({String oid, String message, DateTime when, String author})
            >[];
      final branchAheadOfBase =
          branchLog.isNotEmpty &&
          (baseLog.isEmpty || branchLog.first.oid != baseLog.first.oid);
      final recoverCommittedSubmission = taskCanRecoverCommittedSubmission(
        executionStatus: task.executionStatus,
        description: task.description,
        branchAheadOfBase: branchAheadOfBase,
      );
      final recoveredWip =
          recoverCommittedSubmission &&
          branchLog.first.message.trimLeft().toLowerCase().startsWith('wip:');

      // One conversation PER AGENT: reuse this worker's dedicated session so all
      // of its tasks land in a single ongoing thread (the person can follow the
      // agent there) instead of a brand-new session on every task update.
      final workerSessionPk = await _db.getOrCreateAgentChatSession(
        projectId,
        agentFk,
        persona.name,
      );
      // Picked up & preparing the workspace — the task stays on the Todo board
      // (exec `queued`). It only flips to "In Progress" once a worker turn truly
      // begins (below), so the column never shows work nobody is doing.
      await _db.markTaskQueued(task.task_pk);

      if (recoverCommittedSubmission) {
        await _db.markTaskRunning(
          task.task_pk,
          workerSessionPk: workerSessionPk,
          workBranch: branch,
        );
        await _db.submitTaskForCompletion(
          task.task_pk,
          submissionJson: jsonEncode({
            'summary': recoveredWip
                ? 'Recovered checkpointed task work after an interrupted worker turn.'
                : 'Recovered committed task work after an interrupted submission round.',
            'evidence':
                'Commit ${branchLog.first.oid} is preserved on $branch.',
            'branch': branch,
            'submittedBy': persona.name,
            'submittedAt': DateTime.now().toIso8601String(),
          }),
        );
        submitted = true;
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: recovered task-owned '
          'work ${branchLog.first.oid.substring(0, 8)} and submitted it to the '
          'review gates without another generation round.',
        );
        return;
      }

      // Count a real generation/repair round. Recovering an already-written
      // commit above is only pipeline continuation and must not burn a worker
      // attempt of its own.
      _attempts[task.task_pk] = (_attempts[task.task_pk] ?? 0) + 1;

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
        workTaskId: task.task_pk,
        workerWriteRoots: workerScope.writeRoots,
        workerRequiredFiles: workerScope.requiredFiles,
        fileClaim: claim,
        // Autonomous coders need file/git/build tools directly — no progressive
        // disclosure (that's for the interactive PM chat).
        leanTools: false,
        systemPromptOverride:
            '${await _framedPrompt(role, OrchestratorPromptField.workerFraming, prompts, vars)}'
            '$scopeInstruction\n\n$projectContext',
        reasoningEffort: personaReasoningEffort(persona.configJson),
        enableThinking: resolveEnableThinking(
          agent: personaThinkingMode(
            persona.configJson,
            personaName: persona.name,
          ),
          task: ThinkingMode.fromString(task.thinkingMode),
        ),
      );

      var kickoff = prompts.render(OrchestratorPromptField.workerKickoff, vars);
      // REDO (lighter): if this task is being re-applied after a merge conflict,
      // lead with the re-apply hint (its prior plan) and give it a smaller turn
      // budget — main already has the sibling work, so it should converge fast
      // instead of paying a full from-scratch implementation again.
      final redoHint = _redoHint[task.task_pk];
      final maxTurns = redoHint != null ? _maxRedoTurns : _maxTurnsPerTask;
      if (redoHint != null) kickoff = '$redoHint\n\n$kickoff';
      // Diagnostics carried across turns: did the model ever actually use a tool,
      // and did the backend ever drop tools (model can't tool-call)? A worker
      // that "hits turn cap without submission" on every task is almost always
      // one of these — surface it instead of failing silently.
      var sawToolActivity = false;
      var toolsRejected = false;
      for (var turn = 0; turn < maxTurns && !_disposed; turn++) {
        // Stop promptly if the human paused/stopped the project mid-task — return
        // the task to the board instead of leaving it parked "In Progress".
        final project = await _db.getProjectById(projectId);
        if (project == null || !_isActiveState(project.orchestrationState)) {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: project not active, halting worker.',
          );
          await checkpointUncommitted('before the project stopped');
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
          // _drainTurn (NOT stream.timeout): enforces BOTH the idle timeout AND
          // a hard wall-clock cap, so a backend that trickles keep-alives but
          // never completes can't freeze the worker forever (it did — a stalled
          // call hung the whole build for an hour because plain .timeout resets
          // on every keep-alive).
          await _drainTurn(
            session.runTurn(
              kickoff,
              // Coders need to read → edit → commit → submit; 4 rounds often
              // isn't enough to finish in one turn, so give the worker more room
              // before the turn's forced no-tools wrap-up (which can't submit).
              maxToolRounds: 8,
              // Persist the worker's full trace (tool calls + args + results) per
              // task so it can be exported from Account → Export Tracking — but
              // ONLY when the user toggled worker capture on (it's a lot of
              // data). Gated before the expensive jsonEncode so OFF costs nothing.
              onTrace: (messages) {
                // Reading a provider after the orchestrator was disposed throws
                // — skip the capture in that case.
                if (_disposed || !ref.read(workerCaptureProvider)) return;
                unawaited(
                  _db.upsertTrainingTrace(
                    projectPk: projectId,
                    aiKind: 'worker',
                    conversationId: 'worker:$projectId:${task.task_pk}',
                    messagesJson: jsonEncode(messages),
                  ),
                );
              },
              onToolResult: (r) {
                sawToolActivity = true;
                if (r.startsWith('Updated file "') ||
                    r.startsWith('Created file "') ||
                    r.startsWith('Edited "')) {
                  uncheckpointedEdit = true;
                } else if (r.startsWith('Committed')) {
                  uncheckpointedEdit = false;
                }
                // The session emits this exact note when the backend rejected
                // tool-calling and re-ran the round WITHOUT tools — a worker can
                // never submit in that state.
                if (r.contains('rejected tool-calling')) toolsRejected = true;
                debugPrint(
                  '[Orchestrator p$projectId] task ${task.task_pk} turn $turn '
                  'tool → ${r.length > 140 ? '${r.substring(0, 140)}…' : r}',
                );
              },
            ),
            activity: session.turnActivity,
            wallClock: _workerTurnWallClock,
          );
        } catch (e) {
          // A backend response can cross the watchdog deadline just as its last
          // tool finishes. `submit_for_completion` commits the state change
          // before runTurn emits its terminal event, so always trust the DB over
          // the stale timeout: never send an already-submitted task back to the
          // worker (the duplicate retry can overwrite valid work).
          final afterTurn = await _db.getTaskById(task.task_pk);
          final progressed =
              afterTurn != null &&
              const {
                TaskExecStatus.submitted,
                TaskExecStatus.verifying,
                TaskExecStatus.verified,
                TaskExecStatus.building,
                TaskExecStatus.built,
                TaskExecStatus.merging,
                TaskExecStatus.done,
              }.contains(afterTurn.executionStatus);
          if (progressed) {
            submitted = afterTurn.status == TaskStatus.review;
            debugPrint(
              '[Orchestrator p$projectId] task ${task.task_pk}: turn ended after '
              'submission (${afterTurn.executionStatus}); preserving pipeline state.',
            );
            return;
          }
          if (e is TimeoutException) {
            // The turn stalled — idle (no stream for _turnIdleTimeout) OR it blew
            // the hard wall-clock cap (_turnWallClock) while trickling keep-alives
            // but never completing. NOT the task's fault: undo the attempt and
            // yield back so the slot frees and the pump moves on.
            // A watchdog timeout is an interrupted inference request, regardless
            // of whether it read or edited files first. Preserve any writes below
            // and refund the round; only completed generation/repair rounds may
            // exhaust the deliberate Blocked budget.
            _undoAttempt(task.task_pk);
            _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
            debugPrint(
              '[Orchestrator p$projectId] task ${task.task_pk}: turn $turn '
              'timed out ($e) — aborting, yielding back.',
            );
          } else if (_isNotTaskFault(e)) {
            // 429 backpressure or a transient 5xx/closed/network — NOT a failure.
            // Undo this attempt so a busy/flaky gateway can never push the task to
            // Blocked. But back it off first: a "transient" that keeps recurring
            // (e.g. an over-large prompt that fails every call) would otherwise
            // re-dispatch instantly and spin in a SILENT tight loop (no attempt
            // cost, no log). The cooldown + this log turn that into a visible,
            // calm retry. (429s already carry their own dispatch backoff via
            // _isConnCap; this covers the other transient faults.)
            _undoAttempt(task.task_pk);
            _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
            debugPrint(
              '[Orchestrator p$projectId] task ${task.task_pk}: turn $turn '
              'transient fault (${e.runtimeType}) — backing off '
              '${_parkCooldown.inSeconds}s, yielding back.',
            );
          } else {
            debugPrint(
              '[Orchestrator p$projectId] task ${task.task_pk}: turn $turn failed: $e',
            );
          }
          await checkpointUncommitted('after an interrupted inference turn');
          await _db.markTaskYieldedBack(task.task_pk);
          return;
        }

        final fresh = await _db.getTaskById(task.task_pk);
        if (fresh == null) return;
        if (fresh.executionStatus == TaskExecStatus.submitted) {
          // KEEP this task's file locks — they're held through the merge so no
          // other task can submit conflicting edits to the same files meanwhile.
          submitted = true;
          _redoHint.remove(task.task_pk); // redo produced a submission — done
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: submitted for review.',
          );
          return;
        }

        // A runTurn may reach its internal action cap after writing but before
        // commit. Save that work before asking the Router for another turn.
        await checkpointUncommitted('after an incomplete worker turn');

        // Parked: the worker needs a file another task holds. Don't burn an
        // attempt (it's waiting, not failing) — yield back and retry later; the
        // finally releases this task's own locks so it can't block others while
        // it waits. HOLD ITS WORK, don't toss it: checkpoint any uncommitted
        // edits onto the task branch so the resume continues from here (the
        // resume preserves the branch instead of re-rooting — see above).
        if (parked) {
          await checkpointUncommitted('before pausing for a held file');
          _undoAttempt(task.task_pk);
          // Back off before this task is eligible again, so it doesn't instantly
          // re-dispatch and thrash against the file's owner (the busy-loop above).
          _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: parked — a file it '
            'needs is held by another task; work preserved, will resume after that task merges.',
          );
          await _db.markTaskYieldedBack(task.task_pk);
          return;
        }

        kickoff = prompts.render(OrchestratorPromptField.workerContinue, vars);
      }
      // Ran out of turns without submitting — back to the board (a fresh attempt
      // will re-pick it, up to the retry cap) rather than stuck "In Progress".
      // The diagnostics tell you WHY: `toolsRejected` = the model/server can't
      // tool-call (so it can never submit — the usual cause of every task
      // blocking); `!sawToolActivity` = the model only chatted and never touched
      // a tool. Both point at the worker model, not the task.
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: hit turn cap without '
        'submission (toolsRejected=$toolsRejected, usedTools=$sawToolActivity).',
      );
      await checkpointUncommitted('after reaching the worker turn cap');
      await _db.markTaskYieldedBack(task.task_pk);
    } finally {
      // Unless this task SUBMITTED (and so should hold its files through merge),
      // drop its file claims now — a parked/failed/turn-capped run must not keep
      // others queued behind it.
      if (!submitted) _releaseLocks(task.task_pk);
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

  /// A stage's system prompt with the AUTHORITATIVE project baseline prepended,
  /// so every agent (worker / verifier / merger) implements, checks, and merges
  /// strictly within the platforms + language/framework stack chosen at setup —
  /// never substituting a different technology.
  Future<String> _framedPrompt(
    AgentRole role,
    OrchestratorPromptField field,
    OrchestratorPrompts prompts,
    PromptVars vars,
  ) async {
    final baseline = await buildProjectBaseline(_db, projectId);
    return '$baseline\n\n${defaultSystemPrompt(role)}\n'
        '${prompts.render(field, vars)}';
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

  /// Resolve the task-owned write root and required starter declared by the
  /// Templater. An empty result preserves compatibility with older templates.
  Future<({Set<String> writeRoots, Set<String> requiredFiles})>
  _workerTemplateScope(Task task, Workspace tree) async {
    final roots = <String>{};
    final required = <String>{};
    String normalized(String raw) {
      var path = raw.trim().replaceAll('\\', '/');
      if (path.isEmpty) return '';
      if (!path.startsWith('/')) path = '/$path';
      while (path.contains('//')) {
        path = path.replaceAll('//', '/');
      }
      if (path.length > 1 && path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      return path;
    }

    try {
      final lines = (await tree.readString('/WORK_TEMPLATE.md')).split('\n');
      var inTask = false;
      final header = RegExp('Task #${task.task_pk}\\b');
      final owns = RegExp(r'^-\s*Owns:\s*`([^`]+)`', caseSensitive: false);
      final starter = RegExp(
        r'^-\s*Starter:\s*`([^`]+)`',
        caseSensitive: false,
      );
      for (final raw in lines) {
        final line = raw.trim();
        if (line.startsWith('### ')) {
          inTask = header.hasMatch(line);
          continue;
        }
        if (!inTask) continue;
        final ownMatch = owns.firstMatch(line);
        if (ownMatch != null) roots.add(normalized(ownMatch.group(1)!));
        final starterMatch = starter.firstMatch(line);
        if (starterMatch != null) {
          required.add(normalized(starterMatch.group(1)!));
        }
      }
    } catch (_) {}

    // Deterministic Flutter templates encode task ownership in the directory
    // name. Recover it from the real tree if a hand-edited template omitted the
    // metadata, while leaving non-templated projects unrestricted.
    if (roots.isEmpty || required.isEmpty) {
      try {
        final marker = '/task_${task.task_pk}_';
        for (final entry in await tree.walk()) {
          if (entry.isDirectory) continue;
          final path = normalized(entry.path);
          final markerAt = path.indexOf(marker);
          if (markerAt < 0) continue;
          final slashAfter = path.indexOf('/', markerAt + marker.length);
          if (slashAfter > 0) roots.add(path.substring(0, slashAfter));
          if (path.endsWith('_page.dart')) required.add(path);
        }
      } catch (_) {}
    }
    roots.remove('');
    required.remove('');
    return (writeRoots: roots, requiredFiles: required);
  }

  /// PROJECT-WIDE CONTEXT for a worker: the full task decomposition + the current
  /// file tree (from its own branch) + the "stay in your lane" rules. Without this
  /// a worker only sees its single task and the stack, so with more tasks each
  /// silo re-creates and overwrites the shared/glue files the others also touch —
  /// the "more tasks = more overwriting" failure. Caps keep it cheap to inject on
  /// every worker turn even on a large backlog.
  Future<String> _buildWorkerProjectContext(Task task, Workspace tree) async {
    final b = StringBuffer();
    try {
      final tasks = await _db.getTasksForProject(projectId)
        ..sort((a, c) => a.task_pk.compareTo(c.task_pk));
      b.writeln(
        '=== PROJECT TASK MAP (the full decomposition — build ON these; do NOT '
        'redo or duplicate another task\'s work) ===',
      );
      const taskCap = 80;
      var shown = 0;
      for (final t in tasks) {
        if (shown >= taskCap) {
          b.writeln('… (+${tasks.length - taskCap} more tasks)');
          break;
        }
        shown++;
        final mark = t.task_pk == task.task_pk ? '   ← THIS TASK' : '';
        b.writeln('- #${t.task_pk} [${t.status}] ${t.title}$mark');
      }
    } catch (_) {}
    try {
      final files =
          (await tree.walk())
              .where((f) => !f.isDirectory)
              .map((f) => f.path)
              .toList()
            ..sort();
      if (files.isNotEmpty) {
        b.writeln(
          '\n=== CURRENT PROJECT FILES (already on your branch — read what you '
          'need; do NOT re-list directories) ===',
        );
        const fileCap = 200;
        for (var i = 0; i < files.length && i < fileCap; i++) {
          b.writeln(files[i]);
        }
        if (files.length > fileCap) {
          b.writeln('… (+${files.length - fileCap} more files)');
        }
      }
    } catch (_) {}
    b.write(
      '''

=== RULES ===
- WORK TEMPLATE: if /WORK_TEMPLATE.md exists, read it first and follow its
  milestone dependencies, shared-contract ownership, and task-specific file map.
- FULLY IMPLEMENT your file(s): a working, wired feature — NOT just compiling. No TODO/FIXME/UnimplementedError/"coming soon"/placeholder bodies (Review scans for these and bounces the task).
- WIRE IT IN: the scaffold already routes to your declared Starter file. Keep that class/API intact and replace its placeholder with the complete feature; Review requires that owned starter to change before submission.
- STAY IN YOUR LANE: implement ONLY your task's file(s); other tasks own theirs. To use another component, READ its declared contract/interface and code to its EXACT members — don't recreate it or call members it doesn't declare.
- SHARED GLUE IS COMPLETE — the scaffold already declared the DB schema, main/entry, router/nav, DI container, barrels, and manifest/deps. Code AGAINST them; do NOT edit them (the worker tools enforce your task-owned write scope).
- Do NOT hand-write generated files (`*.g.dart`/`*.freezed.dart`/`*.mocks.dart`): write the SOURCE with its `part '...g.dart';` directive and let codegen run (deps go in dev_dependencies).''',
    );
    return b.toString().trimRight();
  }

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

  /// Markers that betray an UNIMPLEMENTED feature left behind as a placeholder —
  /// the "compiles but does nothing" trap. Deterministic, no LLM.
  static final RegExp _stubMarkerRe = RegExp(
    r'\bTODO\b|\bFIXME\b|UnimplementedError|UnsupportedError'
    r'|not[\s_-]*yet[\s_-]*implemented|not[\s_-]*implemented'
    r'|implement[\s_-]*(this|me|later)\b|coming[\s_-]*soon'
    r'|\bplaceholder\b',
    caseSensitive: false,
  );

  bool _isScannableCodeFile(String path) {
    final p = path.toLowerCase();
    const exts = [
      '.dart',
      '.ts',
      '.tsx',
      '.js',
      '.jsx',
      '.py',
      '.go',
      '.rs',
      '.cs',
      '.java',
      '.kt',
      '.kts',
      '.swift',
      '.cpp',
      '.cc',
      '.c',
      '.h',
      '.hpp',
      '.rb',
      '.php',
      '.vue',
      '.svelte',
    ];
    return exts.any(p.endsWith);
  }

  /// Scan the files THIS task touched (its footprint) for destructive shrinking
  /// and unimplemented-stub markers. By OWNERSHIP, if the task CHANGED/added a
  /// file it owns that file, so
  /// ANY stub in it is rejected (leaving your own deliverable a "— TODO" is the
  /// hole this closes); if the task did NOT change a footprint file (pure
  /// reference — e.g. a UI task reading a stubbed service another task owns), only
  /// a NEW stub line counts, so the templater's pre-existing scaffold stubs are
  /// exempt (the #484 false-positive fix). Returns `file:line` findings (capped);
  /// empty when clean, no footprint, or can't diff. NOTE: this is the EARLY,
  /// footprint-based catch; `_scanTreeForStubs` is the restart-proof whole-tree
  /// backstop that guarantees no stub survives to completion.
  Future<String> _scanTaskForReviewProblems(Task task, String branch) async {
    final footprint = _taskFootprint[task.task_pk];
    if (footprint == null || footprint.isEmpty) return '';
    final code = footprint.where(_isScannableCodeFile).toList();
    if (code.isEmpty) return '';
    final base = await _integrationTargetBranch(task);
    final th = await _resolveTaskHandles(task.task_pk);
    if (th == null) return '';
    try {
      // This task's version of each touched file.
      await th.lane.run(
        () => th.git.materializeInto(branch, th.tree),
        timeout: _laneOpTimeout,
      );
      final taskLines = <String, List<String>>{};
      for (final f in code) {
        final path = f.startsWith('/') ? f : '/$f';
        if (await th.tree.exists(path)) {
          taskLines[f] = (await th.tree.readString(path)).split('\n');
        }
      }
      if (taskLines.isEmpty) return '';

      // The BASE version of each footprint file, kept RAW so we can tell whether
      // this task actually CHANGED the file. Two cases:
      //  • task did NOT change the file (pure reference — e.g. a UI task reading a
      //    stubbed service another task owns): its pre-existing scaffold stubs are
      //    NOT this task's fault → exempt them (this is the #484 false-positive fix).
      //  • task DID change the file (or ADDED it): the task now OWNS that file's
      //    content, so ANY stub in it is this task's to answer for — even one
      //    inherited from the templater scaffold. Leaving your OWN deliverable a
      //    "— TODO" placeholder is the exact hole this closes (#488/#489).
      // Base unreadable → treat as changed (strict: flag all).
      final baseRaw = <String, String?>{};
      try {
        await th.lane.run(
          () => th.git.materializeInto(base, th.tree),
          timeout: _laneOpTimeout,
        );
        for (final f in taskLines.keys) {
          final path = f.startsWith('/') ? f : '/$f';
          baseRaw[f] = await th.tree.exists(path)
              ? await th.tree.readString(path)
              : ''; // absent in base = the task ADDED it → owns it
        }
      } catch (_) {
        // base unavailable — leave baseRaw entries null (flag all task stubs).
      }

      final findings = <String>[];
      for (final entry in taskLines.entries) {
        final f = entry.key;
        final lines = entry.value;
        final baseContent = baseRaw[f];
        final taskContent = lines.join('\n');
        final taskChangedFile =
            baseContent == null || taskContent != baseContent;
        if (taskChangedFile) {
          final structural = taskReviewStructuralProblem(
            path: f,
            baseContent: baseContent,
            taskContent: taskContent,
          );
          if (structural != null) findings.add(structural);
        }
        final preExisting = (baseContent ?? '')
            .split('\n')
            .map((l) => l.trim())
            .toSet();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Flag a stub if the task owns this file (changed/added it), OR — for an
          // unchanged referenced file — only if the stub line is NEW vs base.
          if (_stubMarkerRe.hasMatch(line) &&
              (taskChangedFile || !preExisting.contains(line.trim()))) {
            findings.add(
              '$f:${i + 1}: ${line.trim().length > 120 ? '${line.trim().substring(0, 120)}…' : line.trim()}',
            );
            if (findings.length >= 40) break;
          }
        }
        if (findings.length >= 40) break;
      }
      return findings.join('\n');
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: content review scan skipped ($e).',
      );
      return '';
    } finally {
      await _releaseTaskTree(task.task_pk);
    }
  }

  /// Generated / vendored code that legitimately carries markers and is NOT a
  /// hand-written feature — excluded from the hard-no stub scan so a codegen
  /// artifact never blocks completion.
  bool _isGeneratedOrVendor(String path) {
    final p = path.toLowerCase();
    const genSuffixes = [
      '.g.dart',
      '.freezed.dart',
      '.mocks.dart',
      '.gr.dart',
      '.config.dart',
      '.pb.dart',
      '.pbjson.dart',
      '.pbenum.dart',
      '.gen.dart',
      '.d.ts',
    ];
    if (genSuffixes.any(p.endsWith)) return true;
    const vendorDirs = [
      '/generated/',
      '/.dart_tool/',
      '/build/',
      '/node_modules/',
      '/vendor/',
      '/.git/',
      '/ios/pods/',
      '/android/.gradle/',
    ];
    return vendorDirs.any(p.contains);
  }

  /// WHOLE-TREE stub scan (the "hard no" backstop): read EVERY hand-written code
  /// file on `main` and flag any [_stubMarkerRe] hit. Unlike the per-task diff
  /// scan this has NO base-branch exemption and NO reliance on the in-memory
  /// footprint — so it catches a task that left its OWN scaffolded deliverable a
  /// stub, and survives an orchestrator restart (which clears the footprint). The
  /// project must NOT reach `completed` while this returns anything. Returns
  /// `file:line` findings (capped) grouped so the fixer can implement them, '' when
  /// the whole tree is clean.
  Future<String> _scanTreeForStubs() async {
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    final git = handles.git;
    if (ws == null || git == null) return '';
    try {
      await git.checkoutBranch('main');
    } catch (_) {}
    final findings = <String>[];
    try {
      final files = (await ws.walk())
          .where(
            (f) =>
                !f.isDirectory &&
                _isScannableCodeFile(f.path) &&
                !_isGeneratedOrVendor(f.path),
          )
          .toList();
      for (final f in files) {
        final List<String> lines;
        try {
          lines = (await ws.readString(f.path)).split('\n');
        } catch (_) {
          continue;
        }
        for (var i = 0; i < lines.length; i++) {
          if (_stubMarkerRe.hasMatch(lines[i])) {
            final t = lines[i].trim();
            findings.add(
              '${f.path}:${i + 1}: ${t.length > 120 ? '${t.substring(0, 120)}…' : t}',
            );
            if (findings.length >= 60) return findings.join('\n');
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] whole-tree stub scan skipped ($e).',
      );
      return '';
    }
    return findings.join('\n');
  }

  /// The scaffold's always-green smoke/shell tests prove only that the harness
  /// starts. Final project testing requires at least one additional test that
  /// exercises generated feature code; otherwise a placeholder app can compile
  /// and report "All tests passed" without testing any requested behavior.
  Future<String> _featureTestCoverageProblem() async {
    final kind = await _detectStackKind();
    if (kind != 'flutter' && kind != 'dart') return '';
    final ws = (await _resolveWorkspaceHandles()).ws;
    if (ws == null) {
      return 'Feature-test coverage could not be inspected because the workspace is unavailable.';
    }
    final tests = (await ws.walk())
        .where(
          (entry) =>
              !entry.isDirectory &&
              entry.path.toLowerCase().contains('/test/') &&
              entry.path.toLowerCase().endsWith('_test.dart') &&
              !entry.path.toLowerCase().endsWith('/nxs_smoke_test.dart'),
        )
        .toList();
    for (final file in tests) {
      final content = await ws.readString(file.path);
      final generatedShellOnly =
          content.contains('generated project shell loads') &&
          RegExp(r'\btest(?:Widgets)?\s*\(').allMatches(content).length <= 1;
      if (!generatedShellOnly &&
          RegExp(r'\btest(?:Widgets)?\s*\(').hasMatch(content) &&
          RegExp(r'\bexpect\s*\(').hasMatch(content)) {
        return '';
      }
    }
    return 'Only generated smoke/shell tests exist. Add focused feature tests '
        'that exercise requested behavior and state transitions before the final '
        'CI result can count as a project pass.';
  }

  /// REVIEW. The project's CI/test gate is consolidated into a SINGLE end-of-
  /// project scan ([_maybeFinalizeProject]) — for a mostly-automated pipeline,
  /// testing once at the end is far faster than a full build per task. So per-task
  /// review runs NO build: a task with a real functional `verification` gets a
  /// short Verification Agent to confirm the described behavior; anything else
  /// passes immediately. Compile/test correctness is enforced once, at the end.
  Future<void> _runVerifyStage(Task task) async {
    final branch = task.workBranch ?? 'task/${task.task_pk}';

    // CONTENT GATE — a task is NOT done if it erased an existing implementation
    // or left the feature behind a placeholder marker. Compiling isn't the bar;
    // implementing is. Reject these before they can merge into main.
    final problems = await _scanTaskForReviewProblems(task, branch);
    if (problems.isNotEmpty) {
      await _db.recordTaskVerdict(task.task_pk, passed: false);
      await _db.attachTaskBuildFailure(
        task.task_pk,
        'REJECTED — this task submitted destructive or UNIMPLEMENTED code. '
        'Every feature must be FULLY implemented; never empty or collapse an '
        'existing source file, and never leave a TODO, placeholder, empty body, '
        'or UnimplementedError. Repair these findings:\n\n$problems',
      );
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: REVIEW REJECTED — '
        'destructive or unimplemented edit; sent back to implement for real.',
      );
      return;
    }

    final verification = (task.verification ?? '').trim();
    if (verification.isEmpty) {
      // Nothing functional to confirm — pass immediately (the end-of-project CI
      // scan is the test gate). This is the fast path for most tasks.
      await _db.recordTaskVerdict(task.task_pk, passed: true);
      if (task.requiresBuild) {
        await _db.recordTaskBuildOutcome(task.task_pk, passed: true);
      }
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: review passed (no functional verification; CI runs at project end).',
      );
      return;
    }
    await _runFunctionalVerify(task, branch);
  }

  /// Spawn a SHORT Verification Agent to confirm the task's FUNCTIONAL behavior
  /// by reading the changed code (it must NOT run the build/CI — tests run once at
  /// project end). On a pass for a `requiresBuild` task the result is advanced to
  /// `built` so the legacy build stage stays out of the way. Falls through to a
  /// pass when no verifier persona exists.
  Future<void> _runFunctionalVerify(Task task, String branch) async {
    final persona = await _findPersonaForRole(AgentRole.verificationAgent);
    if (persona == null) {
      // No verifier persona — pass it through (the end-of-project scan is the net).
      await _db.recordTaskVerdict(task.task_pk, passed: true);
      if (task.requiresBuild) {
        await _db.recordTaskBuildOutcome(task.task_pk, passed: true);
      }
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no verifier persona; review passed.',
      );
      return;
    }
    final resolved = await _resolveBackend(persona, taskPk: task.task_pk);
    if (resolved == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no inference server for verifier ${persona.name}.',
      );
      _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
      return;
    }
    final th = await _resolveTaskHandles(task.task_pk);
    if (th == null) {
      _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
      return;
    }
    // Hydrate an isolated tree with the submitted task branch so the verifier
    // reads the work without touching any other agent's tree. Guard the lane op
    // (a hang here would wedge the lane for every task) — on timeout/error yield
    // back so the task stays in Review and the pump retries it.
    try {
      await th.lane.run(
        () => th.git.materializeInto(branch, th.tree),
        timeout: _laneOpTimeout,
      );
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: verify hydrate '
        '${e is TimeoutException ? 'timed out' : 'failed'} ($e) — yielding back.',
      );
      await _releaseTaskTree(task.task_pk);
      // A lane hang is infra, not the task's fault — un-count this Review attempt
      // so a transient freeze can't push a good task toward Blocked. The task is
      // still `submitted` (verifying isn't marked until below), so the verify
      // pool re-picks it next pump on the now self-healed lane.
      _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
      return;
    }

    try {
      final prompts = await _loadPrompts();
      final vars = _varsFor(task, branch);
      final verificationScope = await _workerTemplateScope(task, th.tree);
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
        verificationTaskId: task.task_pk,
        verificationReadFiles: verificationScope.requiredFiles,
        systemPromptOverride: await _framedPrompt(
          AgentRole.verificationAgent,
          OrchestratorPromptField.verifyFraming,
          prompts,
          vars,
        ),
        reasoningEffort: personaReasoningEffort(persona.configJson),
        enableThinking: resolveEnableThinking(
          agent: personaThinkingMode(
            persona.configJson,
            personaName: persona.name,
          ),
          task: ThinkingMode.fromString(task.thinkingMode),
        ),
      );

      var kickoff = prompts.render(OrchestratorPromptField.verifyKickoff, vars);
      for (
        var turn = 0;
        turn < _maxFunctionalVerifyTurns && !_disposed;
        turn++
      ) {
        if (!await _stillRunning()) return;
        try {
          await _drainTurn(
            session.runTurn(
              kickoff,
              maxToolRounds: 6,
              onToolResult: (result) =>
                  debugPrint('[Verifier p$projectId t${task.task_pk}] $result'),
            ),
            activity: session.turnActivity,
          ); // idle + wall-clock cap
        } catch (e) {
          if (e is TimeoutException || _isNotTaskFault(e)) {
            _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
          } else {
            _reviewFailures[task.task_pk] =
                (_reviewFailures[task.task_pk] ?? 0) + 1;
            debugPrint(
              '[Orchestrator p$projectId] task ${task.task_pk}: functional verify turn $turn failed: $e',
            );
          }
          return;
        }
        final fresh = await _db.getTaskById(task.task_pk);
        if (fresh == null) return;
        if (fresh.executionStatus != TaskExecStatus.submitted &&
            fresh.executionStatus != TaskExecStatus.verifying) {
          // A functional PASS on a build-gated task jumps to `built` so the legacy
          // build stage doesn't re-run anything (CI is the end-of-project scan).
          if (fresh.executionStatus == TaskExecStatus.verified &&
              task.requiresBuild) {
            await _db.recordTaskBuildOutcome(task.task_pk, passed: true);
          }
          _reviewFailures.remove(task.task_pk);
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: functional verdict recorded (${fresh.executionStatus}).',
          );
          return;
        }
        kickoff = prompts.render(OrchestratorPromptField.verifyContinue, vars);
      }
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: functional verify hit turn cap without a verdict.',
      );
      _reviewFailures[task.task_pk] = (_reviewFailures[task.task_pk] ?? 0) + 1;
      _parkedUntil[task.task_pk] = DateTime.now().add(_parkCooldown);
    } finally {
      await _releaseTaskTree(task.task_pk);
    }
  }

  /// Run a workflow/dockerfile gate on [branch] and wait for its terminal result
  /// — deterministic, NO LLM. Returns null when the build infra can't run (the
  /// caller retries without penalty); `(passed: true, runPk: null)` when there is
  /// nothing to run; otherwise the run's pass/fail and its id.
  Future<({bool passed, int? runPk})?> _runWorkflowGate({
    required int clientPk,
    required String branch,
    String? workflowPath,
    String? dockerfilePath,
    String? imageTag,
    required String triggeredBy,
  }) async {
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    final build = handles.build;
    if (ws == null || build == null) return null;
    int runPk;
    try {
      if (workflowPath != null && workflowPath.isNotEmpty) {
        runPk = (await build.startWorkflowRun(
          clientPk: clientPk,
          projectPk: projectId,
          ws: ws,
          workflowPath: workflowPath,
          branch: branch,
          triggeredBy: triggeredBy,
        )).runPk;
      } else if (dockerfilePath != null && dockerfilePath.isNotEmpty) {
        final tag = (imageTag != null && imageTag.isNotEmpty)
            ? imageTag
            : 'gate-${branch.replaceAll('/', '-')}:latest';
        runPk = (await build.startDockerBuild(
          clientPk: clientPk,
          projectPk: projectId,
          ws: ws,
          dockerfilePath: dockerfilePath,
          imageTag: tag,
          branch: branch,
          triggeredBy: triggeredBy,
        )).runPk;
      } else {
        return (passed: true, runPk: null);
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] gate failed to start on "$branch": $e',
      );
      return (passed: false, runPk: null);
    }
    final deadline = DateTime.now().add(_buildTimeout);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_buildPollInterval);
      // Disposal (project switch / navigating off the workspace view) can land
      // DURING the delay above; touching `_db` (a ref.read) after that throws
      // "Cannot use Ref after disposed". Bail before the read — the re-mounted
      // orchestrator resumes from the checklist.
      if (_disposed) break;
      final run = await _db.getCiRun(runPk);
      if (run == null) break;
      final status = CiStatusX.fromWire(run.status);
      if (status.isTerminal) {
        return (passed: status == CiStatus.success, runPk: runPk);
      }
    }
    return (
      passed: false,
      runPk: runPk,
    ); // timed out / disposed → fail the gate
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
      await _failBuildGate(task, reason: 'The build run failed to start: $e');
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
        if (passed) {
          await _db.recordTaskBuildOutcome(task.task_pk, passed: true);
        } else {
          await _failBuildGate(
            task,
            runPk: runPk,
            reason:
                'The build gate (${status.wire}) failed on branch "$branch". '
                'Fix EVERY error/warning listed below, then resubmit.',
          );
        }
        return;
      }
    }
    debugPrint(
      '[Orchestrator p$projectId] task ${task.task_pk}: build run $runPk did not finish in time; failing the gate.',
    );
    await _failBuildGate(
      task,
      runPk: runPk,
      reason:
          'The build run did not finish within ${_buildTimeout.inMinutes} '
          'minutes and was treated as failed.',
    );
  }

  /// Send a task back to the board for a red build gate, FIRST attaching the
  /// failing run's full diagnostics (every analyze/compile error, not just the
  /// first) to the task description — so the worker fixes them ALL in one pass
  /// instead of one-error-per-resubmit.
  Future<void> _failBuildGate(Task task, {int? runPk, String? reason}) async {
    try {
      final errors = runPk != null ? await _collectBuildErrors(runPk) : '';
      final detail = [
        if (reason != null && reason.trim().isNotEmpty) reason.trim(),
        if (errors.isNotEmpty) errors,
      ].join('\n\n').trim();
      if (detail.isNotEmpty) {
        await _db.attachTaskBuildFailure(task.task_pk, detail);
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: could not attach build errors: $e',
      );
    }
    await _db.recordTaskBuildOutcome(task.task_pk, passed: false);
  }

  /// Pull every step log of [runPk] and return the diagnostic lines worth handing
  /// the worker — analyzer/compiler errors & warnings, test failures, file:line
  /// references — or the log tail when nothing matches the known shapes. Capped
  /// so a noisy log can't bloat the task description and the next prompt.
  Future<String> _collectBuildErrors(int runPk) async {
    final buf = StringBuffer();
    final jobs = await _db.getCiJobsForRun(runPk);
    for (final job in jobs) {
      final steps = await _db.getCiStepsForJob(job.ci_job_pk);
      for (final step in steps) {
        final log = step.logText.trim();
        if (log.isNotEmpty) buf.writeln(log);
      }
    }
    final lines = buf.toString().split('\n');
    final hits = _preferBlockers(
      lines
          .where((l) => _diagLineRe.hasMatch(l) && !_stackFrameRe.hasMatch(l))
          .map((l) => l.trimRight())
          .where((l) => l.isNotEmpty)
          .toList(),
    );
    final picked = hits.isNotEmpty
        ? hits
        : lines.reversed.take(40).toList().reversed.toList();
    var out = picked.join('\n').trim();
    const cap = 4000;
    if (out.length > cap) out = '…\n${out.substring(out.length - cap)}';
    return out;
  }

  /// Like [_collectBuildErrors] but for the TESTING phase: returns EVERY failpoint
  /// (not just a 4k tail) plus a COUNT, so the fixer can address them ALL in one
  /// pass and the phase can track progress run-over-run. The count excludes the
  /// "N issues found" summary line so it reflects actual failures.
  Future<({String text, int count})> _collectCiFailpoints(int runPk) async {
    final buf = StringBuffer();
    final jobs = await _db.getCiJobsForRun(runPk);
    for (final job in jobs) {
      final steps = await _db.getCiStepsForJob(job.ci_job_pk);
      for (final step in steps) {
        final log = step.logText.trim();
        if (log.isNotEmpty) buf.writeln(log);
      }
    }
    final lines = buf.toString().split('\n');
    final hits = lines
        .where((l) => _diagLineRe.hasMatch(l) && !_stackFrameRe.hasMatch(l))
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    // Count = diagnostic lines that are real failpoints (drop the "N issues
    // found" / summary lines so the progress metric tracks failures, not totals),
    // then keep only genuine blockers (errors/warnings/test failures) so advisory
    // `info` lints don't inflate the count or distract the fixer from what
    // actually breaks CI.
    final summaryRe = RegExp(r'\bissues?\s+found\b', caseSensitive: false);
    final failpoints = _preferBlockers(
      hits.where((l) => !summaryRe.hasMatch(l)).toList(),
    );
    final picked = failpoints.isNotEmpty
        ? failpoints
        : (hits.isNotEmpty
              ? hits
              : lines.reversed.take(60).toList().reversed.toList());
    var text = picked.join('\n').trim();
    // Generous cap (keep the HEAD so the first failures, usually the root cause,
    // survive) — big enough that ~100 failpoints all reach the fixer in one pass.
    if (text.length > _maxFixErrorChars) {
      text =
          '${text.substring(0, _maxFixErrorChars)}\n… (additional failures truncated — fix these first, the rest surface on the next run)';
    }
    return (text: text, count: picked.length);
  }

  /// True when a RED CI run failed ONLY on info-level analyzer lints — no errors,
  /// no warnings, and no non-analyze failure (a failed test/build/pub step). Info
  /// lints (e.g. `use_build_context_synchronously`) are advisory: the app compiles
  /// and runs, but `flutter analyze` exits non-zero on ANY issue, which otherwise
  /// stalls the whole project on a single style hint that the fixer can't reliably
  /// clear. In that case the finalize gate treats the run as GREEN. Conservative:
  /// ANY non-analyze failed step, or any `error -`/`warning -` diagnostic line in
  /// an analyze log, returns false (never masks a real failure).
  Future<bool> _ciRedIsInfoOnly(int runPk) async {
    final jobs = await _db.getCiJobsForRun(runPk);
    final sevRe = RegExp(r'^(error|warning)\s+[-•]', caseSensitive: false);
    var sawFailedAnalyze = false;
    for (final job in jobs) {
      final steps = await _db.getCiStepsForJob(job.ci_job_pk);
      for (final step in steps) {
        if (step.status != 'failed') continue;
        if (!step.name.toLowerCase().contains('analyze')) {
          return false; // a non-analyze step failed → a real failure
        }
        final hasErrOrWarn = step.logText
            .split('\n')
            .any((l) => sevRe.hasMatch(l.trimLeft()));
        if (hasErrOrWarn) return false; // real errors/warnings, not just infos
        sawFailedAnalyze = true;
      }
    }
    return sawFailedAnalyze;
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
    // The paths that actually conflicted — handed to the agent below, and written
    // into its worktree WITH conflict markers so it can see both sides.
    var conflictPaths = const <String>[];
    if (git != null) {
      try {
        final result = await lane.run(() async {
          await _checkout(git, targetBranch, task.task_pk);
          return git.merge(
            branch,
            message: 'Merge task #${task.task_pk}: ${task.title}',
          );
        }, timeout: _laneOpTimeout);
        if (result.outcome != MergeOutcome.conflicts) {
          await _db.approveTask(task.task_pk);
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: auto-merged (${result.outcome.name}) into "$targetBranch".',
          );
          return;
        }
        conflictPaths = result.conflicts;
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: merge conflicts on ${result.conflicts.length} file(s) — escalating.',
        );
      } on TimeoutException catch (e) {
        // The lane op hung (NOT a conflict) — the lane has now self-healed for
        // the next waiter. Don't drag in a Coordinator to "resolve" a conflict
        // that doesn't exist; un-count the attempt and leave the task built/
        // verified so the merge pool retries it cleanly next pump.
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: auto-merge timed out ($e) — yielding back for retry.',
        );
        return;
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: auto-merge errored ($e) — escalating.',
        );
      }
    }

    // FAST LANE (editor tasks): the Editor's worker model implements small edits
    // well but CANNOT reliably resolve conflict markers — driving it through the
    // conflict-resolver just burns turn caps and stalls (observed: two edits that
    // both touched game_screen.dart looped 5× then blocked). Since editor edits
    // are small and behaviour-specified, the reliable move is to REDO, not merge:
    // reopen the task so the implement stage re-roots its branch onto the CURRENT
    // target (which already has whatever merged first) and the worker re-applies
    // its change conflict-free. Un-count this merge attempt so the redo gets the
    // full retry budget rather than being double-charged. Bounded by
    // _maxAttemptsPerTask, and it converges: once the sibling is merged, the redo
    // has a clean base.
    final full = await _db.getTaskById(task.task_pk);
    if (full?.isEdit == true) {
      _markRedo(full!);
      await _db.reopenTask(task.task_pk);
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: editor merge conflict '
        'on ${conflictPaths.length} file(s) → redo on fresh target '
        '(skipping weak-model conflict resolution).',
      );
      return;
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
    final resolved = await _resolveBackend(persona, taskPk: task.task_pk);
    if (resolved == null) {
      debugPrint(
        '[Orchestrator p$projectId] task ${task.task_pk}: no inference server for coordinator ${persona.name}.',
      );
      return;
    }
    // Put the worktree on the target so the Coordinator resolves into it.
    await _checkout(handles.git, targetBranch, task.task_pk);

    // Give the agent the conflict it is being asked to resolve. The file-level
    // merge writes NOTHING on a conflict, so without this the agent lands on a
    // pristine target tree while its prompt tells it to "remove every conflict
    // marker" — impossible, so it burned its turns and the task always Blocked.
    // Writing both sides in with real markers makes that workflow actually work.
    final ws = handles.ws;
    if (git != null && ws != null && conflictPaths.isNotEmpty) {
      try {
        final n = await lane.run(
          () => git.writeConflictMarkers(branch, ws, conflictPaths),
          timeout: _laneOpTimeout,
        );
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: wrote conflict markers into $n file(s) for the agent.',
        );
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] task ${task.task_pk}: could not write conflict markers ($e) — agent gets the paths only.',
        );
      }
    }

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
      systemPromptOverride: await _framedPrompt(
        AgentRole.coordinator,
        OrchestratorPromptField.mergeFraming,
        prompts,
        vars,
      ),
      reasoningEffort: personaReasoningEffort(persona.configJson),
      enableThinking: resolveEnableThinking(
        agent: personaThinkingMode(
          persona.configJson,
          personaName: persona.name,
        ),
        task: ThinkingMode.fromString(task.thinkingMode),
      ),
    );

    var kickoff = prompts.render(OrchestratorPromptField.mergeKickoff, vars);
    if (conflictPaths.isNotEmpty) {
      kickoff +=
          '\n\nCONFLICTED FILES — each is ALREADY in your worktree with '
          '`<<<<<<< ours (current)` / `=======` / `>>>>>>> theirs ($branch)` '
          'markers around the divergent part. Open each one, combine BOTH '
          'sides\' intent, delete every marker line, then git_commit and '
          'approve_task:\n${conflictPaths.map((p) => '- $p').join('\n')}';
    }
    for (var turn = 0; turn < _maxTurnsPerStage && !_disposed; turn++) {
      if (!await _stillRunning()) return;
      try {
        await _drainTurn(
          session.runTurn(kickoff),
          activity: session.turnActivity,
        ); // idle + wall-clock cap
      } catch (e) {
        if (e is! TimeoutException && !_isNotTaskFault(e)) {
          debugPrint(
            '[Orchestrator p$projectId] task ${task.task_pk}: merge turn $turn failed: $e',
          );
        }
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
    // RESOLVER ONCE, THEN REDO: the resolver got one honest shot at the conflict
    // and couldn't clear the markers (the weak local model can't reliably resolve
    // them — this is what leaves tasks Blocked after 5 escalations, e.g. everyone
    // adding models to prisma/schema.prisma). Rather than re-escalate the same
    // failing resolver, REDO the task on fresh main: reopen it so the implement
    // stage re-roots its branch onto the CURRENT target (which already has
    // whatever merged first) and re-applies the change against a base where it no
    // longer conflicts — for additive files that lands clean. The auto-merge
    // committed nothing on conflict (the engine is conservative) and the resolver
    // couldn't commit markers (the commit guard blocks them), so main is clean to
    // redo onto. Bounded by _maxAttemptsPerTask. Editor tasks never reach here —
    // they redo BEFORE the resolver (see the isEdit branch above).
    debugPrint(
      '[Orchestrator p$projectId] task ${task.task_pk}: merge resolver could not '
      'clear the conflict on one pass — redoing on fresh main instead of '
      're-escalating.',
    );
    _markRedo(task);
    await _db.reopenTask(task.task_pk);
  }

  // ── Templater stage (one-shot base scaffold + milestone planning) ───────

  /// Gate the pipeline on a scaffolded base project. Returns true when work may
  /// proceed (templating done, or not applicable to this project), false when it
  /// kicked off / is still running templating — the pump re-runs when it lands.
  Future<bool> _ensureTemplated(Project project) async {
    switch (project.templateStatus) {
      case 'ready':
      case 'none': // legacy / planning-path projects scaffold elsewhere
        // Templating is done — the gate is open; pass silently (this runs on
        // every pump, so logging here spams once-per-cycle forever).
        return true;
      case 'failed':
        return false; // surfaced; a human re-runs templating to retry
      default: // 'pending' | 'scaffolding'
        if (_templating) return false;
        _templating = true;
        // ignore: avoid_print
        print(
          '[Templater] gate open → kicking off templating for project '
          '$projectId (status="${project.templateStatus}")',
        );
        unawaited(
          _runTemplatingPhase(project).whenComplete(() {
            _templating = false;
            if (!_disposed) unawaited(_pump());
          }),
        );
        return false;
    }
  }

  /// One-shot pre-task phase: split the backlog into topic-grouped milestones,
  /// then have the Coordinator scaffold a compiling base project + a stub for each
  /// task and commit it to main. Success → templateStatus `ready` (workers start);
  /// a hard failure → `failed` (gated, surfaced to the human).
  Future<void> _runTemplatingPhase(Project project) async {
    try {
      await _assignMilestones();
      await _db.setProjectTemplateStatus(projectId, 'scaffolding');
      // ignore: avoid_print
      print('[Templater] phase started (scaffolding) for project $projectId');
      final scaffolded = await _runTemplaterAgent(project);
      // ignore: avoid_print
      print('[Templater] scaffolder returned: $scaffolded');
      if (!scaffolded) {
        await _db.setProjectTemplateStatus(projectId, 'failed');
        debugPrint(
          '[Orchestrator p$projectId] templater could not scaffold; gated.',
        );
        return;
      }
      // Guarantee a deterministic CI gate exists so per-task review and the
      // end-of-project scan always have a fast, no-LLM build to run.
      await _ensureDefaultCiWorkflow(project);
      // The base CI gate is a BEST-EFFORT sanity check, NOT a blocker. A stub
      // scaffold legitimately can't pass `flutter test` yet (nothing is built),
      // and a slow/missing runner shouldn't strand the whole project before any
      // task starts. So run it for the log, but ALWAYS open the gate — the
      // end-of-project CI scan is the real test gate (the "test at the end"
      // design). Templating only ends in `failed` when the SCAFFOLD itself
      // couldn't be produced (handled above / in the catch).
      final ciOk = await _runBaseCiGate(project);
      await _db.setProjectTemplateStatus(projectId, 'ready');
      debugPrint(
        '[Orchestrator p$projectId] templating done → ready'
        '${ciOk ? '' : ' (base CI was red/unrunnable — proceeding; end-of-project scan is the real gate)'}.',
      );
    } catch (e, st) {
      debugPrint('[Orchestrator p$projectId] templating errored: $e\n$st');
      await _db.setProjectTemplateStatus(projectId, 'failed');
    }
  }

  /// Compute and persist each task's milestone batch (epic-aware, ceil(n/5)
  /// batches). Tasks under the same story epic stay together; the rest is split
  /// into roughly-even contiguous batches so no milestone runs too deep.
  Future<void> _assignMilestones() async {
    final tasks = await _db.getTasksForProject(projectId);
    if (tasks.isEmpty) {
      await _db.setProjectMilestonePlan(projectId, count: 0);
      return;
    }
    // Group key = each task's topmost story ancestor (its epic), so epic-mates
    // cluster. Tasks with no story are "loose" (null) and pack freely.
    final stories = await _db.getUserStoriesForProject(projectId);
    final parentOf = <int, int?>{
      for (final s in stories) s.story_pk: s.parent_story_fk,
    };
    int? epicOf(int? storyPk) {
      if (storyPk == null) return null;
      var cur = storyPk;
      final seen = <int>{};
      while (parentOf[cur] != null && seen.add(cur)) {
        cur = parentOf[cur]!;
      }
      return cur;
    }

    final items = [
      for (final t in tasks)
        MilestoneItem(
          id: t.task_pk,
          groupKey: epicOf(t.task_story_fk),
          order: t.createdAt.millisecondsSinceEpoch,
        ),
    ];
    final assignment = assignMilestones(items);
    for (final entry in assignment.entries) {
      await _db.setTaskMilestone(entry.key, entry.value);
    }
    await _db.setProjectMilestonePlan(
      projectId,
      count: milestoneBatchCount(tasks.length),
    );
    debugPrint(
      '[Orchestrator p$projectId] milestones: ${tasks.length} tasks → '
      '${milestoneBatchCount(tasks.length)} batch(es).',
    );
  }

  /// Drive a coding persona once to scaffold the base project onto main.
  /// Returns true when main has a commit (the scaffold landed).
  Future<bool> _runTemplaterAgent(Project project) async {
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    final git = handles.git;
    if (ws == null || git == null) {
      // ignore: avoid_print
      print('[Templater] workspace/git unavailable — cannot scaffold.');
      return false;
    }

    var tasks = await _db.getTasksForProject(projectId)
      ..sort((a, b) {
        final byMilestone = (a.milestoneOrder ?? 0).compareTo(
          b.milestoneOrder ?? 0,
        );
        if (byMilestone != 0) return byMilestone;
        return a.task_pk.compareTo(b.task_pk);
      });
    final stackKind = await _detectStackKind();
    if (stackKind == 'flutter') {
      tasks = await _organizeFlutterTasks(tasks);
    }

    // Scaffold onto main so every task branch (created off it) inherits the base.
    try {
      await git.checkoutBranch('main');
    } catch (_) {
      // No main yet — the scaffolder's first commit creates it.
    }
    // RETRY-SAFE: if main already carries a real scaffold (e.g. this is a retry
    // after a later step failed), don't re-run the agent — it would create no new
    // commit (the files exist) and look like a failure. Reuse the scaffold and
    // let the caller proceed (re-run the CI gate, etc.).
    final existingHead = await git.headOid();
    final existing = await _inspectScaffold(ws, tasks);
    final existingFiles = existing.fileCount;
    if (existingHead != null && existing.valid) {
      // ignore: avoid_print
      print(
        '[Templater] scaffold already present (head=$existingHead, '
        '$existingFiles file(s)) — skipping re-scaffold.',
      );
      return true;
    }
    // RETRY after an interrupted run: the agent had written a scaffold but a 502
    // burst killed it before git_commit (head still unborn, files on disk). Don't
    // redo the whole thing — commit what's there and accept.
    if (existingHead == null && existing.valid) {
      try {
        await ref
            .read(gitLaneProvider(projectId))
            .run(
              () => git.commitAll(message: 'chore: scaffold base project'),
              timeout: _laneOpTimeout,
            );
        if ((await git.headOid()) != null) {
          // ignore: avoid_print
          print(
            '[Templater] committed $existingFiles uncommitted scaffold '
            'file(s) from a prior run — scaffold accepted.',
          );
          ref.read(workspaceRevisionProvider(projectId).notifier).state++;
          return true;
        }
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] templater retry-salvage failed: $e',
        );
      }
    }
    // A pre-existing main commit must NOT let the templater "succeed" without
    // doing work, so we only count it scaffolded once a NEW commit lands.
    final beforeHead = await git.headOid();

    // Known application stacks do not need a model to invent their base file
    // layout. Generate the Flutter handoff directly from the accepted project
    // tags and task records. This makes the Templater useful even when a routed
    // model refuses tools or supplies host-machine paths instead of workspace
    // paths, and gives every future worker one explicit file to own.
    if (stackKind == 'flutter') {
      return _writeDeterministicFlutterTemplate(
        project: project,
        tasks: tasks,
        ws: ws,
        git: git,
        beforeHead: beforeHead,
      );
    }

    // Unknown stacks still use a coding persona to choose their initial
    // structure. Prefer a generalist worker and fall back to the Coordinator.
    final persona =
        await _findPersonaForRole(AgentRole.sdeGeneralist) ??
        await _findPersonaForRole(AgentRole.coordinator);
    if (persona == null) {
      // ignore: avoid_print
      print(
        '[Templater] NO generalist/Coordinator persona — cannot scaffold (failed/gated).',
      );
      return false;
    }
    final resolved = await _resolveBackend(persona);
    if (resolved == null) {
      // ignore: avoid_print
      print(
        '[Templater] no inference backend for ${persona.name} — cannot scaffold.',
      );
      return false;
    }
    // ignore: avoid_print
    print(
      '[Templater] running scaffolder agent "${persona.name}" on main '
      '(beforeHead=${beforeHead ?? "unborn"}).',
    );

    final taskList = tasks
        .map((t) {
          final description = (t.description ?? '').trim();
          final acceptance = (t.acceptanceCriteria ?? '').trim();
          return StringBuffer()
            ..writeln(
              '- Milestone ${(t.milestoneOrder ?? 0) + 1}, task #${t.task_pk}: '
              '${t.title}',
            )
            ..writeln(
              '  Description: ${description.isEmpty ? '(none supplied)' : description}',
            )
            ..write(
              '  Acceptance: ${acceptance.isEmpty ? '(none supplied)' : acceptance}',
            );
        })
        .join('\n');
    final baseSpec = await _buildTemplaterBaseSpec();
    final prompts = await _loadPrompts();
    final vars = PromptVars(
      taskId: 0,
      title: project.name,
      branch: 'main',
      taskList: taskList,
      baseSpec: baseSpec,
    );

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
      workspace: ws,
      git: git,
      buildService: handles.build,
      leanTools: false,
      // Scaffold-only toolset: file/git/CI only — no image/story/task tools, so
      // the scaffolder can't wander off (e.g. into image generation).
      scaffoldMode: true,
      // A normal Coordinator prompt says it integrates existing branches and
      // does not write code, which directly contradicts this one-off job. Give
      // the phase a dedicated identity while retaining the authoritative stack
      // baseline and the user-editable templater instructions.
      systemPromptOverride: await _templaterPrompt(prompts, vars),
      reasoningEffort: personaReasoningEffort(persona.configJson),
      enableThinking: resolveEnableThinking(
        agent: personaThinkingMode(
          persona.configJson,
          personaName: persona.name,
        ),
        task: ThinkingMode.off,
      ),
    );

    var kickoff =
        'Your FIRST action must be write_file with path "/WORK_TEMPLATE.md". '
        'In that file, list every task by its #id and milestone, its dependencies, '
        'and the shared versus task-owned files it should use. Then create the '
        'manifest, entry point, .gitignore, contracts and task starting files, '
        'then stop; the app validates and commits the finished scaffold.\n\n'
        '${prompts.render(OrchestratorPromptField.templaterKickoff, vars)}';
    const maxTransientRetries = 10;
    var transientRetries = 0;
    // Manual turn counter so a TRANSIENT failure (502/stall/backpressure) can
    // retry WITHOUT burning a real turn — a burst of 502s used to exhaust the
    // turn cap and fail the scaffold even though the files were being written.
    var turn = 0;
    while (turn < _maxTurnsPerStage && !_disposed) {
      if (!await _stillRunning()) return false;
      var toolCalls = 0;
      var transient = false;
      try {
        await _drainTurn(
          session.runTurn(
            kickoff,
            onToolResult: (r) {
              toolCalls++;
              // ignore: avoid_print
              print(
                '[Templater] tool#$toolCalls: '
                '${r.length > 140 ? "${r.substring(0, 140)}…" : r}',
              );
            },
          ),
          activity: session.turnActivity,
        );
      } catch (e) {
        if (e is! TimeoutException && !_isNotTaskFault(e)) {
          debugPrint(
            '[Orchestrator p$projectId] templater turn $turn failed: $e',
          );
          break; // fall through to the salvage commit below
        }
        transient = true; // 502 / stall / backpressure
        // Surface the REAL cause (was swallowed) — e.g. connection closed vs a
        // 5xx vs a stall — so a "transient" that never bills tokens can be told
        // apart from a genuine backend hiccup.
        // ignore: avoid_print
        print('[Templater] transient cause: ${e.runtimeType}: $e');
      }
      if (transient) {
        transientRetries++;
        if (transientRetries > maxTransientRetries) break;
        // ignore: avoid_print
        print(
          '[Templater] transient error (retry $transientRetries/'
          '$maxTransientRetries) — not burning a turn.',
        );
        await Future<void>.delayed(const Duration(seconds: 4));
        continue; // retry same turn without incrementing
      }
      transientRetries = 0;
      var head = await git.headOid();
      final scaffold = await _inspectScaffold(ws, tasks);
      final wsFiles = scaffold.fileCount;
      // ignore: avoid_print
      print(
        '[Templater] turn $turn: $toolCalls tool call(s); '
        'workspace has $wsFiles file(s); head=${head ?? "unborn"} '
        '(beforeHead=${beforeHead ?? "unborn"}).',
      );
      if (scaffold.valid && head == beforeHead) {
        try {
          await ref
              .read(gitLaneProvider(projectId))
              .run(
                () => git.commitAll(message: 'chore: scaffold base project'),
                timeout: _laneOpTimeout,
              );
          head = await git.headOid();
        } catch (e) {
          debugPrint(
            '[Orchestrator p$projectId] validated scaffold commit failed: $e',
          );
        }
      }
      if (head != beforeHead && scaffold.valid) {
        // ignore: avoid_print
        print('[Templater] NEW commit + $wsFiles file(s) — scaffold accepted.');
        ref.read(workspaceRevisionProvider(projectId).notifier).state++;
        return true;
      }
      kickoff =
          'The scaffold is NOT ready. Missing or invalid: '
          '${scaffold.missing.join(", ")}. Use write_file now to complete the '
          'WORK_TEMPLATE, manifest, entry point, .gitignore, shared contracts '
          'and task-owned starting files. The app commits once validation passes; '
          'a prose answer does not count.';
      turn++;
    }
    // SALVAGE: the agent wrote a scaffold but never committed it (common when a
    // 502 burst interrupts before git_commit). Don't throw the work away — commit
    // the workspace ourselves and accept it. A stub scaffold is a valid base; the
    // base CI gate is non-blocking and the end-of-project scan is the real gate.
    final leftoverState = await _inspectScaffold(ws, tasks);
    final leftover = leftoverState.fileCount;
    if (leftoverState.valid && (await git.headOid()) == beforeHead) {
      try {
        await ref
            .read(gitLaneProvider(projectId))
            .run(
              () => git.commitAll(message: 'chore: scaffold base project'),
              timeout: _laneOpTimeout,
            );
        if ((await git.headOid()) != beforeHead) {
          // ignore: avoid_print
          print(
            '[Templater] salvaged $leftover uncommitted file(s) with a safety '
            'commit — scaffold accepted.',
          );
          ref.read(workspaceRevisionProvider(projectId).notifier).state++;
          return true;
        }
      } catch (e) {
        debugPrint(
          '[Orchestrator p$projectId] templater salvage commit failed: $e',
        );
      }
    }
    // ignore: avoid_print
    print('[Templater] hit turn cap without a real scaffold — FAILED.');
    return false;
  }

  /// Put foundation work before feature composition, then persist the order as
  /// milestone batches. The original task-generation order reflects story
  /// insertion order, which can place physics after the game loop that needs it.
  Future<List<Task>> _organizeFlutterTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return tasks;
    final ordered = [...tasks]
      ..sort((a, b) {
        final byFoundation = _flutterTaskRank(a).compareTo(_flutterTaskRank(b));
        if (byFoundation != 0) return byFoundation;
        return a.task_pk.compareTo(b.task_pk);
      });
    // Preserve dependency layers without turning every topic into a serial
    // milestone. Independent foundations and sibling feature/UI work share a
    // rank and can use separate worker slots; composition still waits for its
    // inputs to settle.
    final ranks = ordered.map(_flutterTaskRank).toSet().toList()..sort();
    final milestoneByRank = <int, int>{
      for (var index = 0; index < ranks.length; index++) ranks[index]: index,
    };
    final batchCount = ranks.length;
    for (var index = 0; index < ordered.length; index++) {
      final milestone = milestoneByRank[_flutterTaskRank(ordered[index])]!;
      if (ordered[index].milestoneOrder != milestone) {
        await _db.setTaskMilestone(ordered[index].task_pk, milestone);
      }
    }
    await _db.setProjectMilestonePlan(projectId, count: batchCount);

    // ignore: avoid_print
    print(
      '[Templater] Flutter build batches: '
      '${ranks.map((rank) => ordered.where((task) => _flutterTaskRank(task) == rank).map((task) => "#${task.task_pk}").join(" + ")).join(" → ")}',
    );

    final refreshed = await _db.getTasksForProject(projectId);
    refreshed.sort((a, b) {
      final byMilestone = (a.milestoneOrder ?? 0).compareTo(
        b.milestoneOrder ?? 0,
      );
      if (byMilestone != 0) return byMilestone;
      final byFoundation = _flutterTaskRank(a).compareTo(_flutterTaskRank(b));
      if (byFoundation != 0) return byFoundation;
      return a.task_pk.compareTo(b.task_pk);
    });
    return refreshed;
  }

  static int _flutterTaskRank(Task task) {
    // Use the title as the task's declared responsibility. Descriptions often
    // mention later UI concepts (for example a core task mentioning menus),
    // which would otherwise distort the dependency order.
    return flutterTaskDependencyRankForTitle(task.title);
  }

  /// Write a stable Flutter project skeleton and its worker handoff without an
  /// inference round. Each task owns one feature directory; shared entry points
  /// and contracts are created once and treated as integration-owned files.
  Future<bool> _writeDeterministicFlutterTemplate({
    required Project project,
    required List<Task> tasks,
    required Workspace ws,
    required NxtprjGitEngine git,
    required String? beforeHead,
  }) async {
    final packageName = _dartIdentifier(
      project.name,
      fallback: 'nexus_project',
    );
    final ownedDirs = <int, String>{};
    final pageFiles = <int, String>{};
    final classNames = <int, String>{};
    for (final task in tasks) {
      final slug = _dartIdentifier(task.title, fallback: 'feature');
      final ownedDir = 'lib/features/task_${task.task_pk}_$slug';
      ownedDirs[task.task_pk] = ownedDir;
      pageFiles[task.task_pk] = '$ownedDir/${slug}_page.dart';
      classNames[task.task_pk] = _dartClassName(task.title, task.task_pk);
    }

    final template = StringBuffer()
      ..writeln('# Work template: ${project.name}')
      ..writeln()
      ..writeln('This file is the handoff for task workers and coordinators. ')
      ..writeln('Implement milestones in the order below. Tasks in the same ')
      ..writeln('milestone may run in parallel. A task owns its listed ')
      ..writeln('feature directory; do not create a second copy elsewhere.')
      ..writeln()
      ..writeln('## Shared files (integration-owned)')
      ..writeln()
      ..writeln('- `/lib/main.dart`: application bootstrapping only')
      ..writeln('- `/lib/app_routes.dart`: the single route registry')
      ..writeln('- `/lib/core/game_contracts.dart`: shared game vocabulary')
      ..writeln('- `/web/index.html`: shared web bootstrap')
      ..writeln('- `/pubspec.yaml`: the single dependency manifest')
      ..writeln()
      ..writeln(
        'Workers consume these shared files. Extend behavior inside the ',
      )
      ..writeln('task-owned directory and leave cross-task integration to the ')
      ..writeln(
        'coordinator, preventing duplicate models, routes, and services.',
      )
      ..writeln()
      ..writeln('## Build order');

    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final milestone = (task.milestoneOrder ?? 0) + 1;
      final prior = tasks
          .where(
            (candidate) => (candidate.milestoneOrder ?? 0) == milestone - 2,
          )
          .map((candidate) => '#${candidate.task_pk}')
          .toList();
      final dependencies = prior.isEmpty
          ? 'none (foundation task)'
          : prior.join(', ');
      final description = (task.description ?? '').trim();
      final acceptance = (task.acceptanceCriteria ?? '').trim();
      template
        ..writeln()
        ..writeln('### ${index + 1}. Task #${task.task_pk}: ${task.title}')
        ..writeln()
        ..writeln('- Milestone: $milestone')
        ..writeln('- Depends on: $dependencies')
        ..writeln('- Owns: `/${ownedDirs[task.task_pk]}`')
        ..writeln('- Starter: `/${pageFiles[task.task_pk]}`')
        ..writeln('- Uses: `/lib/core/game_contracts.dart`')
        ..writeln(
          '- Goal: ${description.isEmpty ? 'Implement the named feature.' : description.replaceAll('\n', ' ')}',
        )
        ..writeln(
          '- Acceptance: ${acceptance.isEmpty ? 'Derive focused tests from the goal before submission.' : acceptance.replaceAll('\n', ' ')}',
        );
    }

    final imports = tasks
        .map((task) => "import '${pageFiles[task.task_pk]!.substring(4)}';")
        .join('\n');
    final routes = tasks
        .map((task) {
          final slug = _dartIdentifier(task.title, fallback: 'feature');
          return "  '/task-${task.task_pk}-$slug': (_) => "
              '${classNames[task.task_pk]}(),';
        })
        .join('\n');

    final writes = <String, String>{
      '/WORK_TEMPLATE.md': template.toString(),
      '/pubspec.yaml': '''name: $packageName
description: Scaffold generated from the Nexus project work template.
publish_to: none
version: 0.1.0+1
environment:
  sdk: ^3.11.5
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.2
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
flutter:
  uses-material-design: true
''',
      '/.gitignore': '''.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
coverage/
*.iml
.idea/
.vscode/
''',
      '/analysis_options.yaml': '''include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - build/**
''',
      '/web/index.html':
          '''<!DOCTYPE html>
<html>
<head>
  <base href="\$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="${_dartLiteral(project.name)}">
  <title>${project.name}</title>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''',
      '/lib/core/game_contracts.dart':
          '''enum DifficultyTier { easy, medium, hard }

enum LevelPack { classic, variants }

class GameSessionState {
  const GameSessionState({
    this.score = 0,
    this.isRunning = false,
    this.isGameOver = false,
  });

  final int score;
  final bool isRunning;
  final bool isGameOver;
}
''',
      '/lib/app_routes.dart':
          '''import 'package:flutter/widgets.dart';

$imports

final Map<String, WidgetBuilder> appRoutes = {
$routes
};
''',
      '/lib/main.dart':
          '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_routes.dart';

void main() {
  runApp(const ProviderScope(child: GeneratedApp()));
}

class GeneratedApp extends StatelessWidget {
  const GeneratedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${_dartLiteral(project.name)}',
      routes: appRoutes,
      home: const TemplateHome(),
    );
  }
}

class TemplateHome extends StatelessWidget {
  const TemplateHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${_dartLiteral(project.name)}')),
      body: ListView(
        children: [
          for (final route in appRoutes.keys)
            ListTile(
              title: Text(route),
              onTap: () => Navigator.of(context).pushNamed(route),
            ),
        ],
      ),
    );
  }
}
''',
      '/test/widget_test.dart':
          '''import 'package:flutter_test/flutter_test.dart';
import 'package:$packageName/main.dart';

void main() {
  testWidgets('generated project shell loads', (tester) async {
    await tester.pumpWidget(const GeneratedApp());
    expect(find.text('${_dartLiteral(project.name)}'), findsOneWidget);
  });
}
''',
    };

    for (final task in tasks) {
      final className = classNames[task.task_pk]!;
      final title = _dartLiteral(task.title);
      writes['/${pageFiles[task.task_pk]}'] =
          '''import 'package:flutter/material.dart';

class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Task #${task.task_pk}: $title')),
    );
  }
}

// TODO(task #${task.task_pk}): Replace this starting page with the task implementation.
''';
    }

    // ignore: avoid_print
    print(
      '[Templater] writing deterministic Flutter work template for '
      '${tasks.length} task(s).',
    );
    for (final entry in writes.entries) {
      await ws.writeString(entry.key, entry.value);
    }

    final scaffold = await _inspectScaffold(ws, tasks);
    if (!scaffold.valid) {
      // ignore: avoid_print
      print('[Templater] deterministic scaffold invalid: ${scaffold.missing}');
      return false;
    }
    try {
      await ref
          .read(gitLaneProvider(projectId))
          .run(
            () => git.commitAll(message: 'chore: scaffold base project'),
            timeout: _laneOpTimeout,
          );
      final head = await git.headOid();
      if (head != beforeHead) {
        // ignore: avoid_print
        print(
          '[Templater] deterministic Flutter scaffold committed: '
          '${scaffold.fileCount} file(s), head=$head.',
        );
        ref.read(workspaceRevisionProvider(projectId).notifier).state++;
        return true;
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] deterministic scaffold commit failed: $e',
      );
    }
    return false;
  }

  static String _dartIdentifier(String value, {required String fallback}) {
    var result = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (result.isEmpty) result = fallback;
    if (RegExp(r'^[0-9]').hasMatch(result)) result = '${fallback}_$result';
    return result;
  }

  static String _dartClassName(String value, int taskPk) {
    final words = value
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((word) => word.isNotEmpty);
    var stem = words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join();
    if (stem.isEmpty || RegExp(r'^[0-9]').hasMatch(stem)) stem = 'Feature$stem';
    return '${stem}Task${taskPk}Page';
  }

  static String _dartLiteral(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ');

  Future<String> _templaterPrompt(
    OrchestratorPrompts prompts,
    PromptVars vars,
  ) async {
    final baseline = await buildProjectBaseline(_db, projectId);
    return '''$baseline

You are the Templater. This is a one-time planning and scaffolding phase before
feature workers start. Establish the implementation order, shared contracts,
shared file ownership, and task-specific starting files so later workers build
on one coherent structure without duplicating or overwriting each other's work.
Your first deliverable is /WORK_TEMPLATE.md. It must mention every task by #id
and record its milestone, dependencies, primary files, and any shared contract
it consumes or owns. This is the handoff future workers use to stay in lane.
Use the provided file and git tools immediately. A prose plan does not change
the workspace and does not count as progress.

${prompts.render(OrchestratorPromptField.templaterFraming, vars)}

FINAL EXECUTION RULE: write the files with write_file. Do not inspect host paths
and do not manage Git; the workspace begins empty and the app validates and
commits the scaffold after all required artifacts exist.''';
  }

  /// A templater commit is useful only when it leaves a concrete handoff and a
  /// runnable project shape. Counting "one file + one commit" accepted malformed
  /// model output as a scaffold, so validate the artifacts that future workers
  /// actually depend on.
  Future<({bool valid, int fileCount, List<String> missing})> _inspectScaffold(
    Workspace ws,
    List<Task> tasks,
  ) async {
    final entries = (await ws.walk()).where((f) => !f.isDirectory).toList();
    final paths = [
      for (final entry in entries) entry.path.replaceAll('\\', '/'),
    ];
    final lower = paths.map((p) => p.toLowerCase()).toList();
    bool hasName(String name) =>
        lower.any((p) => p == name || p.endsWith('/$name'));

    final hasManifest = lower.any((p) {
      final name = p.split('/').last;
      return const {
            'pubspec.yaml',
            'package.json',
            'pyproject.toml',
            'requirements.txt',
            'cargo.toml',
            'go.mod',
            'cmakelists.txt',
            'pom.xml',
            'build.gradle',
            'build.gradle.kts',
            'package.swift',
            'gemfile',
            'composer.json',
          }.contains(name) ||
          name.endsWith('.csproj');
    });
    final hasEntryPoint = lower.any((p) {
      final name = p.split('/').last;
      return const {
        'main.dart',
        'main.py',
        'main.go',
        'main.rs',
        'main.c',
        'main.cpp',
        'main.ts',
        'main.js',
        'main.java',
        'index.ts',
        'index.js',
        'app.py',
        'program.cs',
      }.contains(name);
    });

    String workTemplate = '';
    final workTemplateIndex = lower.indexWhere(
      (p) => p == 'work_template.md' || p.endsWith('/work_template.md'),
    );
    if (workTemplateIndex >= 0) {
      try {
        workTemplate = await ws.readString(paths[workTemplateIndex]);
      } catch (_) {}
    }
    final coversTasks = tasks.every(
      (task) => workTemplate.contains('#${task.task_pk}'),
    );
    final targetFileCount = tasks.length < 9 ? tasks.length + 3 : 12;

    final missing = <String>[
      if (workTemplateIndex < 0) 'WORK_TEMPLATE.md',
      if (workTemplateIndex >= 0 && !coversTasks)
        'all task #ids in WORK_TEMPLATE',
      if (!hasManifest) 'project manifest',
      if (!hasEntryPoint) 'main entry point',
      if (!hasName('.gitignore')) '.gitignore',
      if (entries.length < targetFileCount)
        'task/contract starting files (${entries.length}/$targetFileCount)',
    ];
    return (
      valid: missing.isEmpty,
      fileCount: entries.length,
      missing: missing,
    );
  }

  /// The Templater's base spec: the condensed top-of-tree story (a whole-project
  /// overview the scaffold is built from) plus a database-schema instruction when
  /// the project's stack includes a database. Empty when neither applies.
  Future<String> _buildTemplaterBaseSpec() async {
    final buf = StringBuffer();
    try {
      final stories = await _db.getUserStoriesForProject(projectId);
      final roots = stories.where((s) => s.parent_story_fk == null).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      if (roots.isNotEmpty) {
        final root = roots.first;
        buf.writeln(
          'PROJECT OVERVIEW (the top of the story tree — a condensed view of the '
          'WHOLE project; scaffold the base so it fits this end to end):',
        );
        buf.writeln('- ${root.title}');
        final narrative = root.narrative.trim();
        if (narrative.isNotEmpty) buf.writeln('  $narrative');
        final ac = (root.acceptanceCriteria ?? '').trim();
        if (ac.isNotEmpty) buf.writeln('  Acceptance: $ac');
      }
      // Database in the stack → seed a consistent starter schema in the base so
      // every later task shares one data model.
      final tags = await _db.getTagsForProject(projectId);
      final hasDb = tags.any(
        (t) => t.category == 'databases' && t.status != 'rejected',
      );
      if (hasDb) {
        if (buf.isNotEmpty) buf.writeln();
        buf.writeln(
          'DATABASE: this project uses a database (see the BASELINE). Create a '
          'basic STARTER SCHEMA — the core tables/entities the overview implies — '
          'as a real migration/schema file for the chosen DB, so every task '
          'builds on one consistent data model. Keep it minimal but coherent.',
        );
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] templater base-spec build failed: $e',
      );
    }
    return buf.toString().trim();
  }

  /// Run the project's CI once against main as the base gate: the first
  /// task-configured workflow/dockerfile, else the default CI workflow scaffolded
  /// by [_ensureDefaultCiWorkflow]. Returns true on green / nothing-to-run, false
  /// on a red run (infra-down does NOT block templating).
  Future<bool> _runBaseCiGate(Project project) async {
    final tasks = await _db.getTasksForProject(projectId);
    String? workflowPath;
    String? dockerfilePath;
    for (final t in tasks) {
      final wf = t.workflowPath?.trim() ?? '';
      final df = t.dockerfilePath?.trim() ?? '';
      if (wf.isNotEmpty || df.isNotEmpty) {
        workflowPath = wf.isNotEmpty ? wf : null;
        dockerfilePath = df.isNotEmpty ? df : null;
        break;
      }
    }
    if (workflowPath == null && dockerfilePath == null) {
      // Fall back to the default CI workflow if one was scaffolded.
      final ws = (await _resolveWorkspaceHandles()).ws;
      if (ws != null && await ws.exists(_defaultCiPath)) {
        workflowPath = _defaultCiPath;
      } else {
        return true; // nothing to run → the compiling scaffold is the bar
      }
    }
    final outcome = await _runWorkflowGate(
      clientPk: project.client_fk,
      branch: 'main',
      workflowPath: workflowPath,
      dockerfilePath: dockerfilePath,
      imageTag: 'base:latest',
      triggeredBy: 'templater',
    );
    return outcome?.passed ??
        true; // infra unavailable → don't block templating
  }

  /// Runtime-lib import marker → the dev-dependency that GENERATES its code. A
  /// project using any of these needs the generator AND `build_runner`, or its
  /// `.g.dart`/`.freezed.dart` can never be produced (workers hand-fake them →
  /// hundreds of type-mismatch errors).
  static const Map<String, String> _codegenGenerators = {
    'package:drift/': 'drift_dev',
    'package:freezed_annotation': 'freezed',
    'package:json_annotation': 'json_serializable',
    'package:riverpod_annotation': 'riverpod_generator',
    'package:retrofit/': 'retrofit_generator',
  };

  /// Ensure the CODE-GENERATION toolchain is present in pubspec when the source
  /// ACTUALLY uses it. Detect usage from the app's `.dart` source (generator
  /// imports + `part '…g.dart'` directives), and add any missing generator +
  /// `build_runner` to dev_dependencies (as `any`, so `pub get` resolves a
  /// compatible version), then commit. Flutter/dart only; no-op otherwise.
  Future<void> _ensureCodegenDeps(Project project) async {
    try {
      final kind = await _detectStackKind();
      if (kind != 'flutter' && kind != 'dart') return;
      final handles = await _resolveWorkspaceHandles();
      final ws = handles.ws;
      final git = handles.git;
      if (ws == null || git == null) return;
      final info = await _appManifestInfo(ws);
      final pubPath = info.subdir.isEmpty
          ? '/pubspec.yaml'
          : '/${info.subdir}/pubspec.yaml';
      if (!await ws.exists(pubPath)) return;
      var pubspec = await ws.readString(pubPath);

      final libPrefix = info.subdir.isEmpty ? '/lib/' : '/${info.subdir}/lib/';
      final used = <String>{};
      var sawGenPart = false;
      final partRe = RegExp(r"""part\s+'[^']*\.(g|freezed)\.dart'""");
      for (final f in await ws.walk()) {
        if (f.isDirectory) continue;
        final p = f.path;
        if (!p.startsWith(libPrefix) || !p.endsWith('.dart')) continue;
        if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) continue;
        String content;
        try {
          content = await ws.readString(p);
        } catch (_) {
          continue;
        }
        for (final e in _codegenGenerators.entries) {
          if (content.contains(e.key)) used.add(e.value);
        }
        if (!sawGenPart && partRe.hasMatch(content)) sawGenPart = true;
      }
      if (used.isEmpty && !sawGenPart) return; // no code generation in use

      final needed = <String>{'build_runner', ...used};
      final missing = needed
          .where((d) => !RegExp('(^|\\n)\\s*$d\\s*:').hasMatch(pubspec))
          .toList();
      if (missing.isEmpty) return;

      pubspec = _addDevDependencies(pubspec, missing);
      final lane = ref.read(gitLaneProvider(projectId));
      await lane.run(() async {
        try {
          await git.checkoutBranch('main');
        } catch (_) {}
        await ws.writeString(pubPath, pubspec);
        await git.commitAll(
          message: 'deps: add codegen toolchain (${missing.join(", ")})',
        );
      }, timeout: _laneOpTimeout);
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      debugPrint(
        '[Orchestrator p$projectId] added codegen dev-deps: ${missing.join(", ")}.',
      );
    } catch (e) {
      debugPrint('[Orchestrator p$projectId] ensure codegen deps failed: $e');
    }
  }

  /// Append [deps] (each as `name: any`) under `dev_dependencies:`, creating that
  /// section if it doesn't exist.
  static String _addDevDependencies(String pubspec, List<String> deps) {
    final add = deps.map((d) => '  $d: any').join('\n');
    final lines = pubspec.split('\n');
    final idx = lines.indexWhere(
      (l) => RegExp(r'^dev_dependencies:\s*$').hasMatch(l),
    );
    if (idx < 0) {
      return '${pubspec.trimRight()}\n\ndev_dependencies:\n$add\n';
    }
    lines.insert(idx + 1, add);
    return lines.join('\n');
  }

  /// Guarantee the project has ONE deterministic CI workflow at [_defaultCiPath]
  /// on main, so per-task review and the end-of-project scan always have a fast,
  /// no-LLM gate to run. Idempotent (no-op if the Templater already wrote one).
  /// Written + committed deterministically — no agent — so it can't be skipped or
  /// hallucinated.
  Future<void> _ensureDefaultCiWorkflow(Project project) async {
    try {
      final handles = await _resolveWorkspaceHandles();
      final ws = handles.ws;
      final git = handles.git;
      if (ws == null || git == null) return;
      final kind = await _detectStackKind();
      // For flutter/dart, find the app subdir + whether it uses code generation.
      final info = (kind == 'flutter' || kind == 'dart')
          ? await _appManifestInfo(ws)
          : (subdir: '', codegen: false);

      // Guarantee `flutter test` / `dart test` has at least one test to run.
      // With no `test/` dir those commands FAIL hard ("Test directory 'test' not
      // found"), so a project with no feature tests yet can never go green and
      // the CI gate loops forever. A trivial always-passing smoke test fixes it
      // deterministically and shell-agnostically (CI steps run under cmd on
      // Windows / bash on CI, so a `[ -d test ]` guard in the YAML isn't
      // portable). Real tests from the Testing phase live alongside it. Runs
      // even when the CI YAML already exists (below), so it isn't skipped by the
      // early-return. flutter_test (SDK) / test (dev-dep) are always present when
      // the corresponding `*  test` step runs.
      if (kind == 'flutter' || kind == 'dart') {
        final sub = info.subdir.trim();
        final testPath =
            '${sub.isEmpty ? '' : '/$sub'}/test/nxs_smoke_test.dart';
        if (!await ws.exists(testPath)) {
          final pkg = kind == 'flutter' ? 'flutter_test' : 'test';
          final content =
              '// Auto-added so `$kind test` always has a test to run — CI\'s test\n'
              '// step must not fail merely because no feature tests exist yet.\n'
              "import 'package:$pkg/$pkg.dart';\n\n"
              'void main() {\n'
              "  test('smoke — the test harness runs', () {\n"
              '    expect(true, isTrue);\n'
              '  });\n'
              '}\n';
          final lane = ref.read(gitLaneProvider(projectId));
          await lane.run(() async {
            try {
              await git.checkoutBranch('main');
            } catch (_) {}
            await ws.writeString(testPath, content);
            await git.commitAll(
              message: 'ci: add smoke test so the test step passes',
            );
          }, timeout: _laneOpTimeout);
          ref.read(workspaceRevisionProvider(projectId).notifier).state++;
          debugPrint(
            '[Orchestrator p$projectId] wrote smoke test at $testPath.',
          );
        }
      }

      final existing = await ws.exists(_defaultCiPath)
          ? await ws.readString(_defaultCiPath)
          : null;
      // UPGRADE an existing gate that predates codegen support: a codegen project
      // whose CI never runs build_runner analyzes STALE/absent generated
      // (`.g.dart`) files and reports hundreds of phantom errors for even a simple
      // app. Rewrite it to run build_runner before analyze. Otherwise leave an
      // existing gate untouched.
      final needsCodegen =
          existing != null &&
          info.codegen &&
          !existing.contains('build_runner');
      if (existing != null && !needsCodegen) return;
      final yaml = _defaultCiYaml(
        kind,
        subdir: info.subdir,
        codegen: info.codegen,
      );
      final lane = ref.read(gitLaneProvider(projectId));
      await lane.run(() async {
        try {
          await git.checkoutBranch('main');
        } catch (_) {
          // Unborn main — the scaffolder's commit will have created it by now;
          // if not, commitAll roots the first commit.
        }
        await ws.writeString(_defaultCiPath, yaml);
        await git.commitAll(
          message: needsCodegen
              ? 'ci: run build_runner (codegen) before analyze'
              : 'ci: add default $kind CI gate',
        );
      }, timeout: _laneOpTimeout);
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      debugPrint(
        '[Orchestrator p$projectId] ${needsCodegen ? "upgraded" : "wrote"} CI gate '
        '($kind${info.codegen ? "+codegen" : ""}'
        '${info.subdir.isNotEmpty ? ", subdir=${info.subdir}" : ""}) at $_defaultCiPath.',
      );
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] could not ensure default CI gate: $e',
      );
    }
  }

  /// Pick the CI workflow flavor from the project's chosen stack (tags). Drives
  /// which `run:` steps the local runner executes for the compile/analyze gate.
  Future<String> _detectStackKind() async {
    try {
      final tags = await _db.getTagsForProject(projectId);
      final stack = tags
          .where((t) => t.status != 'rejected')
          .map((t) => '${t.category}:${t.value}'.toLowerCase())
          .join(' ');
      bool has(List<String> needles) => needles.any(stack.contains);
      if (has(['flutter'])) return 'flutter';
      if (has(['dart'])) return 'dart';
      if (has(['c#', 'csharp', '.net', 'dotnet', 'asp.net'])) return 'dotnet';
      if (has([
        'node',
        'javascript',
        'typescript',
        'react',
        'next',
        'vue',
        'angular',
        'express',
      ])) {
        return 'node';
      }
      if (has(['python', 'django', 'flask', 'fastapi'])) return 'python';
      if (has(['golang', ' go ', ':go'])) return 'go';
      if (has(['rust', 'cargo'])) return 'rust';
    } catch (_) {}
    return 'generic';
  }

  /// The default GitHub-Actions-format CI body for [kind]. The local runner runs
  /// `run:` steps as shell commands (`uses:` steps are recorded but skipped), so
  /// these are the conventional compile/analyze/test commands for each stack.
  static String _defaultCiYaml(
    String kind, {
    String subdir = '',
    bool codegen = false,
  }) {
    // `cd <subdir> && ` prefix for a nested app (pubspec/manifest not at the repo
    // root); empty at root.
    final pfx = subdir.trim().isEmpty ? '' : 'cd ${subdir.trim()} && ';
    // Code generation (drift/freezed/json_serializable/riverpod_generator, …) MUST
    // run before analyze — otherwise every reference to the stale/absent generated
    // `.g.dart` files errors, producing hundreds of phantom errors for even a
    // simple app. Only emitted when the project actually depends on build_runner
    // (else `dart run build_runner` would fail on projects that don't use it).
    // `--delete-conflicting-outputs` avoids the interactive prompt that would hang.
    final gen = codegen
        ? '      - run: ${pfx}dart run build_runner build --delete-conflicting-outputs\n'
        : '';
    // --no-fatal-infos: info-level lints (e.g. use_build_context_synchronously)
    // are advisory — don't fail the whole gate on a style hint (errors and
    // warnings still fail). The orchestrator's `_ciRedIsInfoOnly` is the belt-
    // and-suspenders equivalent for projects whose CI YAML predates this.
    final steps = switch (kind) {
      'flutter' =>
        '      - run: ${pfx}flutter pub get\n'
            '$gen'
            '      - run: ${pfx}flutter analyze --no-fatal-infos\n'
            '      - run: ${pfx}flutter test',
      'dart' =>
        '      - run: ${pfx}dart pub get\n'
            '$gen'
            '      - run: ${pfx}dart analyze\n'
            '      - run: ${pfx}dart test',
      'dotnet' =>
        '      - run: ${pfx}dotnet restore\n'
            '      - run: ${pfx}dotnet build --no-restore\n'
            '      - run: ${pfx}dotnet test --no-build',
      'node' =>
        '      - run: ${pfx}npm ci\n'
            '      - run: ${pfx}npm run build --if-present\n'
            '      - run: ${pfx}npm test --if-present',
      'python' =>
        '      - run: ${pfx}pip install -r requirements.txt\n'
            '      - run: ${pfx}python -m pytest',
      'go' =>
        '      - run: ${pfx}go build ./...\n'
            '      - run: ${pfx}go test ./...',
      'rust' =>
        '      - run: ${pfx}cargo build\n'
            '      - run: ${pfx}cargo test',
      _ => '      - run: echo "No build configured for this stack"',
    };
    return 'name: CI\n'
        'on: [push, pull_request]\n'
        'jobs:\n'
        '  build:\n'
        '    runs-on: ubuntu-latest\n'
        '    steps:\n'
        '$steps\n';
  }

  /// For a flutter/dart project, locate the app's pubspec (root or nested) →
  /// its [subdir] (relative dir, '' at root) and whether it uses code generation
  /// (depends on `build_runner`). Drives the CI gate's `cd <subdir>` prefix and
  /// whether it runs build_runner before analyze.
  Future<({String subdir, bool codegen})> _appManifestInfo(Workspace ws) async {
    try {
      String? bestRel;
      var bestDepth = 1 << 30;
      for (final f in await ws.walk()) {
        if (f.isDirectory) continue;
        final rel = f.path.startsWith('/') ? f.path.substring(1) : f.path;
        if (rel.split('/').last.toLowerCase() != 'pubspec.yaml') continue;
        final l = '/${rel.toLowerCase()}/';
        if (l.contains('/build/') || l.contains('/.dart_tool/')) continue;
        final depth = rel.contains('/')
            ? rel
                  .substring(0, rel.lastIndexOf('/'))
                  .split('/')
                  .where((s) => s.isNotEmpty)
                  .length
            : 0;
        if (depth < bestDepth) {
          bestDepth = depth;
          bestRel = rel;
        }
      }
      if (bestRel == null) return (subdir: '', codegen: false);
      final subdir = bestRel.contains('/')
          ? bestRel.substring(0, bestRel.lastIndexOf('/'))
          : '';
      var codegen = false;
      try {
        codegen = (await ws.readString('/$bestRel')).contains('build_runner');
      } catch (_) {}
      return (subdir: subdir, codegen: codegen);
    } catch (_) {
      return (subdir: '', codegen: false);
    }
  }

  /// Open the next milestone after every task in the current-or-earlier layers
  /// has reached a settled state. Done work supplies its implementation; Blocked
  /// work stays visibly unresolved but does not strand independent Todo work in
  /// later batches. Final project completion remains gated on clearing every
  /// Blocked task in [_maybeFinalizeProject]. Advances at most one batch per call.
  Future<bool> _maybeAdvanceMilestone(Project project) async {
    final count = project.milestoneCount;
    if (count <= 1) return false;
    final current = project.currentMilestone;
    if (current >= count - 1) return false;
    final tasks = await _db.getTasksForProject(projectId);
    final inScope = tasks.where((t) => (t.milestoneOrder ?? 0) <= current);
    if (inScope.isEmpty) return false;
    final batchSettled = !inScope.any(
      (t) => !taskStatusSettlesMilestone(t.status),
    );
    if (!batchSettled) return false;
    final next = await _db.advanceProjectMilestone(projectId);
    debugPrint(
      '[Orchestrator p$projectId] milestone $current → opening $next/${count - 1} '
      '(dependency layer settled).',
    );
    return true;
  }

  /// END-OF-PROJECT CI SCAN — the hard gate on "complete". Once the whole backlog
  /// is Done (final milestone, nothing open) we run the project's CI gate ONCE
  /// against main:
  ///   • GREEN → the project is genuinely complete; nothing to do.
  ///   • RED → reopen the most-recently-finished task with the FULL diagnostics
  ///     attached, so the failure is fixed before the project can be counted
  ///     complete (the board is no longer empty, so it isn't "done"). The task's
  ///     retry budget eventually surfaces it as Blocked if it can't be made green.
  /// Per-task review already gated each branch, but the post-merge integration on
  /// main can still surface issues no single branch saw — this is that net.
  /// Returns true when it spawned new assignable work (a fix-phase batch), so
  /// the caller can re-pump immediately to fill idle slots instead of waiting
  /// for the next tick.
  Future<bool> _maybeFinalizeProject(Project project) async {
    if (_testing) return false; // a TESTING phase is already running
    // Only when the project is on its last milestone batch.
    if (project.currentMilestone < project.milestoneCount - 1) return false;
    final tasks = await _db.getTasksForProject(projectId);
    if (tasks.isEmpty) return false;
    final open = tasks.where(
      (t) =>
          t.status == TaskStatus.todo ||
          t.status == TaskStatus.inProgress ||
          t.status == TaskStatus.review,
    );
    if (open.isNotEmpty)
      return false; // work still in flight — not finished yet
    // PRE-TEST RECOVERY: reaching the final boundary with Blocked work means the
    // first worker budget was exhausted. Give every such task one automatic fresh
    // budget before CI. This keeps the safety state useful without making normal
    // unattended runs depend on a human dragging cards back to Todo. The sweep is
    // deliberately once per orchestrator run; a task that blocks again remains
    // Blocked and final testing cannot claim the project passed.
    final blocked = tasks.where((t) => t.status == TaskStatus.blocked).toList();
    if (blocked.isNotEmpty) {
      if (!_blockedRecoverySweepDone) {
        _blockedRecoverySweepDone = true;
        final count = await _db.requeueBlockedTasks(projectId);
        for (final task in blocked) {
          _attempts.remove(task.task_pk);
          _reviewFailures.remove(task.task_pk);
          _parkedUntil.remove(task.task_pk);
        }
        debugPrint(
          '[Orchestrator p$projectId] PRE-TEST RECOVERY: requeued $count Blocked '
          'task(s) with fresh retry budgets before final CI.',
        );
        return count > 0;
      }
      return false;
    }
    final done = tasks.where((t) => t.status == TaskStatus.done).toList();
    if (done.isEmpty) return false; // nothing built — leave it
    // Skip if this exact completed state already passed (or exhausted) testing —
    // don't re-run the slow loop every tick on a settled project.
    final sig =
        '${done.length}:'
        '${done.map((t) => t.updatedAt.millisecondsSinceEpoch).fold<int>(0, (a, b) => a > b ? a : b)}';
    if (sig == _finalScanPassedSig || sig == _testingExhaustedSig) return false;
    // Need a gate to scan against; if none exists there's nothing to enforce.
    final ws = (await _resolveWorkspaceHandles()).ws;
    if (ws == null || !await ws.exists(_defaultCiPath)) return false;

    // FAST LANE: an Editor session (state == 'editing') finalizes LIGHT — no
    // linking pass, no double-check feature scan. Just confirm the edit still
    // builds and flip back to 'completed'. Everything else uses the full Testing
    // phase (linking → CI convergence → double-check).
    if (project.orchestrationState == 'editing') {
      _testing = true;
      unawaited(
        _runEditorFinalize(project, sig).whenComplete(() {
          _testing = false;
          if (!_disposed) unawaited(_pump());
        }),
      );
      return false;
    }

    // Enter the dedicated TESTING phase (mirrors the templating gate): run it in
    // the background and re-pump when it lands, so the pump never blocks on the
    // slow scan/fix loop.
    _testing = true;
    unawaited(
      _runTestingPhase(project, sig).whenComplete(() {
        _testing = false;
        if (!_disposed) unawaited(_pump());
      }),
    );
    return false;
  }

  /// The Editor fast-lane finalize. Skips the two expensive phases the full
  /// Testing gate runs — the LINKING pass and the per-feature DOUBLE-CHECK scan
  /// (an already-built project doesn't need a whole-app re-audit after a tweak).
  /// It just makes sure the edit didn't break the build: ensure the CI gate,
  /// converge CI once (progress-gated, and now driven by the REAL-blocker
  /// failpoint count so `info` lints don't stall it), and on green flip straight
  /// back to `completed`. If CI can't go green on the fast lane, it FALLS BACK to
  /// the full Testing phase so a genuine breakage is still driven to green — the
  /// slow-but-reliable safety net.
  Future<void> _runEditorFinalize(Project project, String doneSig) async {
    _setTesting(true, 'Editor — checking your changes build…');
    try {
      if (!await _stillRunning()) return;
      await _ensureCodegenDeps(project);
      await _ensureDefaultCiWorkflow(project);
      final green = await _convergeCi(project, doneSig);
      if (green == null) return; // infra down — retry on a later pump/tick
      if (green) {
        _finalScanPassedSig = doneSig; // settled — don't re-finalize this state
        await _db.setProjectOrchestrationState(projectId, 'completed');
        debugPrint(
          '[Orchestrator p$projectId] EDITOR finalize: CI green → COMPLETE '
          '(fast lane — no linking pass, no double-check).',
        );
        return;
      }
      // Fast CI couldn't converge — the edit broke something the quick pass can't
      // clear. Fall back to the full Testing phase (linking + convergence +
      // double-check) so it's still driven to green. Reset the gate sigs the
      // convergence may have set so the full pass runs fresh rather than being
      // suppressed as "already exhausted".
      _testingExhaustedSig = null;
      _finalScanPassedSig = null;
      debugPrint(
        '[Orchestrator p$projectId] EDITOR finalize: fast CI did not converge → '
        'falling back to the full Testing phase.',
      );
      await _db.setProjectOrchestrationState(projectId, 'running');
    } finally {
      _setTesting(false, null);
    }
  }

  /// The TESTING phase: a dedicated end-of-project stage (like the yellow
  /// Templating stage — NOT a task) that repeatedly runs CI on main and, on RED,
  /// drives ONE focused fix agent (the strongest model, handed ALL the failpoints
  /// at once) to fix the whole project before the next run, then re-scans. Keeps
  /// looping while it's making PROGRESS (fewer failpoints each run); only gives up
  /// after the count fails to drop for [_maxStagnantRounds] rounds. [doneSig] is
  /// the completed-task signature this run gates, so a pass/exhaust suppresses
  /// re-running for the same settled state.
  /// End-of-project finalize, ordered to avoid the "green → rewire → re-break →
  /// re-converge" thrash: LINK first, CI second, then a read-only double-check
  /// SCAN.
  ///
  ///   PHASE 1 — LINKING PUSH: one solid pass that wires EVERY requested feature
  ///     into the running app (route/nav/entrypoint), UP FRONT, before CI. The
  ///     build phase should already have wired most of it; this closes the gaps
  ///     in a single comprehensive edit instead of one-feature-at-a-time later.
  ///   PHASE 2 — CI CONVERGENCE: compile/test the now-wired app and fix whatever
  ///     the wiring surfaced, progress-gated, until GREEN.
  ///   PHASE 3 — DOUBLE-CHECK SCAN: a READ-ONLY logic re-confirmation that every
  ///     feature is reachable. CI must never *unlink* anything, so this should
  ///     pass first time; only if it genuinely finds a gap does it do a targeted
  ///     rewire and re-converge (bounded by the stagnation gate).
  Future<void> _runTestingPhase(Project project, String doneSig) async {
    _setTesting(true, 'Linking — wiring every feature across the app…');
    try {
      if (!await _stillRunning()) return;

      // Make sure the CI gate is current before we converge — in particular, add
      // the build_runner codegen step for drift/freezed/… projects so we don't
      // grind against stale generated files (hundreds of phantom errors). First
      // provision the codegen toolchain in pubspec if the source uses it but the
      // dev-deps are missing (why generation was never possible), THEN the gate
      // ensure sees build_runner and adds the codegen step.
      await _ensureCodegenDeps(project);
      await _ensureDefaultCiWorkflow(project);

      // ── PHASE 1: LINKING PUSH (one comprehensive wiring pass, before CI) ─────
      await _runLinkingPass(project);

      // ── PHASE 2: CONVERGE CI on the now-wired app ───────────────────────────
      final green = await _convergeCi(project, doneSig);
      if (green == null) return; // infra down — retry on a later pump/tick
      if (!green) return; // exhausted — [_testingExhaustedSig] already set

      // ── PHASE 3: DOUBLE-CHECK (INCREMENTAL — shrinks as features verify) ─────
      // Load the persistent checklist so each pass only re-reviews features that
      // are NOT yet confirmed, and a verified feature is never re-touched. This is
      // what stops the link↔test alternation from re-litigating settled work every
      // round (the count only goes DOWN).
      final prog = await loadFinalizeProgress(projectId);
      _finalPassPrevCount = null;
      _finalPassStagnant = 0;
      for (var pass = 1; pass <= _absoluteMaxTestingRounds; pass++) {
        if (!await _stillRunning()) return;
        _setTesting(true, 'Double-check — re-confirming remaining features…');
        debugPrint(
          '[Orchestrator p$projectId] CI GREEN → DOUBLE-CHECK (pass $pass): '
          '${prog.verified.length} feature(s) already confirmed — re-checking the '
          'rest + stubs + screenshot…',
        );
        final scan = await _runFinalPass(
          project,
          alreadyVerified: prog.verified,
        );
        if (scan.nowVerified.isNotEmpty) {
          prog.verified.addAll(scan.nowVerified);
          await saveFinalizeProgress(projectId, prog);
          debugPrint(
            '[Orchestrator p$projectId] DOUBLE-CHECK: +${scan.nowVerified.length} '
            'feature(s) confirmed this pass (${prog.verified.length} total).',
          );
        }
        if (scan.passed) {
          _finalScanPassedSig = doneSig; // settled green — stop re-scanning
          _finalPassPrevCount = null;
          _finalPassStagnant = 0;
          await _db.setProjectOrchestrationState(projectId, 'completed');
          // Done — drop the checklist so any future re-run (after the project is
          // re-opened / tasks change) re-verifies from scratch.
          await clearFinalizeProgress(projectId);
          debugPrint(
            '[Orchestrator p$projectId] DOUBLE-CHECK OK — project COMPLETE '
            '(linked, CI green, every feature confirmed reachable, no stubs).',
          );
          return;
        }
        // A gap remains (unverified wiring, a stub, or a visual issue). Targeted
        // fix, then re-converge CI. Progress = the issue count dropping OR the
        // verified set growing; only a pass that does NEITHER counts toward the
        // stagnation budget.
        final issueCount = _countIssueBullets(scan.issues);
        final madeProgress =
            scan.nowVerified.isNotEmpty ||
            _finalPassPrevCount == null ||
            issueCount < _finalPassPrevCount!;
        if (!madeProgress) {
          _finalPassStagnant++;
          if (_finalPassStagnant >= _maxFinalPassStagnant) {
            _testingExhaustedSig = doneSig;
            debugPrint(
              '[Orchestrator p$projectId] DOUBLE-CHECK: no progress for '
              '$_maxFinalPassStagnant passes ($issueCount issue(s) left) — '
              'leaving for manual review:\n${scan.issues}',
            );
            return;
          }
        } else {
          _finalPassStagnant = 0;
        }
        _finalPassPrevCount = issueCount;
        debugPrint(
          '[Orchestrator p$projectId] DOUBLE-CHECK found $issueCount issue(s) — '
          'targeted fix then re-converge:\n${scan.issues}',
        );
        _setTesting(
          true,
          'Double-check — fixing $issueCount remaining issue(s)…',
        );
        await _runFixAgent(project, scan.issues, pass, functional: true);
        final reGreen = await _convergeCi(project, doneSig);
        if (reGreen == null) return; // infra down — retry later
        if (!reGreen) return; // exhausted — flag set
      }
      _testingExhaustedSig = doneSig;
      debugPrint(
        '[Orchestrator p$projectId] DOUBLE-CHECK hit the $_absoluteMaxTestingRounds-'
        'pass backstop — leaving for manual review.',
      );
    } catch (e, st) {
      // A torn-down orchestrator (project switch / navigating off the workspace
      // view disposes this autoDispose provider) throws "Cannot use Ref after
      // disposed" from any lingering `_db` read. That's benign here — the
      // re-mounted orchestrator resumes finalize from the persisted checklist —
      // so log it quietly rather than as a phase error.
      if (_disposed || e.toString().contains('after it has been disposed')) {
        debugPrint(
          '[Orchestrator p$projectId] FINALIZE phase bailed (orchestrator '
          'disposed mid-flight) — will resume on re-mount.',
        );
      } else {
        debugPrint(
          '[Orchestrator p$projectId] FINALIZE phase errored: $e\n$st',
        );
      }
    } finally {
      _setTesting(false, null);
    }
  }

  /// PHASE 1 helper — the comprehensive LINKING PUSH. Hands the task list to the
  /// wiring agent and tells it to trace the entrypoint and connect EVERY feature
  /// in one solid pass (edits main, commits). Runs ONCE per project (tracked by
  /// [FinalizeProgress.linkDone]) — on a later entry (restart / re-pump / rebuild)
  /// it is SKIPPED so we don't re-churn already-wired work; the incremental
  /// double-check handles what's left. Features already CONFIRMED wired
  /// ([FinalizeProgress.verified]) are dropped from the worklist so even the first
  /// push only spans what isn't settled.
  Future<void> _runLinkingPass(Project project) async {
    if (!await _stillRunning()) return;
    final prog = await loadFinalizeProgress(projectId);
    if (prog.linkDone) {
      debugPrint(
        '[Orchestrator p$projectId] LINKING PASS: already done on a prior entry — '
        'skipping the full re-link, going straight to the double-check.',
      );
      return;
    }
    final tasks = await _db.getTasksForProject(projectId);
    final pending = tasks
        .where((t) => !prog.verified.contains(t.task_pk))
        .toList();
    if (pending.isEmpty) {
      prog.linkDone = true;
      await saveFinalizeProgress(projectId, prog);
      return;
    }
    final worklist = StringBuffer();
    for (final t in pending) {
      final desc = (t.description ?? '').trim();
      final firstLine = desc.isEmpty ? '' : ' — ${desc.split('\n').first}';
      worklist.writeln('- [#${t.task_pk}] ${t.title}$firstLine');
    }
    debugPrint(
      '[Orchestrator p$projectId] LINKING PASS: one comprehensive wiring push '
      'over ${pending.length}/${tasks.length} feature(s) before CI…',
    );
    _setTesting(true, 'Linking — wiring every feature across the app…');
    await _runFixAgent(
      project,
      worklist.toString().trim(),
      0,
      functional: true,
      linkAll: true,
    );
    prog.linkDone = true;
    await saveFinalizeProgress(projectId, prog);
  }

  /// PHASE 2 helper — the progress-gated CI convergence loop. Runs CI on main and
  /// fixes failures until GREEN. Returns true on green, false when exhausted (the
  /// stagnation/backstop gate fired; [_testingExhaustedSig] set), or null when the
  /// CI infra is unavailable (caller should return and let a later pump retry).
  Future<bool?> _convergeCi(Project project, String doneSig) async {
    var stagnant = 0;
    int? prevCount;
    for (var round = 1; round <= _absoluteMaxTestingRounds; round++) {
      if (!await _stillRunning()) return null;
      _setTesting(true, 'Testing — CI run $round…');
      debugPrint(
        '[Orchestrator p$projectId] CI convergence round $round: running CI on '
        'main (this can take a few minutes)…',
      );
      final outcome = await _runWorkflowGate(
        clientPk: project.client_fk,
        branch: 'main',
        workflowPath: _defaultCiPath,
        triggeredBy: 'testing',
      );
      if (outcome == null)
        return null; // infra down — retry on a later pump/tick
      if (outcome.passed) return true;

      // Info-lint tolerance: `flutter analyze` exits non-zero on ANY issue, so a
      // single advisory INFO (e.g. use_build_context_synchronously) fails the gate
      // even though the app compiles and runs — and the fixer often can't clear a
      // stubborn lint, stalling the whole project. If the red run failed ONLY on
      // info-level lints (no errors/warnings, no test/build failure), accept it as
      // green and move on to the double-check.
      if (outcome.runPk != null && await _ciRedIsInfoOnly(outcome.runPk!)) {
        debugPrint(
          '[Orchestrator p$projectId] CI convergence round $round: run '
          '${outcome.runPk} RED on info-level lints only (no errors/warnings) — '
          'treating as GREEN.',
        );
        return true;
      }

      // Gather ALL failpoints so the fixer resolves them in one pass, not one
      // error per CI run.
      final diag = outcome.runPk != null
          ? await _collectCiFailpoints(outcome.runPk!)
          : (text: '', count: 0);
      debugPrint(
        '[Orchestrator p$projectId] CI convergence round $round: CI RED — '
        '${diag.count} failpoint(s)'
        '${prevCount != null ? ' (was $prevCount)' : ''}.',
      );

      // PROGRESS GATE: keep going while the failure count is dropping; only a
      // NON-improving run counts toward the stagnation budget (lets it grind a
      // big backlog 100 → 60 → 25 → 0 while still bailing if truly stuck).
      if (prevCount != null && diag.count >= prevCount) {
        stagnant++;
        if (stagnant >= _maxStagnantRounds) {
          _testingExhaustedSig = doneSig;
          debugPrint(
            '[Orchestrator p$projectId] CI convergence: failpoint count hasn\'t '
            'dropped for $_maxStagnantRounds rounds (${diag.count} left) — '
            'leaving for manual review.',
          );
          return false;
        }
      } else {
        stagnant = 0; // made progress this round
      }
      prevCount = diag.count;

      _setTesting(
        true,
        'Testing — fixing ${diag.count} error(s) (round $round)…',
      );
      await _runFixAgent(project, diag.text, round);
    }
    // Hard backstop hit (rare — the progress gate usually ends it first).
    _testingExhaustedSig = doneSig;
    debugPrint(
      '[Orchestrator p$projectId] CI convergence hit the $_absoluteMaxTestingRounds-'
      'round backstop — CI still RED; leaving for manual review.',
    );
    return false;
  }

  /// FINAL PASS: with CI green, confirm every REQUESTED feature (task) is truly
  /// implemented AND reachable in the running app — not left as a placeholder or
  /// stub. Two checks: a code-trace review (the reliable one — catches the
  /// "press Start, land on a placeholder screen" case), and a best-effort
  /// screenshot of the running web build for a vision sanity check. Passed only
  /// when neither flags anything.
  /// [alreadyVerified]: task_pks the checklist has already confirmed — the
  /// code-trace SKIPS them (only re-reviews the rest), so each pass shrinks.
  /// [nowVerified] returns the task_pks this pass newly confirmed wired+reachable.
  Future<({bool passed, String issues, Set<int> nowVerified})> _runFinalPass(
    Project project, {
    Set<int> alreadyVerified = const <int>{},
  }) async {
    final buf = StringBuffer();
    var nowVerified = <int>{};
    // HARD NO on stubs — a deterministic whole-tree scan (no base exemption,
    // footprint-independent, restart-proof). This is the guarantee the per-task
    // gate can't give: a task that left its OWN scaffolded deliverable a TODO
    // placeholder is caught here, and the project cannot reach `completed` while
    // any marker remains. Listed FIRST and as bullets so it drives the fixer and
    // counts toward the progress gate. Global (not scoped by the checklist).
    try {
      final treeStubs = await _scanTreeForStubs();
      if (treeStubs.trim().isNotEmpty) {
        buf.writeln(
          'UNIMPLEMENTED STUBS — these files still contain TODO/placeholder '
          'markers. IMPLEMENT each feature FOR REAL (build the actual UI/logic and '
          'remove the marker); do NOT merely wire, comment out, or delete it:',
        );
        for (final line in treeStubs.trim().split('\n')) {
          if (line.trim().isNotEmpty) buf.writeln('- $line');
        }
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] final-pass tree stub scan failed: $e',
      );
      rethrow;
    }
    final testCoverage = await _featureTestCoverageProblem();
    if (testCoverage.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('MISSING FEATURE TEST COVERAGE:');
      buf.writeln('- $testCoverage');
    }
    try {
      final allTasks = await _db.getTasksForProject(projectId);
      final reviewPks = allTasks
          .map((t) => t.task_pk)
          .toSet()
          .difference(alreadyVerified);
      final code = await _finalPassCodeTrace(project, reviewPks: reviewPks);
      nowVerified = code.verified;
      if (code.issues.trim().isNotEmpty) {
        if (buf.isNotEmpty) buf.writeln();
        buf.writeln('UNWIRED / INCOMPLETE FEATURES (from a code review):');
        buf.writeln(code.issues.trim());
      }
      final unconfirmed = reviewPks.difference(code.verified);
      if (unconfirmed.isNotEmpty) {
        final issuePks = RegExp(r'#(\d+)\s+ISSUE\b', caseSensitive: false)
            .allMatches(code.issues)
            .map((match) => int.tryParse(match.group(1)!))
            .whereType<int>()
            .toSet();
        final missingVerdicts = unconfirmed.difference(issuePks);
        if (missingVerdicts.isNotEmpty) {
          if (buf.isNotEmpty) buf.writeln();
          buf.writeln('INCONCLUSIVE FEATURE REVIEW:');
          for (final pk in missingVerdicts.toList()..sort()) {
            buf.writeln(
              '- #$pk was not confirmed implemented and reachable by the code-trace reviewer.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Orchestrator p$projectId] final-pass code trace failed: $e');
      rethrow;
    }
    // VISION is ADVISORY ONLY — it must NOT block completion. The web-build
    // screenshot is inherently unreliable: a NATIVE app (drift/native-SQLite,
    // path_provider, platform channels) compiles for web but renders BLANK at
    // runtime, and render timing/CanvasKit quirks produce false "blank/broken"
    // reports for apps that are actually fine. The authoritative gates are CI
    // (compiles + tests pass), the hard-no STUB scan, and the code-trace wiring
    // review — all above. So log the screenshot's opinion for the human, but do
    // NOT add it to `issues` (which gates completion + drives the fixer).
    try {
      final visual = await _finalPassVision(project);
      if (visual.trim().isNotEmpty) {
        debugPrint(
          '[Orchestrator p$projectId] final-pass VISION (advisory, non-blocking): '
          '${visual.trim()}',
        );
      }
    } catch (e) {
      debugPrint('[Orchestrator p$projectId] final-pass vision skipped: $e');
    }
    final issues = buf.toString().trim();
    return (passed: issues.isEmpty, issues: issues, nowVerified: nowVerified);
  }

  /// Count the flagged features in a Final Pass report (bullet lines) — the
  /// progress metric for the loop's stagnation gate.
  int _countIssueBullets(String issues) => issues
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.startsWith('- ') || l.startsWith('* '))
      .length;

  /// Read-only reviewer: reads the code to trace each task's UI wiring and reports
  /// which features aren't hooked up. Scoped by [reviewPks] (the checklist's
  /// not-yet-verified set) so it shrinks each pass; when null, reviews all tasks.
  /// Returns the ISSUE text (for the fixer) and the set of #pks it CONFIRMED wired
  /// this pass (to add to the checklist). Inconclusive review → empty both (never
  /// blocks completion, never falsely marks verified).
  Future<({String issues, Set<int> verified})> _finalPassCodeTrace(
    Project project, {
    Set<int>? reviewPks,
  }) async {
    const empty = (issues: '', verified: <int>{});
    final persona =
        await _findPersonaForRole(AgentRole.verificationAgent) ??
        await _findPersonaForRole(AgentRole.sdeGeneralist) ??
        await _findPersonaForRole(AgentRole.coordinator);
    if (persona == null) return empty;
    final resolved = await _resolveBackend(persona);
    if (resolved == null) return empty;
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    final git = handles.git;
    if (ws == null || git == null) return empty;
    try {
      await git.checkoutBranch('main');
    } catch (_) {}

    final allTasks = await _db.getTasksForProject(projectId);
    final tasks = reviewPks == null
        ? allTasks
        : allTasks.where((t) => reviewPks.contains(t.task_pk)).toList();
    if (tasks.isEmpty) return empty; // nothing left to review → all confirmed
    final reviewed = tasks.map((t) => t.task_pk).toSet();
    final taskList = StringBuffer();
    for (final t in tasks) {
      final desc = (t.description ?? '').trim();
      final firstLine = desc.isEmpty ? '' : ' — ${desc.split('\n').first}';
      taskList.writeln('- [#${t.task_pk}] ${t.title}$firstLine');
    }

    final baseline = await buildProjectBaseline(_db, projectId);
    final systemPrompt =
        '$baseline\n\n${defaultSystemPrompt(AgentRole.verificationAgent)}\n\n'
        'You are the FINAL PASS reviewer. The project compiles and CI is GREEN, '
        'but that does NOT prove the features are wired up. For EACH requested '
        'feature below, verify it is genuinely implemented AND reachable in the '
        'running app: the UI path that should reach it (entrypoint/home → '
        'button/route/menu/tab) leads to the REAL feature, not a '
        'TODO/placeholder/empty/"coming soon" screen. READ the code — open the '
        'entrypoint (main / home / router) and trace down to each feature. Do NOT '
        'edit anything.\n'
        'Output, for EACH feature, exactly one line:\n'
        '  #<pk> OK               — genuinely wired up and reachable.\n'
        '  #<pk> ISSUE: <what is wrong / what should happen instead + the file>\n'
        'Then a final line: FINALPASS_OK (every feature OK) or FINALPASS_ISSUES.';

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
      workspace: ws,
      git: git,
      buildService: handles.build,
      leanTools: false,
      fixMode: true, // file/git read tools — we instruct it to only read
      systemPromptOverride: systemPrompt,
      reasoningEffort: personaReasoningEffort(persona.configJson),
      enableThinking: resolveEnableThinking(
        agent: personaThinkingMode(
          persona.configJson,
          personaName: persona.name,
        ),
        task: ThinkingMode.off,
      ),
    );

    var kickoff =
        'Requested features (tasks):\n\n${taskList.toString().trim()}\n\n'
        'Trace each in the code, then output one "#<pk> OK" or "#<pk> ISSUE: …" '
        'line per feature, ending with FINALPASS_OK or FINALPASS_ISSUES.';
    final content = StringBuffer();
    for (var turn = 0; turn < _maxFinalPassTurns && !_disposed; turn++) {
      if (!await _stillRunning()) break;
      content.clear();
      var sawTool = false;
      var transient = false;
      try {
        await _drainTurn(
          session.runTurn(
            kickoff,
            maxToolRounds: 8,
            onToolResult: (_) => sawTool = true,
          ),
          activity: session.turnActivity,
          onEvent: (ev) {
            if (ev is ChatContentDelta) content.write(ev.text);
          },
        );
      } catch (e) {
        if (e is! TimeoutException && !_isNotTaskFault(e)) {
          debugPrint(
            '[Orchestrator p$projectId] final-pass turn $turn failed: $e',
          );
          break;
        }
        transient = true;
      }
      if (transient) continue;
      final text = content.toString();
      if (text.contains('FINALPASS_OK') || text.contains('FINALPASS_ISSUES')) {
        return _parseCodeTraceVerdict(text, reviewed);
      }
      if (!sawTool) {
        // No tools + no verdict → nudge once, then accept an inconclusive review.
        kickoff =
            'Give your verdict now: one "#<pk> OK" or "#<pk> ISSUE: …" line per '
            'feature, then FINALPASS_OK or FINALPASS_ISSUES.';
        continue;
      }
      kickoff =
          'Keep tracing the remaining features, then output the per-feature lines '
          'and FINALPASS_OK or FINALPASS_ISSUES.';
    }
    return _parseCodeTraceVerdict(content.toString(), reviewed);
  }

  /// Parse the reviewer's per-feature verdict. A `#N OK` line → verified; a
  /// `#N ISSUE:` line → an issue bullet (and NOT verified). A reviewed feature the
  /// reviewer never mentioned stays UNverified (conservative). If it declared
  /// FINALPASS_OK with no ISSUE lines, all reviewed features are verified.
  ({String issues, Set<int> verified}) _parseCodeTraceVerdict(
    String text,
    Set<int> reviewed,
  ) {
    final verified = <int>{};
    final issued = <int>{};
    final issueLines = <String>[];
    final okRe = RegExp(r'#(\d+)\s+OK\b', caseSensitive: false);
    final issueRe = RegExp(r'#(\d+)\s+ISSUE\b', caseSensitive: false);
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      final iss = issueRe.firstMatch(line);
      if (iss != null) {
        final pk = int.tryParse(iss.group(1)!);
        if (pk != null) issued.add(pk);
        issueLines.add(
          line.startsWith('-') || line.startsWith('*') ? line : '- $line',
        );
        continue;
      }
      final ok = okRe.firstMatch(line);
      if (ok != null) {
        final pk = int.tryParse(ok.group(1)!);
        if (pk != null && reviewed.contains(pk)) verified.add(pk);
      }
    }
    verified.removeAll(
      issued,
    ); // an ISSUE always wins over an OK for the same pk
    if (issueLines.isEmpty && text.contains('FINALPASS_OK')) {
      verified.addAll(reviewed); // clean sweep of the reviewed scope
    }
    return (issues: issueLines.join('\n'), verified: verified);
  }

  /// Best-effort vision check: build the project as web, screenshot the running
  /// app headlessly, and ask the (vision-capable) model whether it renders a real
  /// working UI. Returns '' when it looks fine OR when no screenshot could be
  /// produced (so a missing browser / non-web project never blocks completion).
  Future<String> _finalPassVision(Project project) async {
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    if (ws == null) return '';
    _setTesting(true, 'Final pass — building web preview + screenshot…');
    final shot = await captureProjectWebScreenshot(ws);
    if (shot.png == null) {
      debugPrint(
        '[Orchestrator p$projectId] final-pass: no screenshot available '
        '(non-web / no browser / build failed).',
      );
      return '';
    }
    final persona =
        await _findPersonaForRole(AgentRole.verificationAgent) ??
        await _findPersonaForRole(AgentRole.coordinator) ??
        await _findPersonaForRole(AgentRole.sdeGeneralist);
    if (persona == null) return '';
    final resolved = await _resolveBackend(persona);
    if (resolved == null || resolved.model == null) return '';

    final tasks = await _db.getTasksForProject(projectId);
    final list = tasks.map((t) => '- ${t.title}').join('\n');
    final dataUrl = 'data:image/png;base64,${base64Encode(shot.png!)}';
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You are a QA reviewer looking at a screenshot of a running app.',
      },
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'Screenshot of the running app "${project.name}". Requested '
                'features:\n$list\n\nDoes it render a real, working UI? Report any '
                'VISIBLE problems: blank/error/placeholder/TODO screens, missing '
                'core UI, or obvious breakage. If it looks like a functional app '
                'with no obvious problems, reply EXACTLY "VISUAL_OK".',
          },
          {
            'type': 'image_url',
            'image_url': {'url': dataUrl},
          },
        ],
      },
    ];
    try {
      final resp = await resolved.client
          .createChatCompletion(
            model: resolved.model!,
            messages: messages,
            maxTokens: 800,
          )
          .timeout(_turnIdleTimeout);
      final text =
          (resp.choices.isNotEmpty
              ? resp.choices.first.message.content
              : null) ??
          '';
      if (text.contains('VISUAL_OK')) return '';
      return text.trim();
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] final-pass vision call failed: $e',
      );
      return '';
    }
  }

  /// Drive ONE focused fix agent over the WHOLE project on main: hand it ALL the
  /// CI errors at once and let it read/edit/commit across as many files as it
  /// needs (this is the "fix the project", not "fix one file" job). Uses the
  /// generalist's code-tuned model — on the routed plan that's the full default
  /// Omni collection (the strongest available). Returns true if it landed a new
  /// commit (so the next CI scan sees the changes).
  Future<bool> _runFixAgent(
    Project project,
    String errors,
    int round, {
    bool functional = false,
    // [linkAll]: PHASE-1 comprehensive linking push — [errors] is the full task
    // list (not a scan-derived defect list), and the agent proactively traces the
    // entrypoint and wires EVERY feature in one pass. Implies [functional].
    bool linkAll = false,
  }) async {
    final persona =
        await _findPersonaForRole(AgentRole.sdeGeneralist) ??
        await _findPersonaForRole(AgentRole.coordinator);
    if (persona == null) return false;
    final resolved = await _resolveBackend(persona);
    if (resolved == null) return false;
    final handles = await _resolveWorkspaceHandles();
    final ws = handles.ws;
    final git = handles.git;
    if (ws == null || git == null) return false;

    // The fixer works directly on main (the backlog is drained, so nothing else
    // is touching it). Its commits are what the next CI scan reads.
    try {
      await git.checkoutBranch('main');
    } catch (_) {}
    final beforeHead = await git.headOid();

    final baseline = await buildProjectBaseline(_db, projectId);
    final fileTree =
        (await ws.walk())
            .where((f) => !f.isDirectory)
            .map((f) => f.path)
            .toList()
          ..sort();
    final filesBlock = fileTree.take(300).join('\n');
    final systemPrompt = StringBuffer()
      ..writeln(baseline)
      ..writeln()
      ..writeln(defaultSystemPrompt(AgentRole.sdeGeneralist))
      ..writeln()
      ..writeln(
        linkAll
            ? 'You are the end-of-project LINKING agent. Every requested feature '
                  'below is ALREADY BUILT and merged onto main — this is a WIRING '
                  'pass, NOT a rebuild. In ONE solid pass, go through the WHOLE app '
                  'and make every feature genuinely reachable: open the entrypoint '
                  '(main / home / router) and trace the UI path that should reach '
                  'each feature (route/nav/button/menu/tab/handler). Where a '
                  'feature is orphaned, unhooked, or its trigger lands on a '
                  'placeholder, CONNECT it to the existing implementation with the '
                  'SMALLEST change. Reuse what is there — do NOT rewrite files or '
                  're-implement working code; only implement something new if a '
                  'feature is genuinely absent. Wire everything in this one push. '
                  'Also create or upgrade focused tests under test/ that exercise '
                  'the requested behavior and state transitions. The generated '
                  'smoke test and shell-load widget test do not count as feature '
                  'coverage.'
            : functional
            ? 'You are the end-of-project FINAL PASS agent. The project compiles '
                  'and its CI is GREEN. Each listed problem was found by a code '
                  'REVIEW that read the actual code — so if it says a feature is '
                  'missing/not-implemented, it GENUINELY is not there (a compiling, '
                  'partly-working file is NOT the same as the feature being done). '
                  'Three kinds, resolve them ALL: (1) UNIMPLEMENTED STUBS — a '
                  'TODO/placeholder/empty body/UnimplementedError: build the real '
                  'UI/logic and remove the marker. (2) UNWIRED — the real code '
                  'exists but is unreachable: connect it with the smallest '
                  'route/nav/button change. (3) INCOMPLETE — the feature partly '
                  'works but is MISSING part of its requirement (e.g. "custom dice '
                  'with user-defined sides" when only fixed types exist): BUILD the '
                  'missing part FOR REAL, even if it needs a refactor — widen the '
                  'enum to a class/sealed hierarchy or add a variant AND update '
                  'every usage (model + provider + screen + widget), add the input '
                  'UI, etc. Reading the files is NOT progress — you must EDIT them. '
                  'Before you finish, RE-READ the changed files and CONFIRM the '
                  'EXACT described capability now exists in the code; NEVER commit a '
                  '"implemented/done" message for something you did not actually '
                  'build — the review WILL re-check and reject a false claim.'
            : 'You are the end-of-project TESTING & FIX agent. The whole project '
                  'is built and merged onto main, but its CI build/tests are '
                  'FAILING. Your job is to make the WHOLE project compile cleanly '
                  'and its tests pass.',
      )
      ..writeln(
        functional || linkAll
            ? '- For EACH listed item: if it is a STUB, build the real feature and '
                  'remove the marker; if it merely needs WIRING, find the existing '
                  'implementation and connect its trigger path with a small edit. '
                  'Never leave a TODO/placeholder behind.'
            : '- Work across AS MANY FILES AS NEEDED — read the failing files, '
                  'find the real cause, and fix it. Do not stop at the first '
                  'error; resolve the whole class of failures.',
      )
      ..writeln(
        '- Keep changes minimal and correct; do not delete features or stub '
        'things out to silence errors. Preserve existing behavior.',
      )
      ..writeln(
        '- If feature-test coverage is missing, add focused tests that exercise '
        'the requested behavior or state transitions. A smoke assertion or a '
        'widget-construction-only test is not sufficient.',
      )
      ..writeln(
        '- A failing TEST can be a RUNTIME error, not a compile error — read the '
        'test output for the ROOT cause and fix THAT, not the test. Common Flutter '
        'ones: a `RenderFlex overflowed` / "unbounded height" / layout assertion '
        'from a Column/Row (e.g. the smoke test "App starts without errors" throws '
        'during layout) is fixed by wrapping the offending column in a '
        '`SingleChildScrollView` (or using `Expanded`/`Flexible` for a child that '
        'should flex) — the file:line in the error points at the exact widget. A '
        'missing provider/DB/DI at startup is fixed by initializing it (or a test '
        'setup), never by weakening the test.',
      )
      ..writeln(
        '- ALWAYS read_file the EXACT current contents of a file immediately '
        'before you edit_file it, and copy old_text VERBATIM (exact whitespace, '
        'indentation, and punctuation) from what you just read — never from '
        'memory or a guess. If old_text "was not found", re-read the file and try '
        'again; for a large or uncertain change, use write_file to replace the '
        'whole file instead of edit_file.',
      )
      ..writeln(
        '- When you have applied your fixes, git_commit them (an uncommitted '
        'change does not count — CI only sees committed work). Do NOT run the CI '
        'workflow yourself; the phase re-runs it for you after you commit.',
      )
      ..writeln()
      ..writeln('=== CURRENT PROJECT FILES (on main) ===')
      ..writeln(filesBlock);

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
      workspace: ws,
      git: git,
      buildService: handles.build,
      leanTools: false,
      // File/git ONLY toolset — read/edit/write/commit. No CI/build tools (the
      // phase re-runs CI itself, and the generalist persona denies them, so
      // offering them only tempts a blocked call), no task/story/image tools.
      fixMode: true,
      systemPromptOverride: systemPrompt.toString(),
      reasoningEffort: personaReasoningEffort(persona.configJson),
      enableThinking: resolveEnableThinking(
        agent: personaThinkingMode(
          persona.configJson,
          personaName: persona.name,
        ),
        task: ThinkingMode.off,
      ),
    );

    var kickoff = linkAll
        ? 'These are ALL the requested features. In ONE solid pass, go through the '
              'whole app and make sure EVERY one is wired up and reachable from the '
              'entrypoint — connect any that are orphaned or land on a placeholder, '
              'committing as you go. Do NOT stop after the first; wire them all now. '
              'Requested features:\n\n$errors'
        : functional
        ? 'CI is green but these requested features are NOT wired up. Hook up '
              'EVERY one in this session — implement and connect each so it works '
              'end to end, committing as you go. Do NOT stop after the first one. '
              'Unwired features:\n\n$errors'
        : 'CI on main is RED with the failpoints below. Fix EVERY one of them in '
              'this session — work through the WHOLE list, committing as you finish '
              'each file or group. Do NOT stop after the first fix and do NOT ask '
              'to re-run CI: keep going until every listed failure is addressed '
              '(the phase re-runs CI for you afterwards). Failpoints:\n\n$errors';
    // Work through ALL failpoints in one pass — do NOT bail on the first commit
    // (that's what made it "test after every point"). But the "done" signal is the
    // agent no longer making CHANGES, not no longer using tools: it'll keep
    // reading/searching the whole tree forever otherwise (observed: 1 failpoint
    // fixed by turn 3, still re-scanning at turn 10+). So break once it goes a
    // couple of turns EDITING nothing — then the outer loop re-runs CI once and
    // tackles whatever's left (including any NEW failures the fixes uncovered).
    var idleTurns = 0;
    var noEditTurns = 0;
    for (var turn = 0; turn < _maxFixAgentTurns && !_disposed; turn++) {
      if (!await _stillRunning()) break;
      var sawTool = false;
      var sawEdit = false;
      var transient = false;
      try {
        await _drainTurn(
          session.runTurn(
            kickoff,
            maxToolRounds: 8,
            onToolResult: (r) {
              sawTool = true;
              // Did this tool result actually CHANGE the tree (edit/write/commit/
              // move/create)? Reads & searches don't count toward "still working".
              final rl = r.toLowerCase();
              if (rl.contains('edited "') ||
                  rl.contains('committed all changes') ||
                  rl.contains('committed your working tree') ||
                  rl.contains('updated file') ||
                  rl.contains('created file') ||
                  rl.contains('wrote ') ||
                  rl.contains('moved ')) {
                sawEdit = true;
              }
              debugPrint(
                '[Orchestrator p$projectId] testing-fix r$round turn $turn tool → '
                '${r.length > 140 ? '${r.substring(0, 140)}…' : r}',
              );
            },
          ),
          activity: session.turnActivity,
        );
      } catch (e) {
        if (e is! TimeoutException && !_isNotTaskFault(e)) {
          debugPrint(
            '[Orchestrator p$projectId] testing-fix turn $turn failed: $e',
          );
          break;
        }
        transient = true; // stall / backpressure / transient — retry the turn.
      }
      // Keep the Code & Git view fresh as commits land.
      if (!_disposed) {
        ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      }
      if (transient) continue; // don't count a failed turn as "idle/done"
      if (!sawTool) {
        // A turn with no tool calls = the agent thinks it's finished. Give it one
        // nudge in case it stopped early, then accept it's done.
        idleTurns++;
        if (idleTurns >= 2) break;
        kickoff =
            'If EVERY failpoint above is now fixed AND committed, reply "done". '
            'Otherwise keep fixing the remaining ones and git_commit them.';
        continue;
      }
      idleTurns = 0;
      if (sawEdit) {
        noEditTurns = 0;
        kickoff =
            'Keep going — fix the REMAINING failpoints from the list and '
            'git_commit them. Re-read each file right before editing. When ALL '
            'are fixed and committed, reply "done".';
      } else {
        // Tools ran but nothing changed (just reading/searching). After a couple
        // of these the agent is done fixing — stop and let CI re-run rather than
        // re-scanning the whole project.
        noEditTurns++;
        if (noEditTurns >= 2) break;
        kickoff =
            'You made no code change that turn. If every failpoint is fixed and '
            'committed, reply "done" and stop. If something still needs fixing, '
            'edit it and git_commit now — do NOT keep re-reading files.';
      }
    }
    // SAFETY COMMIT: the next CI run only sees COMMITTED work, so if the agent
    // left edits uncommitted, commit them now rather than losing the pass.
    try {
      if (!(await git.status()).isClean) {
        final lane = ref.read(gitLaneProvider(projectId));
        await lane.run(
          () => git.commitAll(
            message: 'testing: auto-commit pending fixes (round $round)',
          ),
          timeout: _laneOpTimeout,
        );
        debugPrint(
          '[Orchestrator p$projectId] testing-fix r$round: safety-committed '
          'leftover uncommitted fixes.',
        );
      }
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] testing-fix r$round: safety commit skipped ($e).',
      );
    }
    return (await git.headOid()) != beforeHead;
  }

  /// Update the live TESTING phase flag/detail and mirror it into
  /// [orchestratorStatusProvider] so the top-bar shows a yellow "Testing" stage.
  void _setTesting(bool active, String? detail) {
    _testingActive = active;
    _testingDetail = detail;
    if (_disposed) return;
    try {
      final cur = ref.read(orchestratorStatusProvider(projectId));
      ref
          .read(orchestratorStatusProvider(projectId).notifier)
          .state = OrchestratorStatus(
        workerSlots: cur.workerSlots,
        activeStages: cur.activeStages,
        waiting: cur.waiting,
        testing: active,
        testingDetail: detail,
      );
    } catch (_) {}
  }

  // ── Shared helpers ──────────────────────────────────────────────────────

  /// Drain an agent turn stream with BOTH an idle timeout (no event for
  /// [_turnIdleTimeout]) AND a hard wall-clock cap ([_turnWallClock]). Either
  /// firing throws a [TimeoutException] and cancels the subscription (closing the
  /// SSE socket). Unlike `stream.timeout` (which only enforces idle and resets on
  /// every keep-alive), the wall-clock cap guarantees a stuck turn can't hang
  /// forever. [onEvent] gets each event (e.g. to accumulate content).
  Future<void> _drainTurn(
    Stream<ChatStreamEvent> stream, {
    Stream<void>? activity,
    void Function(ChatStreamEvent event)? onEvent,
    Duration? wallClock,
  }) {
    final completer = Completer<void>();
    Timer? idle;
    final effectiveWallClock = wallClock ?? _turnWallClock;
    void fail(Object e, [StackTrace? st]) {
      if (!completer.isCompleted) completer.completeError(e, st);
    }

    final wall = Timer(
      effectiveWallClock,
      () => fail(
        TimeoutException(
          'turn exceeded ${effectiveWallClock.inMinutes}m wall-clock cap',
        ),
      ),
    );
    void bumpIdle() {
      if (completer.isCompleted) return;
      idle?.cancel();
      idle = Timer(
        _turnIdleTimeout,
        () => fail(
          TimeoutException('turn idle for ${_turnIdleTimeout.inMinutes}m'),
        ),
      );
    }

    bumpIdle();
    final activitySub = activity?.listen((_) {
      _consecutiveConnCaps = 0;
      bumpIdle();
    });
    final sub = stream.listen(
      (ev) {
        _consecutiveConnCaps = 0;
        bumpIdle();
        if (onEvent != null) {
          try {
            onEvent(ev);
          } catch (_) {}
        }
      },
      onError: fail,
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    return completer.future.whenComplete(() async {
      idle?.cancel();
      wall.cancel();
      await activitySub?.cancel();
      // Initiate cancellation before a task workspace is released, but never
      // let a non-responsive HTTP stream's cancellation Future defeat the
      // watchdog itself. Once cancel() is called the subscription stops
      // delivering tool events; five seconds is enough for normal propagation.
      try {
        await sub.cancel().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // A single hung cancel may be one zombie socket, but the shared pool
        // carries every other in-flight stage (sibling workers, verifiers) —
        // closing it on the FIRST hang nukes all of them into transient
        // failures that restart from their WIP branches, which multiplies the
        // slowness and scatters spurious errors through the log. Only reset
        // the transport after a REPEATED hang inside the backoff window (the
        // same escalation the 429 path uses); one-off hangs ride out on the
        // per-host idle timeout.
        final now = DateTime.now();
        _consecutiveHungCancels =
            _lastHungCancelAt != null &&
            now.difference(_lastHungCancelAt!) <= _connCapRecoveryWindow
                ? _consecutiveHungCancels + 1
                : 1;
        _lastHungCancelAt = now;
        debugPrint(
          '[Orchestrator p$projectId] timed-out inference stream did not '
          'acknowledge cancellation within 5s (hang #\$'
          '${_consecutiveHungCancels}).',
        );
        if (_consecutiveHungCancels >= 2) {
          _consecutiveHungCancels = 0;
          // `http` cannot abort one streamed request independently from its
          // Client. Repeated hung cancels mean the pool is holding zombie Router
          // sessions counting against the account connection cap — close it and
          // let in-flight stages yield as transient failures and restart from
          // their WIP branches against a fresh transport.
          resetInferenceConnections();
          debugPrint(
            '[Orchestrator p$projectId] repeated hung stream cancels — reset '
            'the shared inference transport to release stale connections.',
          );
        }
      }
    });
  }

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
    if (_disposed) return (ws: null, git: null, build: null);
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
    if (_disposed) return null;
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
    // The orchestrator provider can be DISPOSED (project unfocused / view
    // unmounted) while this stage is still in flight; touching `ref` then throws
    // "Cannot use Ref after it has been disposed". Skip the provider invalidate
    // in that case — just clean the scratch disk (the committed work is safe on
    // the task branch). Guarded + caught so cleanup can never crash a stage.
    if (!_disposed) {
      try {
        ref.invalidate(
          taskWorkspaceProvider((projectId: projectId, taskPk: taskPk)),
        );
      } catch (_) {}
    }
    try {
      await deleteTaskDisk(projectId, taskPk);
    } catch (_) {}
  }

  /// True if [e] is the plan's concurrent-connection cap (HTTP 429 /
  /// too_many_connections). Records a short dispatch backoff so the pump stops
  /// launching new agents until a connection frees. This is BACKPRESSURE, not a
  /// task failure — callers return the task to the board and never Block it.
  bool _isConnCap(Object e) {
    final hit =
        e is LemonadeApiException &&
        (e.statusCode == 429 ||
            e.message.toLowerCase().contains('too_many_connections'));
    if (hit) {
      final now = DateTime.now();
      _connBackoffUntil = now.add(_connBackoff);
      if (_lastConnCapAt != null &&
          now.difference(_lastConnCapAt!) <= _connCapRecoveryWindow) {
        _consecutiveConnCaps++;
      } else {
        _consecutiveConnCaps = 1;
      }
      _lastConnCapAt = now;
      debugPrint(
        '[Orchestrator p$projectId] connection cap (429) — returning task to '
        'the board, pausing new agents for ${_connBackoff.inSeconds}s.',
      );
      if (_consecutiveConnCaps >= 2) {
        _consecutiveConnCaps = 0;
        resetInferenceConnections();
        debugPrint(
          '[Orchestrator p$projectId] repeated 429s without successful inference '
          'traffic — reset the shared transport to release stale connections.',
        );
      }
    }
    return hit;
  }

  /// True if [e] is a TRANSIENT upstream/server hiccup (502/503/504) — the
  /// gateway momentarily couldn't serve the request. Like 429, this is NOT the
  /// task's fault, so it must not burn the retry budget; the caller undoes the
  /// attempt and the task is retried.
  static bool _isTransientServer(Object e) =>
      e is LemonadeApiException &&
      (e.statusCode == 502 || e.statusCode == 503 || e.statusCode == 504);

  /// True if the shared HTTP client was closed out from under an in-flight
  /// request — this happens when the project is unfocused mid-turn
  /// (`resetInferenceConnections`). It is NOT the task's fault: the task yields
  /// and the next pump re-dispatches it against a freshly-created client.
  static bool _isClosedClient(Object e) =>
      e is LemonadeApiException &&
      e.message.toLowerCase().contains('client is already closed');

  /// True if the stream dropped mid-flight — a transient network/connection error
  /// (the router or the socket closed the connection while data was streaming),
  /// NOT a model/task fault. Seen as `http.ClientException: Connection closed
  /// while receiving data` and similar. Without classifying these as transient, a
  /// single flaky stream killed the whole turn (the Testing fix agent broke on
  /// turn 0 and never retried → no progress → the phase gave up). These should be
  /// retried, exactly like a 502/429.
  static bool _isTransientNetwork(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('connection closed') ||
        s.contains('connection reset') ||
        s.contains('connection terminated') ||
        s.contains('connection refused') ||
        s.contains('connection attempt failed') ||
        s.contains('software caused connection abort') ||
        s.contains('socketexception') ||
        s.contains('handshakeexception') ||
        s.contains('httpexception') ||
        (s.contains('clientexception') && s.contains('connection'));
  }

  /// Backpressure (429), a transient 5xx, a client closed by a project swap, or a
  /// dropped stream — none should count as a failed attempt against the task.
  bool _isNotTaskFault(Object e) =>
      _isConnCap(e) ||
      _isTransientServer(e) ||
      _isClosedClient(e) ||
      _isTransientNetwork(e);

  /// Undo one attempt for [taskPk] (used when a turn failed for a reason that
  /// isn't the task's fault, so a flaky gateway can't drive it to Blocked).
  void _undoAttempt(int taskPk) {
    final n = (_attempts[taskPk] ?? 1) - 1;
    if (n <= 0) {
      _attempts.remove(taskPk);
    } else {
      _attempts[taskPk] = n;
    }
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

  /// The orchestration states in which the pump/pipeline is ACTIVE and may drive
  /// work: the normal full build (`running`) and the Editor's snappy fast lane
  /// (`editing`). Every "is the project still going?" check routes through here
  /// so the fast lane can't silently stall the loop by being an unrecognised
  /// state — and so adding another active state later is a one-line change.
  static bool _isActiveState(String? s) => s == 'running' || s == 'editing';

  /// True while the project is still active (running or editing) — used to bail
  /// out of a multi-turn agent stage promptly when the human pauses/stops.
  Future<bool> _stillRunning() async {
    if (_disposed)
      return false; // torn-down orchestrator: never touch _db (ref)
    final project = await _db.getProjectById(projectId);
    return _isActiveState(project?.orchestrationState);
  }

  /// Resolve the inference backend + chat model for [persona] from its connected
  /// server (or the client's first server). Returns null when none exist.
  Future<({InferenceBackend client, String? model})?> _resolveBackend(
    AgentPersona persona, {
    int? taskPk,
  }) async {
    if (_disposed) return null;
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

    final models = chosen.availableModelsJson.isNotEmpty
        ? (jsonDecode(chosen.availableModelsJson) as List).cast<String>()
        : const <String>[];

    // Resolve the worker's model BY TAGS. Fetch the server's full catalog (model
    // labels + collection components) for BOTH routed and local: a collection
    // (e.g. NXS-PJX-Chat) is decomposed to its chat/LLM component so we never send
    // the bare collection id and let the router land on a non-chat component like
    // the embedding model (→ HTTP 400 "does not support chat completion"). An
    // explicit per-persona llmModel still wins; an empty catalog falls back to the
    // collection id as-is. (aiServersCacheProvider is 5-min TTL, so this is cheap.)
    final routed = isRoutedProviderType(chosen.providerType);
    List<ApiModelInfo> serverModels = const [];
    // Best-effort: NEVER let a catalog-fetch failure throw here — it runs on every
    // dispatch and a throw would error the stage → instant re-dispatch → hot loop
    // (observed as "Bad state: Server N not found" spamming when the UI's current
    // client didn't match the project's server). On failure we degrade to the
    // collection id (the resolver's fallback), which still works.
    try {
      final cache = ref.read(aiServersCacheProvider.notifier);
      var entry = cache.entryFor(chosen.server_pk);
      if (entry == null || entry.models.isEmpty) {
        // Look up under the PROJECT's client (not the UI's current client).
        await cache.refreshServerForClient(chosen.server_pk, project.client_fk);
        entry = cache.entryFor(chosen.server_pk);
      }
      serverModels = entry?.models ?? const <ApiModelInfo>[];
    } catch (e) {
      debugPrint(
        '[Orchestrator p$projectId] model catalog unavailable for server '
        '${chosen.server_pk} ($e) — resolving with the collection id as-is.',
      );
    }
    final personaCollection = persona.omniCollectionModel;
    final collection =
        (personaCollection != null && personaCollection.trim().isNotEmpty)
        ? personaCollection.trim()
        : defaultOmniCollectionForTitle(persona.title);
    final pLlm = persona.llmModel;
    // The Router owns modality selection for an Omni collection. Sending its
    // raw Qwen component bypasses that route and lands autonomous work on the
    // shared model pool, where this run received responses from unrelated
    // coding sessions. This mirrors setup/coordinator chat: keep the collection
    // id intact unless the persona explicitly selected a concrete LLM.
    final model = routed
        ? ((pLlm != null && pLlm.trim().isNotEmpty) ? pLlm.trim() : collection)
        : resolveAgentChatModel(
            routed: false,
            personaModel: pLlm,
            selectedModel: chosen.selectedModel,
            serverModels: serverModels,
          );
    debugPrint(
      '[Orchestrator p$projectId] worker "${persona.name}" → server '
      '"${chosen.name}" model=$model (routed=$routed, collection=$collection)',
    );

    final uiServer = ui_server.InferenceServer(
      id: chosen.server_pk.toString(),
      name: chosen.name,
      baseUrl: chosen.baseUrl,
      apiKey: chosen.apiKey,
      // Preserve routed vs self-hosted provenance. LemonadeBackend uses this
      // value to decide whether prompt KV caching is private and safe; labeling
      // the shared Router as local Lemonade enabled an unkeyed cache and leaked
      // stale context from unrelated sessions into autonomous workers.
      providerType: chosen.providerType,
      selectedModel: chosen.selectedModel,
      availableModels: models,
    );
    // Routing session id → the Router pins a session to ONE warm backend and
    // spreads DIFFERENT sessions across the fleet. For concurrent autonomous work
    // we key the session by TASK (not just agent) so several tasks of the SAME
    // persona (e.g. the Generalist doing most of the coding) fan out across
    // backends instead of all piling onto one box — otherwise only ~2 of N worker
    // slots ever get a live connection. A task's own turns reuse its id, so each
    // task still stays warm on its backend. No taskPk (e.g. the one-shot
    // Templater) falls back to the per-agent id.
    final sessionId = taskPk != null
        ? 'agent-${persona.agent_pk}-task-$taskPk-$_routingRunId-${_routingDispatch++}'
        : 'agent-${persona.agent_pk}-$_routingRunId-${_routingDispatch++}';
    return (
      client: backendForServer(
        uiServer,
        agentName: persona.name,
        sessionId: sessionId,
      ),
      model: model,
    );
  }
}

/// The pipeline stage a task is ready for, in execution order.
enum _Stage { implement, verify, build, merge }

/// A live snapshot of the orchestrator's worker-slot usage, published every pump
/// so the UI can explain an idle slot — e.g. a task held back because its files
/// overlap work in flight — instead of just showing fewer agents than the plan
/// allows.
@immutable
class OrchestratorStatus {
  /// Worker pool size = concurrency cap minus the reserved Coordinator slot.
  final int workerSlots;

  /// Tasks in an active pipeline stage right now (implement/verify/build/merge).
  final int activeStages;

  /// One entry per startable-but-blocked task (file-scope holds): its task pk,
  /// the agent assigned to it, and a human-readable reason.
  final List<OrchestratorWait> waiting;

  /// True while the end-of-project TESTING phase is running (CI scan + focused
  /// fix loop). The UI shows a yellow "Testing" stage, like Templating.
  final bool testing;

  /// Human-readable detail for the TESTING phase (e.g. "CI run 2 of 6…").
  final String? testingDetail;

  const OrchestratorStatus({
    this.workerSlots = 0,
    this.activeStages = 0,
    this.waiting = const [],
    this.testing = false,
    this.testingDetail,
  });
}

/// A single held/waiting task in [OrchestratorStatus] — surfaced so the UI can
/// show the blocked slot (which task, which agent, why) instead of just a lower
/// agent count.
@immutable
class OrchestratorWait {
  final int taskPk;
  final int? agentFk;
  final String reason;
  const OrchestratorWait({
    required this.taskPk,
    required this.agentFk,
    required this.reason,
  });
}

/// Per-project orchestrator status the UI reads to surface held/waiting work.
final orchestratorStatusProvider =
    StateProvider.family<OrchestratorStatus, int>(
      (ref, projectId) => const OrchestratorStatus(),
    );

/// One [ProjectOrchestrator] per project. AUTO-DISPOSED: it lives only while the
/// project is FOCUSED (the shell + workspace watch the current project's
/// orchestrator). Switching to another project disposes this one, so the old
/// project stops spawning agents and stops competing for the connection budget —
/// it self-starts again (and resumes if still `running`) when you refocus it.
final projectOrchestratorProvider = Provider.autoDispose
    .family<ProjectOrchestrator, int>((ref, projectId) {
      final orchestrator = ProjectOrchestrator(ref, projectId)..start();
      ref.onDispose(orchestrator.dispose);
      return orchestrator;
    });
