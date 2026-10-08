// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// End-to-end tests for the SOURCE LOCATOR: a captured screen region (rendered
/// text) must reverse-map to the ACTUAL widget that holds its style — so a
/// minor colour/text edit lands straight on the page instead of falling back
/// to the assistant. Covers the three real-world failure modes:
///
///   1. direct `Text('…')`          → anchors to that Text
///   2. parameterised `_W(title:'…')`→ anchors to the Text in _W's BUILD,
///                                     not the (style-less) call site
///   3. a route path rendered as text → must NOT anchor to app_routes.dart
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/exploration/visual_editor/deterministic_edit_ops.dart';
import 'package:nexus_projects_client/features/projects/exploration/visual_editor/region_model.dart';
import 'package:nexus_projects_client/features/projects/exploration/visual_editor/source_locator.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';

/// Minimal in-memory [Workspace] — only [walk] / [readBytes] / [readString] /
/// [exists] are used by [SourceIndex.build]; the rest throw.
class _MemWorkspace implements Workspace {
  _MemWorkspace(this._files);
  final Map<String, String> _files; // wsPath (leading '/') -> content

  @override
  Future<List<FileEntry>> walk({
    String from = '/',
    int maxEntries = 5000,
  }) async {
    return _files.entries
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
  }

  @override
  Future<Uint8List> readBytes(String wsPath) async {
    final c = _files[wsPath];
    if (c == null) throw WorkspaceException('not found: $wsPath');
    return utf8.encode(c);
  }

  @override
  Future<String> readString(String wsPath) async => _files[wsPath]!;

  @override
  Future<bool> exists(String wsPath) async => _files.containsKey(wsPath);

  @override
  Future<FileEntry> stat(String wsPath) async => throw UnimplementedError();
  @override
  Future<List<FileEntry>> list([String wsPath = '/']) async => [];
  @override
  Future<Uint8List> readRange(String wsPath, int o, int l) async =>
      throw UnimplementedError();
  @override
  Future<bool> isProbablyBinary(String wsPath) async => false;
  @override
  Future<FileEntry> writeString(String wsPath, String c) async =>
      throw UnimplementedError();
  @override
  Future<FileEntry> writeBytes(String wsPath, List<int> b) async =>
      throw UnimplementedError();
  @override
  Future<FileEntry> createDirectory(String wsPath) async =>
      throw UnimplementedError();
  @override
  Future<FileEntry> createFile(String wsPath, {bool overwrite = false}) async =>
      throw UnimplementedError();
  @override
  Future<void> delete(String wsPath, {bool recursive = true}) async {}
  @override
  Future<FileEntry> move(String a, String b) async =>
      throw UnimplementedError();
  @override
  Future<FileEntry> copy(String a, String b) async =>
      throw UnimplementedError();
  @override
  Future<({int bytes, int files})> usage() async => (bytes: 0, files: 0);
}

const _routes = '''
final routes = {
  '/lobby': (_) => CasinoLobbyPage(),
};
''';

const _lobby = '''
class CasinoLobbyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Column(children: [
      Text('Featured Games', style: TextStyle(color: Color(0xFFFFD700))),
      _GameTile(title: 'Roulette', icon: Icons.casino),
    ]));
  }
}

class _GameTile extends StatelessWidget {
  final String title;
  final IconData icon;
  const _GameTile({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF222222),
      child: Text(title, style: TextStyle(color: Color(0xFF333333))),
    );
  }
}
''';

const _pageFile = '/lib/features/lobby/casino_lobby.dart';
const _routesFile = '/lib/app_routes.dart';

ScreenRegion _region(String text, {String? route}) => ScreenRegion(
  id: 'test',
  widgetType: 'RenderParagraph',
  rect: const RectBox(0, 0, 100, 20),
  text: text,
  chain: const [],
);

void main() {
  late SourceIndex index;

  setUpAll(() async {
    index = await SourceIndex.build(
      _MemWorkspace({_routesFile: _routes, _pageFile: _lobby}),
    );
  });

  group('source locator anchors on the real styled widget', () {
    test('direct Text(…): anchors to that Text in the page file', () {
      final loc = index.locate('/lobby', _region('Featured Games'));
      expect(loc, isNotNull);
      expect(loc!.$1, _pageFile);
      // The anchor line should be the Text('Featured Games') line.
      final lines = _lobby.split('\n');
      expect(lines[loc.$2 - 1], contains("Text('Featured Games'"));
    });

    test(
      'parameterised _W(title: …): anchors to the Text in the BUILD, not the call site',
      () {
        final loc = index.locate('/lobby', _region('Roulette'));
        expect(loc, isNotNull);
        expect(loc!.$1, _pageFile);
        final lines = _lobby.split('\n');
        // Must be the build's `Text(title, …)` line — NOT the `_GameTile(title: …)`
        // call-site line.
        expect(lines[loc.$2 - 1], contains('Text(title'));
        expect(lines[loc.$2 - 1], isNot(contains('_GameTile(')));
      },
    );

    test(
      'a route path rendered as text does NOT anchor to app_routes.dart',
      () {
        final loc = index.locate('/lobby', _region('/lobby'));
        expect(loc?.$1, isNot(_routesFile));
      },
    );

    test(
      'E2E: direct text → "change to red" lands as a one-line colour swap',
      () {
        final loc = index.locate('/lobby', _region('Featured Games'))!;
        final out = setTextColorEdit(_lobby, anchor: loc.$2, hex: '#FF0000');
        expect(out, isNotNull);
        expect(out, contains('Color(0xFFFF0000)'));
        expect(out, isNot(contains('Color(0xFFFFD700)')));
      },
    );

    test(
      'E2E: parameterised tile → "change to red" lands on the build style',
      () {
        final loc = index.locate('/lobby', _region('Roulette'))!;
        final out = setTextColorEdit(_lobby, anchor: loc.$2, hex: '#FF0000');
        expect(out, isNotNull);
        // The tile's text colour (0xFF333333) is swapped; its background (0xFF222222)
        // is untouched.
        expect(out, contains('Color(0xFFFF0000)'));
        expect(out, isNot(contains('Color(0xFF333333)')));
        expect(out, contains('Color(0xFF222222)'));
      },
    );
  });
}
