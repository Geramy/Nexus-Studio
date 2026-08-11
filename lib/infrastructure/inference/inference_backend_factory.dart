// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Factory that, given an InferenceServer row, returns the correct implementation
/// of InferenceBackend.
///
/// This is the central place where we decide "for this server, use the Lemonade
/// rich client", "for this server, use the Grok implementation", etc.

import '../database/nexus_database.dart' show NexusDatabase;
import '../models/ui/inference_server.dart' as ui_model;
import 'inference_backend.dart';
// Import the concrete implementation — Dart handles circular imports at runtime.
import '../lemonade/lemonade_backend.dart' show LemonadeBackend;
import '../zyphra/zyphra_backend.dart' show ZyphraBackend;

/// Returns a concrete InferenceBackend for the given server row.
///
/// [agentName] is forwarded as the `X-Nexus-Agent` header so the Router can
/// attribute per-agent cost; pass it when the call is made on behalf of a
/// specific agent persona.
///
/// [sessionId] is forwarded as the `X-Nexus-Session` header — a stable id for the
/// message session (conversation / agent run). The Router pins a session to one
/// warm backend and balances different sessions across the fleet, so a single
/// conversation stays warm while concurrent agents fan out across servers.
InferenceBackend backendForServer(
  ui_model.InferenceServer server, {
  String? agentName,
  String? sessionId,
}) {
  final type = server.providerType.toLowerCase();

  switch (type) {
    case 'lemonade':
      return LemonadeBackend(
        server,
        agentName: agentName,
        sessionId: sessionId,
      );

    // The Nexus Router subscription gateway is OpenAI-compatible and is reached
    // through the same transport (ServerConfig maps api.nexus-projects.ai to
    // /api/v1, which the Router proxy serves).
    case 'routed':
      return LemonadeBackend(
        server,
        agentName: agentName,
        sessionId: sessionId,
      );

    // Zyphra Cloud — OpenAI-compatible cloud (chat + TTS; no STT/image).
    case 'zyphra':
      return ZyphraBackend(server, agentName: agentName, sessionId: sessionId);

    default:
      throw UnimplementedError(
        'No backend implementation yet for providerType="$type". '
        'Server: ${server.name}. Implement the backend and wire it here.',
      );
  }
}

/// Resolve an STT-capable fallback backend for a client whose primary backend
/// can't transcribe (Zyphra Cloud has no transcription endpoint). Returns the
/// first enabled server whose providerType isn't [excludeProviderType], or
/// null when none exists.
///
/// Voice loops use this for the mic (hear) side while chat + TTS stay on the
/// primary backend — so a Zyphra persona can talk without a local server
/// powering the LLM.
Future<InferenceBackend?> sttFallbackBackend({
  required int clientId,
  required NexusDatabase db,
  String? excludeProviderType,
}) async {
  final servers = await db.getInferenceServersForClient(clientId);
  for (final s in servers) {
    if (!s.isEnabled) continue;
    if (excludeProviderType != null && s.providerType == excludeProviderType) {
      continue;
    }
    final ui = ui_model.InferenceServer(
      id: s.server_pk.toString(),
      name: s.name,
      baseUrl: s.baseUrl,
      apiKey: s.apiKey,
      providerType: s.providerType,
    );
    return backendForServer(ui);
  }
  return null;
}
