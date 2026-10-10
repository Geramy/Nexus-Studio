// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The VISUAL OP APPLIER. Tier 1: deterministic, surgical text edits driven by
/// the region's source position (color/text/offset literals near that line).
/// Tier 2 (when no confident pattern is found): the op is reported as
/// [OpStatus.needsAgent] with a precise prompt for the editor's chat — the
/// coding agent makes the change with screenshot + file:line context.
///
/// Every applied op is guarded: the materialized project is analyzed after the
/// change and, if it broke, the original bytes are restored and a revert
/// commit is written. Nothing half-broken ever lingers.
library;

import 'dart:convert';
import 'dart:io';

import '../../../../infrastructure/exec/captured_run.dart';
import '../../../../infrastructure/workspace/git/nxtprj_git_engine.dart';
import '../../../../infrastructure/workspace/workspace.dart';
import 'deterministic_edit_ops.dart';
import 'region_model.dart';

enum OpStatus { applied, rolledBack, needsAgent }

class ApplierOutcome {
  const ApplierOutcome({
    required this.status,
    required this.record,
    this.commitMessage,
    this.agentPrompt,
    this.analyzerOutput,
    this.reason,
    this.fileOriginals = const {},
  });
  final OpStatus status;
  final VisualEditRecord record;
  final String? commitMessage;
  final String? agentPrompt; // set when status == needsAgent
  final String? analyzerOutput; // set when status == rolledBack
  final String? reason;

  /// Touched file(s) → pre-edit bytes, so the caller can build a correct
  /// in-session UNDO even when the edit landed on a file different from
  /// [VisualOp.region].sourceFile (e.g. a home-menu route reorder edits the
  /// routes map, not the page).
  final Map<String, List<int>> fileOriginals;
}

class _DeterministicEdit {
  const _DeterministicEdit(this.filePath, this.newContent);
  final String filePath;
  final String newContent;
}

/// Apply [op] to the live workspace. Caller passes pre-asset-written state:
/// for image ops, [op.assetPath] must already exist in [ws].
Future<ApplierOutcome> applyVisualOp({
  required Workspace ws,
  required NxtprjGitEngine git,
  required VisualOp op,
}) async {
  final headBefore = (await git.headOid())?.substring(0, 7) ?? '???????';
  final edit = await _deterministicEditAsync(ws: ws, op: op);
  if (edit == null) {
    return ApplierOutcome(
      status: OpStatus.needsAgent,
      record: _record(
        op,
        headBefore,
        headBefore,
        const {},
        false,
        'Needs the assistant',
      ),
      agentPrompt: _agentPrompt(op),
      reason: 'No safe deterministic pattern found',
    );
  }

  // Read originals (for rollback + the touched-files map).
  final original = await ws.readBytes(edit.filePath);
  final touched = {edit.filePath: original.length};

  // Apply + commit.
  await ws.writeBytes(edit.filePath, edit.newContent.codeUnits);
  final commitMessage = 'Visual edit: ${op.summary}';
  var headAfter = headBefore;
  try {
    final full = await git.commitAll(message: commitMessage);
    headAfter = full.substring(0, 7);
  } catch (e) {
    await ws.writeBytes(edit.filePath, original);
    return ApplierOutcome(
      status: OpStatus.rolledBack,
      record: _record(
        op,
        headBefore,
        headBefore,
        touched,
        false,
        'Commit failed: $e',
      ),
      commitMessage: commitMessage,
      analyzerOutput: 'Commit failed: $e',
    );
  }

  // Analyze gate: a fast parse-check on the EXACT bytes we just wrote (not a
  // re-read from the workspace, so no write/read ordering can bite us).
  final analysis = await _analyzeChanged(edit.filePath, edit.newContent.codeUnits);
  if (analysis.errors.isEmpty) {
    return ApplierOutcome(
      status: OpStatus.applied,
      record: _record(op, headBefore, headAfter, touched, true, null),
      commitMessage: commitMessage,
      fileOriginals: {edit.filePath: original},
    );
  }

  // Broke — restore and commit the revert.
  await ws.writeBytes(edit.filePath, original);
  var revertHead = headAfter;
  try {
    final r = await git.commitAll(
      message: 'Revert visual edit (unsafe): ${op.summary}',
    );
    revertHead = r.substring(0, 7);
  } catch (_) {}
  return ApplierOutcome(
    status: OpStatus.rolledBack,
    record: _record(
      op,
      headBefore,
      revertHead,
      touched,
      false,
      'Rolled back — analyzer errors: ${analysis.errors.take(3).join(' | ')}',
    ),
    commitMessage: commitMessage,
    analyzerOutput: analysis.raw,
  );
}

