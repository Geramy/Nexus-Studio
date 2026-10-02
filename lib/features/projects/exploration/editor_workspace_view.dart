// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The post-completion EDITOR workspace: a mini-IDE shown in place of the
/// story-tree once a project's autonomous build has FINISHED
/// (orchestrationState == 'completed'). Composes the existing workspace
/// file-tree + code editor with the Editor chat and a Launch button — the
/// stories are demoted to reference (still reachable from the other tabs).
///
/// The center pane has two modes: CODE (the editor + source control) and
/// VISUAL (the Visual Editor — see the built screens, click to change
/// colors/text/images/spacing, every edit committed + re-captured).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../docker/launch_project_dialog.dart';
import '../../workspace/code_and_git_right_panel.dart';
import '../../workspace/file_browser_view.dart';
import '../orchestration/project_orchestrator.dart';
import '../workspace_nav.dart';
import 'project_exploration_view.dart' show editorPromptProvider;
import 'stories_chat_sidebar.dart';
import 'visual_editor/visual_editor_view.dart';

class EditorWorkspaceView extends ConsumerStatefulWidget {
  const EditorWorkspaceView({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  final int projectId;
  final String projectName;

  @override
  ConsumerState<EditorWorkspaceView> createState() => _EditorWorkspaceViewState();
}

class _EditorWorkspaceViewState extends ConsumerState<EditorWorkspaceView> {
  bool _visual = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "Launch with Editor" (Overview tab) bumps this; flip to the Visual pane.
    ref.listen<int>(requestVisualEditorProvider, (prev, next) {
      if (next != (prev ?? 0)) setState(() => _visual = true);
    });
    // Keep the orchestrator instance alive while the Editor is open, so the
    // Editor's `start_delegated_build` (which flips the project to `running`)
    // actually spawns worker agents on this already-completed project.
    ref.watch(projectOrchestratorProvider(widget.projectId));
    final promptAsync = ref.watch(
      editorPromptProvider((projectId: widget.projectId, projectName: widget.projectName)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar: title + Visual|Code + Launch ──────────────────────────
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
                      'Editor — "${widget.projectName}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _visual
                          ? 'Point at what to change — every edit is committed to the code.'
                          : 'Built & passing. Edit the code, ask the assistant to make '
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.code, size: 16),
                    label: Text('Code'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.touch_app_outlined, size: 16),
                    label: Text('Visual'),
                  ),
                ],
                selected: {_visual},
                onSelectionChanged: (s) =>
                    setState(() => _visual = s.first),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => LaunchProjectDialog.show(
                  context,
                  projectPk: widget.projectId,
                  db: ref.read(nexusDatabaseProvider),
                ),
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: const Text('Launch'),
              ),
            ],
          ),
        ),
        // ── Body: file tree | code/visual | Editor chat ─────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 300, child: FileBrowserView()),
              const VerticalDivider(width: 1),
              _visual
                  ? Expanded(
                      child: VisualEditorView(
                        key: ValueKey('visual-${widget.projectId}'),
                        projectId: widget.projectId,
                        onViewCode: () => setState(() => _visual = false),
                        onOpenChat: () {}, // chat pane is already visible
                      ),
                    )
                  : const Expanded(child: CodeAndGitRightPanel()),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 460,
                child: promptAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Editor error: $e')),
                  data: (prompt) => StoriesChatSidebar(
                    key: ValueKey('editor-sidebar-${widget.projectId}'),
                    projectId: widget.projectId,
                    projectName: widget.projectName,
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
