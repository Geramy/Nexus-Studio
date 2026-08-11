// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Centralized cache for AI provider servers + their live model lists.
///
/// Fetches models from each configured server's API and caches the results
/// so every consumer (persona editor, admin console, agents hub) shares
/// the same data without redundant network calls.
///
/// Invalidate [aiServersCacheProvider] to force a full refresh.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/core/providers/database_provider.dart';
import 'package:nexus_projects_client/core/providers/app_shell_provider.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show InferenceServer;
import 'package:nexus_projects_client/infrastructure/inference/inference_backend_factory.dart';
import 'package:nexus_projects_client/infrastructure/models/ui/inference_server.dart'
    as ui_model;
import 'package:nexus_projects_client/infrastructure/lemonade/api/lemonade_client.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/api/types/model_info.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/models/server_config.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/services/secure_key_store.dart';

/// Holds the cached model list for a single server.
class ServerModelsEntry {
  final InferenceServer server;
  final List<ApiModelInfo> models;
  final DateTime fetchedAt;
  final String? error;

  ServerModelsEntry({
    required this.server,
    required this.models,
    required this.fetchedAt,
    this.error,
  });

  /// Omni / collection models from this server.
  List<ApiModelInfo> get omniModels =>
      models.where((m) => m.isCollection).toList();

  /// Non-collection individual models.
  List<ApiModelInfo> get individualModels =>
      models.where((m) => !m.isCollection).toList();
}

/// Cache state: map of server pk -> cached entry.
typedef AiServersCache = Map<int, ServerModelsEntry>;

/// Build a [ServerConfig] from a Drift [InferenceServer] row,
/// resolving the API key from secure storage.
Future<ServerConfig> _toServerConfig(InferenceServer row) async {
  String? apiKey;
  if (row.apiKey.isNotEmpty) {
    apiKey = row.apiKey;
  } else {
    try {
      apiKey = await SecureKeyStore.readApiKey(row.name);
    } catch (_) {}
  }
  return ServerConfig(baseUrl: row.baseUrl, apiKey: apiKey, name: row.name);
}

/// Minimal UI-model conversion for [backendForServer] (only name/baseUrl/
/// apiKey/providerType are read when building a backend).
ui_model.InferenceServer _toUiServer(InferenceServer row) {
  return ui_model.InferenceServer(
    id: row.server_pk.toString(),
    name: row.name,
    baseUrl: row.baseUrl,
    apiKey: row.apiKey,
    providerType: row.providerType,
  );
}

/// Notifier that fetches + caches models for all configured inference servers.
class AiServersCacheNotifier extends StateNotifier<AiServersCache> {
  final Ref ref;
  static const _cacheTtl = Duration(minutes: 5);

  AiServersCacheNotifier(this.ref) : super({});

  /// Fetch models for every configured server, merging into the cache.
  Future<void> refresh() async {
    final currentClientId = ref.read(currentClientIdProvider);
    final db = ref.read(nexusDatabaseProvider);
    final servers = await db.getInferenceServersForClient(currentClientId);

    final updated = Map<int, ServerModelsEntry>.from(state);

    for (final server in servers) {
      // Skip if we have a fresh cache entry
      final existing = updated[server.server_pk];
      if (existing != null &&
          DateTime.now().difference(existing.fetchedAt) < _cacheTtl) {
        continue;
      }

      try {
        // Zyphra Cloud has no /models endpoint — use the backend's catalog.
        // Lemonade/Router keep the rich client (labels, recipes, omni bundles).
        if (server.providerType == 'zyphra') {
          final backend = backendForServer(_toUiServer(server));
          final models = <ApiModelInfo>[
            for (final m in await backend.listModels())
              ApiModelInfo(id: m.id, labels: const []),
          ];
          updated[server.server_pk] = ServerModelsEntry(
            server: server,
            models: models,
            fetchedAt: DateTime.now(),
          );
          continue;
        }

        final config = await _toServerConfig(server);
        final client = LemonadeApiClient(config);
        final models = await client.models.all();
        updated[server.server_pk] = ServerModelsEntry(
          server: server,
          models: models,
          fetchedAt: DateTime.now(),
        );
        client.close();
      } catch (e) {
        debugPrint(
          'AiServersCache: failed to fetch models for ${server.name}: $e',
        );
        // Keep existing cache if available, otherwise store error
        if (existing == null) {
          updated[server.server_pk] = ServerModelsEntry(
            server: server,
            models: [],
            fetchedAt: DateTime.now(),
            error: e.toString(),
          );
        }
      }
    }

    state = updated;
  }

