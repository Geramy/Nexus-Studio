// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_shell_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../infrastructure/workspace/workspace_provider.dart';
import 'setup_chat_controller.dart';
import 'tag_board_view.dart';
import 'workspace_tag_observer.dart';

/// The always-available Project Setup tab. The Tag Board fills this center pane;
/// the AI interview runs as a chat in the MainShell right outer panel
/// ([SetupInterviewPanel]), sharing state via [setupChatControllerProvider].
class SetupTab extends ConsumerStatefulWidget {
  const SetupTab({super.key, required this.projectId, required this.clientId});

  final int projectId;
  final int clientId;

  @override
  ConsumerState<SetupTab> createState() => _SetupTabState();
}

class _SetupTabState extends ConsumerState<SetupTab> {
  ({int projectId, int clientId}) get _key =>
      (projectId: widget.projectId, clientId: widget.clientId);

  @override
  void initState() {
    super.initState();
    _observeWorkspace();
  }

  /// Best-effort: turn real manifests (pubspec/Cargo/etc.) into accepted,
  /// workspace-sourced tags so the board reflects what's actually in the tree.
  Future<void> _observeWorkspace() async {
    try {
      final workspace = await ref.read(
        workspaceFsProvider(widget.projectId).future,
      );
      final observer = WorkspaceTagObserver(
        workspace: workspace,
        db: ref.read(nexusDatabaseProvider),
      );
      await observer.scan(widget.projectId);
    } catch (_) {
      // Workspace may not exist yet — ignore.
    }
  }

  /// The single final setup step: generate the plan files (in the background,
  /// for the Plan tab) AND finish setup, then go STRAIGHT to the post-setup
  /// Exploration screen (the user-story / workflow step). No second "done"
  /// button, no separate refine stage.
  Future<void> _finalizeAndExplore() async {
    final controller = ref.read(setupChatControllerProvider(_key));
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Gate: every REQUIRED section (industries, platforms, objectives, features,
    // languages, frameworks, libraries + any industry sub-axis like Genre) must
    // have a tag before we generate the plan — no continuing on a half-filled
    // profile. Databases/services are optional and don't block.
    final gaps = await controller.setupCompletenessGaps();
    if (!mounted) return;
    if (gaps.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            'Fill these before generating the plan: ${gaps.join(', ')}. '
            'Keep talking with the host (or add them on the board) — or use Skip '
            'to set up later.',
          ),
        ),
      );
      return;
    }

    // Write the durable state FIRST (setupStatus=complete, explorationStatus=
    // active) so it can't race the background plan generation below.
    await controller.completeSetup();
    if (!mounted) return;

    // Generate /PLANS in the background — don't make the user wait. Uses the
    // plans-only path so it can't revert setupStatus back to 'refining' and
    // clobber the 'complete' that completeSetup just wrote.
    unawaited(() async {
      try {
        await controller.finalizePlansOnly();
      } catch (_) {
        /* best-effort; the user stories drive tasks now */
      }
    }());

    // Take the user to the project workspace, which now shows the two-pane
    // Exploration screen (user-story tree + discovery chat).
    ref.read(currentMainViewProvider.notifier).setView(MainView.projectPlans);
    navigator.maybePop(); // close the full-screen setup wizard
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 6),
        content: Text(
          'Initial project setup is done — now let\'s build out your user '
          'stories and workflow.',
        ),
      ),
    );
  }

  Future<void> _skip() async {
    await ref.read(setupChatControllerProvider(_key)).skip();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup skipped — you can finish it any time.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the action bar's busy state tracks the shared interview.
    final busy = ref.watch(
      setupChatControllerProvider(_key).select((c) => c.busy),
    );
    return Column(
      children: [
        _ActionBar(
          busy: busy,
          onSkip: _skip,
          onFinalize: _finalizeAndExplore,
        ),
        const Divider(height: 1),
        Expanded(child: TagBoardView(projectPk: widget.projectId)),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onSkip,
    required this.onFinalize,
  });

  final bool busy;
  final VoidCallback onSkip;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.checklist_rtl, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Project Setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onSkip,
            child: const Text('Skip'),
          ),
          const SizedBox(width: 8),
          // The ONE final step: generate the plan, finish setup, and continue
          // straight to the user-story / workflow (Exploration) screen.
          FilledButton.icon(
            onPressed: busy ? null : onFinalize,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Generate plan & continue to user stories'),
          ),
        ],
      ),
    );
  }
}
