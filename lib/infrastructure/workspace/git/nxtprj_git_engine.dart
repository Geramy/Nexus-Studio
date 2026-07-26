// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:git2dart_binaries/git2dart_binaries.dart';

import '../git_status.dart';
import '../vhd_workspace.dart';
import '../workspace.dart';
import 'additive_merge.dart';
import 'nxtprj_git_odb.dart';
import 'nxtprj_git_refdb.dart';

/// libgit2-backed git engine bound to a project's `.nxtprj` SQLite file.
///
/// There is **no working tree**: files live in the [VhdWorkspace] virtual disk
/// and are read through the [Workspace] API. Git objects (blobs/trees/commits)
/// and refs are stored in the same SQLite file via the custom [NxtprjGitOdb]
/// and [NxtprjGitRefdb] backends, so history and files live together.
///
/// Every libgit2 + SQLite call MUST happen on the one isolate that owns the
/// [VhdWorkspace] database handle — the backend callbacks are synchronous
/// `NativeCallable.isolateLocal`s. This class never spawns isolates and never
/// touches libgit2 off the UI isolate.
class NxtprjGitEngine {
  final VhdWorkspace _ws;
  final NxtprjGitOdb _odb;
  final NxtprjGitRefdb _refdb;
  final Pointer<git_repository> _repo;

  bool _disposed = false;

  NxtprjGitEngine._(this._ws, this._odb, this._refdb, this._repo);

  /// Default branch when HEAD is unborn or symbolic-but-unresolvable.
  static const String _defaultBranch = 'main';

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Open (or initialize) the git repository bound to [ws]'s SQLite file.
  ///
  /// Creates the git schema, builds an in-memory `git_repository` wired to the
  /// SQLite-backed ODB and refdb, and ensures HEAD is the symbolic ref
  /// `refs/heads/main` if no HEAD exists yet.
  static Future<NxtprjGitEngine> open(VhdWorkspace ws) async {
    initGitSchema(ws.database);

    final odb = NxtprjGitOdb(ws.database);
    final refdb = NxtprjGitRefdb(ws.database);

    final repoOut = calloc<Pointer<git_repository>>();
    Pointer<git_odb> odbPtr = nullptr;
    Pointer<git_refdb> refdbPtr = nullptr;
    try {
      final rc = libgit2.git_repository_new(repoOut, nullptr);
      if (rc != 0) {
        throw StateError('git_repository_new failed ($rc)');
      }
      final repo = repoOut.value;

      odbPtr = odb.createOdb();
      final rcOdb = libgit2.git_repository_set_odb(repo, odbPtr);
      if (rcOdb != 0) {
        throw StateError('git_repository_set_odb failed ($rcOdb)');
      }

      refdbPtr = refdb.createRefdb(repo);
      final rcRefdb = libgit2.git_repository_set_refdb(repo, refdbPtr);
      if (rcRefdb != 0) {
        throw StateError('git_repository_set_refdb failed ($rcRefdb)');
      }

      final engine = NxtprjGitEngine._(ws, odb, refdb, repo);
      engine._ensureHead();
      return engine;
    } catch (_) {
      // Roll back any partially-created native state on failure.
      if (refdbPtr != nullptr) refdb.dispose();
      if (odbPtr != nullptr) odb.dispose();
      final repo = repoOut.value;
      if (repo != nullptr) libgit2.git_repository_free(repo);
      rethrow;
    } finally {
      calloc.free(repoOut);
    }
  }

