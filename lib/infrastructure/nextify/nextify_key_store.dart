// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the Nextify API token (a `nxt_…` secret) for cloud hosting. It lives
/// in the OS keychain via flutter_secure_storage — never in Drift or prefs
/// (same pattern as the GitHub PAT store).
class NextifyKeyStore {
  static const _store = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // See nexus_account_store.dart: legacy keychain avoids the macOS
    // keychain-access-groups entitlement that crashes ad-hoc debug builds.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static const _key = 'nextify/api-token';

  Future<String?> read() => _store.read(key: _key);

  Future<void> write(String token) => _store.write(key: _key, value: token);

  Future<void> delete() => _store.delete(key: _key);

  Future<bool> hasKey() async => (await read())?.isNotEmpty ?? false;
}

final nextifyKeyStoreProvider = Provider<NextifyKeyStore>((ref) {
  return NextifyKeyStore();
});
