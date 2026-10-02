// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Data model for the Visual Editor's screen map: a captured screen plus the
/// interactive REGIONS on it (which widget is at which pixel, from which source
/// line). One shared shape produced both by the offline screenshot HARNESS
/// (pseudo-run) and, later, by the LIVE edit bridge streaming from a running
/// web build — so the editor UI is agnostic to where the pixels came from.
library;

import 'dart:convert';

/// A rectangle in screen (logical) coordinates.
class RectBox {
  const RectBox(this.x, this.y, this.w, this.h);
  final double x, y, w, h;

  bool contains(double px, double py) =>
      px >= x && px < x + w && py >= y && py < y + h;

  Map<String, dynamic> toJson() =>
      {'x': x, 'y': y, 'w': w, 'h': h};

  factory RectBox.fromJson(Map<String, dynamic> j) => RectBox(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
        (j['w'] as num).toDouble(),
        (j['h'] as num).toDouble(),
      );
}

/// One pickable region of a screen.
class ScreenRegion {
  const ScreenRegion({
    required this.id,
    required this.widgetType,
    required this.rect,
    this.label,
    this.sourceFile,
    this.sourceLine,
    this.depth = 0,
    this.colorHex,
    this.text,
    this.chain = const [],
  });

  final String id; // e.g. "s2-041"

  /// RenderObject runtime type (RenderDecoratedBox, RenderParagraph, …).
  final String widgetType;

  /// Human label for hover/inspector ("Card", "Text", "Button").
  final String? label;

  /// Rendered text content (RenderParagraph regions) — the strongest key for
  /// reverse-mapping the region to a source line.
  final String? text;

  /// Widget runtime-type chain up the element tree (most-local first) —
  /// app-defined types in here point at the owning source file.
  final List<String> chain;

  /// Source position resolved by the locator (or null — still pickable; the
  /// assistant can find it from the screenshot context).
  final String? sourceFile; // workspace path, e.g. /lib/features/…/page.dart
  final int? sourceLine;

  final RectBox rect;
  final int depth; // tree depth — smaller (deeper tree) wins hit-tests

  /// When the harness could extract it (a DecoratedBox with a solid color).
  final String? colorHex;

  bool get hasSource => sourceFile != null && sourceLine != null;

  ScreenRegion copyWithSource(String? file, int? line) => ScreenRegion(
        id: id,
        widgetType: widgetType,
        rect: rect,
        label: label,
        sourceFile: file,
        sourceLine: line,
        depth: depth,
        colorHex: colorHex,
        text: text,
        chain: chain,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        't': widgetType,
        if (label != null) 'label': label,
        if (sourceFile != null) 'file': sourceFile,
        if (sourceLine != null) 'line': sourceLine,
        'r': rect.toJson(),
        'd': depth,
        if (colorHex != null) 'color': colorHex,
        if (text != null) 'text': text,
        if (chain.isNotEmpty) 'chain': chain,
      };

  factory ScreenRegion.fromJson(Map<String, dynamic> j) => ScreenRegion(
        id: j['id'] as String,
        widgetType: j['t'] as String,
        label: j['label'] as String?,
        sourceFile: j['file'] as String?,
        sourceLine: j['line'] as int?,
        rect: RectBox.fromJson(j['r'] as Map<String, dynamic>),
        depth: (j['d'] as int?) ?? 0,
        colorHex: j['color'] as String?,
        text: j['text'] as String?,
        chain: (j['chain'] as List?)?.cast<String>() ?? const [],
      );
}

/// A captured screen of the app.
class CapturedScreen {
  const CapturedScreen({
    required this.route,
    required this.label,
    required this.pngFile,
    required this.width,
    required this.height,
    required this.regions,
    this.error,
  });

  final String route; // '' = the app's home
  final String label; // short name for the rail
  final String pngFile; // filename inside the screen-map folder
  final int width, height;
  final List<ScreenRegion> regions;
  final String? error; // set when this screen failed to capture

