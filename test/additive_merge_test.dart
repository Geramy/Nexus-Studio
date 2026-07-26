// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/additive_merge.dart';

void main() {
  group('additiveThreeWayUnion — resolves purely-additive conflicts', () {
    test('the pubspec case: each side adds a different dependency', () {
      const base = 'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n'
          '  cupertino_icons: ^1.0.8\n';
      const ours = 'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n'
          '  cupertino_icons: ^1.0.8\n'
          '  flame: ^1.18.0\n';
      const theirs = 'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n'
          '  cupertino_icons: ^1.0.8\n'
          '  audioplayers: ^6.0.0\n';
      final merged = additiveThreeWayUnion(base, ours, theirs);
      expect(merged, isNotNull);
      expect(merged, contains('flame: ^1.18.0'));
      expect(merged, contains('audioplayers: ^6.0.0'));
      expect(merged, contains('cupertino_icons: ^1.0.8'));
      // No base line lost.
      expect(merged, contains('    sdk: flutter'));
    });

    test('additions land in their own section (deps vs dev_deps)', () {
      const base = 'dependencies:\n  a: ^1.0.0\n\ndev_dependencies:\n  x: ^1.0.0\n';
      const ours = 'dependencies:\n  a: ^1.0.0\n  b: ^1.0.0\n\ndev_dependencies:\n  x: ^1.0.0\n';
      const theirs = 'dependencies:\n  a: ^1.0.0\n\ndev_dependencies:\n  x: ^1.0.0\n  y: ^1.0.0\n';
      final merged = additiveThreeWayUnion(base, ours, theirs)!;
      final lines = merged.split('\n');
      final depIdx = lines.indexOf('  b: ^1.0.0');
      final devIdx = lines.indexOf('  y: ^1.0.0');
      expect(depIdx, greaterThanOrEqualTo(0));
      expect(devIdx, greaterThan(depIdx));
      // b stays above the dev_dependencies header, y stays below it.
      final devHeader = lines.indexOf('dev_dependencies:');
      expect(depIdx, lessThan(devHeader));
      expect(devIdx, greaterThan(devHeader));
    });

    test('identical addition on both sides is de-duplicated', () {
      const base = 'deps:\n  a\n';
      const ours = 'deps:\n  a\n  shared\n';
      const theirs = 'deps:\n  a\n  shared\n';
      // ours == theirs != base → returns the (identical) added version, once.
      final merged = additiveThreeWayUnion(base, ours, theirs)!;
      expect('shared'.allMatches(merged).length, 1);
    });

    test('one side unchanged returns the other side verbatim', () {
      const base = 'a\nb\n';
      const theirs = 'a\nb\nc\n';
      expect(additiveThreeWayUnion(base, base, theirs), theirs);
      expect(additiveThreeWayUnion(base, theirs, base), theirs);
    });

    test('preserves a trailing newline', () {
      const base = 'a\nb\n';
      const ours = 'a\nb\nc\n';
      const theirs = 'a\nb\nd\n';
      final merged = additiveThreeWayUnion(base, ours, theirs)!;
      expect(merged.endsWith('\n'), isTrue);
      expect(merged, 'a\nb\nc\nd\n');
    });
  });

  group('conflictMarkedText — gives the agent both sides to resolve', () {
    test('marks only the divergent region, keeping shared context verbatim', () {
      const ours = 'class P {\n  int speed = 2;\n  void tick() {}\n}\n';
      const theirs = 'class P {\n  int speed = 5;\n  void tick() {}\n}\n';
      final marked = conflictMarkedText(
        ours,
        theirs,
        oursLabel: 'ours (main)',
        theirsLabel: 'theirs (task/534)',
      );
      final lines = marked.split('\n');
      // Shared context stays OUTSIDE the markers.
      expect(lines.first, 'class P {');
      expect(marked, contains('  void tick() {}'));
      // Both sides' divergent lines are present, inside markers.
      expect(marked, contains('<<<<<<< ours (main)'));
      expect(marked, contains('  int speed = 2;'));
      expect(marked, contains('======='));
      expect(marked, contains('  int speed = 5;'));
      expect(marked, contains('>>>>>>> theirs (task/534)'));
      // The shared trailing context is not duplicated inside the block.
      expect('void tick'.allMatches(marked).length, 1);
    });

    test('a fully-different file marks the whole body', () {
      final marked = conflictMarkedText('one', 'two');
      expect(marked, contains('<<<<<<< ours'));
      expect(marked, contains('one'));
      expect(marked, contains('two'));
      expect(marked, contains('>>>>>>> theirs'));
    });

    test('every marker the prompt tells the agent to remove is present', () {
      final marked = conflictMarkedText('a\nb\n', 'a\nc\n');
      for (final m in ['<<<<<<<', '=======', '>>>>>>>']) {
        expect(marked, contains(m), reason: 'agent is told to remove $m');
      }
    });
  });

  group('additiveThreeWayUnion — refuses non-additive (falls back to conflict)', () {
    test('a modified base line → null', () {
      const base = 'name: app\nversion: 1.0.0\n';
      const ours = 'name: app\nversion: 1.0.1\n'; // changed a base line
      const theirs = 'name: app\nversion: 1.0.0\ndesc: hi\n';
      expect(additiveThreeWayUnion(base, ours, theirs), isNull);
    });

    test('a removed base line → null', () {
      const base = 'a\nb\nc\n';
      const ours = 'a\nc\n'; // removed b
      const theirs = 'a\nb\nc\nd\n';
      expect(additiveThreeWayUnion(base, ours, theirs), isNull);
    });

    test('a reordered base → null', () {
      const base = 'a\nb\n';
      const ours = 'b\na\n';
      const theirs = 'a\nb\nc\n';
      expect(additiveThreeWayUnion(base, ours, theirs), isNull);
    });
  });
}
