// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git_status.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/git_engine_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';

import 'commit_diff_view.dart';

typedef _Commit = ({String oid, String message, DateTime when, String author});

/// Commit history with expandable file-level diff (added/modified/deleted)
/// per commit. Refreshes when the status revision bumps (after a new commit).
class CommitHistoryPanel extends ConsumerStatefulWidget {
  const CommitHistoryPanel({super.key});

  @override
  ConsumerState<CommitHistoryPanel> createState() => _CommitHistoryPanelState();
}

class _CommitHistoryPanelState extends ConsumerState<CommitHistoryPanel> {
  /// Cache of diff results so re-expanding a row doesn't re-fetch.
  final Map<String, List<CommitFileChange>> _diffCache = {};
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(currentProjectIdProvider);
    ref.watch(
      gitStatusRevisionProvider(projectId),
    ); // re-fetch after new commits
    final logFuture = _loadLog(projectId);
    return FutureBuilder<List<_Commit>>(
      future: logFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'History failed: ${snap.error}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          );
        }
        final commits = snap.data ?? const <_Commit>[];
        if (commits.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No commits yet.\nMake your first commit in Source Control.',
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'History (${commits.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: commits.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    _commitTile(context, projectId, commits[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<_Commit>> _loadLog(int projectId) async {
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      return await engine.log(limit: 200);
    } catch (e, st) {
      debugPrint('[git] history log failed: $e\n$st');
      rethrow;
    }
  }

  Widget _commitTile(BuildContext context, int projectId, _Commit c) {
    final expanded = c.oid == _expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            setState(() => _expanded = expanded ? null : c.oid);
            if (!expanded && !_diffCache.containsKey(c.oid)) {
              try {
                final engine = await ref.read(
                  gitEngineProvider(projectId).future,
                );
                final diff = await engine.commitDiff(c.oid);
                if (mounted) setState(() => _diffCache[c.oid] = diff);
              } catch (e, st) {
                debugPrint('[git] diff failed for ${c.oid}: $e\n$st');
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                const Icon(Icons.commit, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.message.split('\n').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.oid.substring(0, 7)} · ${c.author} · ${_relative(c.when)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) _diffSection(projectId, c.oid),
      ],
    );
  }

  Widget _diffSection(int projectId, String oid) {
    final diff = _diffCache[oid];
    if (diff == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (diff.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Text(
          '(empty commit)',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in diff)
            InkWell(
              onTap: () => _openDiff(projectId, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        _changeBadge(c.change),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _changeColor(c.change),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        c.path,
                        style: TextStyle(
                          fontSize: 12,
                          color: _changeColor(c.change),
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDiff(int projectId, CommitFileChange c) async {
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      final before = await engine.blobText(c.oldOid);
      final after = await engine.blobText(c.newOid);
      if (!mounted) return;
      await showCommitFileDiff(
        context,
        path: c.path,
        before: before,
        after: after,
      );
    } catch (e, st) {
      debugPrint('[git] open diff failed for ${c.path}: $e\n$st');
    }
  }

  String _changeBadge(CommitChangeKind k) {
    switch (k) {
      case CommitChangeKind.added:
        return 'A';
      case CommitChangeKind.modified:
        return 'M';
      case CommitChangeKind.deleted:
        return 'D';
    }
  }

  Color _changeColor(CommitChangeKind k) {
    switch (k) {
      case CommitChangeKind.added:
        return const Color(0xFF4FA66A);
      case CommitChangeKind.modified:
        return const Color(0xFFE2A03F);
      case CommitChangeKind.deleted:
        return const Color(0xFFD16969);
    }
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
