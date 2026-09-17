// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show Project;
import 'package:nexus_projects_client/features/project_plans/plan_store.dart';
import 'package:nexus_projects_client/features/project_setup/setup_inference.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/git_engine_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_provider.dart';
import 'package:nexus_projects_client/features/projects/orchestration/project_orchestrator.dart'
    show orchestratorStatusProvider;
import 'package:nexus_projects_client/features/projects/planning/planning_progress.dart';
import 'package:nexus_projects_client/features/projects/planning/project_planning_run.dart';
import 'package:nexus_projects_client/features/projects/task_workflow.dart';
import 'package:nexus_projects_client/features/projects/project_working_hours.dart';

/// Start / Pause / Stop control bar for a project's autonomous worker-spawn
/// loop. Flips the project's `orchestrationState` in the DB; the orchestration
/// driver (a provider keyed by project) watches that state and reacts. Also
/// offers "Build the plan" — re-runs the deep planning agent on demand.
class ProjectOrchestrationControls extends ConsumerStatefulWidget {
  final int projectId;

  /// Compact mode renders just the buttons (for a toolbar); otherwise it adds
  /// a status line + the working-hours summary.
  final bool compact;

  const ProjectOrchestrationControls({
    super.key,
    required this.projectId,
    this.compact = false,
  });

  @override
  ConsumerState<ProjectOrchestrationControls> createState() =>
      _ProjectOrchestrationControlsState();
}

