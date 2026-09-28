// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the optional GitHub Personal Access Token used to lift the
/// unauthenticated REST rate limit (60 req/hr) up to 5000 req/hr while
/// verifying library/framework freshness. The token is a secret, so it lives
/// in the OS keychain via flutter_secure_storage — never in Drift or prefs.
class GithubTokenStore {
  static const _store = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // See nexus_account_store.dart: legacy keychain avoids the macOS
    // keychain-access-groups entitlement that crashes ad-hoc debug builds.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static const _key = 'github/pat';

  Future<String?> read() => _store.read(key: _key);

  Future<void> write(String token) => _store.write(key: _key, value: token);

  Future<void> delete() => _store.delete(key: _key);

  Future<bool> hasToken() async => (await read())?.isNotEmpty ?? false;
}

final githubTokenStoreProvider = Provider<GithubTokenStore>((ref) {
  return GithubTokenStore();
});
