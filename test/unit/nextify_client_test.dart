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
  late final http.Client client;

  Recorder({
    String body = '{}',
    int status = 200,
    String Function(Uri)? responder,
  }) {
    client = MockClient((req) async {
      lastUrl = req.url;
      lastMethod = req.method;
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
