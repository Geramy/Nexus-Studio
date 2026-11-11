// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_projects_client/infrastructure/nextify/nextify_ssh.dart';

void main() {
  group('sshBaseArgs (pure)', () {
    test('includes identity, hardening options, and the user@host', () {
      final args = sshBaseArgs(privPath: '/k/id', host: '1.2.3.4');
      expect(args, containsAllInOrder([
        '-i',
        '/k/id',
        'ubuntu@1.2.3.4',
      ]));
      expect(args, containsAll([
        'BatchMode=yes',
        'StrictHostKeyChecking=no',
        'UserKnownHostsFile=/dev/null',
      ]));
    });

    test('honours a custom user and timeout', () {
      final args =
          sshBaseArgs(privPath: '/k', host: 'h', user: 'ec2-user', timeoutSeconds: 9);
      expect(args.last, 'ec2-user@h');
      expect(args, contains('ConnectTimeout=9'));
    });
    test('exclude host from the base args for scp', () {
      final args = sshBaseArgs(
          privPath: 'priv', host: 'host', includeHost: false);
      expect(args, isNot(contains('user@host')));
      expect(args.first, '-i');
    });
  });

  group('ensureSshKey', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('nexus_ssh_test_');
    });

    tearDown(() async {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('generates an ed25519 keypair and reuses it', () async {
      final a = await ensureSshKey(baseDir: tmp.path);
      expect(File(a.privPath).existsSync(), isTrue);
      expect(File(a.pubPath).existsSync(), isTrue);
      final pub = a.publicKey;
      expect(pub, startsWith('ssh-ed25519 '));
      expect(pub, isNot(contains('\n')));

      final privMtime = File(a.privPath).lastModifiedSync();
      // Second call must NOT regenerate (idempotent).
      final b = await ensureSshKey(baseDir: tmp.path);
      expect(b.privPath, a.privPath);
      expect(File(b.privPath).lastModifiedSync(), privMtime);
    });
  });
}
