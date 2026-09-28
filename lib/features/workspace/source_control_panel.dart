// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git_status.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/git_engine_provider.dart';

/// Source Control panel: the "git resolution" surface. Per-file CHECKBOXES
/// pick which paths the next commit includes; engine.commitFiles writes a
/// tree where unchecked paths retain their HEAD content untouched.
class SourceControlPanel extends ConsumerStatefulWidget {
  const SourceControlPanel({super.key});

  @override
  ConsumerState<SourceControlPanel> createState() => _SourceControlPanelState();
}

class _SourceControlPanelState extends ConsumerState<SourceControlPanel> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _committing = false;

  /// Workspace paths the user has UNchecked (won't be in the next commit).
  /// We track unchecks rather than checks so new dirty paths default to
  /// "included" automatically.
  final Set<String> _excluded = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(currentProjectIdProvider);
    final gitAsync = ref.watch(gitStatusProvider(projectId));
    final git = gitAsync.value ?? GitStatusSnapshot.noRepo;

    final changes =
        git.byPath.entries.where((e) => gitStatusIsDirty(e.value)).toList()
          ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final selectedCount = changes
        .where((e) => !_excluded.contains(e.key))
        .length;
    // Drop any excluded paths no longer in the changes list.
    final liveKeys = changes.map((e) => e.key).toSet();
    _excluded.retainAll(liveKeys);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, projectId, git),
        const Divider(height: 1),
        _commitForm(context, projectId, selectedCount),
        const Divider(height: 1),
        Expanded(
          child: _changesList(
            context,
            projectId,
            changes,
            selectedCount,
            gitAsync.hasError,
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, int projectId, GitStatusSnapshot git) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.source_outlined, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Source Control',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (git.hasRepo)
            Chip(
              avatar: const Icon(
                Icons.call_split,
                size: 12,
                color: Colors.grey,
              ),
              label: Text(
                git.branch ?? '(detached)',
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.upload, size: 18),
            tooltip: 'Push',
            onPressed: () {
              debugPrint('[ui] push tapped (remote layer not wired)');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Push needs a remote configured — the Remote layer lands next.',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(gitStatusRevisionProvider(projectId).notifier).state++,
          ),
        ],
      ),
    );
  }

  Widget _commitForm(BuildContext context, int projectId, int selectedCount) {
    final canCommit =
        selectedCount > 0 && !_committing && _titleCtrl.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Commit title',
              hintText: 'Short summary of this change',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Why this change, anything reviewers should know…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canCommit ? () => _commit(context, projectId) : null,
            icon: _committing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.commit, size: 16),
            label: Text(
              _committing
                  ? 'Committing…'
                  : selectedCount > 0
                  ? 'Commit $selectedCount selected'
                  : 'Nothing selected',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _commit(BuildContext context, int projectId) async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty) return;
    // Build the set of selected paths.
    final git = ref.read(gitStatusProvider(projectId)).value;
    if (git == null) return;
    final selected = git.byPath.entries
        .where((e) => gitStatusIsDirty(e.value) && !_excluded.contains(e.key))
        .map((e) => e.key)
        .toList();
    if (selected.isEmpty) return;
    setState(() => _committing = true);
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      final message = desc.isEmpty ? title : '$title\n\n$desc';
      final oid = await engine.commitFiles(paths: selected, message: message);
      _titleCtrl.clear();
      _descCtrl.clear();
      _excluded.clear();
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      debugPrint(
        '[git] commit ok: ${oid.substring(0, 7)} (${selected.length} file(s))',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Committed ${oid.substring(0, 7)} (${selected.length} files)',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      debugPrint('[git] commit failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Commit failed: $e')));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  Widget _changesList(
    BuildContext context,
    int projectId,
    List<MapEntry<String, GitFileStatus>> changes,
    int selectedCount,
    bool gitErrored,
  ) {
    if (gitErrored) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Git engine failed to start. Check the console for "[git]" lines.',
          style: TextStyle(fontSize: 12, color: Colors.red),
        ),
      );
    }
    if (changes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No changes — working tree is clean.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
          child: Row(
            children: [
              Text(
                'Changes ($selectedCount/${changes.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _excluded.clear()),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Select All', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _excluded.addAll(changes.map((e) => e.key))),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Select None',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: changes.length,
            itemBuilder: (_, i) => _changeRow(
              context,
              projectId,
              changes[i].key,
              changes[i].value,
            ),
          ),
        ),
      ],
    );
  }

  Widget _changeRow(
    BuildContext context,
    int projectId,
    String path,
    GitFileStatus status,
  ) {
    final deco = gitDecorationFor(status);
    final basename = path.split('/').last;
    final dirname = path.substring(
      0,
      path.length - basename.length - (path == '/$basename' ? 1 : 0),
    );
    final included = !_excluded.contains(path);
    return InkWell(
      onTap: () =>
          ref.read(selectedWorkspaceFileProvider(projectId).notifier).state =
              path,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: included,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _excluded.remove(path);
                } else {
                  _excluded.add(path);
                }
              }),
            ),
            if (deco != null && deco.badge.isNotEmpty)
              SizedBox(
                width: 18,
                child: Tooltip(
                  message: deco.tooltip,
                  child: Text(
                    deco.badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: deco.color,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: DefaultTextStyle.of(
                    context,
                  ).style.copyWith(fontSize: 12),
                  children: [
                    TextSpan(
                      text: basename,
                      style: TextStyle(color: deco?.color),
                    ),
                    if (dirname.isNotEmpty)
                      TextSpan(
                        text: ' $dirname',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.undo, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: status == GitFileStatus.untracked
                  ? 'Delete (untracked)'
                  : 'Discard changes',
              onPressed: () => _discard(context, projectId, path, status),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(
    BuildContext context,
    int projectId,
    String path,
    GitFileStatus status,
  ) async {
    final isUntracked = status == GitFileStatus.untracked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isUntracked ? 'Delete untracked file?' : 'Discard changes?',
        ),
        content: Text(
          isUntracked
              ? 'Remove "$path" from the workspace? It is not in any commit, so this cannot be undone.'
              : 'Restore "$path" to its committed (HEAD) version? Your uncommitted changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isUntracked ? 'Delete' : 'Discard',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final fs = await ref.read(workspaceFsProvider(projectId).future);
      if (isUntracked) {
        await fs.delete(path);
        if (ref.read(selectedWorkspaceFileProvider(projectId)) == path) {
          ref.read(selectedWorkspaceFileProvider(projectId).notifier).state =
              null;
        }
      } else {
        // Tracked (modified or deleted): restore the HEAD blob into the workspace.
        final engine = await ref.read(gitEngineProvider(projectId).future);
        final bytes = await engine.headFileBytes(path);
        if (bytes == null) {
          debugPrint(
            '[git] discard: "$path" has no HEAD blob (treating as no-op)',
          );
        } else {
          await fs.writeBytes(path, bytes);
        }
      }
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
      debugPrint('[git] discard ok: $path (${status.name})');
    } catch (e, st) {
      debugPrint('[git] discard failed for $path: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Discard failed: $e')));
    }
  }
}
