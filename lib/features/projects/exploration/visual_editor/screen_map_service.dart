// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Builds and caches the SCREEN MAP for a project: materializes the VHD to a
/// temp dir, injects the generated harness test, runs `flutter test` to pump
/// the real app screen by screen, and caches the PNGs + regions JSON under
/// app support (keyed by project + git HEAD, so a stale map is obvious).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../infrastructure/build/workspace_materializer.dart';
import '../../../../infrastructure/exec/captured_run.dart';
import '../../../../infrastructure/workspace/workspace.dart';
import 'harness_generator.dart';
import 'region_model.dart';

typedef MapProgress = void Function(String stage);

class ScreenMapError extends Error {
  ScreenMapError(this.message, this.log);
  final String message;
  final String log;
  @override
  String toString() => message;
}

Future<Directory> _cacheRoot() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}${Platform.pathSeparator}screens');
  dir.createSync(recursive: true);
  return dir;
}

Future<Directory> cacheDir(int projectId, String head) async =>
    Directory('${(await _cacheRoot()).path}/p${projectId}_${head}');

/// Load a cached map if it exists and is fresh for [head]; else null.
Future<ScreenMap?> loadCachedScreenMap(int projectId, String head) async {
  try {
    final dir = await cacheDir(projectId, head);
    final jsonFile = File('${dir.path}/screens_map.json');
    if (!await jsonFile.exists()) return null;
    final src = await jsonFile.readAsString();
    final map = ScreenMap.fromJson(src);
    return map.head == head ? map : null;
  } catch (_) {
    return null;
  }
}

/// The shallowest directory under [root] containing a pubspec.yaml (skipping
/// build/ and .dart_tool/ trees) — the generated app's root.
String? findFlutterAppDir(String root) {
  String? best;
  var bestDepth = 1 << 30;
  final sep = Platform.pathSeparator;
  try {
    for (final e in Directory(
      root,
    ).listSync(recursive: true, followLinks: false)) {
      if (e is! File || e.uri.pathSegments.last != 'pubspec.yaml') continue;
      final rel = e.path.length > root.length
          ? e.path.substring(root.length)
          : '';
      if (rel.contains('${sep}build$sep') ||
          rel.contains('$sep.dart_tool$sep') ||
          rel.contains('${sep}node_modules$sep') ||
          rel.contains('${sep}.git$sep')) {
        continue;
      }
      final depth = rel.split(sep).where((s) => s.isNotEmpty).length;
      if (depth < bestDepth) {
        bestDepth = depth;
        best = e.parent.path;
      }
    }
  } catch (_) {}
  return best;
}

const maxHarnessRoutes = 14;

