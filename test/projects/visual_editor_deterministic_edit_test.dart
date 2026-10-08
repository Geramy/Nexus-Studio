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
  // Keep test stdout quiet — the ops print a decline REASON when they miss.
  editOpsDebug = false;

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

    test(
      'handles .copyWith(color: themeConstant) — the common generated form',
      () {
        const src = '''
style: textTheme.titleMedium?.copyWith(
  color: scheme.onSurface,
  fontWeight: FontWeight.w700,
),
''';
        final anchor = _lineOf(src, 'copyWith');
        final out = setTextColorEdit(src, anchor: anchor, hex: '#FF0000');
        expect(out, isNotNull);
        expect(out, contains('color: Color(0xFFFF0000)'));
        expect(out, isNot(contains('scheme.onSurface')));
      },
    );

    test('replaces a custom theme constant (MyTheme.gold)', () {
      const src = '''
style: textTheme.bodyMedium?.copyWith(
  color: CasinoTheme.gold,
  fontWeight: FontWeight.w500,
),
''';
      final anchor = _lineOf(src, 'copyWith');
      final out = setTextColorEdit(src, anchor: anchor, hex: '#00FF00');
      expect(out, isNotNull);
      expect(out, contains('color: Color(0xFF00FF00)'));
      expect(out, isNot(contains('CasinoTheme.gold')));
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

    test('swaps a .withValues(alpha: …) fill in full', () {
      const src = '''
  Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: CasinoTheme.gold.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(18),
    ),
  )''';
      final anchor = _lineOf(src, 'withValues');
      final out = setBgColorEdit(src, anchor: anchor, hex: '#123456');
      expect(out, isNotNull);
      expect(out, contains('color: Color(0xFF123456)'));
      expect(out, isNot(contains('withValues')));
      // The neighbouring borderRadius is untouched.
      expect(out, contains('borderRadius: BorderRadius.circular(18)'));
    });

    test('does not treat a text-style colour as a background', () {
      const src = '''
Text(
  'Label',
  style: TextStyle(color: Colors.white),
)''';
      final anchor = _lineOf(src, 'TextStyle');
      // The only colour here is a text colour — no box background to paint.
      final out = setBgColorEdit(src, anchor: anchor, hex: '#FF0000');
      expect(out, isNull);
    });
  });

  group('setBackgroundEdit', () {
    test('inserts backgroundColor into a Scaffold that has none', () {
      const src = '''
return Scaffold(
  appBar: AppBar(title: const Text('Home')),
  body: const Center(child: Text('hi')),
);''';
      final anchor = _lineOf(src, 'Scaffold');
      final out = setBackgroundEdit(src, anchor: anchor, hex: '#0A0A1A');
      expect(out, isNotNull);
      expect(out, contains('backgroundColor: Color(0xFF0A0A1A)'));
    });

    test('replaces an existing Scaffold backgroundColor', () {
      const src = '''
return Scaffold(
  backgroundColor: Colors.black,
  body: const Center(child: Text('hi')),
);''';
      final anchor = _lineOf(src, 'Scaffold');
      final out = setBackgroundEdit(src, anchor: anchor, hex: '#123456');
      expect(out, isNotNull);
      expect(out, contains('backgroundColor: Color(0xFF123456)'));
      expect(out, isNot(contains('Colors.black')));
    });
  });

  group('setBackgroundImageEdit', () {
    test('wraps a multi-line body in a Stack with the image behind it', () {
      const src = '''
class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Text('item one'),
            const Text('item two'),
          ],
        ),
      ),
    );
  }
}''';
      final anchor = _lineOf(src, 'Scaffold');
      final out = setBackgroundImageEdit(
        src,
        anchor: anchor,
        assetPath: '/assets/visual_123.png',
      );
      expect(out, isNotNull);
      expect(
        out,
        contains(
          "Image.asset('assets/visual_123.png', fit: BoxFit.cover)",
        ),
      );
      expect(out, contains('Positioned.fill('));
      expect(out, contains('body: Stack(children: ['));
      // original body preserved inside the stack
      expect(out, contains("const Text('item one')"));
      expect(out, contains('SingleChildScrollView('));
    });

    test('keeps a `const` inner body valid', () {
      const src = '''
return Scaffold(
  appBar: AppBar(title: const Text('Home')),
  body: const Center(child: Text('hi')),
);''';
      final anchor = _lineOf(src, 'Scaffold');
      final out = setBackgroundImageEdit(
        src,
        anchor: anchor,
        assetPath: '/assets/bg.jpg',
      );
      expect(out, isNotNull);
      expect(
        out,
        contains("Image.asset('assets/bg.jpg', fit: BoxFit.cover)"),
      );
      expect(out, contains('const Center('));
      expect(out, contains('body: Stack(children: ['));
    });

    test('returns null when there is no Scaffold body to wrap', () {
      const src = '''
return Center(child: Text('no scaffold here'));
''';
      final anchor = _lineOf(src, 'Center');
      final out = setBackgroundImageEdit(
        src,
        anchor: anchor,
        assetPath: '/assets/x.png',
      );
      expect(out, isNull);
    });
  });
}
