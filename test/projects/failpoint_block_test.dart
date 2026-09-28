// Regression test: the failpoint extractor must surface the ROOT-CAUSE
// exception box, not only the nearest (surface-symptom) one.
//
// Observed (project 3, 9 wasted fix rounds): a widget test failed because
// main.dart set BOTH `home:` and a `'/'` routes entry. Flutter logs the
// root-cause box (WIDGETS LIBRARY assertion) FIRST and the matcher symptom
// (TEST FRAMEWORK: Found 0 widgets) LAST, just before the [E] line. The
// old nearest-box-only extraction handed the fixer only "Found 0 widgets
// with text 'Casino Royale'" — so it read the (correct) start-screen file
// every round, edited nothing, and never saw main.dart's home+routes clash.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/orchestration/project_orchestrator.dart';

void main() {
  // A realistic slice of `flutter test` output: root-cause box, then the
  // matcher-symptom box, then the [E] summary line with its Expected/Actual.
  final lines = <String>[
    '══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞══════════════════════════════',
    'The following assertion was thrown building MaterialApp(dirty):',
    'If the home property is specified, the routes table cannot include an '
        'entry for "/", since it would',
    'be redundant.',
    "'package:flutter/src/widgets/app.dart':",
    "Failed assertion: line 379 pos 10: 'home == null || "
        "!routes.containsKey(Navigator.defaultRouteName)'",
    '',
    'The relevant error-causing widget was',
    'MaterialApp MaterialApp:file:///app/lib/main.dart:16:12',
    '═══════════════════════════════════════════════════════════════════════',
    '',
    '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══════════════════════',
    'The following TestFailure was thrown running a test:',
    'Expected: exactly one matching candidate',
    '  Actual: _TextWidgetFinder:<Found 0 widgets with text "Casino '
        'Royale": []>',
    "   Which: means none were found but one was expected",
    '',
    'When the exception was thrown, this was the stack:',
    '#4      main.<anonymous closure> (file:///app/test/widget_test.dart:22:5)',
    'This was caught by the test expectation on the following line:',
    '  file:///app/test/widget_test.dart line 22',
    '═══════════════════════════════════════════════════════════════════════',
    '00:00 +1 -1: /app/test/widget_test.dart: generated project shell loads [E]',
    '  Test failed. See exception logs above.',
  ];
  final eIndex = lines.indexWhere((l) => l.contains('[E]'));

  test('includes the root-cause box, not just the nearest symptom box', () {
    final block = ProjectOrchestrator.testFailureBlock(lines, eIndex);

    // Surface symptom (nearest box — worked before, must still work).
    expect(
      block,
      contains('Found 0 widgets with text "Casino Royale"'),
      reason: 'nearest exception box message',
    );
    // Root cause (earlier box — the regression).
    expect(
      block,
      contains('If the home property is specified'),
      reason: 'root-cause assertion from the earlier WIDGETS LIBRARY box',
    );
    // Root cause reported BEFORE the surface symptom (log order).
    expect(
      block.indexOf('If the home property is specified'),
      lessThan(block.indexOf('Found 0 widgets')),
      reason: 'boxes must be emitted in log order (root cause first)',
    );
  });

  test('still captures the [E] header and indented Expected/Actual context',
      () {
    final block = ProjectOrchestrator.testFailureBlock(lines, eIndex);
    expect(block, startsWith('FAILING TEST:'));
    expect(block, contains('generated project shell loads [E]'));
  });

  test('single-box failures behave as before', () {
    final single = <String>[
      '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══════════════════════',
      'The following TestFailure was thrown running a test:',
      'Expected: <True>',
      '  Actual: <False>',
      '═══════════════════════════════════════════════════════════════════════',
      '00:01 +0 -1: /app/test/x_test.dart: it works [E]',
    ];
    final i = single.indexWhere((l) => l.contains('[E]'));
    final block = ProjectOrchestrator.testFailureBlock(single, i);
    expect(block, contains('Expected: <True>'));
    expect(block, contains('Actual: <False>'));
  });
}