class _ProjectOrchestrationControlsState
    extends ConsumerState<ProjectOrchestrationControls> {
  bool _building = false;
  String? _buildStatus;

  int get projectId => widget.projectId;
  bool get compact => widget.compact;

  /// Re-run the deep planning agent: expand the plans, engineers review, build
  /// any new tasks, and start orchestration. Progress shows on the button.
  Future<void> _buildPlan() async {
    final db = ref.read(nexusDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final clientId = ref.read(currentClientIdProvider);
    final resolved = await ref.read(
      projectInferenceProvider((
        projectId: projectId,
        clientId: clientId,
      )).future,
    );
    if (resolved == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Add an inference server in Agents Hub to build the plan.',
          ),
        ),
      );
      return;
    }
    final planStore = await ref.read(planStoreProvider(projectId).future);
    final proj = await db.getProjectById(projectId);
    final progress = ref.read(planningProgressProvider(projectId).notifier);
    Workspace? ws;
    NxtprjGitEngine? git;
    try {
      ws = await ref.read(workspaceFsProvider(projectId).future);
      git = await ref.read(gitEngineProvider(projectId).future);
    } catch (_) {}
    setState(() {
      _building = true;
      _buildStatus = 'Starting…';
    });
    progress.start();
    try {
      final result = await ProjectPlanningRun(
        db: db,
        planStore: planStore,
        backend: resolved.backend,
        projectId: projectId,
        projectName: proj?.name ?? 'Project',
        model: resolved.model,
        enableThinking: resolved.enableThinking,
        reasoningEffort: resolved.reasoningEffort,
        workspace: ws,
        git: git,
        scaffold: (proj?.projectType ?? '') == 'application-development',
        brief:
            'Deepen and complete the existing /PLANS: cover anything missing '
            'and split any oversized outline items into small ones.',
        onProgress: (line) {
          progress.add(line);
          if (mounted) setState(() => _buildStatus = line);
        },
      ).run();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Plan built — ${result.tasksCreated} new task(s); agents started.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Build the plan failed: $e')),
      );
    } finally {
      progress.finish();
      if (mounted) {
        setState(() {
          _building = false;
          _buildStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(nexusDatabaseProvider);
    return StreamBuilder<Project?>(
      stream: db.watchProject(projectId),
      builder: (context, snap) {
        final project = snap.data;
        final state = project?.orchestrationState ?? 'stopped';
        final running = state == 'running';
        final paused = state == 'paused';

        Future<void> set(String s) =>
            db.setProjectOrchestrationState(projectId, s);

        final buildButton = _building
            ? OutlinedButton.icon(
                onPressed: null,
                icon: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: const Text('Building…'),
              )
            : OutlinedButton.icon(
                onPressed: _buildPlan,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Build the plan'),
              );

        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!running)
              FilledButton.icon(
                onPressed: () => set('running'),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(paused ? 'Resume' : 'Start'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => set('paused'),
                icon: const Icon(Icons.pause, size: 18),
                label: const Text('Pause'),
              ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: state == 'stopped' ? null : () => set('stopped'),
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop'),
            ),
            const SizedBox(width: 8),
            buildButton,
          ],
        );

        if (compact) return buttons;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StateDot(state: state),
                const SizedBox(width: 8),
                Text(switch (state) {
                  'running' => 'Orchestration running',
                  'paused' => 'Orchestration paused',
                  'completed' => 'Project complete — CI passing ✓',
                  _ => 'Orchestration stopped',
                }, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (running) ...[
                  const SizedBox(width: 10),
                  _ActiveAgentsChip(projectId: projectId),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (project != null)
              Text(
                'Working hours: ${workingHoursSummary(project)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            const SizedBox(height: 12),
            buttons,
            if (_buildStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                _buildStatus!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StateDot extends StatelessWidget {
  final String state;
  const _StateDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      'running' => Colors.green,
      'paused' => Colors.orange,
      'completed' => Colors.blue,
      _ => Colors.grey,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Live count of agents working right now (tasks in an active execution phase),
/// so the user can see parallelism actually happening.
class _ActiveAgentsChip extends ConsumerWidget {
  const _ActiveAgentsChip({required this.projectId});
  final int projectId;

  static const _active = {
    TaskExecStatus.running,
    TaskExecStatus.verifying,
    TaskExecStatus.building,
    TaskExecStatus.merging,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(allTasksForProjectProvider(projectId)).value;
    final n = tasks == null
        ? 0
        : tasks.where((t) => _active.contains(t.executionStatus)).length;
    // Held/waiting work — startable tasks blocked because their files overlap a
    // task in flight. This is why a slot can sit idle and the agent count looks
    // lower than the plan allows; surface it instead of silently showing fewer.
    final status = ref.watch(orchestratorStatusProvider(projectId));
    final waiting = status.waiting;
    if (n == 0 && waiting.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Break the active count down by stage so the user can tell a coding worker
    // from a reviewer / integrator occupying a slot.
    int cnt(String s) =>
        tasks == null ? 0 : tasks.where((t) => t.executionStatus == s).length;
    final breakdown = [
      if (cnt(TaskExecStatus.running) > 0) '${cnt(TaskExecStatus.running)} coding',
      if (cnt(TaskExecStatus.verifying) > 0)
        '${cnt(TaskExecStatus.verifying)} reviewing',
      if (cnt(TaskExecStatus.building) > 0)
        '${cnt(TaskExecStatus.building)} building',
      if (cnt(TaskExecStatus.merging) > 0)
        '${cnt(TaskExecStatus.merging)} integrating',
    ].join(' · ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (n > 0)
          Tooltip(
            message: breakdown.isEmpty ? '' : 'Slots: $breakdown',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 13, color: theme.colorScheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '$n agent${n == 1 ? '' : 's'} working',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (waiting.isNotEmpty) ...[
          if (n > 0) const SizedBox(width: 6),
          Tooltip(
            message: waiting
                .map((w) => 'Task #${w.taskPk} waiting — ${w.reason}')
                .join('\n'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 13,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${waiting.length} waiting (file held)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Editor for a project's working-hours window: an enable toggle, start/end
/// time pickers, and weekday chips. Writes through to the DB on every change.
class ProjectWorkingHoursEditor extends ConsumerWidget {
  final int projectId;
  const ProjectWorkingHoursEditor({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(nexusDatabaseProvider);
    return StreamBuilder<Project?>(
      stream: db.watchProject(projectId),
      builder: (context, snap) {
        final project = snap.data;
        if (project == null) return const SizedBox.shrink();

        final enabled = project.workHoursEnabled;
        final start = project.workHoursStart;
        final end = project.workHoursEnd;
        final mask = project.workDaysMask ?? 0;

        Future<void> save({
          bool? en,
          int? s,
          int? e,
          int? dm,
          bool clearStart = false,
          bool clearEnd = false,
        }) {
          return db.setProjectWorkingHours(
            projectId,
            enabled: en ?? enabled,
            start: clearStart ? null : (s ?? start),
            end: clearEnd ? null : (e ?? end),
            daysMask: dm ?? mask,
          );
        }

        Future<void> pick(bool isStart) async {
          final initialMin =
              (isStart ? start : end) ?? (isStart ? 9 * 60 : 17 * 60);
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: initialMin ~/ 60,
              minute: initialMin % 60,
            ),
          );
          if (picked == null) return;
          final m = picked.hour * 60 + picked.minute;
          await save(s: isStart ? m : null, e: isStart ? null : m);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Limit work to specific hours'),
              subtitle: const Text(
                'Outside these hours the loop idles even while running.',
              ),
              value: enabled,
              onChanged: (v) => save(en: v),
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pick(true),
                      child: Text('Start: ${formatMinutesOfDay(start)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => pick(false),
                      child: Text('End: ${formatMinutesOfDay(end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Active days',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(kWeekdayShortLabels[i]),
                      selected: mask == 0 || (mask & (1 << i)) != 0,
                      onSelected: (sel) {
                        // mask 0 means "every day"; first toggle materializes it.
                        var m = mask == 0 ? 0x7F : mask;
                        if (sel) {
                          m |= (1 << i);
                        } else {
                          m &= ~(1 << i);
                        }
                        save(dm: m & 0x7F);
                      },
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
