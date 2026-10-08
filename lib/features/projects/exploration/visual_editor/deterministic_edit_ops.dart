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

/// When true, the pure edit ops print a one-line REASON whenever they decline
/// (return null) — so the app log shows exactly why a visual edit fell back to
/// the assistant instead of applying. Flip to false (e.g. in tests) to keep
/// stdout quiet.
bool editOpsDebug = true;

void _dbg(String msg) {
  if (editOpsDebug) print('[EditOps] $msg');
}

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
  String content,
  RegExp re,
  int anchor,
  int maxDist,
) {
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

/// True if the character [c] is a Dart identifier character.
bool _isIdentChar(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 0x30 && u <= 0x39) ||
      (u >= 0x41 && u <= 0x5A) ||
      (u >= 0x61 && u <= 0x7A) ||
      c == '_';
}

bool _isWs(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';

/// Whether [idx] lies inside a `TextStyle( … )` or `.copyWith( … )` call —
/// i.e. a TEXT-STYLE colour, as opposed to a box/background `color:`.
bool _insideStyle(String content, int idx) {
  for (final re in [RegExp(r'TextStyle\('), RegExp(r'\.copyWith\(')]) {
    final opens = [
      // The '(' is the last char of the `TextStyle(`/`.copyWith(` match.
      for (final m in re.allMatches(content.substring(0, idx))) m.end - 1,
    ];
    if (opens.isEmpty) continue;
    if (_matchingParen(content, opens.last) > idx) return true;
  }
  return false;
}

/// Every `color:` property in [content], excluding `backgroundColor:` (whose
/// trailing `color` would otherwise match). Yields the `color\s*:\s*` match.
Iterable<RegExpMatch> _colorProps(String content) sync* {
  for (final m in RegExp(r'color\s*:\s*').allMatches(content)) {
    if (m.start > 0 && _isIdentChar(content[m.start - 1])) continue;
    yield m;
  }
}

/// The end index of the value expression starting at [start]: scan forward
/// tracking paren/bracket/brace depth until the next `,`, `;` or a closing
/// `)`/`}` at depth 0. Handles ANY value form — `Color(0x…)`, `Colors.x`,
/// `Theme.of(...).colorScheme.x`, `MyTheme.gold`,
/// `MyTheme.gold.withValues(alpha: 0.15)`, `scheme.onSurface`, a bare var —
/// so we never need to know the colour's source, only where it ends.
int _valueEnd(String content, int start) {
  var depth = 0;
  for (var i = start; i < content.length; i++) {
    final c = content[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return i;
      depth--;
    } else if (depth == 0 && (c == ',' || c == ';')) {
      return i;
    }
  }
  return content.length;
}

/// The (start, end) span of the colour VALUE for a `…: <value>` property whose
/// colon+whitespace ends at [afterColon] — skipping an optional `const ` and
/// trailing whitespace, so the replacement leaves the surrounding code intact.
(int, int) _valueSpan(String content, int afterColon) {
  var s = afterColon;
  // Skip leading whitespace (callers may pass the index right after ':').
  while (s < content.length && _isWs(content[s])) {
    s++;
  }
  final bound = s + 16 > content.length ? content.length : s + 16;
  final constM = RegExp(r'const\s+').firstMatch(content.substring(s, bound));
  if (constM != null) s += constM.end;
  var e = _valueEnd(content, s);
  while (e > s && _isWs(content[e - 1])) {
    e--;
  }
  return (s, e);
}

/// Within [content][bodyStart..bodyEnd) (a call's argument body), the
/// (propStart, afterColon) of [prop] occurring at DEPTH 0 — i.e. a direct
/// argument of that call, not a property of a nested widget. Returns null if
/// absent. This is what lets "set background" target the Scaffold's own
/// `backgroundColor:` and not a `Container(backgroundColor:…)` inside it.
(int, int)? _findPropAtDepth0(
  String content,
  int bodyStart,
  int bodyEnd,
  String prop,
) {
  var depth = 0;
  var i = bodyStart;
  while (i < bodyEnd) {
    final c = content[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (depth == 0 &&
        content.startsWith(prop, i) &&
        (i == 0 || !_isIdentChar(content[i - 1]))) {
      var j = i + prop.length;
      while (j < bodyEnd && (content[j] == ' ' || content[j] == '\t')) {
        j++;
      }
      if (j < bodyEnd && content[j] == ':') {
        return (i, j + 1);
      }
    }
    i++;
  }
  return null;
}

String _fmt(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Replace the first string argument of the nearest `prefix('…')` call to
/// [anchor] (within 12 lines).
String? _replaceStringArg(
  String content,
  int anchor,
  RegExp openRe,
  String newInner, {
  String what = 'replaceStringArg',
}) {
  final m = _nearestMatch(content, openRe, anchor, 12);
  if (m == null) {
    _dbg('$what: no matching call within 12 lines of anchor=$anchor');
    return null;
  }
  final quote = m.$1.group(1)!;
  final contentStart = m.$1.end; // just after the opening quote
  final closeIdx = content.indexOf(quote, m.$1.end);
  if (closeIdx < 0) {
    _dbg('$what: found an opening quote but no closing quote');
    return null;
  }
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
      content,
      RegExp("Text\\(\\s*['\"]" + RegExp.escape(probe)),
      anchor,
      60,
    );
    if (byText != null) {
      final lit = _nearestMatch(
        content,
        RegExp("['\"]" + RegExp.escape(probe)),
        byText.$2,
        3,
      );
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
    content,
    anchor,
    RegExp("Text\\(\\s*(['\"])"),
    newText,
    what: 'setText',
  );
}

/// Recolor the GLYPHS of a text region: the `color:` property of the nearest
/// text style (`TextStyle(…)` or `…copyWith(…)`) to [anchor]. Swaps the value
/// whatever form it is in (Color/Colors/MyTheme.x/.withValues/var). Returns
/// null when the text has no explicit colour of its own (inherits the theme)
/// — the caller then falls back to the assistant.
String? setTextColorEdit(
  String content, {
  required int anchor,
  required String hex,
}) {
  final newColor = colorLiteralForHex(hex);
  if (newColor == null) {
    _dbg('setTextColor: unparsable hex "$hex"');
    return null;
  }
  (int, int)? best;
  var bestDist = 1 << 30;
  var styleColourCount = 0;
  for (final m in _colorProps(content)) {
    if (!_insideStyle(content, m.start))
      continue; // must be a text-style colour
    styleColourCount++;
    final line = _lineAt(content, m.start);
    final dist = (line - anchor).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = _valueSpan(content, m.end);
    }
  }
  if (best != null && bestDist <= 14) {
    return content.substring(0, best.$1) +
        newColor +
        content.substring(best.$2);
  }
  // No explicit colour within 14 lines — try inserting into the nearest style.
  final styleOpen = _nearestStyle(content, anchor, 14);
  if (styleOpen != null) {
    final insertAt = styleOpen + 1; // just after the '('
    return content.substring(0, insertAt) +
        'color: $newColor, ' +
        content.substring(insertAt);
  }
  // Phase 3 — the Text inherits its colour from the theme (no style at all).
  // Add a `style: TextStyle(color: …)` to the nearest Text.
  final styled = _addStyleToNearestText(content, anchor, newColor);
  if (styled != null) return styled;
  _dbg(
    'setTextColor: MISS anchor=$anchor — '
    '${styleColourCount == 0 ? "no text-style `color:` anywhere in file" : "nearest text-style `color:` is $bestDist lines away (>14)"}, '
    'no TextStyle(/copyWith( within 14 lines, and no bare Text( within 6 lines to style',
  );
  return null;
}

/// Index of the '(' of the nearest `TextStyle(` / `.copyWith(` to [anchor],
/// within [maxDist] lines, or null.
int? _nearestStyle(String content, int anchor, int maxDist) {
  int? bestOpen;
  var bestDist = 1 << 30;
  for (final re in [RegExp(r'TextStyle\('), RegExp(r'\.copyWith\(')]) {
    for (final m in re.allMatches(content)) {
      final open = m.end - 1; // the '('
      final line = _lineAt(content, open);
      final dist = (line - anchor).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestOpen = open;
      }
    }
  }
  if (bestOpen == null || bestDist > maxDist) return null;
  return bestOpen;
}

