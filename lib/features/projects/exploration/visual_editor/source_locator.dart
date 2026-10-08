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
  _SrcFile(this.path, this.content) : lines = content.split('\n');
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
    final classRe = RegExp(
      r'^\s*(?:abstract\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)',
      multiLine: true,
    );
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
      final re = RegExp(
        "['\"](/[^'\"]*)['\"]\\s*:\\s*[^,]{0,80}?=>\\s*([A-Za-z_][A-Za-z0-9_]*)\\(",
      );
      for (final m in re.allMatches(routesSrc)) {
        routeToPageClass[m.group(1)!] = m.group(2)!;
      }
      // `NamedRoute`-style maps: '/x': Builder(...).build — capture the
      // trailing `XPage()` when it appears on the same entry line.
      final re2 = RegExp(
        "['\"](/[^'\"]*)['\"]\\s*:[^\\n]*?([A-Z][A-Za-z0-9_]*)\\(",
      );
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

    // 1) Rendered text → literal search. A region's own text is the strongest
    //    anchor; for boxes, the text they CONTAIN (childText) is next.
    final own = (region.text ?? '').trim();
    if (own.length >= 4) {
      final hit = _findText(own, pageFile);
      if (hit != null) return hit;
    }
    final child = (region.childText ?? '').trim();
    if (child.length >= 4) {
      final hit = _findText(child, pageFile);
      if (hit != null) return hit;
    }

    // 2) Solid color → exact literal search.
    final hex = (region.colorHex ?? '').replaceAll('#', '').toUpperCase();
    if (hex.length == 6) {
      final patterns = <String>['0x$hex)', '0xFF$hex)', '0xFF$hex'];
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
            final line = f.content.substring(0, m.start).split('\n').length;
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

  /// Find where [text] is RENDERED and anchor on the ACTUAL widget that holds
  /// its style — so a colour/text edit lands straight on the page. Three
  /// passes, strongest first:
  ///
  ///   1. The text is a literal directly inside a `Text('…')` / `Text.rich`.
  ///   2. The text is data passed to a widget — `_W(title: '…')`. Anchor to
  ///      the `Text` inside `_W`'s build (that's where the style lives), not
  ///      the call site.
  ///   3. Any other string literal, EXCLUDING route-map entry lines (a route
  ///      path rendered as text must not anchor to `app_routes.dart`).
  (String, int)? _findText(String text, String? pageFile) {
    final probe = text.length > 40 ? text.substring(0, 40) : text;
    final escaped = RegExp.escape(probe);

    // Pass 1 — a `Text('…')` / `Text.rich('…')` whose literal IS the text.
    final directRe = RegExp("Text\\s*(?:\\.\\w+\\s*)?\\(\\s*['\"]$escaped");
    final direct = _rank(_scanAll(directRe), pageFile);
    if (direct != null) return direct;

    // Pass 2 — the text is a value passed to a widget; resolve to the `Text`
    // inside that widget's build. `param:` must be the FIRST argument (right
    // after the paren) so we match `_W(title: '…')` and not an outer call like
    // `ListView(children: … _W(title: '…') …)`.
    final callRe = RegExp(
      "\\b([_A-Za-z][A-Za-z0-9_]*)\\s*\\(\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*['\"]$escaped",
    );
    for (final f in files.values) {
      for (final m in callRe.allMatches(f.content)) {
        final resolved = _resolveWidgetText(m.group(1)!, m.group(2)!);
        if (resolved != null) return resolved;
      }
    }

    // Pass 3 — any other literal, EXCLUDING route-map entry lines. Page file
    // first, then any file. (The old "last resort" re-scanned without the
    // route exclusion and could anchor a route path back to app_routes.dart.)
    (String, int)? anyFile;
    for (final f in files.values) {
      for (final m in RegExp("['\"]$escaped").allMatches(f.content)) {
        if (_isRouteEntryLine(f, m.start)) continue;
        final line = f.content.substring(0, m.start).split('\n').length;
        if (f.path == pageFile) return (f.path, line);
        anyFile ??= (f.path, line);
      }
    }
    return anyFile;
  }

  /// First match of [re] in every source file → [(file, line)].
  List<(String, int)> _scanAll(RegExp re) {
    final out = <(String, int)>[];
    for (final f in files.values) {
      final m = re.firstMatch(f.content);
      if (m != null) {
        final line = f.content.substring(0, m.start).split('\n').length;
        out.add((f.path, line));
      }
    }
    return out;
  }

  /// Pick the best candidate: [pageFile] wins, else the first.
  (String, int)? _rank(List<(String, int)> c, String? pageFile) {
    if (c.isEmpty) return null;
    if (pageFile != null) {
      for (final x in c) {
        if (x.$1 == pageFile) return x;
      }
    }
    return c.first;
  }

  /// Resolve a parameterised widget `_W(param: '…')` to the `Text` inside
  /// `_W`'s build (preferring the one fed by [param]), so the anchor sits on
  /// the real styled widget. Returns null if the class/Text can't be found.
  (String, int)? _resolveWidgetText(String widget, String param) {
    final locs = classes[widget];
    if (locs == null || locs.isEmpty) return null;
    for (final (file, _) in locs) {
      final content = files[file]?.content;
      if (content == null) continue;
      // Find the class declaration by OFFSET (the stored class line can drift
      // by a blank line) and take its body up to the next top-level class.
      final cm = RegExp(
        '^(?:\\s*)class\\s+$widget\\b',
        multiLine: true,
      ).firstMatch(content);
      if (cm == null) continue;
      final bodyStart = cm.end;
      var bodyEnd = content.length;
      for (final m in RegExp(
        r'^\s*class\s+',
        multiLine: true,
      ).allMatches(content, bodyStart)) {
        bodyEnd = m.start;
        break;
      }
      final seg = content.substring(bodyStart, bodyEnd);
      // Prefer the Text fed by [param]; else the first Text in the body.
      final pick =
          RegExp("Text\\s*\\(\\s*$param\\b").firstMatch(seg) ??
          RegExp("Text\\s*\\(").firstMatch(seg);
      if (pick == null) continue;
      final line = content
          .substring(0, bodyStart + pick.start)
          .split('\n')
          .length;
      return (file, line);
    }
    return null;
  }

  /// True if the line containing [idx] is a route-map entry — e.g.
  /// `'/task-11-x': (_) => XPage()` — so a route path rendered as text doesn't
  /// anchor to the route table instead of the widget.
  bool _isRouteEntryLine(_SrcFile f, int idx) {
    if (f.path.endsWith('/app_routes.dart')) return true;
    final lineStart = f.content.lastIndexOf('\n', idx) + 1;
    var lineEnd = f.content.indexOf('\n', idx);
    if (lineEnd < 0) lineEnd = f.content.length;
    final line = f.content.substring(lineStart, lineEnd);
    return RegExp(r'''['"]/[^'"]*['"]\s*:''').hasMatch(line) ||
        line.contains('=>');
  }

  static Future<bool> _isProbablyBinary(List<int> bytes) async {
    final n = bytes.length.clamp(0, 512);
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }
}
