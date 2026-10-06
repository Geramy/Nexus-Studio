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

import 'dart:math' as math;

import '../../../core/providers/database_provider.dart';
import '../../docker/launch_project_dialog.dart';
import '../../workspace/code_and_git_right_panel.dart';
import '../../workspace/file_browser_view.dart';
import '../orchestration/project_orchestrator.dart';
import '../workspace_nav.dart';
import 'draggable_divider.dart';
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
  // Drag-resizable panel widths.
  double _treeW = 300;
  double _chatW = 420;
  // The Agent chat collapses to a slim rail — by default in Visual mode,
  // where the canvas wants every pixel.
  bool _chatCollapsed = false;

  void _setVisual(bool v) {
    setState(() {
      _visual = v;
      if (v) _chatCollapsed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "Launch with Editor" (Overview tab) bumps this; flip to the Visual pane.
    ref.listen<int>(requestVisualEditorProvider, (prev, next) {
      if (next != (prev ?? 0)) _setVisual(true);
    });
    // Keep the orchestrator instance alive while the Editor is open, so the
    // Editor's `start_delegated_build` (which flips the project to `running`)
    // actually spawns worker agents on this already-completed project.
    ref.watch(projectOrchestratorProvider(widget.projectId));

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
                    icon: Icon(Icons.auto_awesome, size: 16),
                    label: Text('Agent'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.touch_app_outlined, size: 16),
                    label: Text('Visual'),
                  ),
                ],
                selected: {_visual},
                onSelectionChanged: (s) => _setVisual(s.first),
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
        // ── Body: [file tree |] Agent/Visual | Agent chat ──────────────────
        // In Visual mode the file tree disappears (code IS what the canvas
        // edits — no need for two views of the same thing) and the Agent chat
        // collapses to a slim rail. Every border is drag-resizable.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_visual) ...[
                SizedBox(width: _treeW, child: const FileBrowserView()),
                DraggableVerticalDivider(
                  onDelta: (dx) => setState(() {
                    _treeW = (_treeW + dx).clamp(220.0, 520.0);
                  }),
                ),
              ],
              Expanded(
                child: _visual
                    ? VisualEditorView(
                        key: ValueKey('visual-${widget.projectId}'),
                        projectId: widget.projectId,
                        onViewCode: () => _setVisual(false),
                        onOpenChat: () {}, // chat pane is right there
                      )
                    : const CodeAndGitRightPanel(),
              ),
              if (!_chatCollapsed)
                DraggableVerticalDivider(
                  onDelta: (dx) => setState(() {
                    _chatW = (_chatW - dx).clamp(280.0, 640.0);
                  }),
                ),
              _chatCollapsed
                  ? _CollapsedAgentRail(
                      onExpand: () =>
                          setState(() => _chatCollapsed = false),
                    )
                  : SizedBox(
                      width: _chatW,
                      child: _EditorPromptPane(
                        projectId: widget.projectId,
                        projectName: widget.projectName,
                        onCollapse: () =>
                            setState(() => _chatCollapsed = true),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The collapsed Agent chat: a slim rail so it's one click away in Visual
/// mode without costing the canvas any meaningful space.
class _CollapsedAgentRail extends StatelessWidget {
  const _CollapsedAgentRail({required this.onExpand});
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 42,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Tooltip(
              message: 'Show Agent chat',
              child: IconButton(
                iconSize: 18,
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: onExpand,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Transform.rotate(
            angle: math.pi / 2,
            child: Text(
              'Agent',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// The editor's chat sidebar, wired to the project's editor prompt. A small
/// collapse button tucks it into the slim rail (see [_CollapsedAgentRail]).
class _EditorPromptPane extends ConsumerWidget {
  const _EditorPromptPane({
    required this.projectId,
    required this.projectName,
    required this.onCollapse,
  });
  final int projectId;
  final String projectName;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final promptAsync = ref.watch(editorPromptProvider(
        (projectId: projectId, projectName: projectName)));
    return Stack(
      children: [
        Positioned.fill(
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
        Positioned(
          top: 4,
          right: 4,
          child: Tooltip(
            message: 'Collapse Agent chat',
            child: InkWell(
              onTap: onCollapse,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.chevron_right,
                    size: 18, color: theme.hintColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
