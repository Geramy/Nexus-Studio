// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/features/projects/planning/planning_progress.dart';
import 'package:nexus_projects_client/features/tasks/widgets/task_kanban_board.dart';

/// Project work area with multiple views (List tree + Kanban, etc.).
/// Moved from main/widgets/ during organization refactor (2026-05).
/// This is the main "Project Overview" surface for tasks under the current project.
enum TaskViewMode { list, kanban }

class TasksView extends ConsumerStatefulWidget {
  final Function(int) onTaskSelected;

  const TasksView({super.key, required this.onTaskSelected});

  @override
  ConsumerState<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends ConsumerState<TasksView> {
  TaskViewMode _viewMode = TaskViewMode.list;
  // Which task source the board shows: the original autonomous BUILD tasks, or
  // the post-build EDITOR's edits. Editor edits are filed here (not merged into
  // the build board) so a long editing session doesn't bloat the build history.
  bool _showEdits = false;
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedTaskIdProvider);
    final currentProjectId = ref.watch(currentProjectIdProvider);
    final allTasksAsync = ref.watch(
      allTasksForProjectProvider(currentProjectId),
    );
    final planning = ref.watch(planningProgressProvider(currentProjectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (planning.running) _PlanningBanner(line: planning.latest),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Title + count
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  allTasksAsync.when(
                    data: (tasks) => Chip(
                      label: Text(
                        '${tasks.where((t) => t.isEdit == _showEdits).length} items',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    loading: () => const Chip(label: Text('...')),
                    error: (_, __) => const Chip(label: Text('Error')),
                  ),
                ],
              ),

              // Build ↔ Edits source toggle — only shown once the Editor has
              // created edit tasks, so it stays out of the way during the build.
              allTasksAsync.maybeWhen(
                data: (tasks) {
                  final hasEdits = tasks.any((t) => t.isEdit);
                  if (!hasEdits) return const SizedBox.shrink();
                  final editCount = tasks.where((t) => t.isEdit).length;
                  final buildCount = tasks.length - editCount;
                  return SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.construction, size: 18),
                        label: Text('Build ($buildCount)'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: Text('Edits ($editCount)'),
                      ),
                    ],
                    selected: {_showEdits},
                    onSelectionChanged: (s) =>
                        setState(() => _showEdits = s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

              // View mode switcher
              SegmentedButton<TaskViewMode>(
                segments: const [
                  ButtonSegment(
                    value: TaskViewMode.list,
                    icon: Icon(Icons.list_alt, size: 18),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: TaskViewMode.kanban,
                    icon: Icon(Icons.view_kanban, size: 18),
                    label: Text('Kanban'),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (Set<TaskViewMode> newSelection) {
                  setState(() => _viewMode = newSelection.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ),

              // New Task button
              FilledButton.icon(
                onPressed: () => _showAddTaskDialog(currentProjectId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: allTasksAsync.when(
            data: (allSourceTasks) {
              // Show only the selected source (build vs editor edits).
              final allTasks = allSourceTasks
                  .where((t) => t.isEdit == _showEdits)
                  .toList();
              if (_viewMode == TaskViewMode.kanban) {
                return TaskKanbanBoard(
                  tasks: allTasks,
                  selectedTaskId: selectedId,
                  onTaskSelected: widget.onTaskSelected,
                );
              }

              // Default: hierarchical list (existing tree view)
              final root = allTasks
                  .where((t) => t.task_parent_fk == null)
                  .toList();
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: root
                    .map((t) => _buildNode(t, allTasks, selectedId))
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildNode(dynamic task, List<dynamic> all, int? sel) {
    final children = all
        .where((t) => t.task_parent_fk == task.task_pk)
        .toList();
    final exp = _expanded.contains(task.task_pk);
    final selct = task.task_pk == sel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            widget.onTaskSelected(task.task_pk);
            ref
                .read(selectedTaskIdProvider.notifier)
                .selectTask(task.task_pk);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selct
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (children.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      exp ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    onPressed: () => setState(
                      () => exp
                          ? _expanded.remove(task.task_pk)
                          : _expanded.add(task.task_pk),
                    ),
                  )
                else
                  const SizedBox(width: 20),
                Text('#${task.task_pk} ${task.title}'),
                Chip(
                  label: Text(
                    task.status,
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        if (exp && children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: children.map((c) => _buildNode(c, all, sel)).toList(),
            ),
          ),
      ],
    );
  }

  void _showAddTaskDialog(int projectId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New Task'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(nexusDatabaseProvider)
                    .createTaskInProject(
                      projectPk: projectId,
                      title: ctrl.text.trim(),
                    );
                Navigator.pop(c);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Slim strip shown above the task board while the planning agent is running,
/// so the user can watch what it's doing after being redirected here from setup.
class _PlanningBanner extends StatelessWidget {
  const _PlanningBanner({required this.line});
  final String? line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line ?? 'Planning your project…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
