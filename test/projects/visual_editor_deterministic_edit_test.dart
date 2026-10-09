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

    test('replaces an existing background image instead of nesting another Stack', () {
      const src = '''
return Scaffold(
  body: Stack(children: [
    Positioned.fill(child: Image.asset('assets/old.png', fit: BoxFit.cover)),
    const Text('content'),
  ]),
);''';
      final anchor = _lineOf(src, 'Scaffold');
      final out = setBackgroundImageEdit(
        src,
        anchor: anchor,
        assetPath: '/assets/new.png',
      );
      expect(out, isNotNull);
      expect(out, contains("Image.asset('assets/new.png'"));
      expect(out, isNot(contains('assets/old.png')));
      // Exactly ONE background image remains — no nested Stack was added.
      final bgCount =
          RegExp(r'Positioned\.fill\(child: Image\.asset').allMatches(out!).length;
      expect(bgCount, 1);
    });

    test('on an already-nested body, replaces the innermost (visible) image', () {
      const src = '''
return Scaffold(
  body: Stack(children: [
    Positioned.fill(child: Image.asset('assets/outer.png', fit: BoxFit.cover)),
    Stack(children: [
      Positioned.fill(child: Image.asset('assets/inner.png', fit: BoxFit.cover)),
      const Text('content'),
    ]),
  ]),
);''';
      final anchor = _lineOf(src, 'Scaffold');
      final out = setBackgroundImageEdit(
        src,
        anchor: anchor,
        assetPath: '/assets/new.png',
      );
      expect(out, isNotNull);
      // The innermost (visible) image is the one swapped; the outer stays.
      expect(out, contains("Image.asset('assets/outer.png'"));
      expect(out, contains("Image.asset('assets/new.png'"));
      expect(out, isNot(contains('assets/inner.png')));
    });
  });

  group('insertImageEdit', () {
    const col = '''
return Column(
  children: [
    const Text('first'),
    const Text('second'),
    const Text('third'),
  ],
);''';

    test('inserts an Image.asset before the anchored item', () {
      final anchor = _lineOf(col, "'second'");
      final out = insertImageEdit(
        col,
        anchor: anchor,
        assetPath: '/assets/visual_9.png',
      );
      expect(out, isNotNull);
      expect(out, contains("Image.asset('assets/visual_9.png', fit: BoxFit.contain)"));
      // The new image sits BEFORE 'second' and AFTER 'first'.
      expect(
        out!.indexOf("Image.asset('assets/visual_9.png"),
        lessThan(out.indexOf("'second'")),
      );
      expect(
        out.indexOf("Image.asset('assets/visual_9.png"),
        greaterThan(out.indexOf("'first'")),
      );
      // Still parses (balanced), all originals retained.
      expect(out, contains("'first'"));
      expect(out, contains("'third'"));
    });

    test('matches the surrounding indentation', () {
      final anchor = _lineOf(col, "'third'");
      final out = insertImageEdit(
        col,
        anchor: anchor,
        assetPath: '/assets/a.png',
      );
      expect(out, isNotNull);
      expect(out, contains("    Image.asset('assets/a.png', fit: BoxFit.contain),"));
    });

    test('declines on a const children list (non-const image would invalidate it)', () {
      const csrc = '''
Column(
  children: const [
    Text('a'),
    Text('b'),
  ],
)''';
      final anchor = _lineOf(csrc, "Text('b')");
      expect(
        insertImageEdit(csrc, anchor: anchor, assetPath: '/assets/a.png'),
        isNull,
      );
    });

    test('declines when the anchor is not in a children list', () {
      const leaf = '''
Widget build(BuildContext context) {
  return const Text('only one');
}''';
      final anchor = _lineOf(leaf, 'Text');
      expect(
        insertImageEdit(leaf, anchor: anchor, assetPath: '/assets/a.png'),
        isNull,
      );
    });

    test('declines on a data list (not a widget children list)', () {
      const dat = '''
final titles = <String>[
  'one',
  'two',
];''';
      final anchor = _lineOf(dat, "'two'");
      expect(
        insertImageEdit(dat, anchor: anchor, assetPath: '/assets/a.png'),
        isNull,
      );
    });
  });

  group('reorderEdit', () {
    const col = '''
return Column(
  children: [
    Tab(text: 'Accounts'),
    Tab(text: 'Items'),
    Tab(text: 'Categories'),
  ],
);''';

    test('moves a single-line item up', () {
      final anchor = _lineOf(col, "Tab(text: 'Items')");
      final out = reorderEdit(col, anchor: anchor, up: true);
      expect(out, isNotNull);
      expect(out!.
          indexOf("Tab(text: 'Items')"),
          lessThan(out.indexOf("Tab(text: 'Accounts')")));
    });

    test('moves a single-line item down', () {
      final anchor = _lineOf(col, "Tab(text: 'Accounts')");
      final out = reorderEdit(col, anchor: anchor, up: false);
      expect(out, isNotNull);
      expect(out!.
          indexOf("Tab(text: 'Accounts')"),
          greaterThan(out.indexOf("Tab(text: 'Items')")));
    });

    test('moves a multi-line item up, keeping it intact', () {
      const src = '''
return Column(
  children: [
    HeaderA(
      title: "Top",
    ),
    BodyB(
      text: "Middle",
    ),
  ],
);''';
      final anchor = _lineOf(src, 'BodyB(');
      final out = reorderEdit(src, anchor: anchor, up: true);
      expect(out, isNotNull);
      // BodyB (with its multi-line body) now precedes HeaderA.
      expect(out!.indexOf('BodyB('), lessThan(out.indexOf('HeaderA(')));
      expect(out, contains('text: "Middle"'));
    });

    test('declines when the item is already at the top', () {
      final anchor = _lineOf(col, "Tab(text: 'Accounts')");
      expect(reorderEdit(col, anchor: anchor, up: true), isNull);
    });

    test('declines when the item is already at the bottom', () {
      final anchor = _lineOf(col, "Tab(text: 'Categories')");
      expect(reorderEdit(col, anchor: anchor, up: false), isNull);
    });

    test('declines on a `for`-loop list (single generated item)', () {
      const src = '''
child: Column(
  children: [
    for (final route in appRoutes.keys)
      ListTile(title: Text(route)),
  ],
),''';
      final anchor = _lineOf(src, 'ListTile');
      expect(reorderEdit(src, anchor: anchor, up: true), isNull);
    });
  });

  group('reorderRouteEdit', () {
    const routes = '''
final Map<String, WidgetBuilder> appRoutes = {
  '/task-1': (_) => A(),
  '/task-2': (_) => B(),
  '/task-3': (_) => C()
};''';

    test('moves a route up', () {
      final out = reorderRouteEdit(routes, '/task-2', true);
      expect(out, isNotNull);
      expect(out!.indexOf("'/task-2'"), lessThan(out.indexOf("'/task-1'")));
    });

    test('moves a route down', () {
      final out = reorderRouteEdit(routes, '/task-1', false);
      expect(out, isNotNull);
      expect(out!.indexOf("'/task-1'"), greaterThan(out.indexOf("'/task-2'")));
    });

    test('keeps the map parseable (trailing commas after swap)', () {
      // Move the last entry (no trailing comma) up; both swapped lines must
      // carry a comma so the map literal stays valid Dart.
      final out = reorderRouteEdit(routes, '/task-3', true);
      expect(out, isNotNull);
      for (final l in out!.split('\n')) {
        if (l.contains("'/task-2'") || l.contains("'/task-3'")) {
          expect(l.trimRight().endsWith(','), isTrue,
              reason: 'entry lost its trailing comma: $l');
        }
      }
    });

    test('declines when already at the top', () {
      expect(reorderRouteEdit(routes, '/task-1', true), isNull);
    });

    test('declines when already at the bottom', () {
      expect(reorderRouteEdit(routes, '/task-3', false), isNull);
    });

    test('declines when the label is not a route path', () {
      expect(reorderRouteEdit(routes, 'task-1', true), isNull);
    });

    test('declines when the route is not present', () {
      expect(reorderRouteEdit(routes, '/nope', true), isNull);
    });
  });

  group('setTextColorEdit on Tab labels', () {
    test('inserts labelColor + unselectedLabelColor when absent', () {
      const src = '''
TabBar(
  tabs: const [
    Tab(text: 'Accounts'),
    Tab(text: 'Items'),
  ],
);''';
      final anchor = _lineOf(src, "Tab(text: 'Items')");
      final out = setTextColorEdit(src, anchor: anchor, hex: '#FF0000');
      expect(out, isNotNull);
      expect(out, contains('labelColor: Color(0xFFFF0000)'));
      expect(out, contains('unselectedLabelColor: Color(0xFFFF0000)'));
    });

    test('replaces an existing labelColor / unselectedLabelColor', () {
      const src = '''
TabBar(
  tabs: const [
    Tab(text: 'A'),
  ],
  labelColor: Colors.indigo,
  unselectedLabelColor: Colors.grey,
);''';
      final anchor = _lineOf(src, "Tab(text: 'A')");
      final out = setTextColorEdit(src, anchor: anchor, hex: '#00FF00');
      expect(out, isNotNull);
      expect(out, contains('labelColor: Color(0xFF00FF00)'));
      expect(out, contains('unselectedLabelColor: Color(0xFF00FF00)'));
      expect(out, isNot(contains('Colors.indigo')));
    });

    test('does NOT treat a plain Text as a tab', () {
      const src = '''
Column(
  children: [
    Text('Hello'),
  ],
);''';
      final anchor = _lineOf(src, "Text('Hello')");
      final out = setTextColorEdit(src, anchor: anchor, hex: '#FF0000');
      expect(out, isNotNull);
      expect(out, isNot(contains('labelColor')));
      expect(out, contains('style: TextStyle(color: Color(0xFFFF0000))'));
    });
  });

  group('setTextColorEdit on data-driven text (Text(item.field))', () {
    const dataLine = "title: 'A'";

    test('recolours a Theme text style via !.copyWith(color:)', () {
      const src = '''
final items = [Item(title: 'A'), Item(title: 'B')];
Widget b(BuildContext c, Item it) => Text(
      it.title,
      style: Theme.of(c).textTheme.titleSmall,
    );''';
      final out = setTextColorEdit(src, anchor: _lineOf(src, dataLine), hex: '#FF0000');
      expect(out, isNotNull);
      expect(
        out,
        contains('titleSmall!.copyWith(color: Color(0xFFFF0000))'),
      );
    });

    test('adds a colour inside a plain TextStyle', () {
      const src = '''
final items = [Item(title: 'A'), Item(title: 'B')];
Widget b(BuildContext c, Item it) => Text(
      it.title,
      style: TextStyle(fontSize: 11),
    );''';
      final out = setTextColorEdit(src, anchor: _lineOf(src, dataLine), hex: '#FF0000');
      expect(out, isNotNull);
      expect(out, contains('color: Color(0xFFFF0000)'));
    });

    test('adds a style when the render Text has none', () {
      const src = '''
final items = [Item(title: 'A'), Item(title: 'B')];
Widget b(BuildContext c, Item it) => Text(it.title);''';
      final out = setTextColorEdit(src, anchor: _lineOf(src, dataLine), hex: '#FF0000');
      expect(out, isNotNull);
      expect(out, contains('style: TextStyle(color: Color(0xFFFF0000))'));
    });

    test('declines when there is no Text(item.field) render site nearby', () {
      // `name` field but the only Text is far away and uses a different field.
      const src = '''
final items = [Item(name: 'A'), Item(name: 'B')];
final pad1 = 1;
final pad2 = 2;
final pad3 = 3;
final pad4 = 4;
final pad5 = 5;
final pad6 = 6;
final pad7 = 7;
Widget b(BuildContext c, Item it) => Text(it.other);''';
      final out =
          setTextColorEdit(src, anchor: _lineOf(src, "name: 'A'"), hex: '#FF0000');
      // No Text(...name) render site, and the only Text is >6 lines away →
      // every phase declines.
      expect(out, isNull);
    });
  });
}