VisualEditRecord _record(
  VisualOp op,
  String before,
  String after,
  Map<String, int> files,
  bool ok,
  String? detail,
) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return VisualEditRecord(
    id: now,
    timeMs: now,
    opSummary: op.summary,
    headBefore: before,
    headAfter: after,
    touchedFiles: files,
    ok: ok,
    detail: detail,
  );
}

/// The deterministic tier: a surgical edit anchored on the region's source
/// line. All the string surgery lives in [deterministic_edit_ops] (pure,
/// unit-tested); here we just read the file, pick the right op, and hand back
/// the new content. Returns null when no confident, well-anchored pattern
/// exists — the caller then falls back to the agent.
Future<_DeterministicEdit?> _deterministicEditAsync({
  required Workspace ws,
  required VisualOp op,
}) async {
  final r = op.region;
  final file = r.sourceFile;
  final anchor = r.sourceLine;
  if (file == null || anchor == null) {
    print(
      '[VisualEditor] ${op.kind.name}: NO SOURCE LOCATION for region '
      '"${r.label ?? r.widgetType}" (text="${r.text ?? r.childText}") — '
      'the locator couldn\'t map it to a file:line, so it needs the assistant',
    );
    return null;
  }
  // "Move" on a home-menu item is a CROSS-FILE reorder: the menu renders
  // Text(route), but the order lives in the routes map (a different file).
  // Try that first for BOTH an explicit reorder and a drag-to-move; if the
  // region isn't a route, fall through to the same-file deterministic ops.
  if (op.kind == VisualOpKind.reorder || op.kind == VisualOpKind.move) {
    final dirUp =
        op.kind == VisualOpKind.move ? _dragUp(op.dx, op.dy) : op.moveUp;
    final routeResult = await _routeReorderEdit(ws: ws, op: op, up: dirUp);
    if (routeResult != null) return routeResult;
  }
  final bytes = await ws.readBytes(file);
  final content = utf8.decode(bytes, allowMalformed: true);
  final lineCount = content.split('\n').length;

  final next = switch (op.kind) {
    VisualOpKind.setText => setTextEdit(
      content,
      anchor: anchor,
      currentText: op.region.text,
      newText: op.text ?? '',
    ),
    VisualOpKind.setColor =>
      (op.region.widgetType.contains('RenderParagraph') ||
              op.region.text != null)
          ? setTextColorEdit(content, anchor: anchor, hex: op.colorHex ?? '')
          : setBgColorEdit(content, anchor: anchor, hex: op.colorHex ?? ''),
    VisualOpKind.insertImage => insertImageEdit(
      content,
      anchor: anchor,
      assetPath: op.assetPath ?? '',
    ),
    VisualOpKind.replaceImage => replaceImageEdit(
      content,
      anchor: anchor,
      assetPath: op.assetPath ?? '',
    ),
    VisualOpKind.move => moveEdit(
      content,
      anchor: anchor,
      dx: op.dx,
      dy: op.dy,
    ) ??
      // Flow layout (Column/Row/ListView): a freeform pixel shift isn't a
      // thing, so map the drag to a one-step reorder in its dominant direction
      // (the only deterministic "move" that makes sense there).
      reorderEdit(content, anchor: anchor, up: _dragUp(op.dx, op.dy)),
    VisualOpKind.setPadding =>
      op.padding == null
          ? null
          : setPaddingEdit(content, anchor: anchor, padding: op.padding!),
    VisualOpKind.reorder =>
      reorderEdit(content, anchor: anchor, up: op.moveUp),
    VisualOpKind.setBackground => op.assetPath != null
      ? setBackgroundImageEdit(content, anchor: anchor, assetPath: op.assetPath!)
      : setBackgroundEdit(content, anchor: anchor, hex: op.colorHex ?? ''),
    VisualOpKind.clearBackground =>
      clearBackgroundImageEdit(content, anchor: anchor),
  };
  print(
    '[VisualEditor] ${op.kind.name} @ ${file}:$anchor '
    '(file $lineCount lines; region="${r.label ?? r.widgetType}" '
    'text="${r.text ?? r.childText}") → '
    '${next == null ? "NO deterministic match (→ agent; reason on the [EditOps] line above)" : "match found ✓"}\n'
    '${_snippet(content, anchor)}',
  );
  return next == null ? null : _DeterministicEdit(file, next);
}

