// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The project's persistent, resumable **User Stories** screen (the default
/// workspace tab): a UML-style user-story tree in the center, a "Generate tasks
/// from stories" header, and the Coordinator **Chat | History** sidebar on the
/// right. While the project is still in discovery (explorationStatus !=
/// 'complete') the Coordinator runs the story-building interview and speaks
/// first; once tasks are generated the screen stays available (normal chat) for
/// refining the tree and regenerating. Because it's an ordinary tab — not a
/// one-shot full-screen phase — leaving and returning always resumes the same
/// stories + conversation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../project_setup/providers/tag_providers.dart';
import 'exploration_session.dart';
import 'stories_chat_sidebar.dart';
import 'story_providers.dart';
import 'story_tree_canvas.dart';
import 'task_generator.dart';

/// The discovery system prompt, seeded from the project's setup profile.
final discoveryPromptProvider =
    FutureProvider.family<String, ({int projectId, String projectName})>((
      ref,
      key,
    ) {
      final db = ref.watch(nexusDatabaseProvider);
      return buildDiscoveryPrompt(db, key.projectId, key.projectName);
    });

class ProjectExplorationView extends ConsumerWidget {
  const ProjectExplorationView({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final int projectId;
  final String projectName;

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    // Nothing to generate from: don't mark exploration "complete" on an empty
    // tree (that would strand the project with no tasks and no orchestration).
    // Send the user back to build at least one story first.
    final stories =
        ref.read(projectStoriesProvider(projectId)).valueOrNull ?? const [];
    if (stories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No user stories yet — talk it through with the Coordinator (or add '
            'a story) to capture at least one, then generate tasks.',
          ),
        ),
      );
      return;
    }
    // Walk the tree: each story → its own scoped AI session → 1..N tasks. The
    // run keeps us on this screen (explorationStatus stays 'active' until done)
    // and updates per-story progress; the canvas shows a bar on each story.
    try {
      await ref.read(taskGeneratorProvider(projectId)).run();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task generation failed: $e')),
      );
      return;
    }
    if (!context.mounted) return; // generation can take minutes
    final p = ref.read(taskGeneratorProvider(projectId)).progress;
    final base =
        'Generated ${p.totalTasks} task${p.totalTasks == 1 ? '' : 's'} '
        'from ${p.totalStories} stor${p.totalStories == 1 ? 'y' : 'ies'}.';
    // Don't report a cheerful success when nothing was created or stories errored
    // — show the real reason so a broken backend/DB is visible, not hidden.
    final detail = p.failedStories > 0
        ? ' ${p.failedStories} stor${p.failedStories == 1 ? 'y' : 'ies'} failed'
              '${p.error != null ? ': ${p.error}' : ''}.'
        : (p.totalTasks == 0 && p.error != null ? ' Error: ${p.error}' : '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$base$detail')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stories = ref.watch(projectStoriesProvider(projectId)).valueOrNull ?? const [];
    final progress = ref.watch(taskGeneratorProvider(projectId)).progress;

    // This screen is PERSISTENT and resumable — it's the project's main "User
    // Stories" surface, not a one-shot phase. While the project hasn't finished
    // generating tasks yet (explorationStatus != 'complete') it's in DISCOVERY:
    // the Coordinator runs the story-building interview (story-only tools, speaks
    // first). Once tasks have been generated it stays available for editing the
    // tree and regenerating, with the normal Coordinator chat.
    final explorationStatus =
        ref.watch(projectRowProvider(projectId)).valueOrNull?.explorationStatus;
    final isDiscovery = explorationStatus != 'complete';
    final promptAsync = isDiscovery
        ? ref.watch(
            discoveryPromptProvider((
              projectId: projectId,
              projectName: projectName,
            )),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header / action bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(
                isDiscovery ? Icons.explore_outlined : Icons.account_tree_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'User Stories — "$projectName"',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isDiscovery
                          ? 'Talk it through with the Coordinator — build out the '
                                'user stories, then generate tasks when the idea is solid.'
                          : 'Your user-story map. Refine it with the Coordinator and '
                                'regenerate tasks any time.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (progress.running)
                // Stay on this screen while building; show overall progress.
                SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Building tasks… ${progress.doneStories}/'
                        '${progress.totalStories} stories · '
                        '${progress.totalTasks} tasks',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress.totalStories == 0
                            ? null
                            : progress.fraction,
                        minHeight: 5,
                      ),
                    ],
                  ),
                )
              else ...[
                // "Skip & generate" is only an option during the initial build.
                if (isDiscovery) ...[
                  TextButton(
                    onPressed: () => _generate(context, ref),
                    child: const Text('Skip & generate'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: stories.isEmpty
                      ? null
                      : () => _generate(context, ref),
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: Text(
                    'Generate tasks from stories'
                    '${stories.isEmpty ? '' : ' (${stories.length})'}',
                  ),
                ),
              ],
            ],
          ),
        ),
        // ── Story tree (center) + Coordinator Chat | History sidebar ──────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: UserStoriesView(projectId: projectId)),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 460,
                // Same Chat | History sidebar throughout: discovery interview
                // while building, then the normal Coordinator. The conversation
                // (general project session) carries across the transition.
                child: isDiscovery
                    ? promptAsync!.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Discovery error: $e')),
                        data: (prompt) => StoriesChatSidebar(
                          key: ValueKey('stories-sidebar-discovery-$projectId'),
                          projectId: projectId,
                          projectName: projectName,
                          discoveryMode: true,
                          systemPromptOverride: prompt,
                          autoOpenPrompt: kDiscoveryAutoOpen,
                        ),
                      )
                    : StoriesChatSidebar(
                        key: ValueKey('stories-sidebar-normal-$projectId'),
                        projectId: projectId,
                        projectName: projectName,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
