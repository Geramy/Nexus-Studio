// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_exporter.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_provider.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git_status.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/git_engine_provider.dart';

import 'code_highlight.dart';

// ─────────────────────────────────────────────────────────────────────
// CENTER pane of "Code & Git": the workspace tree + git action toolbar.
// Clicking a file sets selectedWorkspaceFileProvider; the right-panel
// FileEditorPanel watches that and opens the file.
// ─────────────────────────────────────────────────────────────────────

class FileBrowserView extends ConsumerStatefulWidget {
  const FileBrowserView({super.key});

  @override
  ConsumerState<FileBrowserView> createState() => _FileBrowserViewState();
}

class _FileBrowserViewState extends ConsumerState<FileBrowserView> {
  final Set<String> _expanded = {'/'};

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(currentProjectIdProvider);
    final viewBranch = ref.watch(viewBranchProvider(projectId));
    final fsAsync = ref.watch(viewWorkspaceFsProvider(projectId));
    ref.watch(workspaceRevisionProvider(projectId)); // re-walk on mutations
    final git =
        ref.watch(gitStatusProvider(projectId)).value ??
        GitStatusSnapshot.noRepo;
    final selectedPath = ref.watch(selectedWorkspaceFileProvider(projectId));
    // When viewing a task branch read-only, the live git status (which tracks
    // the working tree) doesn't apply — don't paint stale change badges.
    final treeGit = viewBranch == null ? git : GitStatusSnapshot.noRepo;