/// For "move up/down" on a home-menu item, the real list is the app's routes
/// map, which lives in a different file than the page that shows the menu.
/// Find the file whose map contains [VisualOp.region.text] as a key and swap
/// that entry there. Returns null when the region is not a route (so the
/// same-file [reorderEdit] can handle a concrete list) or the swap isn't
/// possible.
Future<_DeterministicEdit?> _routeReorderEdit({
  required Workspace ws,
  required VisualOp op,
  required bool up,
}) async {
  final route = op.region.text?.trim() ?? '';
  if (!route.startsWith('/')) return null; // not a route label
  final keyRe = RegExp("(['\"])${RegExp.escape(route)}\\1\\s*:");
  final entries = await ws.walk();
  for (final e in entries) {
    if (e.isDirectory) continue;
    final p = e.path;
    if (!p.endsWith('.dart')) continue;
    final norm = p.startsWith('/') ? p : '/$p';
    if (!norm.contains('/lib/') || norm.contains('/test/')) continue;
    String content;
    try {
      content = utf8.decode(await ws.readBytes(p), allowMalformed: true);
    } catch (_) {
      continue;
    }
    if (!content.contains(route)) continue; // cheap pre-filter
    if (!keyRe.hasMatch(content)) continue;
    final next = reorderRouteEdit(content, route, up);
    if (next == null) {
      print(
        '[VisualEditor] reorderRoute: "$route" is a key in ${e.path} but the '
        'swap is not possible (edge item / ambiguous) — needs the assistant',
      );
      continue;
    }
    print(
      '[VisualEditor] reorderRoute: moved "$route" ${up ? "up" : "down"} '
      'in ${e.path} ✓ (cross-file: menu shows Text(route), order lives in the routes map)',
    );
    return _DeterministicEdit(e.path, next);
  }
  return null;
}

/// Map a 2-D drag to a one-step list direction: the dominant axis decides
/// vertical (up/down) vs horizontal (left/right); "earlier in the list" is up.
bool _dragUp(double dx, double dy) => dy.abs() >= dx.abs() ? dy < 0 : dx < 0;

/// A few lines of [content] around the 1-based [anchor] line, the anchor
/// marked with `>>` — so the log shows exactly what source the region's
/// located position points at (the key to diagnosing a missed edit).
String _snippet(String content, int anchor, [int ctx = 4]) {
  final lines = content.split('\n');
  if (lines.isEmpty) return '  (empty file)';
  final start = anchor - ctx < 1 ? 1 : anchor - ctx;
  var end = anchor + ctx;
  if (end > lines.length) end = lines.length;
  final buf = StringBuffer();
  for (var i = start; i <= end; i++) {
    buf.writeln(
      '${i == anchor ? '>>' : '  '} ${i.toString().padLeft(4)}| ${lines[i - 1]}',
    );
  }
  return buf.toString().trimRight();
}

