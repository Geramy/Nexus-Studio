// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

// Proves the PARALLEL task workflow at the git layer end-to-end: two isolated
// per-task working trees edit different files concurrently, each commits to its
// own branch in the SHARED object/ref DB without clobbering the other, the work
// stays isolated per branch, and both branches merge cleanly to main — exactly
// the path the orchestrator drives when N agents run at once.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/infrastructure/workspace/async_lock.dart';
import 'package:nexus_projects_client/infrastructure/workspace/vhd_workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';

void main() {
  group('parallel per-task git workflow', () {
    late Directory dir;
    setUp(
      () async => dir = await Directory.systemTemp.createTemp('nx-parallel'),
    );
    tearDown(() async => dir.delete(recursive: true));

    test(
      'two isolated tasks commit to their own branches and both merge to main',
      () async {
        final ws = await VhdWorkspace.open('${dir.path}/project.nxtprj');
        final git = await NxtprjGitEngine.open(ws);

        // Scaffold: a base commit on main (what the scaffolder does up front).
        await ws.writeString('/README.md', 'base');
        await git.commitAll(message: 'chore: scaffold');
        expect(await git.branches(), contains('main'));

        // Two isolated per-task working trees (separate .nxtprj files).
        final t1 = await VhdWorkspace.open('${dir.path}/t1.nxtprj');
        final t2 = await VhdWorkspace.open('${dir.path}/t2.nxtprj');

        // Root each task branch on main and hydrate its tree (orchestrator setup).
        await git.createBranchAt('task/1', base: 'main');
        await git.createBranchAt('task/2', base: 'main');
        await git.materializeInto('task/1', t1);
        await git.materializeInto('task/2', t2);
        expect(await t1.readString('/README.md'), 'base');
        expect(await t2.readString('/README.md'), 'base');

        // Two agents edit DIFFERENT files at the same time (interleaved).
        await Future.wait([
          t1.writeString('/lib/a.dart', 'class A {}'),
          t2.writeString('/lib/b.dart', 'class B {}'),
        ]);

        // Each commits its own tree onto its own branch (what git_commit does in
        // isolated-task mode) — concurrently, no HEAD contention.
        await Future.wait([
          git.commitFrom(t1, branch: 'task/1', message: 'feat: A'),
          git.commitFrom(t2, branch: 'task/2', message: 'feat: B'),
        ]);

        // ISOLATION: task/1 has a.dart and not b.dart; task/2 the reverse.
        final v1 = await VhdWorkspace.open('${dir.path}/v1.nxtprj');
        final v2 = await VhdWorkspace.open('${dir.path}/v2.nxtprj');
        await git.materializeInto('task/1', v1);
        await git.materializeInto('task/2', v2);
        expect(await v1.exists('/lib/a.dart'), isTrue);
        expect(await v1.exists('/lib/b.dart'), isFalse);
        expect(await v2.exists('/lib/b.dart'), isTrue);
        expect(await v2.exists('/lib/a.dart'), isFalse);

        // MERGE both task branches into main (deterministic, non-overlapping).
        await git.checkoutBranch('main');
        final m1 = await git.merge('task/1');
        final m2 = await git.merge('task/2');
        expect(m1.outcome, isNot(MergeOutcome.conflicts));
        expect(m2.outcome, isNot(MergeOutcome.conflicts));

        // main now contains BOTH agents' work plus the scaffold.
        final mainTree = await VhdWorkspace.open('${dir.path}/main.nxtprj');
        await git.materializeInto('main', mainTree);
        expect(await mainTree.exists('/lib/a.dart'), isTrue);
        expect(await mainTree.exists('/lib/b.dart'), isTrue);
        expect(await mainTree.exists('/README.md'), isTrue);
        expect(await mainTree.readString('/lib/a.dart'), 'class A {}');
        expect(await mainTree.readString('/lib/b.dart'), 'class B {}');

        git.dispose();
        for (final w in [ws, t1, t2, v1, v2, mainTree]) {
          w.dispose();
        }
      },
    );

    test(
      'additive edits to a shared file (pubspec deps) auto-merge as a union',
      () async {
        final ws = await VhdWorkspace.open('${dir.path}/pu.nxtprj');
        final git = await NxtprjGitEngine.open(ws);
        await ws.writeString(
          '/pubspec.yaml',
          'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n',
        );
        await git.commitAll(message: 'base');

        final t1 = await VhdWorkspace.open('${dir.path}/pu1.nxtprj');
        final t2 = await VhdWorkspace.open('${dir.path}/pu2.nxtprj');
        await git.createBranchAt('task/1', base: 'main');
        await git.createBranchAt('task/2', base: 'main');
        await git.materializeInto('task/1', t1);
        await git.materializeInto('task/2', t2);

        // Each task appends a DIFFERENT dependency — the dominant real conflict
        // that used to block the orchestrator's merge lane.
        await t1.writeString(
          '/pubspec.yaml',
          'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n  flame: ^1.18.0\n',
        );
        await t2.writeString(
          '/pubspec.yaml',
          'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n  audioplayers: ^6.0.0\n',
        );
        await git.commitFrom(t1, branch: 'task/1', message: 'a');
        await git.commitFrom(t2, branch: 'task/2', message: 'b');

        await git.checkoutBranch('main');
        final m1 = await git.merge('task/1'); // fast-forward
        expect(m1.outcome, isNot(MergeOutcome.conflicts));
        final m2 = await git.merge('task/2'); // additive union — NOT a conflict
        expect(
          m2.outcome,
          isNot(MergeOutcome.conflicts),
          reason: 'additive dependency additions should union-merge, not block',
        );

        final mainTree = await VhdWorkspace.open('${dir.path}/pumain.nxtprj');
        await git.materializeInto('main', mainTree);
        final pubspec = await mainTree.readString('/pubspec.yaml');
        expect(pubspec, contains('flame: ^1.18.0'));
        expect(pubspec, contains('audioplayers: ^6.0.0'));
        expect(pubspec, contains('sdk: flutter'));

        git.dispose();
        for (final w in [ws, t1, t2, mainTree]) {
          w.dispose();
        }
      },
    );

    test('a real merge conflict is reported (not silently merged)', () async {
      final ws = await VhdWorkspace.open('${dir.path}/p.nxtprj');
      final git = await NxtprjGitEngine.open(ws);
      await ws.writeString('/shared.txt', 'original');
      await git.commitAll(message: 'base');

      final t1 = await VhdWorkspace.open('${dir.path}/c1.nxtprj');
      final t2 = await VhdWorkspace.open('${dir.path}/c2.nxtprj');
      await git.createBranchAt('task/1', base: 'main');
      await git.createBranchAt('task/2', base: 'main');
      await git.materializeInto('task/1', t1);
      await git.materializeInto('task/2', t2);

      // Both change the SAME file differently → conflict.
      await t1.writeString('/shared.txt', 'one');
      await t2.writeString('/shared.txt', 'two');
      await git.commitFrom(t1, branch: 'task/1', message: 'a');
      await git.commitFrom(t2, branch: 'task/2', message: 'b');

      await git.checkoutBranch('main');
      final m1 = await git.merge('task/1'); // clean (main unchanged)
      expect(m1.outcome, isNot(MergeOutcome.conflicts));
      final m2 = await git.merge('task/2'); // same file, diverged → conflict
      expect(m2.outcome, MergeOutcome.conflicts);
      expect(m2.conflicts.any((c) => c.endsWith('shared.txt')), isTrue);

      git.dispose();
      for (final w in [ws, t1, t2]) {
        w.dispose();
      }
    });
  });

  group('AsyncLock', () {
    test(
      'serializes callbacks in call order even when started together',
      () async {
        final lock = AsyncLock();
        final order = <int>[];
        Future<void> job(int i, int delayMs) => lock.run(() async {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          order.add(i);
        });
        // Start three out of order by delay; the lock must run them in call order.
        await Future.wait([job(1, 30), job(2, 5), job(3, 1)]);
        expect(order, [1, 2, 3]);
      },
    );

    test('a throwing job releases the lane for the next', () async {
      final lock = AsyncLock();
      await expectLater(
        lock.run(() async => throw StateError('boom')),
        throwsStateError,
      );
      final r = await lock.run(() async => 42);
      expect(r, 42);
    });
  });
}
