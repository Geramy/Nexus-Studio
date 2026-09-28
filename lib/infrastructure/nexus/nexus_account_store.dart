// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Secure persistence for the Nexus ACCOUNT credential. Parallels
/// infrastructure/lemonade/services/secure_key_store.dart (a thin wrapper over
/// flutter_secure_storage) but is dedicated to the single account token + a
/// cached copy of the user/client JSON so the UI can hydrate on launch without
/// a round-trip.
///
/// The token NEVER touches SharedPreferences or Drift — only the keychain.
/// The token is never logged.
///
/// Storage uses the LEGACY file-based keychain (usesDataProtectionKeychain:
/// false) — no `keychain-access-groups` / data-protection entitlement. That
/// entitlement is fragile for Developer-ID apps distributed outside the App
/// Store (it can make macOS reject the app at launch), and an ad-hoc/debug build
/// can't carry it at all. A properly signed + notarized app reads its own
/// file-based items silently; this matches SecureKeyStore + GithubTokenStore.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/nexus_account_models.dart';

class NexusAccountStore {
  static const FlutterSecureStorage _store = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static const _tokenKey = 'nexus/account_token';
  static const _identityKey = 'nexus/account_identity';
  static const _gatewayKey = 'nexus/gateway_base_url';
  static const _deviceIdKey = 'nexus/device_id';

  // ── Device id ───────────────────────────────────────────────────────
  // A stable, per-install id sent on login/register as `device_id`. The router
  // mints a per-(user, device_id, app_name) token, so a fresh login on this
  // device rotates only this device's token. Generated once, persisted in the
  // keychain, and NOT cleared on sign-out (so the same device keeps its bucket).

  static Future<String> deviceId() async {
    final existing = await _store.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final r = Random.secure();
    final id = List<int>.generate(
      16,
      (_) => r.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _store.write(key: _deviceIdKey, value: id);
    return id;
  }

  // ── Token ───────────────────────────────────────────────────────────

  static Future<String?> readToken() => _store.read(key: _tokenKey);

  static Future<void> writeToken(String token) =>
      _store.write(key: _tokenKey, value: token);

  static Future<void> deleteToken() => _store.delete(key: _tokenKey);

  // ── Cached identity (user + client) ─────────────────────────────────

  /// Persist a compact JSON of the signed-in user + client for fast hydration.
  static Future<void> writeIdentity(NexusUser user, NexusClient client) {
    final json = jsonEncode({'user': user.toJson(), 'client': client.toJson()});
    return _store.write(key: _identityKey, value: json);
  }

  /// Reads the cached identity, or null if absent/corrupt.
  static Future<({NexusUser user, NexusClient client})?> readIdentity() async {
    final raw = await _store.read(key: _identityKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final user = NexusUser.fromJson(
          Map<String, dynamic>.from(decoded['user'] as Map),
        );
        final client = NexusClient.fromJson(
          Map<String, dynamic>.from(decoded['client'] as Map),
        );
        return (user: user, client: client);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteIdentity() => _store.delete(key: _identityKey);

  // ── Gateway base URL override (optional) ────────────────────────────

  static Future<String?> readGatewayBaseUrl() => _store.read(key: _gatewayKey);

  static Future<void> writeGatewayBaseUrl(String url) =>
      _store.write(key: _gatewayKey, value: url);

  /// Clear all account credentials on sign-out.
  static Future<void> clear() async {
    await deleteToken();
    await deleteIdentity();
  }
}