/// Run the full capture. [ws] is the live project workspace; it is READ ONLY
/// (the harness lives in the materialized copy and is discarded).
Future<ScreenMap> buildScreenMap({
  required Workspace ws,
  required int projectId,
  required String head,
  MapProgress? onProgress,
}) async {
  void stage(String s) => onProgress?.call(s);

  final materializer = WorkspaceMaterializer();
  final mat = await materializer.materialize(ws, tag: 'screenmap');
  try {
    final appDir = findFlutterAppDir(mat.path);
    if (appDir == null) {
      throw ScreenMapError(
        'No Flutter app (pubspec.yaml) found in the project workspace.',
        '',
      );
    }
    print('[ScreenMap] project=$projectId head=$head appDir=$appDir');
    final pubspecFile = File('$appDir${Platform.pathSeparator}pubspec.yaml');
    final pubspec = await pubspecFile.readAsString();
    final pkgName = parsePubspecName(pubspec);
    if (pkgName == null) {
      throw ScreenMapError(
        'Could not read the app name from pubspec.yaml.',
        '',
      );
    }

    // Routes: parse app_routes.dart if present, cap the list.
    final routes = <HarnessRoute>[const HarnessRoute('', 'Home')];
    final routesFile = File(
      '$appDir${Platform.pathSeparator}lib${Platform.pathSeparator}app_routes.dart',
    );
    if (await routesFile.exists()) {
      final names = parseNamedRoutes(await routesFile.readAsString());
      for (final name in names.take(maxHarnessRoutes - 1)) {
        final label = _labelForRoute(name);
        routes.add(HarnessRoute(name, label));
      }
    }

    stage(
      'Capturing ${routes.length} screens (first run takes a few minutes)…',
    );
    final outDir = '${mat.path}${Platform.pathSeparator}.nexus_screen_out';
    Directory(outDir).createSync(recursive: true);
    final testPath =
        '$appDir${Platform.pathSeparator}test${Platform.pathSeparator}nexus_screen_map_test.dart';
    File(testPath).createSync(recursive: true);
    await File(testPath).writeAsString(
      generateHarnessTest(packageName: pkgName, routes: routes, outDir: outDir),
    );

    final run = await runCaptured(
      'flutter pub get >/dev/null 2>&1; flutter test test/nexus_screen_map_test.dart --reporter compact',
      workingDirectory: appDir,
      timeout: const Duration(minutes: 15),
    );

    final jsonFile = File('$outDir${Platform.pathSeparator}screens.json');
    final ok = await jsonFile.exists();
    print(
      '[ScreenMap] harness exit=${run.exitCode} jsonWritten=$ok '
      'output=${run.output.length} chars',
    );
    if (!ok || run.exitCode != 0) {
      final lines = run.output.split('\n');
      final tail = lines.length > 40 ? lines.sublist(lines.length - 40) : lines;
      print('[ScreenMap] FAILED — log tail:\n${tail.join('\n')}');
      throw ScreenMapError(
        ok
            ? 'Screen capture reported a failure (exit ${run.exitCode}).'
            : 'Screen capture failed — the harness test did not complete.',
        run.output,
      );
    }

    // Assemble the ScreenMap from the harness output.
    final raw = await jsonFile.readAsString();
    final list = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .toList();
    final screens = <CapturedScreen>[];
    final dir = await cacheDir(projectId, head);
    dir.createSync(recursive: true);
    for (final s in list) {
      final pngName = s['png'] as String? ?? '';
      CapturedScreen? screen;
      try {
        screen = CapturedScreen.fromJson(s);
      } catch (_) {
        continue;
      }
      if (pngName.isNotEmpty) {
        final src = File('$outDir${Platform.pathSeparator}$pngName');
        if (await src.exists()) {
          await src.copy('${dir.path}${Platform.pathSeparator}$pngName');
        }
      }
      screens.add(screen);
    }
    final map = ScreenMap(
      projectId: projectId,
      head: head,
      screens: screens,
      log: run.output,
    );
    await File(
      '${dir.path}${Platform.pathSeparator}screens_map.json',
    ).writeAsString(map.toJson());
    stage(
      'Done — ${screens.where((s) => s.error == null).length}/${screens.length} screens captured.',
    );
    return map;
  } finally {
    await mat.dispose();
  }
}