  /// Fetch models for a single server by ID.
  Future<void> refreshServer(int serverId) async {
    final currentClientId = ref.read(currentClientIdProvider);
    final db = ref.read(nexusDatabaseProvider);
    final servers = await db.getInferenceServersForClient(currentClientId);
    final server = servers.firstWhere(
      (s) => s.server_pk == serverId,
      orElse: () => throw StateError('Server $serverId not found'),
    );

    try {
      if (server.providerType == 'zyphra') {
        final backend = backendForServer(_toUiServer(server));
        final models = <ApiModelInfo>[
          for (final m in await backend.listModels())
            ApiModelInfo(id: m.id, labels: const []),
        ];
        state = {
          ...state,
          serverId: ServerModelsEntry(
            server: server,
            models: models,
            fetchedAt: DateTime.now(),
          ),
        };
        return;
      }

      final config = await _toServerConfig(server);
      final client = LemonadeApiClient(config);
      final models = await client.models.all();
      state = {
        ...state,
        serverId: ServerModelsEntry(
          server: server,
          models: models,
          fetchedAt: DateTime.now(),
        ),
      };
      client.close();
    } catch (e) {
      debugPrint(
        'AiServersCache: failed to fetch models for ${server.name}: $e',
      );
      if (state[serverId] == null) {
        state = {
          ...state,
          serverId: ServerModelsEntry(
            server: server,
            models: [],
            fetchedAt: DateTime.now(),
            error: e.toString(),
          ),
        };
      }
    }
  }

  /// Get all models across all servers (deduplicated by model id).
  List<ApiModelInfo> getAllModels() {
    final seen = <String, ApiModelInfo>{};
    for (final entry in state.values) {
      for (final m in entry.models) {
        seen.putIfAbsent(m.id, () => m);
      }
    }
    return seen.values.toList();
  }

  /// Get all omni/collection models across all servers.
  List<ApiModelInfo> getAllOmniModels() {
    return getAllModels().where((m) => m.isCollection).toList();
  }

  /// Get the entry for a specific server, or null.
  ServerModelsEntry? entryFor(int serverId) => state[serverId];
}

/// Main cached provider — consumers should watch this for the full cache.
final aiServersCacheProvider =
    StateNotifierProvider<AiServersCacheNotifier, AiServersCache>((ref) {
      final notifier = AiServersCacheNotifier(ref);
      // Refresh whenever the configured server list changes for the current client.
      // This is what fetches models for a server added *after* startup — most
      // importantly the built-in Nexus Router (subscription) server, which is
      // materialized only once the account signs in. Without this, a freshly-added
      // server would have no cache entry until the 5-min TTL and would appear to
      // have no models. `refresh()` is per-server TTL-guarded, so this is cheap.
      final clientId = ref.watch(currentClientIdProvider);
      ref.listen<AsyncValue<List<InferenceServer>>>(
        inferenceServersForClientProvider(clientId),
        (_, next) => next.whenData((_) => notifier.refresh()),
        fireImmediately: true,
      );
      return notifier;
    });

/// Convenience: all models across every configured server (deduplicated).
final allAiModelsProvider = Provider<List<ApiModelInfo>>((ref) {
  return ref.watch(aiServersCacheProvider.notifier).getAllModels();
});

/// Convenience: all omni/collection models across every server.
final allOmniModelsProvider = Provider<List<ApiModelInfo>>((ref) {
  return ref.watch(aiServersCacheProvider.notifier).getAllOmniModels();
});
