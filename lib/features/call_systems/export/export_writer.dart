// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../infrastructure/workspace/workspace.dart';

/// Result of zipping a project workspace to disk.
class WorkspaceZip {
  WorkspaceZip({
    required this.zipPath,
    required this.fileCount,
    required this.bytes,
  });
  final String zipPath;
  final int fileCount;
  final int bytes;
}

/// Export the ENTIRE project workspace (our git-backed sandbox storage — flow
/// JSON, prompt audio, exported artifacts, plans, everything) as a single `.zip`
/// the user can download/deploy. The workspace is the source of truth, so this
/// is the one true export: walk every file, add it to a zip, write it to the
/// user's Documents/NexusExports, and return the path to reveal.
Future<WorkspaceZip> exportWorkspaceZip(
  Workspace ws,
  String projectName,
) async {
  final entries = await ws.walk(maxEntries: 50000);
  final archive = Archive();
  var count = 0;
  for (final e in entries) {
    if (e.isDirectory) continue;
    try {
      final bytes = await ws.readBytes(e.path);
      final name = e.path.startsWith('/') ? e.path.substring(1) : e.path;
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      count++;
    } catch (_) {
      // Skip unreadable entries rather than failing the whole export.
    }
  }
  final zipped = ZipEncoder().encode(archive);

  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'NexusExports'));
  await dir.create(recursive: true);
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp('[:.]'), '-')
      .replaceAll('T', '_')
      .substring(0, 19);
  final zipPath = p.join(dir.path, '${_slug(projectName)}_$stamp.zip');
  await File(zipPath).writeAsBytes(zipped);

  return WorkspaceZip(zipPath: zipPath, fileCount: count, bytes: zipped.length);
}

/// Reveal a file/folder in the OS file manager (Finder/Explorer/xdg-open).
Future<void> revealInFileManager(String path) async {
  try {
    if (Platform.isMacOS) {
      // -R reveals (selects) the file in Finder.
      await Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [p.dirname(path)]);
    }
  } catch (_) {
    // Best-effort; the snackbar still shows the path.
  }
}

String _slug(String raw) {
  final s = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return s.isEmpty ? 'call_system' : s;
}