  /// Point HEAD at `refs/heads/main` (symbolic) when there is no HEAD yet, so a
  /// fresh repo commits onto `main` and `currentBranch()` is meaningful even
  /// before the first commit.
  ///
  /// Written straight to `git_refs`: `git_repository_set_head` does not route
  /// HEAD creation through our custom refdb backend, so the row would never
  /// persist and HEAD resolution would always come back unborn.
  void _ensureHead() {
    if (_lookupRefRow('HEAD') != null) return;
    _ws.database.execute(
      'INSERT OR REPLACE INTO git_refs(name, target, symbolic) VALUES(?, NULL, ?)',
      ['HEAD', 'refs/heads/$_defaultBranch'],
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Free the repository first (it references the odb/refdb), then the
    // backends (which close their retained NativeCallables).
    libgit2.git_repository_free(_repo);
    _refdb.dispose();
    _odb.dispose();
  }

  // ── Queries ───────────────────────────────────────────────────────────

  /// Hex oid that HEAD resolves to, or null if HEAD is unborn.
  Future<String?> headOid() async => _resolveOid('HEAD');

  /// Resolve a ref name to a hex oid, following symbolic refs, or null if it
  /// cannot resolve (e.g. unborn HEAD).
  ///
  /// Reads the `git_refs` table directly rather than going through libgit2's
  /// `git_reference_name_to_id`: libgit2's refdb layer caches HEAD resolution
  /// and does not observe the branch ref we move ourselves on commit, so its
  /// view goes stale. The SQLite table is our source of truth.
  String? _resolveOid(String refName) {
    var name = refName;
    for (var i = 0; i < 10; i++) {
      final row = _lookupRefRow(name);
      if (row == null) return null;
      final target = row.target;
      if (target != null && target.isNotEmpty) return target;
      final sym = row.symbolic;
      if (sym != null && sym.isNotEmpty) {
        name = sym;
        continue;
      }
      return null;
    }
    return null; // ref cycle guard
  }

  /// Current branch short name (e.g. `main`), or null if HEAD is detached (not
  /// pointing at a `refs/heads/*` ref).
  Future<String?> currentBranch() async {
    final ref = _headSymbolicTarget();
    const prefix = 'refs/heads/';
    if (ref == null || !ref.startsWith(prefix)) return null;
    return ref.substring(prefix.length);
  }

  /// The full ref name HEAD symbolically points at (e.g. `refs/heads/main`), or
  /// null if HEAD is missing or detached.
  String? _headSymbolicTarget() {
    final head = _lookupRefRow('HEAD');
    final sym = head?.symbolic;
    return (sym != null && sym.isNotEmpty) ? sym : null;
  }

  /// The branch ref to commit onto: HEAD's symbolic target, falling back to the
  /// default branch when HEAD is unborn/detached.
  String _commitRefName() =>
      _headSymbolicTarget() ?? 'refs/heads/$_defaultBranch';

  // ── Commit ────────────────────────────────────────────────────────────

  /// Snapshot every workspace file into a commit on the current branch.
  ///
  /// Reads all files via [VhdWorkspace.walk] + [VhdWorkspace.readBytes], creates
  /// a blob per file, builds the nested tree bottom-up with treebuilders, and
  /// creates the commit on `refs/heads/<branch>` with the previous HEAD (if any)
  /// as the sole parent. Returns the new commit's hex oid.
  Future<String> commitAll({
    required String message,
    String authorName = 'Coordinator',
    String authorEmail = 'agent@nexus.local',
    Workspace? tree,
  }) async {
    final ws = tree ?? _ws;
    final entries = await ws.walk();
    // Collect file contents keyed by their path segments.
    final files = <List<String>, Uint8List>{};
    for (final e in entries) {
      if (e.isDirectory) continue;
      final segs = _segments(e.path);
      if (segs.isEmpty) continue;
      files[segs] = await ws.readBytes(e.path);
    }

    final treeOid = _buildTree(files);
    final parentHex = await headOid();

    return _createCommit(
      message: message,
      authorName: authorName,
      authorEmail: authorEmail,
      treeHex: treeOid,
      parentHex: parentHex,
    );
  }

  /// Commit the full contents of an ISOLATED working tree [tree] onto [branch]
  /// in the shared object/ref database — without touching HEAD or any other
  /// working tree. The parent is [branch]'s current tip and the branch ref is
  /// advanced directly, so any number of per-task trees can commit to their own
  /// branches concurrently (serialize the call through the git lane). Returns
  /// the new commit hex.
  Future<String> commitFrom(
    Workspace tree, {
    required String branch,
    required String message,
    String authorName = 'Coordinator',
    String authorEmail = 'agent@nexus.local',
  }) async {
    final entries = await tree.walk();
    final files = <List<String>, Uint8List>{};
    for (final e in entries) {
      if (e.isDirectory) continue;
      final segs = _segments(e.path);
      if (segs.isEmpty) continue;
      files[segs] = await tree.readBytes(e.path);
    }
    final treeOid = _buildTree(files);
    final refName = 'refs/heads/$branch';
    final parentHex = _resolveOid(refName);
    return _createCommit(
      message: message,
      authorName: authorName,
      authorEmail: authorEmail,
      treeHex: treeOid,
      parentHex: parentHex,
      refName: refName,
    );
  }

  /// Hydrate an isolated working tree [tree] with the tip of [branch] (writing
  /// every tracked blob, deleting files absent from that tree) — the per-task
  /// equivalent of [checkoutBranch], but it never moves HEAD or the shared tree.
  /// No-op (clears nothing) when the branch is unborn.
  Future<void> materializeInto(String branch, Workspace tree) async {
    final tipHex = _resolveOid('refs/heads/$branch');
    if (tipHex == null) return;
    await _materializeTree(tipHex, tree: tree);
  }

  /// Create [name] pointing at [base]'s tip without checking it out or touching
  /// any working tree (ref-only). Used to root a task branch on main/parent so a
  /// per-task tree can then be materialized from it. No-op if [name] exists.
  Future<void> createBranchAt(String name, {required String base}) async {
    final clean = name.trim();
    if (clean.isEmpty ||
        !_branchNameOk.hasMatch(clean) ||
        clean.startsWith('/') ||
        clean.endsWith('/')) {
      throw StateError('Invalid branch name: "$name"');
    }
    final refName = 'refs/heads/$clean';
    final exists = _ws.database.select('SELECT 1 FROM git_refs WHERE name=?', [
      refName,
    ]).isNotEmpty;
    if (exists) return;
    final baseHex = _resolveOid('refs/heads/$base');
    // Unborn base (fresh project, no commit yet): leave the task branch unborn
    // too — it's born by the worker's first commitFrom (parent = none).
    if (baseHex == null) return;
    _ws.database.execute(
      'INSERT INTO git_refs(name, target, symbolic) VALUES(?, ?, NULL)',
      [refName, baseHex],
    );
  }

  /// Delete a branch ref outright. Used to RE-ROOT a task branch: deleting it and
  /// then [createBranchAt] again rebases the next attempt onto the CURRENT target,
  /// so a redo after a merge conflict or failed gate builds on the latest main
  /// instead of its stale, diverged work. (A task parked on a held file instead
  /// PRESERVES its branch and resumes from it — it is not re-rooted.) No-op if
  /// absent. Orphaned
  /// commits are reclaimed by later GC. Never pass a branch that is checked out
  /// as a live HEAD — task branches are re-rooted while detached on their own
  /// scratch tree, which is safe.
  Future<void> deleteBranch(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _ws.database.execute('DELETE FROM git_refs WHERE name=?', [
      'refs/heads/$clean',
    ]);
  }

  /// Build the nested tree from a flat path→bytes map and return the root tree
  /// oid (hex). Directories are materialized bottom-up: subtrees are written
  /// first and their oids inserted into the parent treebuilder.
  String _buildTree(Map<List<String>, Uint8List> files) {
    // Build a directory node structure first.
    final root = _DirNode();
    files.forEach((segs, bytes) {
      var node = root;
      for (var i = 0; i < segs.length - 1; i++) {
        node = node.dirs.putIfAbsent(segs[i], () => _DirNode());
      }
      node.files[segs.last] = bytes;
    });
    return _writeDir(root);
  }

  /// Write one directory node (recursively) and return its tree oid hex.
  String _writeDir(_DirNode node) {
    final builderOut = calloc<Pointer<git_treebuilder>>();
    try {
      final rc = libgit2.git_treebuilder_new(builderOut, _repo, nullptr);
      if (rc != 0) throw StateError('git_treebuilder_new failed ($rc)');
      final builder = builderOut.value;
      try {
        // Subtrees first.
        node.dirs.forEach((name, child) {
          final childOidHex = _writeDir(child);
          _insertEntry(
            builder,
            name,
            childOidHex,
            git_filemode_t.GIT_FILEMODE_TREE,
          );
        });
        // Existing blobs from HEAD (unchanged in this commit) — referenced by
        // their existing oid, no rewrite. Inserted before new-content files so
        // a same-name new file overrides via git_treebuilder's replace semantics.
        node.existingFiles.forEach((name, oidHex) {
          _insertEntry(builder, name, oidHex, git_filemode_t.GIT_FILEMODE_BLOB);
        });
        // Then files (blobs).
        node.files.forEach((name, bytes) {
          final blobOidHex = _createBlob(bytes);
          _insertEntry(
            builder,
            name,
            blobOidHex,
            git_filemode_t.GIT_FILEMODE_BLOB,
          );
        });

        final oidOut = calloc<git_oid>();
        try {
          final rcW = libgit2.git_treebuilder_write(oidOut, builder);
          if (rcW != 0) throw StateError('git_treebuilder_write failed ($rcW)');
          return _oidHex(oidOut);
        } finally {
          calloc.free(oidOut);
        }
      } finally {
        libgit2.git_treebuilder_free(builder);
      }
    } finally {
      calloc.free(builderOut);
    }
  }

  void _insertEntry(
    Pointer<git_treebuilder> builder,
    String name,
    String oidHex,
    git_filemode_t mode,
  ) {
    final oid = calloc<git_oid>();
    final cName = name.toNativeUtf8();
    final entryOut = calloc<Pointer<git_tree_entry>>();
    try {
      _oidFromHex(oidHex, oid);
      final rc = libgit2.git_treebuilder_insert(
        entryOut,
        builder,
        cName.cast(),
        oid,
        mode,
      );
      if (rc != 0) throw StateError('git_treebuilder_insert failed ($rc)');
    } finally {
      calloc.free(entryOut);
      calloc.free(cName);
      calloc.free(oid);
    }
  }

  /// Create a blob from [bytes] in the ODB; returns its oid hex.
  String _createBlob(Uint8List bytes) {
    final oidOut = calloc<git_oid>();
    final buf = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);
    try {
      if (bytes.isNotEmpty) {
        buf.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
      }
      final rc = libgit2.git_blob_create_from_buffer(
        oidOut,
        _repo,
        buf.cast(),
        bytes.length,
      );
      if (rc != 0) throw StateError('git_blob_create_from_buffer failed ($rc)');
      return _oidHex(oidOut);
    } finally {
      if (buf != nullptr) calloc.free(buf);
      calloc.free(oidOut);
    }
  }

