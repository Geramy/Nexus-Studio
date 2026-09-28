// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'workspace.dart';
import 'git/nxtprj_git_odb.dart' show initGitSchema;

/// A project's "virtual hard drive": the entire filesystem stored in ONE SQLite
/// file, accessed purely through this API (never mounted).
///
/// Files are stored as fixed-size BLOCKS (like disk sectors), not one giant
/// blob — small blobs are SQLite's fast path, partial writes touch only the
/// affected blocks, and [readRange] seeks straight to a byte offset. The git
/// engine (git2dart custom ODB/refdb backend) binds to this same file so files
/// and git history live together in the one disk.
class VhdWorkspace implements Workspace {
  final Database _db;

  /// Block size (bytes). 64 KiB: small enough for fine-grained edits, large
  /// enough to keep row counts reasonable for big files.
  static const int blockSize = 1 << 16;

  VhdWorkspace._(this._db);

  /// The underlying SQLite connection. The git engine shares this same handle
  /// so the filesystem and git objects/refs live in the one `.nxtprj` file and
  /// stay on a single isolate (required by the libgit2 backend callbacks).
  Database get database => _db;

  /// Open (creating if needed) the SQLite virtual disk at [filePath].
  static Future<VhdWorkspace> open(String filePath) async {
    final db = sqlite3.open(filePath);
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA foreign_keys=ON;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS nodes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER REFERENCES nodes(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_dir INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL DEFAULT 0,
        mtime INTEGER NOT NULL,
        UNIQUE(parent_id, name)
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS blocks(
        node_id INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
        block_no INTEGER NOT NULL,
        data BLOB NOT NULL,
        PRIMARY KEY(node_id, block_no)
      ) WITHOUT ROWID;
    ''');
    // Ensure the root directory (id is forced to 1).
    db.execute(
      "INSERT OR IGNORE INTO nodes(id, parent_id, name, is_dir, size, mtime) VALUES(1, NULL, '', 1, 0, ?);",
      [_now()],
    );
    // The project disk IS a git repo — create the git tables eagerly so the
    // engine doesn't need a "git init" UX. The engine binds to these on its
    // first open and HEAD starts unborn (refs/heads/main).
    initGitSchema(db);
    return VhdWorkspace._(db);
  }

  void dispose() => _db.close();

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  // ── Node resolution ─────────────────────────────────────────────────

  /// Resolve a workspace path to its node row, or null if missing.
  Map<String, Object?>? _node(String wsPath) {
    final segs = pathSegments(wsPath);
    int id = 1; // root
    var row = _rowById(1);
    for (final name in segs) {
      final child = _db.select(
        'SELECT id, parent_id, name, is_dir, size, mtime FROM nodes WHERE parent_id=? AND name=?',
        [id, name],
      );
      if (child.isEmpty) return null;
      row = child.first;
      id = row['id'] as int;
    }
    return row;
  }

  Map<String, Object?>? _rowById(int id) {
    final r = _db.select(
      'SELECT id, parent_id, name, is_dir, size, mtime FROM nodes WHERE id=?',
      [id],
    );
    return r.isEmpty ? null : r.first;
  }

  /// Resolve (and optionally create) the parent directory of [wsPath]; returns
  /// the parent node id and the final segment name.
  ({int parentId, String name}) _resolveParent(
    String wsPath, {
    bool create = false,
  }) {
    final segs = pathSegments(wsPath);
    if (segs.isEmpty)
      throw WorkspaceException(
        'Refusing to operate on the root itself: "$wsPath"',
      );
    final name = segs.removeLast();
    int id = 1;
    for (final seg in segs) {
      final child = _db.select(
        'SELECT id, is_dir FROM nodes WHERE parent_id=? AND name=?',
        [id, seg],
      );
      if (child.isEmpty) {
        if (!create)
          throw WorkspaceException(
            'No such directory: contains "$seg" in "$wsPath"',
          );
        _db.execute(
          'INSERT INTO nodes(parent_id, name, is_dir, size, mtime) VALUES(?, ?, 1, 0, ?)',
          [id, seg, _now()],
        );
        id = _db.lastInsertRowId;
      } else {
        if ((child.first['is_dir'] as int) == 0)
          throw WorkspaceException('Not a directory: "$seg" in "$wsPath"');
        id = child.first['id'] as int;
      }
    }
    return (parentId: id, name: name);
  }

  FileEntry _entry(Map<String, Object?> row, String path) => FileEntry(
    name: (row['name'] as String).isEmpty ? '' : row['name'] as String,
    path: path,
    isDirectory: (row['is_dir'] as int) == 1,
    size: row['size'] as int,
    modified: DateTime.fromMillisecondsSinceEpoch(row['mtime'] as int),
  );

  String _childPath(String parentPath, String name) =>
      parentPath == '/' ? '/$name' : '$parentPath/$name';

  // ── Reads ───────────────────────────────────────────────────────────

  @override
  Future<bool> exists(String wsPath) async => _node(wsPath) != null;

  @override
  Future<FileEntry> stat(String wsPath) async {
    final row = _node(wsPath);
    if (row == null) throw WorkspaceException('Not found: "$wsPath"');
    return _entry(row, '/${normalizeRel(wsPath)}'.replaceAll('//', '/'));
  }

  @override
  Future<List<FileEntry>> list([String wsPath = '/']) async {
    final dir = _node(wsPath);
    if (dir == null) throw WorkspaceException('Not found: "$wsPath"');
    if ((dir['is_dir'] as int) == 0)
      throw WorkspaceException('Not a directory: "$wsPath"');
    final basePath = '/${normalizeRel(wsPath)}'.replaceAll('//', '/');
    final rows = _db.select(
      'SELECT id, name, is_dir, size, mtime FROM nodes WHERE parent_id=? ORDER BY is_dir DESC, name COLLATE NOCASE',
      [dir['id']],
    );
    return [
      for (final r in rows)
        _entry(r, _childPath(basePath, r['name'] as String)),
    ];
  }

  @override
  Future<List<FileEntry>> walk({
    String from = '/',
    int maxEntries = 5000,
  }) async {
    final out = <FileEntry>[];
    Future<void> recurse(String dir) async {
      if (out.length >= maxEntries) return;
      for (final e in await list(dir)) {
        if (out.length >= maxEntries) return;
        out.add(e);
        if (e.isDirectory) await recurse(e.path);
      }
    }

    await recurse(from);
    return out;
  }

  @override
  Future<Uint8List> readBytes(String wsPath) async {
    final row = _fileRow(wsPath);
    final size = row['size'] as int;
    final out = Uint8List(size);
    final blocks = _db.select(
      'SELECT block_no, data FROM blocks WHERE node_id=? ORDER BY block_no',
      [row['id']],
    );
    for (final b in blocks) {
      final data = b['data'] as Uint8List;
      final offset = (b['block_no'] as int) * blockSize;
      out.setRange(offset, offset + data.length, data);
    }
    return out;
  }

  @override
  Future<String> readString(String wsPath) async =>
      decodeUtf8Lossy(await readBytes(wsPath));

  @override
  Future<Uint8List> readRange(String wsPath, int offset, int length) async {
    final row = _fileRow(wsPath);
    final size = row['size'] as int;
    if (offset < 0 || offset >= size || length <= 0) return Uint8List(0);
    final end = (offset + length).clamp(0, size);
    final firstBlock = offset ~/ blockSize;
    final lastBlock = (end - 1) ~/ blockSize;
    final out = BytesBuilder(copy: false);
    final rows = _db.select(
      'SELECT block_no, data FROM blocks WHERE node_id=? AND block_no BETWEEN ? AND ? ORDER BY block_no',
      [row['id'], firstBlock, lastBlock],
    );
    for (final b in rows) {
      final blockNo = b['block_no'] as int;
      final data = b['data'] as Uint8List;
      final blockStart = blockNo * blockSize;
      final from = offset > blockStart ? offset - blockStart : 0;
      final to = end < blockStart + data.length
          ? end - blockStart
          : data.length;
      if (to > from) out.add(data.sublist(from, to));
    }
    return out.toBytes();
  }

  @override
  Future<bool> isProbablyBinary(String wsPath) async {
    final row = _fileRow(wsPath);
    if ((row['size'] as int) == 0) return false;
    final first = _db.select(
      'SELECT data FROM blocks WHERE node_id=? AND block_no=0',
      [row['id']],
    );
    if (first.isEmpty) return false;
    final data = first.first['data'] as Uint8List;
    final sample = data.length > 4096 ? data.sublist(0, 4096) : data;
    return sample.contains(0);
  }

  Map<String, Object?> _fileRow(String wsPath) {
    final row = _node(wsPath);
    if (row == null) throw WorkspaceException('File not found: "$wsPath"');
    if ((row['is_dir'] as int) == 1)
      throw WorkspaceException('Is a directory: "$wsPath"');
    return row;
  }

  // ── Writes ──────────────────────────────────────────────────────────

  @override
  Future<FileEntry> writeString(String wsPath, String content) =>
      writeBytes(wsPath, utf8.encode(content));

  @override
  Future<FileEntry> writeBytes(String wsPath, List<int> bytes) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final p = _resolveParent(wsPath, create: true);
    _db.execute('BEGIN');
    try {
      var existing = _db.select(
        'SELECT id, is_dir FROM nodes WHERE parent_id=? AND name=?',
        [p.parentId, p.name],
      );
      int nodeId;
      if (existing.isEmpty) {
        _db.execute(
          'INSERT INTO nodes(parent_id, name, is_dir, size, mtime) VALUES(?, ?, 0, ?, ?)',
          [p.parentId, p.name, data.length, _now()],
        );
        nodeId = _db.lastInsertRowId;
      } else {
        if ((existing.first['is_dir'] as int) == 1)
          throw WorkspaceException('Is a directory: "$wsPath"');
        nodeId = existing.first['id'] as int;
        _db.execute('DELETE FROM blocks WHERE node_id=?', [nodeId]);
        _db.execute('UPDATE nodes SET size=?, mtime=? WHERE id=?', [
          data.length,
          _now(),
          nodeId,
        ]);
      }
      final stmt = _db.prepare(
        'INSERT INTO blocks(node_id, block_no, data) VALUES(?, ?, ?)',
      );
      for (var i = 0, block = 0; i < data.length; i += blockSize, block++) {
        final endIdx = (i + blockSize < data.length)
            ? i + blockSize
            : data.length;
        stmt.execute([nodeId, block, data.sublist(i, endIdx)]);
      }
      stmt.close();
      _db.execute('COMMIT');
      return await stat(wsPath);
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<FileEntry> createDirectory(String wsPath) async {
    final p = _resolveParent(wsPath, create: true);
    final existing = _db.select(
      'SELECT id, is_dir FROM nodes WHERE parent_id=? AND name=?',
      [p.parentId, p.name],
    );
    if (existing.isNotEmpty) {
      if ((existing.first['is_dir'] as int) == 0)
        throw WorkspaceException('A file already exists at "$wsPath"');
    } else {
      _db.execute(
        'INSERT INTO nodes(parent_id, name, is_dir, size, mtime) VALUES(?, ?, 1, 0, ?)',
        [p.parentId, p.name, _now()],
      );
    }
    return stat(wsPath);
  }

  @override
  Future<FileEntry> createFile(String wsPath, {bool overwrite = false}) async {
    final existing = _node(wsPath);
    if (existing != null && !overwrite)
      throw WorkspaceException('Already exists: "$wsPath"');
    return writeBytes(wsPath, Uint8List(0));
  }

  @override
  Future<void> delete(String wsPath, {bool recursive = true}) async {
    if (pathSegments(wsPath).isEmpty)
      throw WorkspaceException('Refusing to delete the root.');
    final row = _node(wsPath);
    if (row == null) throw WorkspaceException('Not found: "$wsPath"');
    // ON DELETE CASCADE removes child nodes and blocks.
    _db.execute('DELETE FROM nodes WHERE id=?', [row['id']]);
  }

  @override
  Future<FileEntry> move(String fromWs, String toWs) async {
    final src = _node(fromWs);
    if (src == null) throw WorkspaceException('Not found: "$fromWs"');
    final p = _resolveParent(toWs, create: true);
    final clash = _db.select(
      'SELECT id FROM nodes WHERE parent_id=? AND name=?',
      [p.parentId, p.name],
    );
    if (clash.isNotEmpty)
      throw WorkspaceException('Target already exists: "$toWs"');
    _db.execute('UPDATE nodes SET parent_id=?, name=?, mtime=? WHERE id=?', [
      p.parentId,
      p.name,
      _now(),
      src['id'],
    ]);
    return stat(toWs);
  }

  @override
  Future<FileEntry> copy(String fromWs, String toWs) async {
    final src = _node(fromWs);
    if (src == null) throw WorkspaceException('Not found: "$fromWs"');
    if ((src['is_dir'] as int) == 1) {
      await createDirectory(toWs);
      for (final child in await list(fromWs)) {
        await copy(
          child.path,
          _childPath(
            '/${normalizeRel(toWs)}'.replaceAll('//', '/'),
            child.name,
          ),
        );
      }
      return stat(toWs);
    }
    return writeBytes(toWs, await readBytes(fromWs));
  }

  @override
  Future<({int bytes, int files})> usage() async {
    final r = _db.select(
      "SELECT COUNT(*) AS files, COALESCE(SUM(size),0) AS bytes FROM nodes WHERE is_dir=0",
    );
    return (bytes: (r.first['bytes'] as int), files: (r.first['files'] as int));
  }
}
