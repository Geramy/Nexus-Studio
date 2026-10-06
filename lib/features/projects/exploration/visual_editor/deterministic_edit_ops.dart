// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Pure, side-effect-free deterministic source edits for the visual editor.
///
/// Each function takes a file's full content plus an ANCHOR LINE (1-based, from
/// the on-screen region's located source position) and returns the new content,
/// or null when no confident edit exists. Every candidate token is matched
/// across the WHOLE file and the one CLOSEST to the anchor wins — a fixed
/// ±window + first-match mis-targets whenever a colour or string repeats.
///
/// Kept pure (String in → String out) so it is trivially unit-testable against
/// real generated source, and so [code_applier] can stay a thin orchestrator.
library;

/// A single recognisable colour VALUE (no property name): `Color(0x…)`,
/// `Color.fromARGB(…)`, `Colors.x[.shadeN]`, or `Theme.of(...).colorScheme.x`.
const String colorValueRe =
    r'Color\(0x[0-9A-Fa-f]{6,8}\)|Color\.fromARGB\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)|Colors\.[A-Za-z]+(?:\.shade\d+)?|Theme\.of\([^)]*\)\.colorScheme\.[A-Za-z]+';

/// Build the replacement literal for a picked hex (#RRGGBB or #AARRGGBB).
String? colorLiteralForHex(String hex) {
  final h = hex.replaceAll('#', '').trim().toUpperCase();
  if (h.length == 8) {
    final a = h.substring(0, 2);
    if (a == '00') return null;
    return 'Color(0x$a${h.substring(2)})';
  }
  if (h.length == 6) return 'Color(0xFF$h)';
  return null;
}

int _lineAt(String content, int idx) =>
    content.substring(0, idx).split('\n').length;

