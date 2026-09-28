// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistent record of how far the end-of-project finalize phase has gotten,
/// so the BUILD PHASE 2 (linking push → feature check) passes SHRINK across
/// re-entries instead of redoing everything each time (restart, re-pump, or a
/// rebuild all re-enter the phase). Without this the linking push re-processes
/// all features every time and the feature check re-reviews all of them,
/// churning already-settled work.
///
/// Stored as a sidecar JSON next to the project's `.nxtprj` disks (survives
/// restarts, needs no DB schema change, and doesn't pollute the project's git
/// repo).
class FinalizeProgress {
  /// The one-shot comprehensive LINKING PUSH (Build phase 2, step 1) has already
  /// run — don't redo the whole-app wiring push on a later entry; go straight
  /// to the (incremental) feature check.
  bool linkDone;

  /// task_pk of every feature the feature check has CONFIRMED coded + reachable.
  /// These are skipped by later linking pushes and code-trace
  /// reviews, so each pass only works on what's left.
  final Set<int> verified;

  FinalizeProgress({this.linkDone = false, Set<int>? verified})
    : verified = verified ?? <int>{};

  Map<String, dynamic> toJson() => {
    'linkDone': linkDone,
    'verified': verified.toList()..sort(),
  };

  factory FinalizeProgress.fromJson(Map<String, dynamic> j) => FinalizeProgress(
    linkDone: j['linkDone'] == true,
    verified: {
      for (final v in (j['verified'] as List? ?? const []))
        if (v is int) v else if (v is num) v.toInt(),
    },
  );
}

Future<String> _finalizePath(int projectId) async {
  final base = (await getApplicationSupportDirectory()).path;
  return p.join(base, 'workspaces', 'finalize_project_$projectId.json');
}

Future<FinalizeProgress> loadFinalizeProgress(int projectId) async {
  try {
    final f = File(await _finalizePath(projectId));
    if (!await f.exists()) return FinalizeProgress();
    final decoded = jsonDecode(await f.readAsString());
    if (decoded is! Map<String, dynamic>) return FinalizeProgress();
    return FinalizeProgress.fromJson(decoded);
  } catch (_) {
    return FinalizeProgress();
  }
}

Future<void> saveFinalizeProgress(int projectId, FinalizeProgress prog) async {
  try {
    final path = await _finalizePath(projectId);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsString(jsonEncode(prog.toJson()));
  } catch (_) {
    // Best-effort: losing the checklist only costs a redundant pass, never
    // correctness.
  }
}

/// Wipe the checklist (e.g. when a fresh full build should re-verify everything).
Future<void> clearFinalizeProgress(int projectId) async {
  try {
    final f = File(await _finalizePath(projectId));
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
