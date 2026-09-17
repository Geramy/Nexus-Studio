// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Adapter that makes the rich ported `LemonadeApiClient` implement the
/// common `InferenceBackend` interface.

import 'package:http/http.dart' as http;

import '../inference/inference_backend.dart' as iface;
import 'api/lemonade_client.dart';
import 'api/types/audio_request.dart';
import 'api/types/chat_request.dart';
import 'api/types/chat_response.dart' as api_types;
import 'api/types/tool_call.dart' as tc;
import 'api/types/image_request.dart';
import 'api/endpoints/images_endpoint.dart' show ImageEditRequest;
import 'models/server_config.dart';
import '../models/ui/inference_server.dart' as ui_model;

class LemonadeBackend implements iface.InferenceBackend {
  final ui_model.InferenceServer _row;
  late final LemonadeApiClient _client;

  /// When [client] is supplied (the shared per-host transport from
  /// [backendForServer]) it is REUSED — this backend must not own/close it.
  final bool _ownsClient;

  LemonadeBackend(
    this._row, {
    String? agentName,
    String? sessionId,
    http.Client? client,
  }) : _ownsClient = client == null {
    final cfg = ServerConfig(
      name: _row.name,
      baseUrl: _row.baseUrl,
      apiKey: _row.apiKey,
      agentName: agentName,
      sessionId: sessionId,
    );
    _client = LemonadeApiClient(cfg, client: client);
  }

  @override
  String get serverId => _row.id;
  @override
  String get name => _row.name;
  @override
  String get implementationType => 'lemonade';
  @override
  bool get allowsPromptKvCache => _row.providerType.toLowerCase() == 'lemonade';

  // ── Chat (non-streaming) via new endpoints ────────────────────────

