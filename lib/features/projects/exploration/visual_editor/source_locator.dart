// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Reverse-maps captured screen REGIONS to source file:line.
///
/// The new Flutter SDKs no longer expose a widget's creation stack, so the
/// harness instead records each region's rendered TEXT, solid COLOR and
/// WIDGET CHAIN — all of which are greppable in the app's own source. This
/// locator builds an index of the workspace's Dart files and resolves each
/// region with three descending-strength heuristics:
///
///   1. rendered text → string literal search (screen's page file first)
///   2. solid color → exact color-literal search (hex / fromARGB / named)
///   3. widget chain → `class <Type>` search for the screen's page file
///
/// A region that resolves to nothing is still pickable: "View code" can jump
/// to the screen's page file, and the assistant fallback gets the screenshot
/// context either way.
library;

import 'dart:convert';

import '../../../../infrastructure/workspace/workspace.dart';
import 'region_model.dart';

/// Named Flutter colors we can reverse-map hex → `Colors.x`.
const _namedColors = <String, String>{
  'FFFFFF': 'white',
  '000000': 'black',
  '9E9E9E': 'grey',
  'FF0000': 'red',
  '4CAF50': 'green',
  '2196F3': 'blue',
  'FFD900': 'amber',
  '009688': 'teal',
  'FF9800': 'orange',
  'F06292': 'pink',
  '9C27B0': 'purple',
  '673AB7': 'deepPurple',
  '3F51B5': 'indigo',
  '00BCD4': 'cyan',
  '03A9F4': 'lightBlue',
  'FFF176': 'yellow',
  '795548': 'brown',
  'FF5722': 'deepOrange',
  '607D8B': 'blueGrey',
};

class _SrcFile {
  _SrcFile(this.path, this.content)
      : lines = content.split('\n');
  final String path;
  final String content;
  final List<String> lines;
}

class SourceIndex {
  SourceIndex._(this.files, this.classes, this.routeToPageClass);

  /// All app Dart sources, keyed by workspace path.
  final Map<String, _SrcFile> files;

  /// Widget class name → [(file, classLine)].
  final Map<String, List<(String, int)>> classes;

  /// Route key → page widget class name (from app_routes.dart).
  final Map<String, String> routeToPageClass;

  static Future<SourceIndex> build(Workspace ws) async {
    final files = <String, _SrcFile>{};
    final classes = <String, List<(String, int)>>{};
    String? routesSrc;
    final entries = await ws.walk();
    for (final e in entries) {
      if (e.isDirectory) continue;
      final p = e.path;
      if (!p.endsWith('.dart')) continue;
      final norm = p.startsWith('/') ? p : '/$p';
      if (!norm.contains('/lib/') || norm.contains('/test/')) continue;
      final bytes = await ws.readBytes(p);
      if (await _isProbablyBinary(bytes)) continue;
      final content = utf8.decode(bytes, allowMalformed: true).trimRight();
      files[norm] = _SrcFile(norm, content);
      if (norm.endsWith('/app_routes.dart')) routesSrc = content;
    }
    // Class index.
    final classRe =
        RegExp(r'^\s*(?:abstract\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)',
            multiLine: true);
    for (final f in files.values) {
      for (final m in classRe.allMatches(f.content)) {
        final name = m.group(1)!;
        final line = f.content.substring(0, m.start).split('\n').length;
        classes.putIfAbsent(name, () => []).add((f.path, line));
      }
    }
    // Route → page class.
    final routeToPageClass = <String, String>{};
    if (routesSrc != null) {
      final re = RegExp("['\"](/[^'\"]*)['\"]\\s*:\\s*[^,]{0,80}?=>\\s*([A-Za-z_][A-Za-z0-9_]*)\\(");
      for (final m in re.allMatches(routesSrc)) {
        routeToPageClass[m.group(1)!] = m.group(2)!;
      }
      // `NamedRoute`-style maps: '/x': Builder(...).build — capture the
      // trailing `XPage()` when it appears on the same entry line.
      final re2 = RegExp("['\"](/[^'\"]*)['\"]\\s*:[^\\n]*?([A-Z][A-Za-z0-9_]*)\\(");
      for (final m in re2.allMatches(routesSrc)) {
        routeToPageClass.putIfAbsent(m.group(1)!, () => m.group(2)!);
      }
    }
    return SourceIndex._(files, classes, routeToPageClass);
  }

  /// Resolve [region] on screen [route] to file:line (or null).
  (String, int)? locate(String route, ScreenRegion region) {
    // The screen's page file — strongest anchor for disambiguation.
    final pageClass = routeToPageClass[route];
    final pageFile = pageClass == null
        ? null
        : classes[pageClass]?.isNotEmpty == true
            ? classes[pageClass]!.first.$1
            : null;

    // 1) Rendered text → literal search.
    final text = (region.text ?? '').trim();
    if (text.length >= 4) {
      final probe = text.length > 30 ? text.substring(0, 30) : text;
      final escaped = RegExp.escape(probe);
      final re = RegExp("['\"]$escaped");
      final candidates = <(String, int)>[];
      for (final f in files.values) {
        final m = re.firstMatch(f.content);
        if (m != null) {
          final line = f.content.substring(0, m.start).split('\n').length;
          candidates.add((f.path, line));
        }
      }
      if (candidates.length == 1) return candidates.first;
      if (candidates.length > 1) {
        // Prefer the screen's page file, then the first.
        for (final c in candidates) {
          if (c.$1 == pageFile) return c;
        }
        return candidates.first;
      }
    }

    // 2) Solid color → exact literal search.
    final hex = (region.colorHex ?? '').replaceAll('#', '').toUpperCase();
    if (hex.length == 6) {
      final patterns = <String>[
        '0x$hex)',
        '0xFF$hex)',
        '0xFF$hex',
      ];
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      patterns
        ..add('fromARGB(255, $r, $g, $b)')
        ..add('fromARGB( 255, $r, $g, $b)');
      final named = _namedColors[hex];
      if (named != null) patterns.add('Colors.$named');
      final candidates = <(String, int)>[];
      for (final pat in patterns) {
        final re = RegExp(RegExp.escape(pat).replaceAll(r'\ ', r'\s*'));
        for (final f in files.values) {
          final m = re.firstMatch(f.content);
          if (m != null) {
            final line =
                f.content.substring(0, m.start).split('\n').length;
            if (!candidates.any((c) => c.$1 == f.path)) {
              candidates.add((f.path, line));
            }
          }
        }
        if (candidates.isNotEmpty) break;
      }
      if (candidates.length == 1) return candidates.first;
      if (candidates.length > 1) {
        for (final c in candidates) {
          if (c.$1 == pageFile) return c;
        }
        return candidates.first;
      }
    }

    // 3) Chain → app-defined class search.
    for (final type in region.chain) {
      final locs = classes[type];
      if (locs == null || locs.isEmpty) continue;
      if (locs.length == 1) return locs.first;
      for (final l in locs) {
        if (l.$1 == pageFile) return l;
      }
      return locs.first;
    }

    // 4) Screen-level fallback: the page file's class line.
    if (pageFile != null) {
      final locs = classes[pageClass!];
      if (locs != null && locs.isNotEmpty) return locs.first;
    }
    return null;
  }

  static Future<bool> _isProbablyBinary(List<int> bytes) async {
    final n = bytes.length.clamp(0, 512);
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }
}