  Map<String, dynamic> toJson() => {
        'route': route,
        'label': label,
        'png': pngFile,
        'w': width,
        'h': height,
        if (error != null) 'error': error,
        'regions': regions.map((r) => r.toJson()).toList(),
      };

  factory CapturedScreen.fromJson(Map<String, dynamic> j) => CapturedScreen(
        route: j['route'] as String,
        label: j['label'] as String,
        pngFile: j['png'] as String,
        width: j['w'] as int,
        height: j['h'] as int,
        error: j['error'] as String?,
        regions: (j['regions'] as List?)
                ?.map((r) => ScreenRegion.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// The full screen map for a project at a given git HEAD.
class ScreenMap {
  const ScreenMap({
    required this.projectId,
    required this.head,
    required this.screens,
    this.log,
  });

  final int projectId;
  final String head; // git HEAD (short) the map was captured at
  final List<CapturedScreen> screens;
  final String? log; // harness/build log tail (for surfacing failures)

  CapturedScreen? firstGood() =>
      screens.where((s) => s.error == null).cast<CapturedScreen?>().firstWhere(
            (s) => s != null,
            orElse: () => null,
          );

  String toJson() => jsonEncode({
        'v': 1,
        'project': projectId,
        'head': head,
        'screens': screens.map((s) => s.toJson()).toList(),
      });

  factory ScreenMap.fromJson(String src) {
    final j = jsonDecode(src) as Map<String, dynamic>;
    return ScreenMap(
      projectId: j['project'] as int,
      head: j['head'] as String,
      screens: (j['screens'] as List)
          .map((s) => CapturedScreen.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A visual edit operation (what the user did) and the result of applying it.
enum VisualOpKind { setColor, setText, insertImage, replaceImage, move }

class VisualOp {
  const VisualOp({
    required this.kind,
    required this.region,
    required this.screenRoute,
    this.colorHex,
    this.text,
    this.assetPath, // workspace path of the image to (re)insert
    this.dx = 0,
    this.dy = 0,
  });

  final VisualOpKind kind;
  final ScreenRegion region;
  final String screenRoute;
  final String? colorHex;
  final String? text;
  final String? assetPath;
  final double dx, dy;

  String get summary {
    final where = region.label ?? region.widgetType;
    switch (kind) {
      case VisualOpKind.setColor:
        return 'change color of $where to $colorHex';
      case VisualOpKind.setText:
        return 'edit text of $where to "$text"';
      case VisualOpKind.insertImage:
        return 'insert image into $where';
      case VisualOpKind.replaceImage:
        return 'replace image in $where';
      case VisualOpKind.move:
        return 'move $where by (${dx.round()}, ${dy.round()})';
    }
  }
}

/// One entry of the visual-edit log (drives Undo + the ops panel).
class VisualEditRecord {
  const VisualEditRecord({
    required this.id,
    required this.timeMs,
    required this.opSummary,
    required this.headBefore,
    required this.headAfter,
    required this.touchedFiles,
    required this.ok,
    this.detail,
  });

  final int id;
  final int timeMs;
  final String opSummary;
  final String headBefore;
  final String headAfter;
  /// Files the op changed (path → size of the ORIGINAL bytes stored).
  final Map<String, int> touchedFiles;
  final bool ok;
  final String? detail; // e.g. "rolled back — analyzer errors"

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': timeMs,
        'op': opSummary,
        'before': headBefore,
        'after': headAfter,
        'files': touchedFiles,
        'ok': ok,
        if (detail != null) 'detail': detail,
      };

  factory VisualEditRecord.fromJson(Map<String, dynamic> j) => VisualEditRecord(
        id: j['id'] as int,
        timeMs: j['time'] as int,
        opSummary: j['op'] as String,
        headBefore: j['before'] as String,
        headAfter: j['after'] as String,
        touchedFiles: (j['files'] as Map?)?.cast<String, int>() ?? const {},
        ok: j['ok'] as bool,
        detail: j['detail'] as String?,
      );
}
