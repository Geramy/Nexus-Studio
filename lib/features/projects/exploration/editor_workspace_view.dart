// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The post-completion EDITOR workspace: a mini-IDE shown in place of the
/// story-tree once a project's autonomous build has FINISHED
/// (orchestrationState == 'completed'). Composes the existing workspace
/// file-tree + code editor with the Editor chat and a Launch button — the
/// stories are demoted to reference (still reachable from the other tabs).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../docker/launch_project_dialog.dart';
import '../../workspace/code_and_git_right_panel.dart';
import '../../workspace/file_browser_view.dart';
import '../orchestration/project_orchestrator.dart';
import 'project_exploration_view.dart' show editorPromptProvider;
import 'stories_chat_sidebar.dart';

class EditorWorkspaceView extends ConsumerWidget {
  const EditorWorkspaceView({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final int projectId;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Keep the orchestrator instance alive while the Editor is open, so the
    // Editor's `start_delegated_build` (which flips the project to `running`)
    // actually spawns worker agents on this already-completed project.
    ref.watch(projectOrchestratorProvider(projectId));
    final promptAsync = ref.watch(
      editorPromptProvider((projectId: projectId, projectName: projectName)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar: title + Launch ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_note_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Editor — "$projectName"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Built & passing. Edit the code, ask the assistant to make '
                      'changes, or launch it.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => LaunchProjectDialog.show(
                  context,
                  projectPk: projectId,
                  db: ref.read(nexusDatabaseProvider),
                ),
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: const Text('Launch'),
              ),
            ],
          ),
        ),
        // ── Body: file tree | code editor + source control | Editor chat ────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 300, child: FileBrowserView()),
              const VerticalDivider(width: 1),
              const Expanded(child: CodeAndGitRightPanel()),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 460,
                child: promptAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Editor error: $e')),
                  data: (prompt) => StoriesChatSidebar(
                    key: ValueKey('editor-sidebar-$projectId'),
                    projectId: projectId,
                    projectName: projectName,
                    editorMode: true,
                    systemPromptOverride: prompt,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