/// Re-capture ONLY [route] — much faster than [buildScreenMap] because it
/// pumps a single screen instead of every one. The other screens are seeded
/// from the most recent prior capture (under a different HEAD), so the map
/// stays complete. Any failure bubbles up; the caller falls back to a full
/// [buildScreenMap].
Future<ScreenMap> recaptureOneScreen({
  required Workspace ws,
  required int projectId,
  required String head,
  required String route,
  MapProgress? onProgress,
}) async {
  void stage(String s) => onProgress?.call(s);

  final materializer = WorkspaceMaterializer();
  final mat = await materializer.materialize(ws, tag: 'screenmap1');
  try {
    final appDir = findFlutterAppDir(mat.path);
    if (appDir == null) {
      throw ScreenMapError('No Flutter app (pubspec.yaml) found.', '');
    }
    final pubspec = await File(
      '$appDir${Platform.pathSeparator}pubspec.yaml',
    ).readAsString();
    final pkgName = parsePubspecName(pubspec);
    if (pkgName == null) {
      throw ScreenMapError('Could not read the app name.', '');
    }

    final label = route.isEmpty ? 'Home' : _labelForRoute(route);
    stage('Re-capturing "$label"…');
    final outDir = '${mat.path}${Platform.pathSeparator}.nexus_screen_out1';
    Directory(outDir).createSync(recursive: true);
    final testPath =
        '$appDir${Platform.pathSeparator}test${Platform.pathSeparator}nexus_screen_map_1_test.dart';
    File(testPath).createSync(recursive: true);
    await File(testPath).writeAsString(
      generateHarnessTest(
        packageName: pkgName,
        routes: [HarnessRoute(route, label)],
        outDir: outDir,
      ),
    );

    final run = await runCaptured(
      'flutter pub get >/dev/null 2>&1; flutter test test/nexus_screen_map_1_test.dart --reporter compact',
      workingDirectory: appDir,
      timeout: const Duration(minutes: 8),
    );
    final jsonFile = File('$outDir${Platform.pathSeparator}screens.json');
    if (run.exitCode != 0 || !await jsonFile.exists()) {
      throw ScreenMapError(
        'Single-screen re-capture did not complete.',
        run.output,
      );
    }
    final list = (jsonDecode(await jsonFile.readAsString()) as List)
        .cast<Map<String, dynamic>>()
        .toList();
    if (list.isEmpty) {
      throw ScreenMapError(
        'Single-screen re-capture produced no screen.',
        run.output,
      );
    }
    CapturedScreen fresh;
    try {
      fresh = CapturedScreen.fromJson(list.first);
    } catch (_) {
      throw ScreenMapError(
        'Single-screen re-capture output was malformed.',
        run.output,
      );
    }

    final target = await cacheDir(projectId, head);
    target.createSync(recursive: true);
    if (fresh.pngFile.isNotEmpty) {
      final src = File('$outDir${Platform.pathSeparator}${fresh.pngFile}');
      if (await src.exists()) {
        await src.copy(
          '${target.path}${Platform.pathSeparator}${fresh.pngFile}',
        );
      }
    }

    // Seed the other screens from the latest prior capture (different HEAD),
    // replacing [route] in place to preserve ordering.
    final merged = <CapturedScreen>[];
    var replaced = false;
    final seedDir = await _latestPriorCacheDir(projectId, head);
    if (seedDir != null) {
      final seedFile = File(
        '${seedDir.path}${Platform.pathSeparator}screens_map.json',
      );
      if (await seedFile.exists()) {
        try {
          final seed = ScreenMap.fromJson(await seedFile.readAsString());
          for (final s in seed.screens) {
            if (s.route == route) {
              merged.add(fresh);
              replaced = true;
              continue;
            }
            if (s.pngFile.isNotEmpty) {
              final sp = File(
                '${seedDir.path}${Platform.pathSeparator}${s.pngFile}',
              );
              final tp = File(
                '${target.path}${Platform.pathSeparator}${s.pngFile}',
              );
              if (await sp.exists() && !await tp.exists()) {
                await sp.copy(tp.path);
              }
            }
            merged.add(s);
          }
        } catch (_) {
          merged.clear();
        }
      }
    }
    if (!replaced) merged.add(fresh);

    final map = ScreenMap(
      projectId: projectId,
      head: head,
      screens: merged,
      log: run.output,
    );
    await File(
      '${target.path}${Platform.pathSeparator}screens_map.json',
    ).writeAsString(map.toJson());
    stage('Done — "$label" refreshed.');
    return map;
  } finally {
    await mat.dispose();
  }
}

/// The most recently modified screen-map cache dir for [projectId] whose HEAD
/// is not [excludeHead] — used to seed a single-screen re-capture.
Future<Directory?> _latestPriorCacheDir(
  int projectId,
  String excludeHead,
) async {
  final root = await _cacheRoot();
  final prefix = 'p${projectId}_';
  Directory? best;
  var bestTime = DateTime.fromMillisecondsSinceEpoch(0);
  try {
    for (final e in root.listSync()) {
      if (e is! Directory) continue;
      final name = e.uri.pathSegments.last;
      if (!name.startsWith(prefix)) continue;
      if (name.substring(prefix.length) == excludeHead) continue;
      final mt = e.statSync().modified;
      if (mt.isAfter(bestTime)) {
        bestTime = mt;
        best = e;
      }
    }
  } catch (_) {}
  return best;
}

String _labelForRoute(String route) {
  // /task-56-lounge-and-leaderboards-hub → "Lounge & Leaderboards Hub"
  var s = route.replaceAll(RegExp(r'^/'), '');
  final dash = s.indexOf('-');
  if (dash > 0 && s.substring(0, dash).startsWith('task')) {
    s = s.substring(dash + 1);
  }
  s = s.replaceAll(RegExp(r'-'), ' ');
  final words = s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .toList();
  var label = words.join(' ');
  if (label.length > 26) {
    label = '${label.substring(0, 26)}…';
  }
  return label;
}