  /// Try to resolve a modify/modify conflict on a TEXT file with a deterministic
  /// additive union (see [additiveThreeWayUnion]). Reads the three blobs, skips
  /// binary content, and on a successful union writes the merged blob and
  /// returns its oid; returns null to leave the conflict for the merge agent.
  String? _tryAdditiveUnion(String baseOid, String ourOid, String theirOid) {
    try {
      final baseB = _readBlobBytes(baseOid);
      final ourB = _readBlobBytes(ourOid);
      final theirB = _readBlobBytes(theirOid);
      // Skip binary blobs (a NUL byte is git's usual text/binary heuristic).
      if (baseB.contains(0) || ourB.contains(0) || theirB.contains(0)) {
        return null;
      }
      final merged = additiveThreeWayUnion(
        utf8.decode(baseB, allowMalformed: true),
        utf8.decode(ourB, allowMalformed: true),
        utf8.decode(theirB, allowMalformed: true),
      );
      if (merged == null) return null;
      return _createBlob(Uint8List.fromList(utf8.encode(merged)));
    } catch (_) {
      return null; // any failure → fall back to a normal conflict
    }
  }

  String _createCommit({
    required String message,
    required String authorName,
    required String authorEmail,
    required String treeHex,
    required String? parentHex,
    String? refName,
  }) {
    final sigOut = calloc<Pointer<git_signature>>();
    final cName = authorName.toNativeUtf8();
    final cEmail = authorEmail.toNativeUtf8();
    final cMessage = message.toNativeUtf8();
    // Advance an explicit branch ref when given (so a per-task commit moves
    // task/<id> directly, never the shared HEAD — the key to safe concurrency);
    // otherwise move whatever branch HEAD points at.
    final refNameStr = refName ?? _commitRefName();
    final treeOid = calloc<git_oid>();
    final treeOut = calloc<Pointer<git_tree>>();
    final commitOut = calloc<git_oid>();
    final parentArr = calloc<Pointer<git_commit>>();
    Pointer<git_commit> parentCommit = nullptr;
    Pointer<git_tree> tree = nullptr;
    Pointer<git_signature> sig = nullptr;
    try {
      final rcSig = libgit2.git_signature_now(
        sigOut,
        cName.cast(),
        cEmail.cast(),
      );
      if (rcSig != 0) throw StateError('git_signature_now failed ($rcSig)');
      sig = sigOut.value;

      _oidFromHex(treeHex, treeOid);
      final rcTree = libgit2.git_tree_lookup(treeOut, _repo, treeOid);
      if (rcTree != 0) throw StateError('git_tree_lookup failed ($rcTree)');
      tree = treeOut.value;

      int parentCount = 0;
      if (parentHex != null) {
        final parentOid = calloc<git_oid>();
        final parentOut = calloc<Pointer<git_commit>>();
        try {
          _oidFromHex(parentHex, parentOid);
          final rcP = libgit2.git_commit_lookup(parentOut, _repo, parentOid);
          if (rcP == 0) {
            parentCommit = parentOut.value;
            parentArr[0] = parentCommit;
            parentCount = 1;
          }
        } finally {
          calloc.free(parentOid);
          calloc.free(parentOut);
        }
      }

      // Pass NULL for update_ref: libgit2's internal ref update runs a
      // compare-and-swap that conflicts with our custom refdb (GIT_EMODIFIED
      // -15). We own the refdb (the git_refs table), so we create the commit
      // object only, then move the branch ref ourselves below.
      final rc = libgit2.git_commit_create(
        commitOut,
        _repo,
        nullptr, // update_ref: none — we move the branch ref directly
        sig,
        sig,
        nullptr, // message encoding (UTF-8)
        cMessage.cast(),
        tree,
        parentCount,
        parentArr,
      );
      if (rc != 0) throw StateError('git_commit_create failed ($rc)');
      final commitHex = _oidHex(commitOut);
      // Point the branch ref at the new commit (HEAD stays symbolic → branch).
      _ws.database.execute(
        'INSERT OR REPLACE INTO git_refs(name, target, symbolic) VALUES(?, ?, NULL)',
        [refNameStr, commitHex],
      );
      return commitHex;
    } finally {
      if (parentCommit != nullptr) libgit2.git_commit_free(parentCommit);
      if (tree != nullptr) libgit2.git_tree_free(tree);
      if (sig != nullptr) libgit2.git_signature_free(sig);
      calloc.free(parentArr);
      calloc.free(commitOut);
      calloc.free(treeOut);
      calloc.free(treeOid);
      calloc.free(cMessage);
      calloc.free(cEmail);
      calloc.free(cName);
      calloc.free(sigOut);
    }
  }

  // ── Log ───────────────────────────────────────────────────────────────