/// The Text inherits its colour from the theme (no explicit style). Find the
/// nearest `Text(` to [anchor] (within 6 lines) that has no `style:` argument
/// and add one — the minimal change that makes the colour stick. Returns the
/// new content, or null if there's no safe target.
String? _addStyleToNearestText(String content, int anchor, String newColor) {
  int? bestOpen;
  var bestDist = 1 << 30;
  for (final m in RegExp(r'Text\s*\(').allMatches(content)) {
    final open = m.end - 1; // the '('
    final dist = (_lineAt(content, open) - anchor).abs();
    if (dist < bestDist) {
      bestDist = dist;
      bestOpen = open;
    }
  }
  if (bestOpen == null || bestDist > 6) return null;
  final close = _matchingParen(content, bestOpen);
  if (close < 0) return null;
  final args = content.substring(bestOpen + 1, close);
  if (RegExp(r'\bstyle\s*:').hasMatch(args)) {
    _dbg(
      'addStyle: nearest Text( already has a style: (the insert-into-'
      'TextStyle path should have handled it)',
    );
    return null;
  }
  final prefix = args.trimRight().endsWith(',') ? ' style:' : ', style:';
  return content.substring(0, close) +
      '$prefix TextStyle(color: $newColor)' +
      content.substring(close);
}

