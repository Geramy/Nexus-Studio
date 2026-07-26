// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../infrastructure/database/nexus_database.dart' as db_lib;
import '../models/project_tag.dart';

/// Maps a Drift [ProjectTag] row → the UI model. The category is kept as the
/// raw section key (a setup-flow stage key) so non-software flows (IVR) round-
/// trip; software consumers use [ProjectTag.knownCategory].
ProjectTag _fromRow(db_lib.ProjectTag row) {
  return ProjectTag(
    tagPk: row.tag_pk,
    category: row.category,
    value: row.value,
    source: TagSourceX.fromWire(row.source),
    origin: row.origin,
    status: TagStatusX.fromWire(row.status),
    layerKey: row.layerKey,
    forLanguage: row.forLanguage,
    rationale: row.rationale,
    sourceUrl: row.sourceUrl,
    verdict: row.verdict,
    verifiedAt: row.verifiedAt,
  );
}

/// Live project row — used to gate on `setupStatus` and show the summary.
final projectRowProvider = StreamProvider.family<db_lib.Project?, int>((
  ref,
  projectPk,
) {
  return ref.watch(nexusDatabaseProvider).watchProject(projectPk);
});

/// Live tag profile for a project, mapped to UI models. Backed by the
/// ProjectTags table so edits persist and reopening the board is instant.
final projectTagsProvider = StreamProvider.family<List<ProjectTag>, int>((
  ref,
  projectPk,
) {
  final db = ref.watch(nexusDatabaseProvider);
  return db
      .watchTagsForProject(projectPk)
      .map((rows) => rows.map(_fromRow).whereType<ProjectTag>().toList());
});

/// The adaptive scoping derived from a project's currently-selected industries:
/// the sub-axis sections to surface (e.g. Gaming → "Genre" with its values) and
/// scoped suggestion overrides for features/libraries. Drives the
/// board so genres + industry-tailored vocab appear the moment an industry is
/// picked — independent of whether the AI host calls the scope tools.
class ScopedBoard {
  const ScopedBoard({required this.subAxes, required this.scoped});
  final List<({String name, String key, List<String> values})> subAxes;
  final Map<String, List<String>> scoped; // category → scoped suggestions
  static const ScopedBoard empty = ScopedBoard(subAxes: [], scoped: {});
}

final scopedBoardProvider = FutureProvider.family<ScopedBoard, int>((
  ref,
  projectPk,
) async {
  final db = ref.watch(nexusDatabaseProvider);
  final tags = await ref.watch(projectTagsProvider(projectPk).future);
  final industries = tags
      .where((t) => t.category == 'industries' && !t.isRejected)
      .map((t) => t.value)
      .toList();
  if (industries.isEmpty) return ScopedBoard.empty;

  final axes = await db.subAxesForIndustries(industries);
  final subValues = <String>[];
  for (final a in axes) {
    subValues.addAll(
      tags
          .where((t) => t.category == a.key && !t.isRejected)
          .map((t) => t.value),
    );
  }
  final scoped = <String, List<String>>{};
  // `features` already unions the legacy objectives rows + the common base
  // inside db.scopeOptions, so we no longer fetch `objectives` separately.
  for (final cat in const ['features', 'libraries']) {
    final v = await db.scopeOptions(
      industries: industries,
      subValues: subValues,
      category: cat,
    );
    if (v.isNotEmpty) scoped[cat] = v;
  }
  return ScopedBoard(subAxes: axes, scoped: scoped);
});

/// Tags for one section (by raw category key), excluding rejected.
final tagsForCategoryProvider =
    Provider.family<List<ProjectTag>, ({int projectPk, String category})>((
      ref,
      args,
    ) {
      final all =
          ref.watch(projectTagsProvider(args.projectPk)).value ?? [];
      return all
          .where((t) => t.category == args.category && !t.isRejected)
          .toList();
    });

/// Write-side controller: all mutations go through the DB DAOs.
class TagController {
  TagController(this._db, this._projectPk);

  final db_lib.NexusDatabase _db;
  final int _projectPk;

  /// Insert or update a tag (dedups on project+category+value). Returns its pk.
  Future<int> upsert(ProjectTag tag) {
    return _db.upsertTag(
      db_lib.ProjectTagsCompanion(
        project_fk: Value(_projectPk),
        category: Value(tag.category),
        value: Value(tag.value),
        source: Value(tag.source.wire),
        origin: Value(tag.origin),
        status: Value(tag.status.wire),
        layerKey: Value(tag.layerKey),
        forLanguage: Value(tag.forLanguage),
        rationale: Value(tag.rationale),
        sourceUrl: Value(tag.sourceUrl),
        verdict: Value(tag.verdict),
        verifiedAt: Value(tag.verifiedAt),
      ),
    );
  }

  /// Manual add from the "+ Add" picker; user-sourced and immediately accepted.
  Future<int> addManual({
    required String category,
    required String value,
    String? layerKey,
  }) {
    return upsert(
      ProjectTag(
        category: category,
        value: value.trim(),
        source: TagSource.user,
        origin: 'setup',
        status: TagStatus.accepted,
        layerKey: layerKey,
      ),
    );
  }

  Future<void> accept(int tagPk) =>
      _db.setTagStatus(tagPk, TagStatus.accepted.wire);
  Future<void> reject(int tagPk) =>
      _db.setTagStatus(tagPk, TagStatus.rejected.wire);
  Future<void> reset(int tagPk) =>
      _db.setTagStatus(tagPk, TagStatus.proposed.wire);
  Future<void> remove(int tagPk) => _db.deleteTag(tagPk);
}

final tagControllerProvider = Provider.family<TagController, int>((
  ref,
  projectPk,
) {
  return TagController(ref.watch(nexusDatabaseProvider), projectPk);
});