  /// Walk the first-parent commit chain newest first. Starts at HEAD by
  /// default, or at the tip of [from] (a branch name) when given — orchestrated
  /// workers are pinned to their task branch while HEAD stays on the trunk, so
  /// without this their own commits would be invisible to `git_log`.
  Future<List<({String oid, String message, DateTime when, String author})>>
  log({int limit = 50, String? from}) async {
    final out =
        <({String oid, String message, DateTime when, String author})>[];
    final startHex = (from != null && from.trim().isNotEmpty)
        ? _resolveOid('refs/heads/${from.trim()}')
        : await headOid();
    if (startHex == null) return out;

    String? cursor = startHex;
    final seen = <String>{};
    while (cursor != null && out.length < limit && seen.add(cursor)) {
      final oid = calloc<git_oid>();
      final commitOut = calloc<Pointer<git_commit>>();
      try {
        _oidFromHex(cursor, oid);
        final rc = libgit2.git_commit_lookup(commitOut, _repo, oid);
        if (rc != 0) break;
        final commit = commitOut.value;
        try {
          out.add((
            oid: cursor,
            message: _readCString(libgit2.git_commit_message(commit)),
            when: DateTime.fromMillisecondsSinceEpoch(
              libgit2.git_commit_time(commit) * 1000,
              isUtc: true,
            ),
            author: _signatureName(libgit2.git_commit_author(commit)),
          ));
          // Advance to the first parent, if any.
          if (libgit2.git_commit_parentcount(commit) > 0) {
            final parentOut = calloc<Pointer<git_commit>>();
            try {
              final rcP = libgit2.git_commit_parent(parentOut, commit, 0);
              if (rcP == 0) {
                final parent = parentOut.value;
                cursor = _oidHexPtr(libgit2.git_commit_id(parent));
                libgit2.git_commit_free(parent);
              } else {
                cursor = null;
              }
            } finally {
              calloc.free(parentOut);
            }
          } else {
            cursor = null;
          }
        } finally {
          libgit2.git_commit_free(commit);
        }
      } finally {
        calloc.free(commitOut);
        calloc.free(oid);
      }
    }
    return out;
  }

  // ── Status ────────────────────────────────────────────────────────────

  /// Compare the workspace files against the HEAD commit's tree.
  ///
  /// For each file the engine hashes its content (without writing) and compares
  /// against the corresponding HEAD tree entry oid → `clean`/`modified`, or
  /// `untracked` when the path is absent from HEAD. Paths present in the HEAD
  /// tree but missing from the workspace are `deleted`. When HEAD is unborn
  /// everything is `untracked`.
  Future<GitStatusSnapshot> status() async {
    final branch = await currentBranch();
    final headHex = await headOid();

    final entries = await _ws.walk();
    final wsFiles =
        <String, Uint8List>{}; // path-without-leading-slash -> bytes
    for (final e in entries) {
      if (e.isDirectory) continue;
      final rel = _segments(e.path).join('/');
      if (rel.isEmpty) continue;
      wsFiles[rel] = await _ws.readBytes(e.path);
    }

    final byPath = <String, GitFileStatus>{};

    if (headHex == null) {
      // Unborn HEAD: nothing is tracked yet.
      for (final rel in wsFiles.keys) {
        byPath['/$rel'] = GitFileStatus.untracked;
      }
      return GitStatusSnapshot(
        hasRepo: true,
        branch: branch ?? _defaultBranch,
        isClean: byPath.isEmpty,
        byPath: byPath,
      );
    }

    // Map of tracked path -> blob oid hex from the HEAD tree.
    final tracked = _flattenHeadTree(headHex);

    for (final entry in wsFiles.entries) {
      final rel = entry.key;
      final wsKey = '/$rel';
      final trackedOid = tracked[rel];
      if (trackedOid == null) {
        byPath[wsKey] = GitFileStatus.untracked;
      } else {
        final blobOid = _hashBlob(entry.value);
        byPath[wsKey] = blobOid == trackedOid
            ? GitFileStatus.clean
            : GitFileStatus.modified;
      }
    }
    // Tracked files that no longer exist in the workspace → deleted.
    for (final rel in tracked.keys) {
      if (!wsFiles.containsKey(rel)) {
        byPath['/$rel'] = GitFileStatus.deleted;
      }
    }

    final dirty = byPath.values.any((s) => s != GitFileStatus.clean);
    return GitStatusSnapshot(
      hasRepo: true,
      branch: branch ?? _defaultBranch,
      isClean: !dirty,
      byPath: byPath,
    );
  }

  /// Flatten the HEAD commit's tree into a map of path (no leading slash) →
  /// blob oid hex.
  Map<String, String> _flattenHeadTree(String headHex) {
    final out = <String, String>{};
    final commitOid = calloc<git_oid>();
    final commitOut = calloc<Pointer<git_commit>>();
    try {
      _oidFromHex(headHex, commitOid);
      if (libgit2.git_commit_lookup(commitOut, _repo, commitOid) != 0) {
        return out;
      }
      final commit = commitOut.value;
      try {
        final treeOut = calloc<Pointer<git_tree>>();
        try {
          if (libgit2.git_commit_tree(treeOut, commit) != 0) return out;
          final tree = treeOut.value;
          try {
            _walkTree(tree, '', out);
          } finally {
            libgit2.git_tree_free(tree);
          }
        } finally {
          calloc.free(treeOut);
        }
      } finally {
        libgit2.git_commit_free(commit);
      }
    } finally {
      calloc.free(commitOut);
      calloc.free(commitOid);
    }
    return out;
  }

  /// Recursively collect blob entries from [tree] into [out] under [prefix].
  void _walkTree(
    Pointer<git_tree> tree,
    String prefix,
    Map<String, String> out,
  ) {
    final count = libgit2.git_tree_entrycount(tree);
    for (var i = 0; i < count; i++) {
      final entry = libgit2.git_tree_entry_byindex(tree, i);
      if (entry == nullptr) continue;
      final name = _readCString(libgit2.git_tree_entry_name(entry));
      final path = prefix.isEmpty ? name : '$prefix/$name';
      final type = libgit2.git_tree_entry_type(entry);
      final oidHex = _oidHexPtr(libgit2.git_tree_entry_id(entry));
      if (type == git_object_t.GIT_OBJECT_TREE) {
        final subOid = calloc<git_oid>();
        final subOut = calloc<Pointer<git_tree>>();
        try {
          _oidFromHex(oidHex, subOid);
          if (libgit2.git_tree_lookup(subOut, _repo, subOid) == 0) {
            final sub = subOut.value;
            try {
              _walkTree(sub, path, out);
            } finally {
              libgit2.git_tree_free(sub);
            }
          }
        } finally {
          calloc.free(subOut);
          calloc.free(subOid);
        }
      } else if (type == git_object_t.GIT_OBJECT_BLOB) {
        out[path] = oidHex;
      }
    }
  }