    return fsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Workspace error: $e')),
      data: (fs) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(context, projectId, viewBranch),
          const Divider(height: 1),
          _branchViewBar(context, projectId, viewBranch),
          if (viewBranch == null) ...[
            _gitHeader(context, git),
            _gitActions(context, projectId, git),
          ],
          const Divider(height: 1),
          Expanded(child: _tree(context, fs, projectId, treeGit, selectedPath)),
          const Divider(height: 1),
          _footer(fs),
        ],
      ),
    );
  }

  // ── Toolbar ──────────────────────────────────────────────────────

  Widget _toolbar(BuildContext context, int projectId, String? viewBranch) {
    final readOnly = viewBranch != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 230;
          return Row(
            children: [
              if (!narrow) ...[
                const Icon(Icons.folder_special_outlined, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  'Workspace',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined, size: 15),
            iconSize: 15,
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: readOnly ? 'Read-only branch view' : 'New file',
            onPressed: readOnly
                ? null
                : () => _create(context, projectId, parent: '/', isFolder: false),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 15),
            iconSize: 15,
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: readOnly ? 'Read-only branch view' : 'New folder',
            onPressed: readOnly
                ? null
                : () => _create(context, projectId, parent: '/', isFolder: true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 15),
            tooltip: 'Workspace storage',
            itemBuilder: (_) => const [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'Project disk (.nxtprj)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              PopupMenuItem(
                value: 'export_zip',
                child: Text('Export all files (.zip)'),
              ),
              PopupMenuItem(
                value: 'export_image',
                child: Text('Export as image… (soon)'),
              ),
            ],
            onSelected: (value) => _onStorageMenu(context, projectId, value),
          ),
            ],
          );
        },
      ),
    );
  }

  /// Workspace storage menu: export-all-files (zip) or the not-yet-built image
  /// export. The zip lands in Downloads; the snackbar reveals it in Finder/etc.
  Future<void> _onStorageMenu(
    BuildContext context,
    int projectId,
    String value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (value == 'export_image') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Native image export (.dmg/.vhd/ext4) is the next phase.',
          ),
        ),
      );
      return;
    }
    if (value != 'export_zip') return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Exporting project files…'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final fs = await ref.read(workspaceFsProvider(projectId).future);
      final project = await ref
          .read(nexusDatabaseProvider)
          .getProjectById(projectId);
      const exporter = WorkspaceExporter();
      final file = await exporter.exportZip(
        fs,
        projectName: project?.name ?? 'project',
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported to ${file.path}'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Show',
            onPressed: () => exporter.revealInFileManager(file.path),
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // ── Branch view selector (read-only "see the agent's work") ──────

  /// A picker that switches the browser between the LIVE workspace and a
  /// read-only snapshot of any branch (e.g. a running task's `task/<id>`), plus
  /// a banner + refresh while a branch is being viewed. This is how in-progress
  /// agent work becomes visible before it's merged to main.
  Widget _branchViewBar(
    BuildContext context,
    int projectId,
    String? viewBranch,
  ) {
    final branches = ref.watch(branchListProvider(projectId)).value ?? [];
    final scheme = Theme.of(context).colorScheme;
    final viewing = viewBranch != null;

    return Container(
      color: viewing ? scheme.tertiaryContainer.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: Row(
        children: [
          Icon(
            viewing ? Icons.visibility_outlined : Icons.account_tree_outlined,
            size: 15,
            color: viewing ? scheme.onTertiaryContainer : null,
          ),
          const SizedBox(width: 6),
          Text(
            'View:',
            style: TextStyle(
              fontSize: 12,
              color: viewing ? scheme.onTertiaryContainer : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButton<String?>(
              value: viewBranch,
              isDense: true,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Live workspace (editable)'),
                ),
                for (final b in branches)
                  DropdownMenuItem<String?>(
                    value: b,
                    child: Text(
                      'Branch: $b  (read-only)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (b) {
                // Drop any open file so the editor reloads from the new source.
                ref
                        .read(selectedWorkspaceFileProvider(projectId).notifier)
                        .state =
                    null;
                ref.read(viewBranchProvider(projectId).notifier).state = b;
              },
            ),
          ),
          if (viewing)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: 'Refresh — pick up new commits',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref
                      .read(workspaceRevisionProvider(projectId).notifier)
                      .state++,
            ),
        ],
      ),
    );
  }

  // ── Git header (branch + change count) ───────────────────────────

  Widget _gitHeader(BuildContext context, GitStatusSnapshot git) {
    final dirtyCount = git.byPath.values.where(gitStatusIsDirty).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: [
          Icon(
            git.hasRepo ? Icons.call_split : Icons.source_outlined,
            size: 14,
            color: Colors.grey,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              git.hasRepo
                  ? '${git.branch ?? "(detached)"}${dirtyCount > 0 ? " • $dirtyCount change${dirtyCount == 1 ? "" : "s"}" : " • clean"}'
                  : 'No git repo yet',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (git.hasRepo && (git.ahead > 0 || git.behind > 0))
            Text(
              '↑${git.ahead} ↓${git.behind}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // ── Git action toolbar (Commit / Push / Pull / Merge / History / Branch) ──

  Widget _gitActions(
    BuildContext context,
    int projectId,
    GitStatusSnapshot git,
  ) {
    final dirtyCount = git.byPath.values.where(gitStatusIsDirty).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _GitButton(
            icon: Icons.commit,
            label: dirtyCount > 0 ? 'Commit ($dirtyCount)' : 'Commit',
            tint: dirtyCount > 0 ? Colors.green : null,
            onTap: dirtyCount > 0 ? () => _commit(context, projectId) : null,
          ),
          _GitButton(
            icon: Icons.upload,
            label: 'Push',
            onTap: () => _remoteNotice(context, 'Push'),
          ),
          _GitButton(
            icon: Icons.download,
            label: 'Pull',
            onTap: () => _remoteNotice(context, 'Pull'),
          ),
          _GitButton(
            icon: Icons.merge_type,
            label: 'Merge',
            onTap: () => _remoteNotice(context, 'Merge'),
          ),
          _GitButton(
            icon: Icons.history,
            label: 'History',
            onTap: () => _showHistory(context, projectId),
          ),
          _GitButton(
            icon: Icons.account_tree_outlined,
            label: git.branch ?? 'main',
            onTap: () => _branches(context, projectId, git),
          ),
        ],
      ),
    );
  }

  void _remoteNotice(BuildContext context, String op) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$op needs a remote configured — the Remote (URL + credentials) layer lands next.',
        ),
      ),
    );
  }

  // ── Tree ─────────────────────────────────────────────────────────

  Widget _tree(
    BuildContext context,
    Workspace fs,
    int projectId,
    GitStatusSnapshot git,
    String? selectedPath,
  ) {
    return FutureBuilder<List<FileEntry>>(
      future: fs.walk(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(fontSize: 12),
            ),
          );
        }
        final entries = snap.data ?? const <FileEntry>[];
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Empty workspace.\nUse the + buttons to add files.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        }
        final byParent = <String, List<FileEntry>>{};
        for (final e in entries) {
          byParent.putIfAbsent(e.parent, () => []).add(e);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: _level(
            context,
            byParent,
            '/',
            0,
            projectId,
            git,
            selectedPath,
          ),
        );
      },
    );
  }

  List<Widget> _level(
    BuildContext context,
    Map<String, List<FileEntry>> byParent,
    String parent,
    int depth,
    int projectId,
    GitStatusSnapshot git,
    String? selectedPath,
  ) {
    final children = byParent[parent] ?? const [];
    final widgets = <Widget>[];
    for (final e in children) {
      widgets.add(_row(context, e, depth, projectId, git, selectedPath));
      if (e.isDirectory && _expanded.contains(e.path)) {
        widgets.addAll(
          _level(
            context,
            byParent,
            e.path,
            depth + 1,
            projectId,
            git,
            selectedPath,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _row(
    BuildContext context,
    FileEntry e,
    int depth,
    int projectId,
    GitStatusSnapshot git,
    String? selectedPath,
  ) {
    final isSelected = e.path == selectedPath;
    final isOpen = e.isDirectory && _expanded.contains(e.path);
    final deco = e.isDirectory ? null : gitDecorationFor(git.statusFor(e.path));
    final folderDirty =
        e.isDirectory && git.hasRepo && git.folderHasChanges(e.path);
    final defaultText = Theme.of(context).textTheme.bodyMedium?.color;
    final nameColor = deco?.color ?? defaultText;

    return InkWell(
      onTap: () {
        if (e.isDirectory) {
          setState(
            () => _expanded.contains(e.path)
                ? _expanded.remove(e.path)
                : _expanded.add(e.path),
          );
        } else {
          ref.read(selectedWorkspaceFileProvider(projectId).notifier).state =
              e.path;
        }
      },
      child: Container(
        color: isSelected
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        padding: EdgeInsets.only(
          left: 8.0 + depth * 14,
          top: 5,
          bottom: 5,
          right: 4,
        ),
        child: Row(
          children: [
            Icon(
              e.isDirectory
                  ? (isOpen ? Icons.folder_open : Icons.folder)
                  : _fileIcon(e.name),
              size: 16,
              color: e.isDirectory ? Colors.amber.shade700 : Colors.blueGrey,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                e.name + (e.isLink ? ' ↗' : ''),
                style: TextStyle(
                  fontSize: 13,
                  color: (deco?.muted ?? false) ? Colors.grey : nameColor,
                  fontStyle: (deco?.muted ?? false)
                      ? FontStyle.italic
                      : FontStyle.normal,
                  decoration: (deco?.strike ?? false)
                      ? TextDecoration.lineThrough
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (folderDirty)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.circle, size: 7, color: Color(0xFFE2A03F)),
              ),
            if (deco != null && deco.badge.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 2),
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
            _rowMenu(context, e, projectId),
          ],
        ),
      ),
    );
  }

  Widget _rowMenu(BuildContext context, FileEntry e, int projectId) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 16),
      padding: EdgeInsets.zero,
      tooltip: 'Actions',
      itemBuilder: (_) => [
        if (e.isDirectory)
          const PopupMenuItem(value: 'newFile', child: Text('New file inside')),
        if (e.isDirectory)
          const PopupMenuItem(
            value: 'newFolder',
            child: Text('New folder inside'),
          ),
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
      onSelected: (v) async {
        switch (v) {
          case 'newFile':
            setState(() => _expanded.add(e.path));
            await _create(context, projectId, parent: e.path, isFolder: false);
            break;
          case 'newFolder':
            setState(() => _expanded.add(e.path));
            await _create(context, projectId, parent: e.path, isFolder: true);
            break;
          case 'rename':
            await _rename(context, projectId, e);
            break;
          case 'delete':
            await _delete(context, projectId, e);
            break;
        }
      },
    );
  }

  // ── Footer ───────────────────────────────────────────────────────

  Widget _footer(Workspace fs) {
    return FutureBuilder<({int bytes, int files})>(
      future: fs.usage(),
      builder: (context, snap) {
        final txt = snap.hasData
            ? '${snap.data!.files} files · ${formatBytes(snap.data!.bytes)}'
            : '…';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 12, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  txt,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── File mutations ───────────────────────────────────────────────

  Future<void> _create(
    BuildContext context,
    int projectId, {
    required String parent,
    required bool isFolder,
  }) async {
    final name = await _prompt(
      context,
      isFolder ? 'New folder' : 'New file',
      'Name',
    );
    if (name == null || name.trim().isEmpty) return;
    final fs = await ref.read(workspaceFsProvider(projectId).future);
    final path = parent == '/' ? '/${name.trim()}' : '$parent/${name.trim()}';
    try {
      if (isFolder) {
        await fs.createDirectory(path);
      } else {
        await fs.createFile(path);
        ref.read(selectedWorkspaceFileProvider(projectId).notifier).state =
            path;
      }
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  Future<void> _rename(BuildContext context, int projectId, FileEntry e) async {
    final name = await _prompt(context, 'Rename', 'New name', initial: e.name);
    if (name == null || name.trim().isEmpty || name.trim() == e.name) return;
    final fs = await ref.read(workspaceFsProvider(projectId).future);
    final target = e.parent == '/'
        ? '/${name.trim()}'
        : '${e.parent}/${name.trim()}';
    try {
      await fs.move(e.path, target);
      if (ref.read(selectedWorkspaceFileProvider(projectId)) == e.path) {
        ref.read(selectedWorkspaceFileProvider(projectId).notifier).state =
            target;
      }
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
    } catch (err) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rename failed: $err')));
    }
  }

  Future<void> _delete(BuildContext context, int projectId, FileEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${e.isDirectory ? 'folder' : 'file'}'),
        content: Text(
          'Delete "${e.name}"${e.isDirectory ? ' and everything inside it' : ''}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final fs = await ref.read(workspaceFsProvider(projectId).future);
    try {
      await fs.delete(e.path);
      if (ref.read(selectedWorkspaceFileProvider(projectId)) == e.path) {
        ref.read(selectedWorkspaceFileProvider(projectId).notifier).state =
            null;
      }
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
    } catch (err) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $err')));
    }
  }

  // ── Git actions ──────────────────────────────────────────────────

  Future<void> _commit(BuildContext context, int projectId) async {
    final msg = await _prompt(context, 'Commit', 'Commit message');
    if (msg == null || msg.trim().isEmpty) return;
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      final oid = await engine.commitAll(message: msg.trim());
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Committed ${oid.substring(0, 7)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Commit failed: $e')));
    }
  }

  Future<void> _showHistory(BuildContext context, int projectId) async {
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      final commits = await engine.log(limit: 100);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Commit history'),
          content: SizedBox(
            width: 480,
            height: 400,
            child: commits.isEmpty
                ? const Center(
                    child: Text(
                      'No commits yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: commits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = commits[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.commit, size: 16),
                        title: Text(
                          c.message.split('\n').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${c.oid.substring(0, 7)} · ${c.author} · ${c.when.toLocal().toString().substring(0, 16)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('History failed: $e')));
    }
  }

  // ── Branches ─────────────────────────────────────────────────────

  Future<void> _branches(
    BuildContext context,
    int projectId,
    GitStatusSnapshot git,
  ) async {
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      final branches = await engine.branches();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Branches'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (branches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No branches yet — make your first commit to create "main".',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                for (final b in branches)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      b == git.branch
                          ? Icons.check
                          : Icons.account_tree_outlined,
                      size: 18,
                      color: b == git.branch ? Colors.green : null,
                    ),
                    title: Text(b),
                    onTap: b == git.branch
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _checkout(context, projectId, b, git);
                          },
                  ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add, size: 18),
                  title: const Text('New branch…'),
                  enabled: git.hasRepo,
                  onTap: () {
                    Navigator.pop(ctx);
                    _createBranch(context, projectId);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Branches failed: $e')));
    }
  }

  Future<void> _createBranch(BuildContext context, int projectId) async {
    final name = await _prompt(
      context,
      'New branch',
      'Branch name (e.g. feature/x)',
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      await engine.createBranch(name.trim(), checkout: true);
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created & switched to "${name.trim()}"')),
      );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Create branch failed: $e')));
    }
  }

  Future<void> _checkout(
    BuildContext context,
    int projectId,
    String branch,
    GitStatusSnapshot git,
  ) async {
    final dirty = git.byPath.values.where(gitStatusIsDirty).isNotEmpty;
    if (dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Switch branch with uncommitted changes?'),
          content: Text(
            'You have uncommitted changes that will be overwritten by switching to "$branch". Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final engine = await ref.read(gitEngineProvider(projectId).future);
      await engine.checkoutBranch(branch);
      // The open editor may now point at a file that changed/vanished — reload.
      ref.read(selectedWorkspaceFileProvider(projectId).notifier).state = ref
          .read(selectedWorkspaceFileProvider(projectId));
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Switched to "$branch"')));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Switch failed: $e')));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Future<String?> _prompt(
    BuildContext context,
    String title,
    String label, {
    String? initial,
  }) {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.dart')) return Icons.flutter_dash;
    if (lower.endsWith('.md')) return Icons.article_outlined;
    if (lower.endsWith('.json') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml'))
      return Icons.data_object;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif'))
      return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

/// Compact action button used in the git toolbar.
class _GitButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tint;
  const _GitButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color =
        tint ??
        (enabled ? Theme.of(context).textTheme.bodyMedium?.color : Colors.grey);
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
      ),
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// RIGHT panel of "Code & Git": viewer/editor for the currently-selected
// workspace file. Watches selectedWorkspaceFileProvider.
// ─────────────────────────────────────────────────────────────────────

class FileEditorPanel extends ConsumerStatefulWidget {
  const FileEditorPanel({super.key});

  @override
  ConsumerState<FileEditorPanel> createState() => _FileEditorPanelState();
}

class _FileEditorPanelState extends ConsumerState<FileEditorPanel> {
  final CodeController _editor = CodeController();
  bool _dirty = false;
  bool _binaryView = false;
  bool _loading = false;
  String? _loadedPath;
  int? _lastRev;

  @override
  void initState() {
    super.initState();
    ensureHighlightLanguages();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(currentProjectIdProvider);
    final selectedPath = ref.watch(selectedWorkspaceFileProvider(projectId));
    final readOnly = ref.watch(viewBranchProvider(projectId)) != null;
    final fsAsync = ref.watch(viewWorkspaceFsProvider(projectId));
    final rev = ref.watch(workspaceRevisionProvider(projectId));

    // Auto-load on selection change, or when the workspace mutated underneath
    // us (e.g. branch switch / discard) and there are no unsaved edits.
    final pathChanged = selectedPath != _loadedPath;
    final revChanged = _lastRev != null && rev != _lastRev && !_dirty;
    _lastRev = rev;
    if ((pathChanged || revChanged) && fsAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (selectedPath != _loadedPath || revChanged)
          _open(fsAsync.value!, selectedPath, projectId);
      });
    }

    if (selectedPath == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a file in the workspace to view or edit it here.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return fsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Workspace error: $e')),
      data: (fs) => _editorUi(context, fs, projectId, selectedPath, readOnly),
    );
  }

  Widget _editorUi(
    BuildContext context,
    Workspace fs,
    int projectId,
    String path,
    bool readOnly,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_dirty)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('●', style: TextStyle(color: Colors.orange)),
                ),
              if (readOnly)
                Text(
                  'read-only',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (!_binaryView)
                FilledButton.icon(
                  onPressed: _dirty ? () => _save(fs, projectId) : null,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _binaryView
              ? const Center(
                  child: Text(
                    'Binary file — preview not shown.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : _codeEditor(context, readOnly),
        ),
      ],
    );
  }

  Widget _codeEditor(BuildContext context, bool readOnly) {
    final brightness = Theme.of(context).brightness;
    return Container(
      color: highlightBackground(brightness),
      child: CodeTheme(
        data: CodeThemeData(styles: highlightThemeFor(brightness)),
        child: CodeField(
          controller: _editor,
          readOnly: readOnly,
          expands: true,
          wrap: false,
          background: highlightBackground(brightness),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.4,
          ),
          gutterStyle: const GutterStyle(
            showLineNumbers: true,
            showErrors: false,
            showFoldingHandles: false,
          ),
          onChanged: (_) {
            if (!_dirty) setState(() => _dirty = true);
          },
        ),
      ),
    );
  }

  Future<void> _open(Workspace fs, String? path, int projectId) async {
    if (path == null) {
      setState(() {
        _loadedPath = null;
        _editor.text = '';
        _dirty = false;
        _binaryView = false;
      });
      return;
    }
    if (_dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text('You have unsaved edits in the current file.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _loading = true;
      _binaryView = false;
    });
    try {
      final binary = await fs.isProbablyBinary(path);
      if (binary) {
        if (!mounted) return;
        setState(() {
          _binaryView = true;
          _dirty = false;
          _loading = false;
          _loadedPath = path;
        });
        return;
      }
      final content = await fs.readString(path);
      if (!mounted) return;
      _editor.language = languageModeForPath(path);
      _editor.text = content;
      // One-shot "jump to line" (Visual Editor → View code): highlight the
      // requested line once the file is loaded, then consume the request.
      final jump = ref.read(workspaceJumpLineProvider(projectId));
      if (jump != null) {
        ref.read(workspaceJumpLineProvider(projectId).notifier).state = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _selectLine(jump);
        });
      }
      setState(() {
        _dirty = false;
        _loading = false;
        _loadedPath = path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Open failed: $e')));
    }
  }

  void _selectLine(int line) {
    final text = _editor.text;
    final lines = text.split('\n');
    final idx = (line - 1).clamp(0, lines.length - 1);
    var offset = 0;
    for (var i = 0; i < idx; i++) {
      offset += lines[i].length + 1;
    }
    final end = offset + lines[idx].length;
    _editor.selection = TextSelection(baseOffset: offset, extentOffset: end);
  }

  Future<void> _save(Workspace fs, int projectId) async {
    final path = _loadedPath;
    if (path == null) return;
    try {
      await fs.writeString(path, _editor.text);
      // Refresh the tree decorations (M badge appears).
      ref.read(gitStatusRevisionProvider(projectId).notifier).state++;
      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      setState(() => _dirty = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $path'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }
}
