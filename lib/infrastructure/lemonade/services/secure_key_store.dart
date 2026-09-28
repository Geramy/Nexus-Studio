// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Ported exactly from ~/IdeaProjects/lemonade_mobile/lib/storage/secure_storage.dart
/// Thin wrapper around flutter_secure_storage. API keys are keyed by server name.
/// Plaintext API keys never touch SharedPreferences or the Drift row (only a hasApiKey flag).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  static const _store = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // See nexus_account_store.dart: legacy keychain avoids the macOS
    // keychain-access-groups entitlement that crashes ad-hoc debug builds.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static String _key(String serverName) => 'apikey/$serverName';

  static Future<String?> readApiKey(String serverName) {
    return _store.read(key: _key(serverName));
  }

  static Future<void> writeApiKey(String serverName, String apiKey) {
    return _store.write(key: _key(serverName), value: apiKey);
  }

  static Future<void> deleteApiKey(String serverName) {
    return _store.delete(key: _key(serverName));
  }

  /// Rename the secure-storage entry when a server is renamed.
  static Future<void> renameApiKey(String oldName, String newName) async {
    final value = await readApiKey(oldName);
    if (value == null) return;
    await writeApiKey(newName, value);
    await deleteApiKey(oldName);
  }
}
