// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nextify_client.dart';
import 'nextify_key_store.dart';

/// A [NextifyClient] built from the stored token, or null when no key is set.
/// Re-reads the keychain on each access, so a freshly entered key is picked up
/// without manual invalidation.
final nextifyClientProvider = FutureProvider<NextifyClient?>((ref) async {
  final token = (await ref.read(nextifyKeyStoreProvider).read())?.trim();
  if (token == null || token.isEmpty) return null;
  return NextifyClient(token);
});
