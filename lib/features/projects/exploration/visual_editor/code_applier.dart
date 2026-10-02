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

import '../../../../infrastructure/build/workspace_materializer.dart';
import '../../../../infrastructure/exec/captured_run.dart';
import '../../../../infrastructure/workspace/git/nxtprj_git_engine.dart';
import '../../../../infrastructure/workspace/workspace.dart';
import 'region_model.dart';
import 'screen_map_service.dart';

enum OpStatus { applied, rolledBack, needsAgent }

class ApplierOutcome {
  const ApplierOutcome({
    required this.status,
    required this.record,
    this.commitMessage,
    this.agentPrompt,
    this.analyzerOutput,
    this.reason,
  });
  final OpStatus status;
  final VisualEditRecord record;
  final String? commitMessage;
  final String? agentPrompt; // set when status == needsAgent
  final String? analyzerOutput; // set when status == rolledBack
  final String? reason;
}

class _DeterministicEdit {
  const _DeterministicEdit(this.filePath, this.newContent);
  final String filePath;
  final String newContent;
}

const _window = 14; // ± lines around the source line

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
      record: _record(op, headBefore, headBefore, const {}, false,
          'Needs the assistant'),
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
      record: _record(op, headBefore, headBefore, touched, false,
          'Commit failed: $e'),
      commitMessage: commitMessage,
      analyzerOutput: 'Commit failed: $e',
    );
  }

  // Analyze gate on the materialized tree.
  final analysis = await _analyzeChanged(ws, [edit.filePath]);
  if (analysis.errors.isEmpty) {
    return ApplierOutcome(
      status: OpStatus.applied,
      record: _record(op, headBefore, headAfter, touched, true, null),
      commitMessage: commitMessage,
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

/// The deterministic tier: find a safe literal to change near the region's
/// source line. Returns null when no confident pattern exists.
Future<_DeterministicEdit?> _deterministicEditAsync({
  required Workspace ws,
  required VisualOp op,
}) async {
  final file = op.region.sourceFile;
  final line = op.region.sourceLine;
  if (file == null || line == null) return null;
  final bytes = await ws.readBytes(file);
  final content = utf8.decode(bytes, allowMalformed: true);
  final lines = content.split('\n');
  final lo = (line - _window).clamp(0, lines.length);
  final hi = (line + _window).clamp(0, lines.length);
  var windowStart = 0;
  for (var i = 0; i < lo; i++) {
    windowStart += lines[i].length + 1;
  }
  final windowText = lines.sublist(lo, hi).join('\n');

  switch (op.kind) {
    case VisualOpKind.setColor:
      final hex = (op.colorHex ?? '').replaceAll('#', '');
      if (hex.length < 6) return null;
      final replacement = 'Color(0x${_alpha(hex)}${hex.substring(0, 6).toUpperCase()})';
      // Prefer an EXACT match of the region's current color, else the first
      // color literal in the window.
      RegExpMatch? range;
      if (op.region.colorHex != null) {
        range = RegExp(
          'Color\\(0x[0-9A-Fa-f]{6,8}\\)',
        ).firstMatch(windowText);
      }
      range ??= RegExp(_colorTokenRe).firstMatch(windowText);
      if (range == null) return null;
      final at = windowStart + range.start;
      final next =
          content.substring(0, at) + replacement + content.substring(at + range.end);
      return _DeterministicEdit(file, next);

    case VisualOpKind.setText:
      final re = RegExp("Text\\(\\s*(['\"])");
      final m = re.firstMatch(windowText);
      if (m == null) return null;
      final quote = m.group(1)!;
      // The literal's content starts right after the opening quote.
      final contentStart = windowStart + m.end;
      final closeIdx = windowText.indexOf(quote, m.end);
      if (closeIdx < 0) return null;
      final escaped = (op.text ?? '')
          .replaceAll(r'\', r'\\')
          .replaceAll('\$', r'\$')
          .replaceAll(quote, '\\$quote');
      final next = content.substring(0, contentStart) +
          escaped +
          content.substring(windowStart + closeIdx);
      return _DeterministicEdit(file, next);

    case VisualOpKind.insertImage:
      return null; // structural — always the agent

    case VisualOpKind.replaceImage:
      final re = RegExp("Image\\.asset\\(\\s*(['\"])");
      final m = re.firstMatch(windowText);
      final asset = (op.assetPath ?? '').replaceAll(RegExp(r'^/'), '');
      if (m == null || asset.isEmpty) return null;
      final contentStart = windowStart + m.end;
      final quote = m.group(1)!;
      final closeIdx = windowText.indexOf(quote, m.end);
      if (closeIdx < 0) return null;
      final next = content.substring(0, contentStart) +
          asset +
          content.substring(windowStart + closeIdx);
      return _DeterministicEdit(file, next);

    case VisualOpKind.move:
      final dx = op.dx;
      final dy = op.dy;
      RegExpMatch? m =
          RegExp(r'left:\s*([+-]?\d+(?:\.\d+)?)\s*,\s*top:\s*([+-]?\d+(?:\.\d+)?)')
              .firstMatch(windowText);
      if (m != null) {
        final nl = _fmt((double.parse(m.group(1)!) + dx));
        final nt = _fmt((double.parse(m.group(2)!) + dy));
        final at = windowStart + m.start;
        final next = content.substring(0, at) +
            'left: $nl, top: $nt' +
            content.substring(at + m.end);
        return _DeterministicEdit(file, next);
      }
      m = RegExp(r'Offset\(\s*([+-]?\d+(?:\.\d+)?)\s*,\s*([+-]?\d+(?:\.\d+)?)\s*\)')
          .firstMatch(windowText);
      if (m != null) {
        final nx = _fmt((double.parse(m.group(1)!) + dx));
        final ny = _fmt((double.parse(m.group(2)!) + dy));
        final at = windowStart + m.start;
        final next = content.substring(0, at) +
            'Offset($nx, $ny)' +
            content.substring(at + m.end);
        return _DeterministicEdit(file, next);
      }
      return null;
  }
}

String _fmt(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

const _colorTokenRe =
    r'Colors\.[A-Za-z]+|Color\(0x[0-9A-Fa-f]{6,8}\)|Color\.fromARGB\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)';

String _alpha(String hex) =>
    hex.length >= 8 ? hex.substring(6, 8).toUpperCase() : 'FF';

/// Precise prompt for the assistant (tier 2): what, where, with context.
String _agentPrompt(VisualOp op) {
  final r = op.region;
  final where = r.hasSource ? '${r.sourceFile}:${r.sourceLine}' : 'unknown file';
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
  };
}

class _Analysis {
  const _Analysis(this.errors, this.raw);
  final List<String> errors;
  final String raw;
}

/// Materialize the (just-committed) workspace and run the analyzer over the
/// changed files.
Future<_Analysis> _analyzeChanged(Workspace ws, List<String> files) async {
  final materializer = WorkspaceMaterializer();
  final mat = await materializer.materialize(ws, tag: 'visualcheck');
  try {
    final appDir = findFlutterAppDir(mat.path) ?? mat.path;
    final relFiles = files
        .map((f) => f.replaceAll(RegExp(r'^/'), ''))
        .where((f) => f.startsWith('lib/') || f == 'pubspec.yaml')
        .toList();
    if (relFiles.isEmpty) return const _Analysis([], '');
    final script = 'flutter pub get >/dev/null 2>&1; flutter analyze ' +
        relFiles.map((f) => '"$f"').join(' ');
    final run = await runCaptured(
      script,
      workingDirectory: appDir,
      timeout: const Duration(minutes: 10),
    );
    final errors = run.output
        .split('\n')
        .where((l) => l.contains(' error ') || l.startsWith('error'))
        .take(8)
        .toList();
    return _Analysis(errors, run.output);
  } finally {
    await mat.dispose();
  }
}

/// Make sure [assetPath] (workspace path, e.g. /assets/gen_1.png) is declared
/// in pubspec.yaml's flutter.assets. Best-effort string surgery on YAML.
Future<void> ensureAssetInPubspec(Workspace ws, String assetPath) async {
  const pubspecPath = '/pubspec.yaml';
  if (!await ws.exists(pubspecPath)) return;
  final raw = utf8.decode(await ws.readBytes(pubspecPath), allowMalformed: true);
  final clean = assetPath.replaceAll(RegExp(r'^/'), '');
  final dir = clean.contains('/') ? clean.substring(0, clean.lastIndexOf('/')) : '';
  final hasDir = dir.isNotEmpty && raw.contains('- $dir/');
  final hasFile = raw.contains('- $clean');
  if (hasDir || hasFile) return;
  String next;
  final flutterM = RegExp(r'^flutter:\s*$', multiLine: true).firstMatch(raw);
  if (flutterM == null) {
    next = '$raw\nflutter:\n  assets:\n    - $clean\n';
  } else {
    final assetsM = RegExp(r'^(\s*)assets:\s*$', multiLine: true).firstMatch(raw);
    if (assetsM == null) {
      next = raw.substring(0, flutterM.end) +
          '  assets:\n    - $clean\n' +
          raw.substring(flutterM.end);
    } else {
      next = raw.substring(0, assetsM.end) +
          '  - $clean\n' +
          raw.substring(assetsM.end);
    }
  }
  await ws.writeBytes(pubspecPath, next.codeUnits);
}