  @override
  Future<iface.ChatCompletionResponse> createChatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? maxCompletionTokens,
    bool? enableThinking,
    Map<String, dynamic>? extra,
  }) async {
    final resp = await _client.chat.create(
      ChatCompletionRequest(
        model: model,
        messages: messages,
        tools: tools,
        stream: false,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
        maxCompletionTokens: maxCompletionTokens ?? maxTokens,
        enableThinking: enableThinking,
        extra: extra,
      ),
    );

    final msg = resp.message;
    final mappedTools = msg.toolCalls == null
        ? null
        : <iface.ToolCall>[
            for (final tc in msg.toolCalls!) _toolCallToIface(tc),
          ];
    final mappedMsg = iface.Message(
      role: msg.role.name,
      content: msg.content,
      toolCalls: mappedTools,
    );
    return iface.ChatCompletionResponse(
      id: resp.id,
      choices: [
        iface.Choice(
          index: 0,
          message: mappedMsg,
          finishReason: resp.finishReason,
        ),
      ],
      usage: null,
    );
  }

  // ── Chat (streaming) via new endpoints ────────────────────────────

  @override
  Stream<iface.ChatStreamEvent> streamChatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? maxCompletionTokens,
    bool? enableThinking,
    Map<String, dynamic>? extra,
  }) async* {
    final req = ChatCompletionRequest(
      model: model,
      messages: messages,
      tools: tools,
      stream: true,
      temperature: temperature,
      topP: topP,
      topK: topK,
      repeatPenalty: repeatPenalty,
      maxCompletionTokens: maxCompletionTokens ?? maxTokens,
      enableThinking: enableThinking,
      extra: extra,
    );

    await for (final event in _client.chat.stream(req)) {
      yield _mapStreamEvent(event);
    }
  }

  // ── Models ────────────────────────────────────────────────────────

  @override
  Future<List<iface.ModelInfo>> listModels({bool showAll = false}) async {
    final list = await (showAll
        ? _client.models.all()
        : _client.models.installed());
    return list
        .map(
          (m) => iface.ModelInfo(
            id: m.id,
            raw: {
              'downloaded': m.downloaded,
              'recipe': m.recipe,
              'labels': m.labels,
            },
          ),
        )
        .toList();
  }

  // ── Audio via endpoints ───────────────────────────────────────────

  @override
  Future<iface.TranscriptionResult> transcribeAudio({
    required List<int> audioBytes,
    required String filename,
    String? model,
    String? language,
    String? prompt,
  }) async {
    final result = await _client.audio.transcribe(
      TranscriptionRequest(
        model: model ?? 'whisper-1',
        audioBytes: audioBytes,
        audioFilename: filename,
      ),
    );
    return iface.TranscriptionResult(text: result.text);
  }

  @override
  Future<iface.SpeechResult> generateSpeech({
    required String input,
    String? model,
    String voice = 'alloy',
    String responseFormat = 'mp3',
    double? speed,
  }) async {
    final result = await _client.audio.speech(
      TextToSpeechRequest(
        model: model ?? '',
        input: input,
        voice: voice,
        responseFormat: responseFormat,
        speed: speed,
      ),
    );
    return iface.SpeechResult(
      audioBytes: result.audioBytes,
      contentType: result.mime,
    );
  }

  // ── Image Generation via endpoint ────────────────────────────────

  @override
  Future<iface.ImageGenerationResponse> generateImage({
    required String prompt,
    String? model,
    String size = '1024x1024',
    int n = 1,
    String responseFormat = 'url',
  }) async {
    final req = ImageGenerationRequest.bySize(
      model: model ?? '',
      prompt: prompt,
      size: size,
    );
    final resp = await _client.images.generate(req);
    return iface.ImageGenerationResponse(
      data: resp.images
          .map((img) => iface.ImageData(url: img.url, b64Json: img.b64Json))
          .toList(),
    );
  }

  @override
  Future<iface.ImageGenerationResponse> generateImageEdit({
    required List<int> imageBytes,
    required String prompt,
    String imageMime = 'image/png',
    String? model,
    String size = '1024x1024',
    String responseFormat = 'b64_json',
  }) async {
    final resp = await _client.images.edit(
      ImageEditRequest(
        model: model ?? '',
        prompt: prompt,
        sourceImageBytes: imageBytes,
        sourceImageMime: imageMime,
        sourceFilename: 'image.${imageMime.split('/').last}',
        size: size,
        responseFormat: responseFormat,
      ),
    );
    return iface.ImageGenerationResponse(
      data: resp.images
          .map((img) => iface.ImageData(url: img.url, b64Json: img.b64Json))
          .toList(),
    );
  }

  // ── Type mapping helpers ──────────────────────────────────────────

  static iface.ChatStreamEvent _mapStreamEvent(
    api_types.ChatStreamEvent event,
  ) {
    if (event is api_types.ChatContentDelta)
      return iface.ChatContentDelta(event.text);
    if (event is api_types.ChatReasoningDelta)
      return iface.ChatReasoningDelta(event.text);
    if (event is api_types.ChatToolCallDelta) {
      final partials = <iface.PartialToolCall>[];
      for (final p in event.partials) {
        partials.add(
          iface.PartialToolCall(
            index: p.index,
            id: p.id ?? '',
            name: p.name ?? '',
            argumentsAccum: p.argumentsAccum,
          ),
        );
      }
      return iface.ChatToolCallDelta(partials);
    }
    if (event is api_types.ChatStreamFinish) {
      final mappedTools = <iface.ToolCall>[];
      for (final tc in event.toolCalls) {
        mappedTools.add(
          iface.ToolCall(
            id: tc.id,
            type: 'function',
            function: iface.FunctionCall(
              name: tc.name,
              arguments: tc.argumentsJson,
            ),
          ),
        );
      }
      return iface.ChatStreamFinish(
        finishReason: event.finishReason,
        toolCalls: mappedTools,
        contentSoFar: event.contentSoFar,
      );
    }
    throw StateError('Unknown ChatStreamEvent subtype');
  }

  static iface.ToolCall _toolCallToIface(tc.ToolCall tc) {
    return iface.ToolCall(
      id: tc.id,
      type: 'function',
      function: iface.FunctionCall(name: tc.name, arguments: tc.argumentsJson),
    );
  }

  /// Close only a transport this backend OWNS. When the shared per-host client
  /// was injected (the normal path via [backendForServer]), closing is a no-op —
  /// the pooled transport is app-lifetime and reused by other backends.
  void close() {
    if (_ownsClient) _client.close();
  }
}
