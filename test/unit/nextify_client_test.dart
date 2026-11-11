// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexus_projects_client/infrastructure/nextify/nextify_client.dart';
import 'package:nexus_projects_client/infrastructure/nextify/nextify_models.dart';

/// A [http.Client] that records the last request and answers [body] (or
/// [status]/[errBody] for error cases).
class Recorder {
  Uri? lastUrl;
  String? lastMethod;
  String? lastBody;
  late final http.Client client;

  Recorder({
    String body = '{}',
    int status = 200,
    String Function(Uri)? responder,
  }) {
    client = MockClient((req) async {
      lastUrl = req.url;
      lastMethod = req.method;
      lastBody = req.body;
      return http.Response(
        responder != null ? responder(req.url) : body,
        status,
        headers: {'content-type': 'application/json'},
      );
    });
  }
}

void main() {
  group('NextifyClient URL building', () {
    test('base path is /v1 and appends the route', () async {
      final r = Recorder();
      final client = NextifyClient('nxt_test', httpClient: r.client);
      await client.me();
      expect(r.lastUrl.toString(), 'https://api.nextifynow.com/v1/me');
    });

    test('query params are appended', () async {
      final r = Recorder();
      final client = NextifyClient('t', httpClient: r.client);
      await client.listInstances(status: 'running');
      expect(r.lastUrl.toString(),
          'https://api.nextifynow.com/v1/instances?status=running');
    });

    test('sends the Bearer token header', () async {
      String? auth;
      final mock = MockClient((req) async {
        auth = req.headers['Authorization'];
        return http.Response('{}', 200);
      });
      final client = NextifyClient('nxt_abc', httpClient: mock);
      await client.me();
      expect(auth, 'Bearer nxt_abc');
    });
  });

  group('NextifyClient parsing', () {
    test('parses an instance list', () async {
      final r = Recorder(
        body: '{"items": [{"id":"a1","name":"web-1","status":"running",'
            '"public_ip":"1.2.3.4","machine_type":"sm1.s1-1",'
            '"region":"us-west-1","image":"ubuntu-24.04",'
            '"labels":{"env":"stg"}}]}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final list = await client.listInstances();
      expect(list, hasLength(1));
      expect(list.first.publicIp, '1.2.3.4');
      expect(list.first.isRunning, isTrue);
      expect(list.first.labels['env'], 'stg');
    });

    test('parses job progress', () async {
      final r = Recorder(
        body: '{"id":"42","type":"instance.create","action":"Create",'
            '"status":"running","progress":{"percent":30,"stage":"Booting"},'
            '"attempts":0,"error":null}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final j = await client.job('42');
      expect(j.status, 'running');
      expect(j.isTerminal, isFalse);
      expect(j.progress?.percent, 30);
      expect(j.progress?.stage, 'Booting');
    });

    test('parses machine pricing', () async {
      final r = Recorder(
        body: '{"items": [{"code":"sm1.s1-1","vcpu":1,"ram_gb":1,'
            '"price_month_cents":630}]}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final m = await client.machines(region: 'us-west-1');
      expect(m.single.code, 'sm1.s1-1');
      expect(m.single.priceLabel, '\$6.30/mo');
    });

    test('create instance echoes name + job_id', () async {
      final r = Recorder(
        body: '{"id":"x9","name":"nexus-14","status":"creating",'
            '"desired_status":"running","job_id":"777"}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final c = await client.createInstance(
        name: 'nexus-14',
        machineType: 'sm1.s1-1',
        region: 'us-west-1',
        image: 'ubuntu-24.04',
        userData: '#!/bin/bash\necho hi\n',
        labels: {'app': 'nexus'},
      );
      expect(c.instance.id, 'x9');
      expect(c.instance.status, 'creating');
      expect(c.jobId, '777');
      expect(r.lastMethod, 'POST');
    });

    test('parses security_group_ids on an instance', () async {
      final r = Recorder(
        body: '{"items": [{"id":"a1","name":"web-1","status":"running",'
            '"security_group_ids":["sg-1","sg-2"]}]}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final inst = (await client.listInstances()).first;
      expect(inst.securityGroupIds, ['sg-1', 'sg-2']);
    });
  });

  group('NextifyClient SSH + security rules', () {
    test('addSshKey POSTs name + public_key and returns the id', () async {
      final r = Recorder(body: '{"id":"key-1","name":"nexus"}');
      final client = NextifyClient('t', httpClient: r.client);
      final id =
          await client.addSshKey(name: 'nexus', publicKey: 'ssh-ed25519 AAAA');
      expect(r.lastMethod, 'POST');
      expect(r.lastUrl.toString(), 'https://api.nextifynow.com/v1/ssh-keys');
      expect(id, 'key-1');
      expect(r.lastBody, contains('ssh-ed25519 AAAA'));
    });

    test('addSecurityGroupRule returns true on 201', () async {
      final r = Recorder(body: '{"id":"rule-1"}', status: 201);
      final client = NextifyClient('t', httpClient: r.client);
      final added = await client.addSecurityGroupRule(
        groupId: 'sg-1',
        protocol: 'tcp',
        portFrom: 80,
        cidr: '0.0.0.0/0',
      );
      expect(added, isTrue);
      expect(r.lastUrl.toString(),
          'https://api.nextifynow.com/v1/security-groups/sg-1/rules');
    });

    test('addSecurityGroupRule returns false on 409 (already present)', () async {
      final r = Recorder(
        body: '{"error":{"code":"duplicate_rule","message":"exists"}}',
        status: 409,
      );
      final client = NextifyClient('t', httpClient: r.client);
      final added = await client.addSecurityGroupRule(
        groupId: 'sg-1',
        protocol: 'tcp',
        portFrom: 80,
        cidr: '0.0.0.0/0',
      );
      expect(added, isFalse);
    });

    test('addSecurityGroupRule rethrows non-409 errors', () async {
      final r = Recorder(
        body: '{"error":{"code":"not_found","message":"no such group"}}',
        status: 404,
      );
      final client = NextifyClient('t', httpClient: r.client);
      await expectLater(
        client.addSecurityGroupRule(
            groupId: 'nope', protocol: 'tcp', portFrom: 80, cidr: '0.0.0.0/0'),
        throwsA(isA<NextifyApiException>().having((e) => e.status, 's', 404)),
      );
    });

    test('defaultSecurityGroup picks the is_default group', () async {
      final r = Recorder(
        body: '{"items":[{"id":"g1","name":"custom","is_default":false},{"id":"g2","name":"default","is_default":true}]}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final g = await client.defaultSecurityGroup();
      expect(g?.id, 'g2');
      expect(g?.isDefault, isTrue);
    });

    test('an instance whose `image` is a nested object still parses (single shape)',
        () {
      final inst = NextifyInstance.fromJson({
        'id': 'i1',
        'name': 'x',
        'status': 'running',
        'public_ip': '1.2.3.4',
        'image': {'slug': 'ubuntu-24.04', 'display_name': 'Ubuntu 24.04 LTS'},
        'security_group_ids': [],
      });
      expect(inst.image, 'ubuntu-24.04');
      expect(inst.securityGroupIds, isEmpty);
    });

    test('an instance whose `image` is a plain string still parses (list shape)',
        () {
      final inst = NextifyInstance.fromJson({
        'id': 'i1',
        'name': 'x',
        'status': 'running',
        'image': 'ubuntu-24.04',
      });
      expect(inst.image, 'ubuntu-24.04');
    });

    test('ensureSshKey reuses an existing key that matches by key material', () async {
      // GET /ssh-keys returns a key whose material matches (comment may differ).
      final r = Recorder(
        body: '{"items":[{"id":"existing-1","name":"old",'
            '"public_key":"ssh-ed25519 AAAAB3NzaC1lZDI1NTE5AAAAIKILLcNHBv hebbi@x"}]}',
      );
      final client = NextifyClient('t', httpClient: r.client);
      final id = await client.ensureSshKey(
        name: 'nexus-studio-deploy',
        publicKey: 'ssh-ed25519 AAAAB3NzaC1lZDI1NTE5AAAAIKILLcNHBv someone@else',
      );
      expect(id, 'existing-1');
      expect(r.lastMethod, 'GET'); // no POST when found
    });

    test('ensureSshKey creates when no key matches', () async {
      final mock = MockClient((req) async {
        if (req.method == 'GET') {
          return http.Response('{"items":[]}', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{"id":"created-9"}', 201,
            headers: {'content-type': 'application/json'});
      });
      final client = NextifyClient('t', httpClient: mock);
      final id = await client.ensureSshKey(
        name: 'nexus-studio-deploy',
        publicKey: 'ssh-ed25519 AAAA-new-key material',
      );
      expect(id, 'created-9');
    });
  });

  group('NextifyClient errors', () {
    test('surfaces a stable error code from the API', () async {
      final r = Recorder(
        body: '{"error":{"code":"unauthorized","message":"bad token"}}',
        status: 401,
      );
      final client = NextifyClient('bad', httpClient: r.client);
      await expectLater(
        client.me(),
        throwsA(
          isA<NextifyApiException>()
              .having((e) => e.code, 'code', 'unauthorized')
              .having((e) => e.status, 'status', 401),
        ),
      );
    });

    test('a 409 quota refusal carries its message', () async {
      final r = Recorder(
        body:
            '{"error":{"code":"quota_exceeded","message":"max_instances exceeded"}}',
        status: 409,
      );
      final client = NextifyClient('t', httpClient: r.client);
      await expectLater(
        client.createInstance(
          name: 'x',
          machineType: 'sm1.s1-1',
          region: 'us-west-1',
          image: 'ubuntu-24.04',
        ),
        throwsA(isA<NextifyApiException>().having((e) => e.status, 's', 409)),
      );
    });
  });
}
