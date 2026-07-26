// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/project_setup/models/project_tag.dart';
import 'package:nexus_projects_client/features/project_setup/models/tag_category.dart';
import 'package:nexus_projects_client/features/project_setup/stack_resolver.dart';

/// The objectives→features merge is load-bearing: the deterministic resolver
/// derives the whole architecture from the intent tags, and it used to read the
/// (now-retired) `objectives` category. These tests lock in that it reads the
/// UNION — a capability signal drives the stack whether a new project tagged it
/// under `features` or a legacy one under `objectives`.
void main() {
  ProjectTag tag(TagCategory cat, String value) =>
      ProjectTag(category: cat.wire, value: value);

  List<String> frameworksFor(ResolvedStack r) =>
      r.stackTags
          .where((t) => t.knownCategory == TagCategory.frameworks)
          .map((t) => t.value)
          .toList();

  test('a UI feature yields a Flutter/Dart client', () {
    final resolved = const StackResolver().resolve([
      tag(TagCategory.features, 'Customer-facing UI'),
    ]);
    expect(frameworksFor(resolved), contains('Flutter'));
  });

  test('a heavy-computation FEATURE routes the server to native C++/Drogon', () {
    final resolved = const StackResolver().resolve([
      tag(TagCategory.platforms, 'Web'),
      tag(TagCategory.features, 'Heavy computation'),
    ]);
    final fw = frameworksFor(resolved);
    expect(fw, contains('Drogon'));
    expect(fw, isNot(contains('ASP.NET Core')));
  });

  test('the SAME signal under legacy `objectives` still drives the stack', () {
    final resolved = const StackResolver().resolve([
      tag(TagCategory.platforms, 'Web'),
      tag(TagCategory.objectives, 'Heavy computation'),
    ]);
    expect(frameworksFor(resolved), contains('Drogon'));
  });

  test('a plain business app keeps the default C#/ASP.NET server', () {
    final resolved = const StackResolver().resolve([
      tag(TagCategory.platforms, 'Web'),
      tag(TagCategory.features, 'User accounts'),
    ]);
    final fw = frameworksFor(resolved);
    expect(fw, contains('ASP.NET Core'));
    expect(fw, isNot(contains('Drogon')));
  });

  test('memory-safety feature adds the Rust module', () {
    final resolved = const StackResolver().resolve([
      tag(TagCategory.features, 'Memory-safety critical'),
    ]);
    expect(resolved.layers, contains(Layer.module));
    expect(
      resolved.stackTags.any((t) => t.value == 'Rust'),
      isTrue,
    );
  });
}