  /// Compute the oid a blob of [bytes] would have, without writing it.
  String _hashBlob(Uint8List bytes) {
    final oidOut = calloc<git_oid>();
    final buf = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);
    try {
      if (bytes.isNotEmpty) {
        buf.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
      }
      final rc = libgit2.git_odb_hash(
        oidOut,
        buf.cast(),
        bytes.length,
        git_object_t.GIT_OBJECT_BLOB,
        git_oid_t.GIT_OID_SHA1,
      );
      if (rc != 0) throw StateError('git_odb_hash failed ($rc)');
      return _oidHex(oidOut);
    } finally {
      if (buf != nullptr) calloc.free(buf);
      calloc.free(oidOut);
    }
  }

  // ── Ref / oid helpers ───────────────────────────────────────────────────

  /// Read a ref row straight from the refdb-backed SQLite table.
  _RefRow? _lookupRefRow(String name) {
    final rows = _ws.database.select(
      'SELECT name, target, symbolic FROM git_refs WHERE name=?',
      [name],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return _RefRow(r['target'] as String?, r['symbolic'] as String?);
  }

  // ── Low-level FFI string/oid utilities ─────────────────────────────────

  List<String> _segments(String wsPath) => pathSegments(wsPath);

  /// 40-char hex of a `git_oid*`.
  String _oidHex(Pointer<git_oid> oid) => _oidHexPtr(oid);

  String _oidHexPtr(Pointer<git_oid> oid) {
    final b = StringBuffer();
    for (var i = 0; i < 20; i++) {
      b.write(oid.ref.id[i].toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  void _oidFromHex(String hex, Pointer<git_oid> out) {
    final cHex = hex.toNativeUtf8();
    try {
      final rc = libgit2.git_oid_fromstr(
        out,
        cHex.cast(),
        git_oid_t.GIT_OID_SHA1,
      );
      if (rc != 0) throw StateError('git_oid_fromstr failed ($rc) for "$hex"');
    } finally {
      calloc.free(cHex);
    }
  }

  String _readCString(Pointer<Char> p) {
    if (p == nullptr) return '';
    return p.cast<Utf8>().toDartString();
  }

  String _signatureName(Pointer<git_signature> sig) {
    if (sig == nullptr) return '';
    final namePtr = sig.ref.name;
    if (namePtr == nullptr) return '';
    return namePtr.cast<Utf8>().toDartString();
  }

  // ── Branches ──────────────────────────────────────────────────────────

  static final RegExp _branchNameOk = RegExp(r'^[A-Za-z0-9._\-/]+$');

  /// Local branch short names (e.g. `main`, `feature/x`), sorted.
  Future<List<String>> branches() async {
    const prefix = 'refs/heads/';
    final rows = _ws.database.select(
      "SELECT name FROM git_refs WHERE name LIKE 'refs/heads/%' ORDER BY name",
    );
    return rows
        .map((r) => (r['name'] as String).substring(prefix.length))
        .toList();
  }

  /// Create a new branch at the current HEAD commit. Optionally switch to it.
  /// Throws if HEAD is unborn (no commit to branch from) or the name is invalid
  /// or already exists.
  Future<void> createBranch(String name, {bool checkout = false}) async {
    final clean = name.trim();
    if (clean.isEmpty ||
        !_branchNameOk.hasMatch(clean) ||
        clean.startsWith('/') ||
        clean.endsWith('/')) {
      throw StateError('Invalid branch name: "$name"');
    }
    final headHex = await headOid();
    if (headHex == null) {
      throw StateError('Commit something before creating a branch.');
    }
    final refName = 'refs/heads/$clean';
    final exists = _ws.database.select('SELECT 1 FROM git_refs WHERE name=?', [
      refName,
    ]).isNotEmpty;
    if (exists) throw StateError('Branch "$clean" already exists.');
    _ws.database.execute(
      'INSERT INTO git_refs(name, target, symbolic) VALUES(?, ?, NULL)',
      [refName, headHex],
    );
    if (checkout) await checkoutBranch(clean);
  }

  /// Switch HEAD to [name] and materialize that branch tip's tree into the
  /// workspace (writing/overwriting tracked files, deleting files absent from
  /// the target tree). Uncommitted workspace changes are overwritten — callers
  /// should confirm with the user first.
  Future<void> checkoutBranch(String name) async {
    final refName = 'refs/heads/$name';
    final exists = _ws.database.select('SELECT 1 FROM git_refs WHERE name=?', [
      refName,
    ]).isNotEmpty;
    if (!exists) throw StateError('Branch "$name" does not exist.');

    // Repoint HEAD (symbolic) at the target branch.
    _ws.database.execute(
      'INSERT OR REPLACE INTO git_refs(name, target, symbolic) VALUES(?, NULL, ?)',
      ['HEAD', refName],
    );

    final tipHex = _resolveOid('HEAD');
    if (tipHex == null) return; // Unborn target branch: leave workspace as-is.
    await _materializeTree(tipHex);
  }

  /// Overwrite the workspace files to match [commitHex]'s tree: write every
  /// tracked blob and delete workspace files absent from that tree.
  Future<void> _materializeTree(String commitHex, {Workspace? tree}) async {
    final ws = tree ?? _ws;
    final target = _flattenHeadTree(commitHex); // rel -> blob oid hex
    for (final entry in target.entries) {
      await ws.writeBytes('/${entry.key}', _readBlobBytes(entry.value));
    }
    final wsEntries = await ws.walk();
    for (final e in wsEntries) {
      if (e.isDirectory) continue;
      final rel = _segments(e.path).join('/');
      if (rel.isNotEmpty && !target.containsKey(rel)) {
        await ws.delete(e.path);
      }
    }
  }

  // ── Merge ───────────────────────────────────────────────────────────────

  /// Merge [branch] into the current branch.
  ///
  /// Resolves into one of four outcomes ([MergeResult]):
  ///  - **upToDate**: the current branch already contains [branch]'s tip.
  ///  - **fastForward**: the current tip is an ancestor of [branch], so HEAD's
  ///    branch ref is advanced to [branch]'s tip (no merge commit).
  ///  - **merged**: histories diverged but every file change is non-overlapping;
  ///    a two-parent merge commit is created on the current branch.
  ///  - **conflicts**: the same files changed differently on both sides. No
  ///    commit is made and no refs move — the caller should send the work back
  ///    rather than guess. The conflicting paths are returned.
  ///
  /// Three-way resolution is per-file (tree level), not per-line: a file is a
  /// conflict only when both sides changed it to different content. This is
  /// deliberately conservative — it never fabricates a blended file.
  Future<MergeResult> merge(
    String branch, {
    String authorName = 'Coordinator',
    String authorEmail = 'agent@nexus.local',
    String? message,
  }) async {
    final theirRef = 'refs/heads/$branch';
    final theirHex = _resolveOid(theirRef);
    if (theirHex == null) {
      throw StateError('Branch "$branch" does not exist or has no commits.');
    }

    final ourRef = _commitRefName();
    final ourHex = await headOid();

    // Unborn current branch: adopt theirs wholesale (fast-forward).
    if (ourHex == null) {
      _ws.database.execute(
        'INSERT OR REPLACE INTO git_refs(name, target, symbolic) VALUES(?, ?, NULL)',
        [ourRef, theirHex],
      );
      await _materializeTree(theirHex);
      return MergeResult(MergeOutcome.fastForward, oid: theirHex);
    }

    if (ourHex == theirHex) return const MergeResult(MergeOutcome.upToDate);

    final base = _mergeBase(ourHex, theirHex);

    // Their tip is already in our history → nothing to do.
    if (base == theirHex) return const MergeResult(MergeOutcome.upToDate);

    // Our tip is an ancestor of theirs → fast-forward.
    if (base == ourHex) {
      _ws.database.execute(
        'INSERT OR REPLACE INTO git_refs(name, target, symbolic) VALUES(?, ?, NULL)',
        [ourRef, theirHex],
      );
      await _materializeTree(theirHex);
      return MergeResult(MergeOutcome.fastForward, oid: theirHex);
    }

    // Diverged: three-way merge at the file level.
    final baseTree = base == null ? <String, String>{} : _flattenHeadTree(base);
    final ourTree = _flattenHeadTree(ourHex);
    final theirTree = _flattenHeadTree(theirHex);

    final merged = <String, String>{}; // rel -> blob oid hex
    final conflicts = <String>[];

    final allPaths = <String>{
      ...baseTree.keys,
      ...ourTree.keys,
      ...theirTree.keys,
    };
    for (final p in allPaths) {
      final b = baseTree[p];
      final o = ourTree[p];
      final t = theirTree[p];
      if (o == t) {
        if (o != null)
          merged[p] = o; // identical on both sides (or both deleted)
        continue;
      }
      if (o == b) {
        // We didn't touch it; take theirs (modification or deletion).
        if (t != null) merged[p] = t;
        continue;
      }
      if (t == b) {
        // They didn't touch it; keep ours.
        if (o != null) merged[p] = o;
        continue;
      }
      // Both sides changed it differently (modify/modify, add/add,
      // modify/delete, delete/modify). Before declaring a conflict, try a
      // deterministic ADDITIVE union for the modify/modify TEXT case — the
      // dominant real orchestrator conflict is two tasks that each only ADDED
      // lines to the same shared file (e.g. a dependency appended to
      // pubspec.yaml). The union applies ONLY when neither side removed or
      // changed a base line, so it never fabricates a blended file; every other
      // shape falls through to a real conflict for the merge agent, exactly as
      // before.
      if (b != null && o != null && t != null) {
        final unionOid = _tryAdditiveUnion(b, o, t);
        if (unionOid != null) {
          merged[p] = unionOid;
          continue;
        }
      }
      conflicts.add('/$p');
    }

    if (conflicts.isNotEmpty) {
      conflicts.sort();
      return MergeResult(MergeOutcome.conflicts, conflicts: conflicts);
    }

    final root = _DirNode();
    merged.forEach((rel, oidHex) => _addExistingToTree(root, rel, oidHex));
    final treeOid = _writeDir(root);

    final mergeHex = _createMergeCommit(
      message: message ?? "Merge branch '$branch'",
      authorName: authorName,
      authorEmail: authorEmail,
      treeHex: treeOid,
      parentHexes: [ourHex, theirHex],
    );
    await _materializeTree(mergeHex);
    return MergeResult(MergeOutcome.merged, oid: mergeHex);
  }

  /// For a CONFLICTED [merge] of [branch] into the current branch, write each
  /// path in [paths] into [ws] with standard `<<<<<<< / ======= / >>>>>>>`
  /// markers so an agent can SEE both sides and resolve them.
  ///
  /// [merge] itself is file-level and deliberately writes NOTHING on a conflict,
  /// which left the merge agent staring at an unmodified file while being told to
  /// "remove every conflict marker" — impossible, so every real conflict ended in
  /// a Blocked task. Call this before handing the conflict to an agent.
  ///
  /// Binary blobs are skipped (nothing useful to mark). Returns how many files
  /// were marked.
  Future<int> writeConflictMarkers(
    String branch,
    Workspace ws,
    List<String> paths,
  ) async {
    final theirHex = _resolveOid('refs/heads/$branch');
    final ourHex = await headOid();
    if (theirHex == null || ourHex == null) return 0;
    final ourTree = _flattenHeadTree(ourHex);
    final theirTree = _flattenHeadTree(theirHex);

    String? textOf(String? oidHex) {
      if (oidHex == null) return null;
      final bytes = _readBlobBytes(oidHex);
      if (bytes.contains(0)) return null; // binary
      return utf8.decode(bytes, allowMalformed: true);
    }

    var marked = 0;
    for (final raw in paths) {
      final rel = raw.startsWith('/') ? raw.substring(1) : raw;
      final oOid = ourTree[rel];
      final tOid = theirTree[rel];
      if (oOid == null && tOid == null) continue;
      final oTxt = textOf(oOid);
      final tTxt = textOf(tOid);
      // Binary on either present side → leave the file alone.
      if ((oOid != null && oTxt == null) || (tOid != null && tTxt == null)) {
        continue;
      }
      await ws.writeString(
        '/$rel',
        conflictMarkedText(
          oTxt ?? '(file deleted on this branch)',
          tTxt ?? '(file deleted on "$branch")',
          oursLabel: 'ours (current)',
          theirsLabel: 'theirs ($branch)',
        ),
      );
      marked++;
    }
    return marked;
  }

  /// Lowest common ancestor of two commits, or null if they share none.
  ///
  /// Collects every ancestor of [aHex], then walks [bHex]'s ancestry
  /// breadth-first and returns the first commit that also belongs to a's set.
  String? _mergeBase(String aHex, String bHex) {
    final ancestorsOfA = <String>{};
    final stack = <String>[aHex];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      if (!ancestorsOfA.add(cur)) continue;
      stack.addAll(_commitParents(cur));
    }
    final seen = <String>{};
    final queue = <String>[bHex];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (!seen.add(cur)) continue;
      if (ancestorsOfA.contains(cur)) return cur;
      queue.addAll(_commitParents(cur));
    }
    return null;
  }

  /// The parent commit oids (hex) of [hex], in order.
  List<String> _commitParents(String hex) {
    final out = <String>[];
    final oid = calloc<git_oid>();
    final commitOut = calloc<Pointer<git_commit>>();
    try {
      _oidFromHex(hex, oid);
      if (libgit2.git_commit_lookup(commitOut, _repo, oid) != 0) return out;
      final commit = commitOut.value;
      try {
        final n = libgit2.git_commit_parentcount(commit);
        for (var i = 0; i < n; i++) {
          final pOut = calloc<Pointer<git_commit>>();
          try {
            if (libgit2.git_commit_parent(pOut, commit, i) == 0) {
              final p = pOut.value;
              out.add(_oidHexPtr(libgit2.git_commit_id(p)));
              libgit2.git_commit_free(p);
            }
          } finally {
            calloc.free(pOut);
          }
        }
      } finally {
        libgit2.git_commit_free(commit);
      }
    } finally {
      calloc.free(commitOut);
      calloc.free(oid);
    }
    return out;
  }

  /// Create a commit with an arbitrary number of parents (used for merge
  /// commits) and advance the current branch ref to it. Mirrors [_createCommit]
  /// but takes a parent list.
  String _createMergeCommit({
    required String message,
    required String authorName,
    required String authorEmail,
    required String treeHex,
    required List<String> parentHexes,
  }) {
    final sigOut = calloc<Pointer<git_signature>>();
    final cName = authorName.toNativeUtf8();
    final cEmail = authorEmail.toNativeUtf8();
    final cMessage = message.toNativeUtf8();
    final refNameStr = _commitRefName();
    final treeOid = calloc<git_oid>();
    final treeOut = calloc<Pointer<git_tree>>();
    final commitOut = calloc<git_oid>();
    final parentArr = calloc<Pointer<git_commit>>(
      parentHexes.isEmpty ? 1 : parentHexes.length,
    );
    final parents = <Pointer<git_commit>>[];
    Pointer<git_tree> tree = nullptr;
    Pointer<git_signature> sig = nullptr;
    try {
      final rcSig = libgit2.git_signature_now(
        sigOut,
        cName.cast(),
        cEmail.cast(),
      );
      if (rcSig != 0) throw StateError('git_signature_now failed ($rcSig)');
      sig = sigOut.value;

      _oidFromHex(treeHex, treeOid);
      final rcTree = libgit2.git_tree_lookup(treeOut, _repo, treeOid);
      if (rcTree != 0) throw StateError('git_tree_lookup failed ($rcTree)');
      tree = treeOut.value;

      var count = 0;
      for (final ph in parentHexes) {
        final pOid = calloc<git_oid>();
        final pOut = calloc<Pointer<git_commit>>();
        try {
          _oidFromHex(ph, pOid);
          if (libgit2.git_commit_lookup(pOut, _repo, pOid) == 0) {
            final pc = pOut.value;
            parents.add(pc);
            parentArr[count] = pc;
            count++;
          }
        } finally {
          calloc.free(pOid);
          calloc.free(pOut);
        }
      }

      final rc = libgit2.git_commit_create(
        commitOut,
        _repo,
        nullptr, // update_ref: none — we move the branch ref ourselves
        sig,
        sig,
        nullptr,
        cMessage.cast(),
        tree,
        count,
        parentArr,
      );
      if (rc != 0) throw StateError('git_commit_create failed ($rc)');
      final commitHex = _oidHex(commitOut);
      _ws.database.execute(
        'INSERT OR REPLACE INTO git_refs(name, target, symbolic) VALUES(?, ?, NULL)',
        [refNameStr, commitHex],
      );
      return commitHex;
    } finally {
      for (final p in parents) {
        libgit2.git_commit_free(p);
      }
      if (tree != nullptr) libgit2.git_tree_free(tree);
      if (sig != nullptr) libgit2.git_signature_free(sig);
      calloc.free(parentArr);
      calloc.free(commitOut);
      calloc.free(treeOut);
      calloc.free(treeOid);
      calloc.free(cMessage);
      calloc.free(cEmail);
      calloc.free(cName);
      calloc.free(sigOut);
    }
  }

  // ── Per-file commit + diff ───────────────────────────────────────────

  /// Commit ONLY the given workspace paths (with leading-slash form, matching
  /// the [Workspace] API). Files not in [paths] retain their previous HEAD
  /// content. A selected path whose workspace file is missing is committed as
  /// a deletion. Returns the new commit's oid hex.
  Future<String> commitFiles({
    required Iterable<String> paths,
    required String message,
    String authorName = 'Coordinator',
    String authorEmail = 'agent@nexus.local',
  }) async {
    final selected = paths
        .map((p) => p.startsWith('/') ? p.substring(1) : p)
        .where((p) => p.isNotEmpty)
        .toSet();
    final parentHex = await headOid();
    final root = _DirNode();

    // 1) Carry forward HEAD's entries for paths the user did NOT select.
    if (parentHex != null) {
      final headEntries = _flattenHeadTree(parentHex);
      headEntries.forEach((rel, oidHex) {
        if (!selected.contains(rel)) {
          _addExistingToTree(root, rel, oidHex);
        }
      });
    }

    // 2) Apply the selected paths from the workspace (skip deletions).
    for (final rel in selected) {
      final wsPath = '/$rel';
      if (!await _ws.exists(wsPath)) continue; // selected deletion
      final stat = await _ws.stat(wsPath);
      if (stat.isDirectory) continue;
      final bytes = await _ws.readBytes(wsPath);
      _addBytesToTree(root, rel, bytes);
    }

    final treeOid = _writeDir(root);
    return _createCommit(
      message: message,
      authorName: authorName,
      authorEmail: authorEmail,
      treeHex: treeOid,
      parentHex: parentHex,
    );
  }

  void _addExistingToTree(_DirNode root, String rel, String oidHex) {
    final segs = rel.split('/');
    if (segs.isEmpty) return;
    var node = root;
    for (var i = 0; i < segs.length - 1; i++) {
      node = node.dirs.putIfAbsent(segs[i], () => _DirNode());
    }
    node.existingFiles[segs.last] = oidHex;
  }

  void _addBytesToTree(_DirNode root, String rel, Uint8List bytes) {
    final segs = rel.split('/');
    if (segs.isEmpty) return;
    var node = root;
    for (var i = 0; i < segs.length - 1; i++) {
      node = node.dirs.putIfAbsent(segs[i], () => _DirNode());
    }
    node.files[segs.last] = bytes;
    // New content wins over a same-name existing entry.
    node.existingFiles.remove(segs.last);
  }

  /// Raw bytes of a tracked file as stored in the HEAD commit, or null if the
  /// path is not in HEAD (untracked / unborn). [path] may be in leading-slash
  /// workspace form or relative. Used to restore a file on "discard changes".
  Future<Uint8List?> headFileBytes(String path) async {
    final headHex = await headOid();
    if (headHex == null) return null;
    final rel = _segments(path).join('/');
    if (rel.isEmpty) return null;
    final oidHex = _flattenHeadTree(headHex)[rel];
    if (oidHex == null) return null;
    return _readBlobBytes(oidHex);
  }

  /// Read a blob's raw content from the ODB by oid hex (copied out of libgit2's
  /// buffer so the caller owns it after the blob is freed).
  Uint8List _readBlobBytes(String oidHex) {
    final oid = calloc<git_oid>();
    final blobOut = calloc<Pointer<git_blob>>();
    try {
      _oidFromHex(oidHex, oid);
      final rc = libgit2.git_blob_lookup(blobOut, _repo, oid);
      if (rc != 0) throw StateError('git_blob_lookup failed ($rc)');
      final blob = blobOut.value;
      try {
        final size = libgit2.git_blob_rawsize(blob);
        if (size == 0) return Uint8List(0);
        final ptr = libgit2.git_blob_rawcontent(blob);
        return Uint8List.fromList(ptr.cast<Uint8>().asTypedList(size));
      } finally {
        libgit2.git_blob_free(blob);
      }
    } finally {
      calloc.free(blobOut);
      calloc.free(oid);
    }
  }

  /// UTF-8 (lossy) text of a blob by oid hex, or null for a null oid. Used by
  /// the side-by-side diff to show the before/after content of a commit.
  Future<String?> blobText(String? oidHex) async {
    if (oidHex == null || oidHex.isEmpty) return null;
    return decodeUtf8Lossy(_readBlobBytes(oidHex));
  }

  /// path→blobOid map of [branch]'s tip commit (paths are workspace-relative
  /// without a leading slash). Empty if the branch/ref doesn't exist. Read-only:
  /// reads the object DB without touching any working tree — safe to call while
  /// the orchestrator is committing on the same repo. Backs the Code browser's
  /// read-only "view a task branch" snapshot.
  Future<Map<String, String>> treeAt(String branch) async {
    final tip = _resolveOid('refs/heads/$branch');
    if (tip == null) return const {};
    return _flattenHeadTree(tip);
  }

  /// Raw bytes of a blob by oid hex (for the branch snapshot file viewer).
  Uint8List blobBytesByOid(String oidHex) => _readBlobBytes(oidHex);

  /// File-level diff for a commit (vs its first parent; vs empty tree for the
  /// root commit). Returns per-path entries used by the History panel.
  Future<List<CommitFileChange>> commitDiff(String commitOidHex) async {
    final oid = calloc<git_oid>();
    final commitOut = calloc<Pointer<git_commit>>();
    final newTreeOut = calloc<Pointer<git_tree>>();
    final parentOut = calloc<Pointer<git_commit>>();
    final parentTreeOut = calloc<Pointer<git_tree>>();
    try {
      _oidFromHex(commitOidHex, oid);
      if (libgit2.git_commit_lookup(commitOut, _repo, oid) != 0)
        return const [];
      final commit = commitOut.value;
      try {
        if (libgit2.git_commit_tree(newTreeOut, commit) != 0) return const [];
        final newTree = newTreeOut.value;
        try {
          final newMap = <String, String>{};
          _walkTree(newTree, '', newMap);
          final oldMap = <String, String>{};
          if (libgit2.git_commit_parentcount(commit) > 0) {
            if (libgit2.git_commit_parent(parentOut, commit, 0) == 0) {
              final parent = parentOut.value;
              try {
                if (libgit2.git_commit_tree(parentTreeOut, parent) == 0) {
                  final pt = parentTreeOut.value;
                  try {
                    _walkTree(pt, '', oldMap);
                  } finally {
                    libgit2.git_tree_free(pt);
                  }
                }
              } finally {
                libgit2.git_commit_free(parent);
              }
            }
          }
          final out = <CommitFileChange>[];
          for (final entry in newMap.entries) {
            final path = '/${entry.key}';
            final oldOid = oldMap[entry.key];
            if (oldOid == null) {
              out.add(
                CommitFileChange(
                  path: path,
                  change: CommitChangeKind.added,
                  oldOid: null,
                  newOid: entry.value,
                ),
              );
            } else if (oldOid != entry.value) {
              out.add(
                CommitFileChange(
                  path: path,
                  change: CommitChangeKind.modified,
                  oldOid: oldOid,
                  newOid: entry.value,
                ),
              );
            }
          }
          for (final entry in oldMap.entries) {
            if (!newMap.containsKey(entry.key)) {
              out.add(
                CommitFileChange(
                  path: '/${entry.key}',
                  change: CommitChangeKind.deleted,
                  oldOid: entry.value,
                  newOid: null,
                ),
              );
            }
          }
          out.sort((a, b) => a.path.compareTo(b.path));
          return out;
        } finally {
          libgit2.git_tree_free(newTree);
        }
      } finally {
        libgit2.git_commit_free(commit);
      }
    } finally {
      calloc.free(oid);
      calloc.free(commitOut);
      calloc.free(newTreeOut);
      calloc.free(parentOut);
      calloc.free(parentTreeOut);
    }
  }
}

/// How a [NxtprjGitEngine.merge] resolved.
enum MergeOutcome {
  /// The current branch already contains the merged branch's tip.
  upToDate,

  /// The branch ref was advanced to the merged branch (no merge commit).
  fastForward,

  /// A two-parent merge commit was created (non-overlapping changes).
  merged,

  /// Both sides changed the same files differently; nothing was committed.
  conflicts,
}

/// Result of a merge attempt. [oid] is the resulting commit for
/// fastForward/merged; [conflicts] lists the clashing paths for conflicts.
class MergeResult {
  final MergeOutcome outcome;
  final String? oid;
  final List<String> conflicts;
  const MergeResult(this.outcome, {this.oid, this.conflicts = const []});
}

enum CommitChangeKind { added, modified, deleted }

class CommitFileChange {
  final String path;
  final CommitChangeKind change;
  final String? oldOid;
  final String? newOid;
  const CommitFileChange({
    required this.path,
    required this.change,
    this.oldOid,
    this.newOid,
  });
}

/// In-memory directory node used while assembling the commit tree.
class _DirNode {
  final Map<String, _DirNode> dirs = {};

  /// New content from the workspace (will be written as a blob).
  final Map<String, Uint8List> files = {};

  /// Existing blob oid hex from HEAD tree (referenced as-is, no blob write).
  final Map<String, String> existingFiles = {};
}

/// A row from the `git_refs` table.
class _RefRow {
  final String? target;
  final String? symbolic;
  _RefRow(this.target, this.symbolic);
}