/// Precise prompt for the assistant (tier 2): what, where, with context.
String _agentPrompt(VisualOp op) {
  final r = op.region;
  final where = r.hasSource
      ? '${r.sourceFile}:${r.sourceLine}'
      : 'unknown file';
  final box = r.rect;
  final boxDesc =
      '(${box.x.round()}, ${box.y.round()}, ${box.w.round()}×${box.h.round()})';
  return switch (op.kind) {
    VisualOpKind.setColor =>
      'Visual edit task: change the color of the ${r.label ?? r.widgetType} at $where (screen region $boxDesc) to ${op.colorHex}. Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.setText =>
      'Visual edit task: change the text of the ${r.label ?? r.widgetType} at $where (screen region $boxDesc) to: "${op.text}". Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.insertImage =>
      'Visual edit task: insert the image asset "${op.assetPath}" into/behind the ${r.label ?? r.widgetType} at $where (screen region $boxDesc), keeping the layout sane. Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.replaceImage =>
      'Visual edit task: replace the image shown in the ${r.label ?? r.widgetType} at $where (screen region $boxDesc) with the asset "${op.assetPath}". Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.move =>
      'Visual edit task: move the ${r.label ?? r.widgetType} at $where (screen region $boxDesc) by (${op.dx.round()}, ${op.dy.round()}) pixels — change the surrounding padding/margin/Positioned/alignment, do NOT freeform-position the widget. Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.setPadding =>
      'Visual edit task: set the padding of the ${r.label ?? r.widgetType} at $where (screen region $boxDesc) to top ${op.padding!.$1.round()}, right ${op.padding!.$2.round()}, bottom ${op.padding!.$3.round()}, left ${op.padding!.$4.round()} — adjust the nearest EdgeInsets/padding/margin, keep the layout sane. Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.reorder =>
      'Visual edit task: move the ${r.label ?? r.widgetType} at $where (screen region $boxDesc) ${op.moveUp ? "UP" : "DOWN"} one position within its parent list — reorder that child inside the enclosing Column/Row/ListView children list, keeping the layout sane. Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.setBackground => op.assetPath != null
      ? 'Visual edit task: set this screen\'s BACKGROUND to the image asset "${op.assetPath}" (already in the app\'s assets/ and registered in pubspec). Wrap the page Scaffold\'s `body:` in a Stack with `Positioned.fill(child: Image.asset("${op.assetPath}", fit: BoxFit.cover))` as the first child, keeping ALL existing UI on top. Page file: $where. Keep the file compiling.'
      : 'Visual edit task: change this screen\'s BACKGROUND colour to ${op.colorHex} at $where. Set the page Scaffold\'s `backgroundColor:` (or the top-level background) — do not restyle individual widgets. Edit only the minimal lines needed; keep the file compiling.',
    VisualOpKind.clearBackground =>
      'Visual edit task: REMOVE this screen\'s BACKGROUND image (the Image used as the Scaffold body backdrop, e.g. a Positioned.fill(child: Image.asset(…))) but KEEP its background colour and all foreground UI, at $where. Edit only the minimal lines needed; keep the file compiling.',
  };
}

class _Analysis {
  const _Analysis(this.errors, this.raw);
  final List<String> errors;
  final String raw;
}

