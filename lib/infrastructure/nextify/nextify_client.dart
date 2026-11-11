// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nextify_models.dart';

/// A minimal client for the Nextify cloud-hosting REST API
/// (`https://api.nextifynow.com/v1`).
///
/// JSON-over-HTTPS, `Authorization: Bearer <token>` on every request. Async
/// mutations (create/delete/start/stop) return a `job_id`; use [job] or
/// [waitForJob] to follow them.
class NextifyClient {
  NextifyClient(this.token, {Uri? baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _base = baseUrl ?? Uri.https('api.nextifynow.com', 'v1');

  final String token;
  final Uri _base;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final base = _base.toString().replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p')
        .replace(queryParameters: query.isEmpty ? null : query);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Parse a JSON body, returning null when it is not a JSON object.
  Map<String, dynamic>? _json(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final d = jsonDecode(body);
      return d is Map ? d.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// Decode a response; on non-2xx surface the API's stable error code +
  /// message as a [NextifyApiException].
  Future<Map<String, dynamic>> _decode(http.Response res) async {
    final body = res.body;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var code = 'http_${res.statusCode}';
      var message = body.isNotEmpty ? body : (res.reasonPhrase ?? '');
      final j = _json(body);
      final err = j?['error'];
      if (err is Map) {
        code = err['code']?.toString() ?? code;
        message = err['message']?.toString() ?? message;
      }
      throw NextifyApiException(res.statusCode, code, message);
    }
    return _json(body) ?? const {};
  }

  // ── Account ─────────────────────────────────────────────────────────────
  /// `GET /me` — who this token is. Cheap; good for "test connection".
  Future<NextifyAccount> me() async {
    final res = await _http.get(_uri('/me'), headers: _headers);
    return NextifyAccount.fromJson(await _decode(res));
  }

  /// `GET /limits` — current instance quota, as a short human string.
  Future<String> limitsSummary() async {
    final res = await _http.get(_uri('/limits'), headers: _headers);
    final j = await _decode(res);
    final limits = (j['limits'] as List?) ?? const [];
    for (final l in limits) {
      final m = l as Map;
      if (m['key'] == 'max_instances') {
        return 'instances ${m['used']}/${m['effective']} (of '
            '${m['default']})';
      }
    }
    return 'n/a';
  }

  // ── Catalog ─────────────────────────────────────────────────────────────
  Future<List<String>> regions() async {
    final res = await _http.get(_uri('/regions'), headers: _headers);
    final j = await _decode(res);
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => (e['code'] as String?) ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
  }

  Future<List<NextifyMachine>> machines({String? region}) async {
    final q = region == null ? <String, String>{} : {'region': region};
    final res = await _http.get(_uri('/machines', q), headers: _headers);
    final j = await _decode(res);
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => NextifyMachine.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<String>> images({String? region, String? machineType}) async {
    final q = <String, String>{};
    if (region != null) q['region'] = region;
    if (machineType != null) q['machine_type'] = machineType;
    final res = await _http.get(_uri('/images', q), headers: _headers);
    final j = await _decode(res);
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => (e['slug'] as String?) ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
  }

  Future<List<NextifyApp>> apps() async {
    final res = await _http.get(_uri('/apps'), headers: _headers);
    final j = await _decode(res);
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => NextifyApp.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ── Instances ───────────────────────────────────────────────────────────
  Future<List<NextifyInstance>> listInstances({String? status}) async {
    final q = <String, String>{};
    if (status != null) q['status'] = status;
    final res = await _http.get(_uri('/instances', q), headers: _headers);
    final j = await _decode(res);
    return ((j['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => NextifyInstance.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<NextifyInstance> getInstance(String id) async {
    final res = await _http.get(_uri('/instances/$id'), headers: _headers);
    return NextifyInstance.fromJson(await _decode(res));
  }

  /// Create an instance. [env] entries marked secret are stored encrypted and
  /// never returned by the API. [userData] is a `#!` startup script (≤64 KiB)
  /// that runs once at first boot as root. Returns the transitional instance +
  /// the [NextifyInstanceCreate.jobId] to follow.
  Future<NextifyInstanceCreate> createInstance({
    required String name,
    required String machineType,
    required String region,
    required String image,
    List<String> sshKeyIds = const [],
    String? userData,
    List<Map<String, dynamic>> env = const [],
    Map<String, String> labels = const {},
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'machine_type': machineType,
      'region': region,
      'image': image,
      if (sshKeyIds.isNotEmpty) 'ssh_key_ids': sshKeyIds,
      if (userData != null) 'user_data': userData,
      if (env.isNotEmpty) 'env': env,
      if (labels.isNotEmpty) 'labels': labels,
    };
    final res = await _http.post(
      _uri('/instances'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return NextifyInstanceCreate.fromJson(await _decode(res));
  }

  /// Power on/off: `PATCH /instances/{id}` with `desired_status`.
  Future<String> setDesiredStatus(String id, String desiredStatus) async {
    final res = await _http.patch(
      _uri('/instances/$id'),
      headers: _headers,
      body: jsonEncode({'desired_status': desiredStatus}),
    );
    final j = await _decode(res);
    return (j['job_id'] as String?) ?? '';
  }

  /// Delete (billing stops on delete). Returns the job id to follow.
  Future<String> deleteInstance(String id) async {
    final res = await _http.delete(_uri('/instances/$id'), headers: _headers);
    final j = await _decode(res);
    return (j['job_id'] as String?) ?? '';
  }

  /// The startup script's output — useful to see why a first-boot deploy
  /// failed. The response shape isn't fully documented, so accept the common
  /// wrappers.
  Future<String> setupLog(String id) async {
    final res = await _http.get(
      _uri('/instances/$id/setup-log'),
      headers: _headers,
    );
    final j = await _decode(res);
    for (final k in const ['log', 'output', 'stdout', 'text']) {
      final v = j[k];
      if (v is String) return v;
    }
    return '';
  }

  // ── SSH keys + security groups (for the direct-push / Option-B deploy) ──
  /// `GET /security-groups` — the account's security groups. Blank instances
  /// inherit the default one, so [defaultSecurityGroup] finds it.
  Future<List<NextifySecurityGroup>> listSecurityGroups() async {
    final res = await _http.get(_uri('/security-groups'), headers: _headers);
    final j = await _decode(res);
    final items = (j['items'] is List) ? (j['items'] as List) : const [];
    return items
        .whereType<Map>()
        .map((e) => NextifySecurityGroup.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// The account's default security group (the one blank instances inherit), or
  /// null if there are none.
  Future<NextifySecurityGroup?> defaultSecurityGroup() async {
    final groups = await listSecurityGroups();
    for (final g in groups) {
      if (g.isDefault) return g;
    }
    for (final g in groups) {
      if (g.name == 'default') return g;
    }
    return groups.isEmpty ? null : groups.first;
  }

  /// `POST /ssh-keys` — register a public key so we can SSH into instances we
  /// create. Returns the key id to pass as `ssh_key_ids` on create.
  Future<String> addSshKey({required String name, required String publicKey}) async {
    final res = await _http.post(
      _uri('/ssh-keys'),
      headers: _headers,
      body: jsonEncode({'name': name, 'public_key': publicKey}),
    );
    final j = await _decode(res);
    return (j['id'] as String?) ?? '';
  }

  /// `GET /ssh-keys` — the account's registered public keys.
  Future<List<NextifySshKey>> listSshKeys() async {
    final res = await _http.get(_uri('/ssh-keys'), headers: _headers);
    final j = await _decode(res);
    final items = (j['items'] is List) ? (j['items'] as List) : const [];
    return items
        .whereType<Map>()
        .map((e) => NextifySshKey.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Find-or-create an SSH key by [publicKey]; returns the key id. The API keys
  /// by public key (a duplicate 409s), so we look for an existing match first —
  /// comparing the key material (the first two space-delimited tokens) so a
  /// differing trailing comment still matches.
  Future<String> ensureSshKey({
    required String publicKey,
    required String name,
  }) async {
    String keyPart(String k) =>
        k.trim().split(RegExp(r'\s+')).take(2).join(' ');
    final want = keyPart(publicKey);
    try {
      for (final k in await listSshKeys()) {
        if (keyPart(k.publicKey) == want) return k.id;
      }
    } catch (_) {}
    return addSshKey(name: name, publicKey: publicKey);
  }

  /// `POST /security-groups/{id}/rules` — open an inbound port. Returns true
  /// when added, false when it already existed (409). The default group only
  /// allows intra-group inbound, so a blank VM needs explicit rules for the
  /// app port (and, briefly, 22 for the file push).
  Future<bool> addSecurityGroupRule({
    required String groupId,
    required String protocol,
    required int portFrom,
    int? portTo,
    required String cidr,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'direction': 'in',
      'protocol': protocol,
      'port_from': portFrom,
      'port_to': portTo ?? portFrom,
      'cidr': cidr,
      if (description != null) 'description': description,
    };
    try {
      final res = await _http.post(
        _uri('/security-groups/$groupId/rules'),
        headers: _headers,
        body: jsonEncode(body),
      );
      await _decode(res);
      return true;
    } on NextifyApiException catch (e) {
      if (e.status == 409) return false; // already present
      rethrow;
    }
  }

  // ── Jobs ────────────────────────────────────────────────────────────────
  Future<NextifyJob> job(String jobId) async {
    final res = await _http.get(_uri('/jobs/$jobId'), headers: _headers);
    return NextifyJob.fromJson(await _decode(res));
  }

  /// Poll [jobId] until it is terminal (succeeded/failed), reporting progress
  /// via [onProgress]. Throws [NextifyApiException] if the job fails or the
  /// [timeout] elapses.
  Future<NextifyJob> waitForJob(
    String jobId, {
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 12),
    void Function(NextifyJob)? onProgress,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final j = await job(jobId);
      onProgress?.call(j);
      if (j.isSucceeded) return j;
      if (j.isFailed) {
        throw NextifyApiException(
          0,
          j.errorCode ?? 'job_failed',
          j.errorMessage ?? 'job failed',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw NextifyApiException(
          0,
          'timeout',
          'job $jobId did not finish within ${timeout.inMinutes}m '
              '(last: ${j.status} ${j.progress?.percent ?? 0}%)',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }
}
