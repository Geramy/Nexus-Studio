// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Unit tests for the deterministic visual-edit ops, run against realistic
/// generated source snippets (the exact shapes the build pipeline emits:
/// `const Text(...)`, `const Color(...)`, repeated colours, etc.).
///
/// These guard the "semi-real-time, no AI" path: a colour/text/offset change
/// must land as a surgical one-line edit at the RIGHT occurrence, and when the
/// pattern is ambiguous the op must return null (→ agent) rather than guess.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/exploration/visual_editor/deterministic_edit_ops.dart';

/// 1-based line of the first occurrence of [needle] in [content].
int _lineOf(String content, String needle) {
  final idx = content.indexOf(needle);
  expect(idx, greaterThanOrEqualTo(0), reason: 'needle not found: $needle');
  return content.substring(0, idx).split('\n').length;
}

void main() {
  group('setTextEdit', () {
    const src = '''
    Widget build(BuildContext context) {
      return Column(
        children: [
          const Text(
            'Welcome to the Marketplace',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Buy and sell items from anyone, anywhere.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      );
    }
''';
    test('rewrites only the anchored Text string', () {
      final anchor = _lineOf(src, 'Buy and sell items');
      final out = setTextEdit(
        src,
        anchor: anchor,
        currentText: 'Buy and sell items from anyone, anywhere.',
        newText: 'Buy and sell globally',
      );
      expect(out, isNotNull);
      expect(out, contains("'Buy and sell globally'"));
      expect(out, isNot(contains('anyone, anywhere')));
      // The sibling Text is untouched.
      expect(out, contains("'Welcome to the Marketplace'"));
    });
  });

  group('setTextColorEdit', () {
    test('inserts colour into a TextStyle that has none', () {
      const src =
          'style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),';
      final anchor = _lineOf(src, 'TextStyle');
      final out = setTextColorEdit(src, anchor: anchor, hex: '#0064D2');
      expect(out, isNotNull);
      expect(out, contains('color: Color(0xFF0064D2)'));
      expect(out, contains('fontSize: 28'));
    });

    test('replaces the existing colour in the anchored TextStyle', () {
      const src = 'style: TextStyle(fontSize: 16, color: Colors.grey),';
      final anchor = _lineOf(src, 'TextStyle');
      final out = setTextColorEdit(src, anchor: anchor, hex: '#0064D2');
      expect(out, isNotNull);
      expect(out, contains('color: Color(0xFF0064D2)'));
      expect(out, isNot(contains('Colors.grey')));
    });
  });

  group('setBgColorEdit', () {
    test('swaps the anchored backgroundColor, leaving const in place', () {
      const src = '''
      AppBar(
        title: const Text('Marketplace'),
        backgroundColor: const Color(0xFF0064D2),
      )
''';
      final anchor = _lineOf(src, 'backgroundColor');
      final out = setBgColorEdit(src, anchor: anchor, hex: '#FF0000');
      expect(out, isNotNull);
      expect(out, contains('backgroundColor: const Color(0xFFFF0000)'));
    });

    test('targets the nearest colour to the anchor, not a repeated one', () {
      const src = '''
      Container(color: Color(0xFF0064D2)),
      SizedBox(height: 100),
      Container(color: Color(0xFF112233)),
''';
      // Anchor the SECOND box.
      final anchor = _lineOf(src, '112233');
      final out = setBgColorEdit(src, anchor: anchor, hex: '#FF0000');
      expect(out, isNotNull);
      // The second (anchored) box changed…
      expect(out, contains('Container(color: Color(0xFFFF0000))'));
      // …and the first box kept its colour.
      expect(out, contains('Container(color: Color(0xFF0064D2))'));
    });

    test('returns null when no background colour is near the anchor', () {
      const src = 'Row(\n  children: const [Icon(Icons.add)],\n)';
      final out = setBgColorEdit(src, anchor: 2, hex: '#FF0000');
      expect(out, isNull);
    });
  });
}
