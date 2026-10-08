// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Regression tests for `ensureAssetInPubspec` — registering a generated
/// image asset in pubspec.yaml must produce VALID YAML. The bug being guarded
/// against: the old code inserted at `match.end` (right after the `flutter:`
/// token, before the newline), merging the new `assets:` onto the same line as
/// `flutter:` → `flutter:  assets:` → a ScannerError that broke the whole
/// screen-capture harness.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/exploration/visual_editor/code_applier.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';

class _MemWs implements Workspace {
  _MemWs(this._files);
  final Map<String, String> _files;

  @override
  Future<List<FileEntry>> walk({String from = '/', int maxEntries = 5000}) async =>
      _files.entries
          .map(
            (e) => FileEntry(
              name: e.key.substring(e.key.lastIndexOf('/') + 1),
              path: e.key,
              isDirectory: false,
              isLink: false,
              size: e.value.length,
              modified: DateTime(2026),
            ),
          )
          .toList();
  @override
  Future<Uint8List> readBytes(String p) async => utf8.encode(_files[p]!);
  @override
  Future<String> readString(String p) async => _files[p]!;
  @override
  Future<bool> exists(String p) async => _files.containsKey(p);
  @override
  Future<FileEntry> writeBytes(String p, List<int> b) async {
    _files[p] = utf8.decode(b);
    return FileEntry(
      name: p,
      path: p,
      isDirectory: false,
      isLink: false,
      size: b.length,
      modified: DateTime(2026),
    );
  }
  @override
  dynamic noSuchMethod(Invocation i) =>
      super.noSuchMethod(throw UnimplementedError('$i'));
}

/// Parse the flutter: section's keys to assert the YAML is well-formed enough
/// that `flutter:` is on its own line and `assets:` is a sibling of
/// `uses-material-design`.
void _assertWellFormed(String pubspec) {
  expect(
    RegExp(r'^flutter:[ \t]+\S', multiLine: true).hasMatch(pubspec),
    isFalse,
    reason: '`flutter:` must be on its own line (was it merged with assets:?)',
  );
  expect(
    RegExp(r'^flutter:\n', multiLine: true).hasMatch(pubspec),
    isTrue,
    reason: 'expected a clean `flutter:` line',
  );
  final assetsLines =
      pubspec.split('\n').where((l) => l.trim() == 'assets:').length;
  expect(assetsLines, greaterThanOrEqualTo(1), reason: pubspec);
}

void main() {
  const base = '''
name: website_test
description: Scaffold.
publish_to: none
version: 0.1.0+1
environment:
  sdk: ^3.11.5
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.2
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
flutter:
  uses-material-design: true
''';

  test('adds an assets block under flutter: on its own lines (valid YAML)', () async {
    final ws = _MemWs({'/pubspec.yaml': base});
    await ensureAssetInPubspec(ws, '/assets/visual_1.png');
    final out = await ws.readString('/pubspec.yaml');
    _assertWellFormed(out);
    expect(out, contains('  assets:\n    - assets/visual_1.png\n'));
    expect(out, contains('  uses-material-design: true'));
    // assets must sit BETWEEN the flutter: line and uses-material-design.
    expect(
      out.indexOf('  assets:'),
      lessThan(out.indexOf('  uses-material-design')),
    );
  });

  test('appends a new asset to an EXISTING assets: list without breaking it',
      () async {
    final withAssets = base.replaceFirst(
      'flutter:\n  uses-material-design: true',
      'flutter:\n  assets:\n    - assets/existing.png\n  uses-material-design: true',
    );
    final ws = _MemWs({'/pubspec.yaml': withAssets});
    await ensureAssetInPubspec(ws, '/assets/visual_2.png');
    final out = await ws.readString('/pubspec.yaml');
    _assertWellFormed(out);
    expect(out, contains('- assets/existing.png'));
    expect(out, contains('- assets/visual_2.png'));
  });

  test('is idempotent — does not duplicate an already-listed asset', () async {
    final ws = _MemWs({'/pubspec.yaml': base});
    await ensureAssetInPubspec(ws, '/assets/visual_1.png');
    final once = await ws.readString('/pubspec.yaml');
    await ensureAssetInPubspec(ws, '/assets/visual_1.png');
    expect(await ws.readString('/pubspec.yaml'), once);
  });
}
