// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Deterministic three-way union for PURELY ADDITIVE text changes.
///
/// The orchestrator's dominant real merge conflict is two tasks that each only
/// ADDED lines to the same shared file — e.g. each appends a dependency to
/// `pubspec.yaml`, or an import/registration to a barrel/`main.dart`. The
/// file-level git merge flags these as a conflict (the blob differs on both
/// sides) and hands them to a flaky agent, which is what blocks tasks.
///
/// [additiveThreeWayUnion] resolves exactly that case and ONLY that case: it
/// returns a merge that keeps every [base] line plus every line either side
/// inserted, but ONLY when neither side removed or modified a base line (i.e.
/// [base] is a subsequence of BOTH [ours] and [theirs]). Any other shape — a
/// changed or deleted base line, a reordering, an add/add with no base — returns
/// `null`, so the caller falls back to a real conflict. It therefore never
/// fabricates a blended file for overlapping edits; it can only turn a subset of
/// today's conflicts into the obviously-correct union.
String? additiveThreeWayUnion(String base, String ours, String theirs) {
  if (ours == base) return theirs;
  if (theirs == base) return ours;

  final baseL = base.split('\n');
  final ourIns = _insertionsOverBase(baseL, ours.split('\n'));
  if (ourIns == null) return null; // ours changed/removed a base line
  final theirIns = _insertionsOverBase(baseL, theirs.split('\n'));
  if (theirIns == null) return null; // theirs changed/removed a base line

  final out = <String>[];
  for (var i = 0; i <= baseL.length; i++) {
    final a = ourIns[i] ?? const <String>[];
    final b = theirIns[i] ?? const <String>[];
    out.addAll(a);
    for (final line in b) {
      // Dedup a line BOTH sides inserted at the same spot (e.g. the identical
      // dependency), but keep genuinely different additions from each side.
      if (!a.contains(line)) out.add(line);
    }
    if (i < baseL.length) out.add(baseL[i]);
  }
  return out.join('\n');
}

/// Render a conflicted file the way git does: the agreed content verbatim, with
/// ONLY the divergent region wrapped in standard `<<<<<<< / ======= / >>>>>>>`
/// markers.
///
/// The engine's merge is file-level and, on a conflict, writes nothing — so the
/// merge agent used to be asked to "remove every conflict marker" in a file that
/// had none, with no way to even see the other branch's version. That made real
/// conflicts unresolvable by construction. Writing this into the worktree gives
/// the agent both sides inline, so the documented resolve-and-commit workflow
/// actually works.
///
/// The common leading/trailing lines are trimmed out of the marked block, so a
/// file that differs in one spot marks only that spot rather than the whole file.
String conflictMarkedText(
  String ours,
  String theirs, {
  String oursLabel = 'ours',
  String theirsLabel = 'theirs',
}) {
  final o = ours.split('\n');
  final t = theirs.split('\n');

  var p = 0; // shared prefix length
  while (p < o.length && p < t.length && o[p] == t[p]) {
    p++;
  }
  var s = 0; // shared suffix length (never overlapping the prefix)
  while (s < o.length - p && s < t.length - p && o[o.length - 1 - s] == t[t.length - 1 - s]) {
    s++;
  }

  return [
    ...o.sublist(0, p),
    '<<<<<<< $oursLabel',
    ...o.sublist(p, o.length - s),
    '=======',
    ...t.sublist(p, t.length - s),
    '>>>>>>> $theirsLabel',
    ...o.sublist(o.length - s),
  ].join('\n');
}

/// Map of base-gap-index (0..baseL.length) → the lines [x] inserted at that gap,
/// or `null` if [baseL] is NOT a subsequence of [x] (meaning x changed/removed a
/// base line, not a pure insertion). Gap `i` holds the lines that appear before
/// base line `i`; gap `baseL.length` holds the trailing insertions.
Map<int, List<String>>? _insertionsOverBase(
  List<String> baseL,
  List<String> x,
) {
  final ins = <int, List<String>>{};
  var bi = 0;
  var pending = <String>[];
  for (final line in x) {
    if (bi < baseL.length && line == baseL[bi]) {
      if (pending.isNotEmpty) {
        ins[bi] = pending;
        pending = <String>[];
      }
      bi++;
    } else {
      pending.add(line);
    }
  }
  if (bi != baseL.length) return null; // not all base lines matched in order
  if (pending.isNotEmpty) ins[baseL.length] = pending;
  return ins;
}