/// Repaint a BOX's background: the nearest `backgroundColor:` — or a `color:`
/// that is NOT a text-style colour (a Container/Card/BoxDecoration/Icon fill)
/// — to [anchor]. The value is replaced whatever form it is in.
String? setBgColorEdit(
  String content, {
  required int anchor,
  required String hex,
}) {
  final newColor = colorLiteralForHex(hex);
  if (newColor == null) {
    _dbg('setBgColor: unparsable hex "$hex"');
    return null;
  }
  (int, int)? best;
  var bestDist = 1 << 30;
  // `backgroundColor:` is unambiguously a background.
  for (final m in RegExp(r'backgroundColor\s*:\s*').allMatches(content)) {
    final line = _lineAt(content, m.start);
    final dist = (line - anchor).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = _valueSpan(content, m.end);
    }
  }
  // `color:` that is not a text-style colour (box / decoration / icon fill).
  for (final m in _colorProps(content)) {
    if (_insideStyle(content, m.start)) continue;
    final line = _lineAt(content, m.start);
    final dist = (line - anchor).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = _valueSpan(content, m.end);
    }
  }
  if (best == null || bestDist > 40) {
    _dbg(
      'setBgColor: MISS anchor=$anchor — '
      '${best == null ? "no backgroundColor:/box `color:` anywhere in file" : "nearest background colour is $bestDist lines away (>40)"}',
    );
    return null;
  }
  return content.substring(0, best.$1) + newColor + content.substring(best.$2);
}

/// Set a SCREEN's background colour: the nearest `Scaffold(` to [anchor]; swap
/// its `backgroundColor:` if present, else insert one right after `Scaffold(`.
/// This is the reliable, screen-level "change the background" the user can't
/// reach by clicking (the background sits behind every region).
String? setBackgroundEdit(
  String content, {
  required int anchor,
  required String hex,
}) {
  final newColor = colorLiteralForHex(hex);
  if (newColor == null) {
    _dbg('setBackground: unparsable hex "$hex"');
    return null;
  }
  final scaffold = _nearestMatch(content, RegExp(r'Scaffold\('), anchor, 400);
  if (scaffold == null) {
    _dbg(
      'setBackground: no Scaffold( within 400 lines of anchor=$anchor '
      '(page may not use a Scaffold)',
    );
    return null;
  }
  final openParen = scaffold.$1.end - 1; // the '(' of Scaffold(
  final closeParen = _matchingParen(content, openParen);
  if (closeParen < 0) {
    _dbg('setBackground: Scaffold( has an unmatched paren — cannot target it');
    return null;
  }
  final bodyStart = openParen + 1;
  // Only a Scaffold-LEVEL backgroundColor (depth 0), never a nested widget's.
  final hit = _findPropAtDepth0(
    content,
    bodyStart,
    closeParen,
    'backgroundColor',
  );
  if (hit != null) {
    final span = _valueSpan(content, hit.$2);
    return content.substring(0, span.$1) +
        newColor +
        content.substring(span.$2);
  }
  // No backgroundColor yet — insert one as the first Scaffold argument.
  return content.substring(0, bodyStart) +
      'backgroundColor: $newColor, ' +
      content.substring(bodyStart);
}

