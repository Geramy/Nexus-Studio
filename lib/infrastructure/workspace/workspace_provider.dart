// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'async_lock.dart';
import 'git/git_engine_provider.dart';
import 'git_branch_workspace.dart';
import 'workspace.dart';
import 'vhd_workspace.dart';

/// Host path of a project's virtual disk file — one `.nxtprj` (SQLite) file per
/// project, holding its whole filesystem and (next) its git repository.
Future<String> projectDiskPath(int projectId) async {
  final base = (await getApplicationSupportDirectory()).path;
  return p.join(base, 'workspaces', 'project_$projectId.nxtprj');
}

/// Host path of a per-TASK working-tree disk — an isolated `.nxtprj` holding one
/// task's checked-out files while it runs concurrently. Git objects/refs stay in
/// the project disk; this holds only the task's working-tree file state.
Future<String> taskDiskPath(int projectId, int taskPk) async {
  final base = (await getApplicationSupportDirectory()).path;
  return p.join(
    base,
    'workspaces',
    'tasks',
    'project_${projectId}_task_$taskPk.nxtprj',
  );
}

/// Delete a finished task's working-tree disk (best-effort). The project's git
/// object/ref database is untouched — only the task's scratch tree is removed.
Future<void> deleteTaskDisk(int projectId, int taskPk) async {
  try {
    final f = File(await taskDiskPath(projectId, taskPk));
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

/// Remove any leftover per-task working-tree disks (e.g. from a crash) for a
/// fresh orchestration start. Best-effort.
Future<void> pruneTaskDisks(int projectId) async {
  try {
    final base = (await getApplicationSupportDirectory()).path;
    final dir = Directory(p.join(base, 'workspaces', 'tasks'));
    if (!await dir.exists()) return;
    await for (final e in dir.list()) {
      if (e is File &&
          p.basename(e.path).startsWith('project_${projectId}_task_')) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  } catch (_) {}
}

/// The project's workspace: a single-file SQLite "virtual disk", accessed
/// purely through the [Workspace] API (no mounting). Cached per project; the
/// same file is later bound to the git2dart custom backend.
final workspaceFsProvider = FutureProvider.family<Workspace, int>((
  ref,
  projectId,
) async {
  final path = await projectDiskPath(projectId);
  // Ensure the parent dir exists before SQLite opens the file.
  await Directory(p.dirname(path)).create(recursive: true);
  final ws = await VhdWorkspace.open(path);
  ref.onDispose(() => ws.dispose());
  return ws;
});

/// An ISOLATED per-task working tree (its own `.nxtprj`), so concurrent task
/// agents don't clobber each other's files. Keyed by (projectId, taskPk). The
/// orchestrator hydrates it from the task branch (via the shared git engine,
/// under the git lane) and commits it back; the file is deleted on completion.
final taskWorkspaceProvider =
    FutureProvider.family<Workspace, ({int projectId, int taskPk})>((
      ref,
      key,
    ) async {
      final path = await taskDiskPath(key.projectId, key.taskPk);
      await Directory(p.dirname(path)).create(recursive: true);
      final ws = await VhdWorkspace.open(path);
      ref.onDispose(() => ws.dispose());
      return ws;
    });

/// Per-project "git lane": serializes all multi-step git object/ref operations
/// (materialize / commit / merge) across concurrent task agents, since the
/// libgit2 + SQLite engine is single-isolate. Kept alive for the session.
final gitLaneProvider = Provider.family<AsyncLock, int>((ref, projectId) {
  return AsyncLock();
});

/// Bumped to force the browser to re-list after a mutation (create/delete/move).
final workspaceRevisionProvider = StateProvider.family<int, int>(
  (ref, projectId) => 0,
);

/// The currently-open file in the right-panel editor. Shared between the
/// center tree and the right-panel editor so a click in the tree opens the
/// file on the right.
final selectedWorkspaceFileProvider = StateProvider.family<String?, int>(
  (ref, projectId) => null,
);

/// One-shot "jump to line" request for the right-panel editor (Visual Editor
/// → "View code"): the line (1-based) to select once [path] is open. The
/// editor consumes (resets to null) it after applying.
final workspaceJumpLineProvider = StateProvider.family<int?, int>(
  (ref, projectId) => null,
);

/// One-shot prompt the Visual Editor wants pre-filled into the editor chat
/// composer (the "send the assistant this exact task" tier-2 fallback). The
/// chat consumes (resets to null) it on the next build.
final pendingEditorPromptProvider = StateProvider.family<String?, int>(
  (ref, projectId) => null,
);

/// The branch the Code browser is VIEWING read-only — a running task's
/// `task/<id>` so its in-progress (committed-but-unmerged) work is visible
/// instead of only after merge. `null` = the live workspace (current branch).
/// Purely a view concern: selecting a branch never checks it out or mutates the
/// tree, so it's safe while the orchestrator is committing.
final viewBranchProvider = StateProvider.family<String?, int>(
  (ref, projectId) => null,
);

/// The workspace the Code browser/editor should render: the live disk workspace
/// when [viewBranchProvider] is null, otherwise a read-only [GitBranchWorkspace]
/// snapshot of the selected branch's tip. Re-reads when the workspace revision
/// bumps so the "Refresh" action picks up new agent commits.
final viewWorkspaceFsProvider = FutureProvider.family<Workspace, int>((
  ref,
  projectId,
) async {
  final branch = ref.watch(viewBranchProvider(projectId));
  if (branch == null) {
    return ref.watch(workspaceFsProvider(projectId).future);
  }
  ref.watch(workspaceRevisionProvider(projectId));
  final engine = await ref.watch(gitEngineProvider(projectId).future);
  final tree = await engine.treeAt(branch);
  return GitBranchWorkspace(engine, branch, tree);
});

/// All branches in the project repo (for the Code browser's view-branch picker).
/// Re-reads on workspace mutations so freshly-created task branches show up.
final branchListProvider = FutureProvider.family<List<String>, int>((
  ref,
  projectId,
) async {
  ref.watch(workspaceRevisionProvider(projectId));
  final engine = await ref.watch(gitEngineProvider(projectId).future);
  return engine.branches();
});
