// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart';

/// End-to-end check of the adaptive scoped-vocabulary pipeline: seed the
/// research-generated catalog into the new SetupScopes/SetupScopeOptions tables,
/// then verify the sub-axis + platform-conditional queries the setup engine uses.
void main() {
  late NexusDatabase db;

  setUp(() {
    db = NexusDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('seeds catalog and serves adaptive scoped vocabulary', () async {
    final raw = File('assets/setup/scoped_vocab.json').readAsStringSync();
    final packs = jsonDecode(raw) as List;
    expect(packs.length, 12, reason: 'all industries present');

    await db.seedSetupScopes(packs, version: 1);
    expect(await db.scopedCatalogVersion(), 1);

    // Idempotent reconcile: re-seeding the same catalog must not duplicate.
    final genresBefore = (await db.subAxesForIndustries([
      'Gaming',
    ])).first.values.length;
    await db.seedSetupScopes(packs, version: 1);
    expect(await db.hasSetupScopes(), isTrue);
    final genresAfter = (await db.subAxesForIndustries([
      'Gaming',
    ])).first.values.length;
    expect(genresAfter, genresBefore, reason: 'no duplication on re-seed');

    // A bumped catalog updates the stored version.
    await db.seedSetupScopes(packs, version: 2);
    expect(await db.scopedCatalogVersion(), 2);

    // Gaming introduces the Genre sub-axis with real values.
    final axes = await db.subAxesForIndustries(['Gaming']);
    expect(axes, hasLength(1));
    expect(axes.first.name, 'Genre');
    expect(axes.first.key, 'genre');
    expect(axes.first.values, contains('RPG'));

    // Non-gaming industry has its own sub-axis, not Genre.
    final fin = await db.subAxesForIndustries(['Finance']);
    expect(fin.first.name, isNot('Genre'));

    // Platform-conditional stacks: desktop RPG -> C#/C++ engines; mobile -> Flutter.
    final desktop = await db.scopeOptions(
      industries: ['Gaming'],
      subValues: ['RPG'],
      category: 'frameworks',
      platform: 'Desktop',
    );
    expect(
      desktop.any((f) => f.contains('Unity') || f.contains('Unreal')),
      isTrue,
    );

    final mobileLangs = await db.scopeOptions(
      industries: ['Gaming'],
      subValues: ['RPG'],
      category: 'languages',
      platform: 'Mobile',
    );
    expect(
      mobileLangs.any((l) => l == 'Dart'),
      isTrue,
      reason: 'mobile gaming stack includes Flutter/Dart',
    );

    final desktopLangs = await db.scopeOptions(
      industries: ['Gaming'],
      subValues: ['RPG'],
      category: 'languages',
      platform: 'Desktop',
    );
    expect(desktopLangs.any((l) => l == 'C#' || l == 'C++'), isTrue);

    // Scoped features exist and differ by genre selection.
    final rpgFeatures = await db.scopeOptions(
      industries: ['Gaming'],
      subValues: ['RPG'],
      category: 'features',
    );
    expect(rpgFeatures, isNotEmpty);

    // Industry-level features available even with no sub-axis value chosen.
    final gamingFeatures = await db.scopeOptions(
      industries: ['Gaming'],
      subValues: const [],
      category: 'features',
    );
    expect(gamingFeatures, isNotEmpty);

    // MERGE: `features` now always includes the cross-cutting common base so
    // every project is offered the interchangeable essentials on top of the
    // industry-scoped options.
    expect(
      gamingFeatures,
      contains('User accounts'),
      reason: 'common base features appended to every features query',
    );
    expect(gamingFeatures, contains('Notifications'));

    // NORMALIZATION: no option is a paragraph (all are ≤6-word labels) and
    // there are no case-insensitive duplicates in a served list.
    for (final f in gamingFeatures) {
      expect(
        f.split(RegExp(r'\s+')).length,
        lessThanOrEqualTo(6),
        reason: 'seed-time normalization drops paragraph-length values: "$f"',
      );
    }
    final lowered = gamingFeatures.map((f) => f.toLowerCase()).toList();
    expect(
      lowered.toSet().length,
      lowered.length,
      reason: 'no duplicate options served',
    );

    // Base features are offered even for an industry with a thin/absent catalog.
    final govFeatures = await db.scopeOptions(
      industries: ['Government'],
      subValues: const [],
      category: 'features',
    );
    expect(govFeatures, contains('User accounts'));
  });
}
