// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'workspace.dart';

/// Bundles every file in a project's virtual [Workspace] (the `.nxtprj` SQLite
/// disk) into a single `.zip` on the real filesystem, so users can take their
/// project out of the app. Nothing else exposes the workspace to the host FS
/// besides this and the build materializer.
class WorkspaceExporter {
  const WorkspaceExporter();

  /// Zips all files under `/` and writes the archive to the user's Downloads
  /// folder (falling back to the app documents dir). Returns the saved file.
  /// Throws [WorkspaceException] if the project has no files.
  Future<File> exportZip(
    Workspace ws, {
    required String projectName,
    int maxEntries = 20000,
  }) async {
    final entries = await ws.walk(from: '/', maxEntries: maxEntries);
    final archive = Archive();
    for (final e in entries) {
      if (e.isDirectory) continue;
      final rel = normalizeRel(e.path);
      if (rel.isEmpty) continue;
      final bytes = await ws.readBytes(e.path);
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }
    if (archive.isEmpty) {
      throw WorkspaceException('This project has no files to export yet.');
    }

    final data = ZipEncoder().encode(archive);

    final dir = await _destinationDir();
    final file = File(
      p.join(
        dir.path,
        '${_safeName(projectName)}_export_'
        '${_stamp(DateTime.now())}.zip',
      ),
    );
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  /// Reveals the exported file in the platform file manager (best-effort).
  Future<void> revealInFileManager(String filePath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [p.dirname(filePath)]);
      }
    } catch (_) {
      // Best-effort; the snackbar still shows the full path.
    }
  }

  Future<Directory> _destinationDir() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } catch (_) {
      // Not all platforms expose a Downloads dir — fall through.
    }
    return getApplicationDocumentsDirectory();
  }

  static String _safeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'project';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  static String _stamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}