/// Index of the ')' matching the '(' at [openIdx], or -1.
int _matchingParen(String content, int openIdx) {
  if (openIdx < 0 || openIdx >= content.length || content[openIdx] != '(') {
    return -1;
  }
  var depth = 0;
  for (var i = openIdx; i < content.length; i++) {
    final c = content[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// The closest match of [re] to [anchor] (1-based line), within [maxDist]
/// lines. Returns (match, matchLine) or null.
(RegExpMatch, int)? _nearestMatch(
    String content, RegExp re, int anchor, int maxDist) {
  RegExpMatch? best;
  var bestLine = 0;
  var bestDist = 1 << 30;
  for (final m in re.allMatches(content)) {
    final line = _lineAt(content, m.start);
    final dist = (line - anchor).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = m;
      bestLine = line;
    }
  }
  if (best == null || bestDist > maxDist) return null;
  return (best, bestLine);
}

/// The identifier of the named property immediately before [at] in [body]
/// (i.e. the `color` in `color: <value>`), or null.
String? _propBefore(String body, int at) {
  final m = RegExp(r'([A-Za-z_]+)\s*:\s*$').firstMatch(body.substring(0, at));
  return m?.group(1);
}

/// True if [idx] lies inside a `TextStyle( … )` call.
bool _insideTextStyle(String content, int idx) {
  final opens = [
    for (final m in RegExp(r'TextStyle\(').allMatches(content.substring(0, idx)))
      m.start
  ];
  if (opens.isEmpty) return false;
  return _matchingParen(content, opens.last) > idx;
}

String _fmt(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Replace the first string argument of the nearest `prefix('…')` call to
/// [anchor] (within 12 lines).
String? _replaceStringArg(
    String content, int anchor, RegExp openRe, String newInner) {
  final m = _nearestMatch(content, openRe, anchor, 12);
  if (m == null) return null;
  final quote = m.$1.group(1)!;
  final contentStart = m.$1.end; // just after the opening quote
  final closeIdx = content.indexOf(quote, m.$1.end);
  if (closeIdx < 0) return null;
  final escaped = newInner
      .replaceAll(r'\', r'\\')
      .replaceAll('\$', r'\$')
      .replaceAll(quote, '\\$quote');
  return content.substring(0, contentStart) +
      escaped +
      content.substring(closeIdx);
}

/// Change a region's rendered TEXT. Anchored on the CURRENT rendered text
/// [currentText] (which is unique to the widget) — find `Text('<current>')`
/// and rewrite its string. Falls back to the nearest `Text('…')` to [anchor].
String? setTextEdit(
  String content, {
  required int anchor,
  String? currentText,
  required String newText,
}) {
  final cur = (currentText ?? '').trim();
  if (cur.length >= 3) {
    final probe = cur.length > 40 ? cur.substring(0, 40) : cur;
    final byText = _nearestMatch(
        content, RegExp("Text\\(\\s*['\"]" + RegExp.escape(probe)), anchor, 60);
    if (byText != null) {
      final lit = _nearestMatch(
          content, RegExp("['\"]" + RegExp.escape(probe)), byText.$2, 3);
      if (lit != null) {
        final m = lit.$1;
        final quote = content[m.start];
        final contentStart = m.start + 1;
        final closeIdx = content.indexOf(quote, m.start + 1);
        if (closeIdx >= 0) {
          final escaped = newText
              .replaceAll(r'\', r'\\')
              .replaceAll('\$', r'\$')
              .replaceAll(quote, '\\$quote');
          return content.substring(0, contentStart) +
              escaped +
              content.substring(closeIdx);
        }
      }
    }
  }
  return _replaceStringArg(
      content, anchor, RegExp("Text\\(\\s*(['\"])"), newText);
}

/// Recolor the GLYPHS of a text region: nearest `TextStyle(…)` to [anchor];
/// swap its `color:` value if present, else insert one.
String? setTextColorEdit(
  String content, {
  required int anchor,
  required String hex,
}) {
  final newColor = colorLiteralForHex(hex);
  if (newColor == null) return null;
  final ts = _nearestMatch(content, RegExp(r'TextStyle\('), anchor, 8);
  if (ts == null) return null;
  final openParen = ts.$1.end - 1; // the '(' of TextStyle(
  final closeParen = _matchingParen(content, openParen);
  if (closeParen < 0) return null;
  final bodyStart = openParen + 1;
  final body = content.substring(bodyStart, closeParen);
  final cm = RegExp(colorValueRe).firstMatch(body);
  if (cm != null && _propBefore(body, cm.start) == 'color') {
    final valStart = bodyStart + cm.start;
    final valEnd = bodyStart + cm.end;
    return content.substring(0, valStart) +
        newColor +
        content.substring(valEnd);
  }
  // No colour yet — insert it right after TextStyle(
  return content.substring(0, bodyStart) +
      'color: $newColor, ' +
      content.substring(bodyStart);
}

/// Repaint a BOX's background: the nearest `backgroundColor:`/`color:` that is
/// NOT inside a TextStyle, to [anchor] (within 40 lines).
String? setBgColorEdit(
  String content, {
  required int anchor,
  required String hex,
}) {
  final newColor = colorLiteralForHex(hex);
  if (newColor == null) return null;
  // Allow an optional `const ` before the value (generated code often writes
  // `backgroundColor: const Color(…)`); it stays in place when we swap the value.
  final re = RegExp(
      '(?:backgroundColor|color)\\s*:\\s*(?:const\\s+)?(' + colorValueRe + ')');
  RegExpMatch? best;
  var bestDist = 1 << 30;
  for (final m in re.allMatches(content)) {
    if (_insideTextStyle(content, m.start)) continue;
    final line = _lineAt(content, m.start);
    final dist = (line - anchor).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = m;
    }
  }
  if (best == null || bestDist > 40) return null;
  // Group 1 is the trailing colour value, so it ends at the match end.
  final val = best.group(1)!;
  final valEnd = best.end;
  final valStart = valEnd - val.length;
  return content.substring(0, valStart) +
      newColor +
      content.substring(valEnd);
}

/// Replace an `Image.asset` path near [anchor].
String? replaceImageEdit(
  String content, {
  required int anchor,
  required String assetPath,
}) {
  final asset = assetPath.replaceAll(RegExp(r'^/'), '');
  if (asset.isEmpty) return null;
  return _replaceStringArg(
      content, anchor, RegExp("Image\\.asset\\(\\s*(['\"])"), asset);
}

/// Move: nearest `Positioned(left:, top:)` or `Offset(x, y)` to [anchor].
String? moveEdit(
  String content, {
  required int anchor,
  required double dx,
  required double dy,
}) {
  final a = _nearestMatch(
      content,
      RegExp(
          r'left:\s*([+-]?\d+(?:\.\d+)?)\s*,\s*top:\s*([+-]?\d+(?:\.\d+)?)'),
      anchor,
      20);
  if (a != null) {
    final m = a.$1;
    final nl = _fmt(double.parse(m.group(1)!) + dx);
    final nt = _fmt(double.parse(m.group(2)!) + dy);
    return content.substring(0, m.start) +
        'left: $nl, top: $nt' +
        content.substring(m.start + m.end);
  }
  final b = _nearestMatch(
      content,
      RegExp(r'Offset\(\s*([+-]?\d+(?:\.\d+)?)\s*,\s*([+-]?\d+(?:\.\d+)?)\s*\)'),
      anchor,
      20);
  if (b != null) {
    final m = b.$1;
    final nx = _fmt(double.parse(m.group(1)!) + dx);
    final ny = _fmt(double.parse(m.group(2)!) + dy);
    return content.substring(0, m.start) +
        'Offset($nx, $ny)' +
        content.substring(m.start + m.end);
  }
  return null;
}

/// Padding: nearest `EdgeInsets.*` to [anchor], normalised to fromLTRB.
/// [padding] is (top, right, bottom, left).
String? setPaddingEdit(
  String content, {
  required int anchor,
  required (double, double, double, double) padding,
}) {
  final t = _fmt(padding.$1);
  final rt = _fmt(padding.$2);
  final b = _fmt(padding.$3);
  final l = _fmt(padding.$4);
  final m = _nearestMatch(
      content,
      RegExp(r'EdgeInsets\.(?:all|only|symmetric|fromLTRB)\(\s*[^)]*\)'),
      anchor,
      24);
  if (m == null) return null;
  final mm = m.$1;
  return content.substring(0, mm.start) +
      'EdgeInsets.fromLTRB($l, $t, $rt, $b)' +
      content.substring(mm.start + mm.end);
}