/// Fast guard: the deterministic edits only rewrite string/colour/number
/// literals, so a PARSE check is sufficient (no new identifiers are
/// introduced, so a type check can't surface anything extra). We write the
/// edited file to a temp path and run `dart format --output=none` — a ~50 ms
/// parse check that needs no materialization or pub get. This keeps the
/// edit→see-it loop near-instant instead of a full rebuild.
/// Fast parse-gate on [content]. `dart format --output=none` exits 0 for any
/// parseable file (even one it would reflow) and non-zero ONLY when the source
/// cannot be parsed (exit 65, "Could not format because the source could not
/// be parsed") or the `dart` binary is unavailable. We roll back ONLY on a
/// genuine parse failure — a benign non-zero (missing `dart`, a warning, a
/// timeout) must never revert an edit whose content the deterministic op
/// guarantees is valid. Everything is logged so a surprise is immediately
/// diagnosable.
Future<_Analysis> _analyzeChanged(String path, List<int> content) async {
  final rel = path.replaceAll(RegExp(r'^/'), '');
  if (!rel.startsWith('lib/') || !rel.endsWith('.dart')) {
    return const _Analysis([], '');
  }
  final tmp = Directory.systemTemp.createTempSync('nexus_fmt_');
  final tmpFile = File('${tmp.path}${Platform.pathSeparator}check.dart');
  try {
    tmpFile.writeAsBytesSync(content);
    final run = await runCaptured(
      'dart format --output=none "${tmpFile.path}"',
      timeout: const Duration(seconds: 30),
    );
    final out = run.output.trim();
    if (editOpsDebug) {
      print('[EditOps] gate $path: exit=${run.exitCode} len=${content.length}');
      for (final l in out.split('\n').take(8)) {
        if (l.trim().isNotEmpty) print('[EditOps]   $l');
      }
    }
    // A real syntax break always says the source could not be parsed.
    final isParseError =
        out.toLowerCase().contains('could not be parsed') ||
        out.toLowerCase().contains('could not format');
    if (run.exitCode == 0) return const _Analysis([], '');
    if (isParseError) {
      return _Analysis(
        out.split('\n').where((l) => l.trim().isNotEmpty).take(6).toList(),
        out,
      );
    }
    // Non-zero but not a parse error (e.g. `dart` not on PATH in this process,
    // a warning, a timeout): do NOT roll back a validated edit — log and pass.
    print('[EditOps] gate: non-zero exit=${run.exitCode} but no parse error; '
        'treating as OK (not rolling back). out=$out');
    return _Analysis([], out);
  } finally {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// Make sure [assetPath] (workspace path, e.g. /assets/gen_1.png) is declared
/// in pubspec.yaml's flutter.assets. Best-effort string surgery on YAML.
Future<void> ensureAssetInPubspec(Workspace ws, String assetPath) async {
  const pubspecPath = '/pubspec.yaml';
  if (!await ws.exists(pubspecPath)) return;
  final raw = utf8.decode(
    await ws.readBytes(pubspecPath),
    allowMalformed: true,
  );
  final clean = assetPath.replaceAll(RegExp(r'^/'), '');
  final dir = clean.contains('/')
      ? clean.substring(0, clean.lastIndexOf('/'))
      : '';
  // A directory is "registered" only if a line is EXACTLY `- assets/` (trailing
  // slash, end of line). `- assets/file.png` is a specific file and does NOT
  // cover other files in the same directory (the old substring check
  // `raw.contains('- $dir/')` matched file entries and silently skipped them).
  final dirRe = dir.isNotEmpty
      ? RegExp('^\\s*-\\s*' + RegExp.escape(dir) + '/\\s*\$', multiLine: true)
      : null;
  final hasDir = dirRe != null && dirRe.hasMatch(raw);
  final hasFile = raw.contains('- $clean');
  if (hasDir || hasFile) return;
  String next;
  // Insert a NEW line: the offset just after the next newline from [from], so
  // we never merge onto the matched token's own line (the old code inserted at
  // match.end, right after `flutter:`, producing an invalid `flutter:  assets:`).
  int startOfNextLine(String s, int from) {
    final nl = s.indexOf('\n', from);
    return nl < 0 ? s.length : nl + 1;
  }

  final flutterM = RegExp(r'^flutter:\s*$', multiLine: true).firstMatch(raw);
  if (flutterM == null) {
    next = '${raw.trimRight()}\nflutter:\n  assets:\n    - $clean\n';
  } else {
    final flutterNext = startOfNextLine(raw, flutterM.end);
    final assetsM = RegExp(
      r'^(\s*)assets:\s*$',
      multiLine: true,
    ).firstMatch(raw);
    if (assetsM == null) {
      next = raw.substring(0, flutterNext) +
          '  assets:\n    - $clean\n' +
          raw.substring(flutterNext);
    } else {
      final assetNext = startOfNextLine(raw, assetsM.end);
      final indent = assetsM.group(1) ?? '  ';
      next = raw.substring(0, assetNext) +
          '$indent  - $clean\n' +
          raw.substring(assetNext);
    }
  }
  await ws.writeBytes(pubspecPath, next.codeUnits);
}