/// Set the screen BACKGROUND to an IMAGE: wrap the Scaffold's `body:` value in
/// a Stack with the image filling the screen BEHIND the existing UI. Returns
/// the new content, or null when the page has no Scaffold body to wrap (the
/// caller then falls back to the assistant — with the image already copied into
/// the workspace, so it CAN complete).
String? setBackgroundImageEdit(
  String content, {
  required int anchor,
  required String assetPath,
}) {
  final asset = assetPath.replaceAll(RegExp(r'^/'), '');
  if (asset.isEmpty) {
    _dbg('setBackgroundImage: empty asset path');
    return null;
  }
  final scaffold = _nearestMatch(content, RegExp(r'Scaffold\('), anchor, 400);
  if (scaffold == null) {
    _dbg(
      'setBackgroundImage: no Scaffold( within 400 lines of anchor=$anchor',
    );
    return null;
  }
  final openParen = scaffold.$1.end - 1;
  final closeParen = _matchingParen(content, openParen);
  if (closeParen < 0) {
    _dbg('setBackgroundImage: Scaffold( has an unmatched paren');
    return null;
  }
  final hit = _findPropAtDepth0(content, openParen + 1, closeParen, 'body');
  if (hit == null) {
    _dbg('setBackgroundImage: Scaffold has no depth-0 body: argument');
    return null;
  }
  // Capture the FULL body value (keeping any `const` on the inner widget — it
  // stays valid inside the new Stack). No `const` skip here, unlike _valueSpan.
  var s = hit.$2;
  while (s < content.length && _isWs(content[s])) {
    s++;
  }
  var e = _valueEnd(content, s);
  while (e > s && _isWs(content[e - 1])) {
    e--;
  }
  final bodyExpr = content.substring(s, e);
  if (bodyExpr.isEmpty) {
    _dbg('setBackgroundImage: Scaffold body: value is empty');
    return null;
  }
  final wrapped = 'Stack(children: [\n'
      "        Positioned.fill(child: Image.asset('$asset', fit: BoxFit.cover)),\n"
      '        $bodyExpr,\n'
      '      ])';
  return content.substring(0, s) + wrapped + content.substring(e);
}

/// Replace an `Image.asset` path near [anchor].
String? replaceImageEdit(
  String content, {
  required int anchor,
  required String assetPath,
}) {
  final asset = assetPath.replaceAll(RegExp(r'^/'), '');
  if (asset.isEmpty) {
    _dbg('replaceImage: empty asset path');
    return null;
  }
  return _replaceStringArg(
    content,
    anchor,
    RegExp("Image\\.asset\\(\\s*(['\"])"),
    asset,
    what: 'replaceImage',
  );
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
    RegExp(r'left:\s*([+-]?\d+(?:\.\d+)?)\s*,\s*top:\s*([+-]?\d+(?:\.\d+)?)'),
    anchor,
    20,
  );
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
    20,
  );
  if (b != null) {
    final m = b.$1;
    final nx = _fmt(double.parse(m.group(1)!) + dx);
    final ny = _fmt(double.parse(m.group(2)!) + dy);
    return content.substring(0, m.start) +
        'Offset($nx, $ny)' +
        content.substring(m.start + m.end);
  }
  _dbg(
    'move: no Positioned(left:, top:) or Offset(, ) within 20 lines of '
    'anchor=$anchor',
  );
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
    24,
  );
  if (m == null) {
    _dbg('setPadding: no EdgeInsets.* within 24 lines of anchor=$anchor');
    return null;
  }
  final mm = m.$1;
  return content.substring(0, mm.start) +
      'EdgeInsets.fromLTRB($l, $t, $rt, $b)' +
      content.substring(mm.start + mm.end);
}
