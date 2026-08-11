// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Zyphra Cloud backend — OpenAI-compatible inference cloud
/// (https://cloud.zyphra.com). Reuses the Lemonade transport (same wire
/// format) for chat + streaming + TTS.
///
/// Zyphra has no `/models`, transcription, or image endpoints, so those are
/// handled locally: [listModels] returns the documented catalog, and
/// [transcribeAudio] / [generateImage] throw a clear [UnsupportedError]
/// (voice mode degrades to typing; the error is caught by the voice loops).

import '../inference/inference_backend.dart' as iface;
import '../lemonade/lemonade_backend.dart';
import '../lemonade/services/tts_voices.dart';
import '../models/ui/inference_server.dart' as ui_model;

/// Default voice id on Zyphra (neutral US female — the ZONOS2 equivalent of
/// Kokoro's `af_heart`). Used when the persona leaves the voice unset or picks
/// a Kokoro voice id that Zyphra doesn't know.
const String kZyphraDefaultVoice = 'american-female-2';

/// Zyphra's documented open-weight chat models (no `/models` endpoint exists).
const List<String> kZyphraModels = [
  'moonshotai/Kimi-K2.6',
  'deepseek-ai/DeepSeek-V3.2',
  'zai-org/GLM-5.2-FP8',
];

class ZyphraBackend implements iface.InferenceBackend {
  final LemonadeBackend _delegate;

  ZyphraBackend(
    ui_model.InferenceServer server, {
    String? agentName,
    String? sessionId,
  }) : _delegate = LemonadeBackend(
         server,
         agentName: agentName,
         sessionId: sessionId,
       );

  @override
  String get serverId => _delegate.serverId;
  @override
  String get name => _delegate.name;
  @override
  String get implementationType => 'zyphra';

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
  }) => _delegate.createChatCompletion(
    model: model,
    messages: messages,
    tools: tools,
    temperature: temperature,
    topP: topP,
    topK: topK,
    repeatPenalty: repeatPenalty,
    maxTokens: maxTokens,
    maxCompletionTokens: maxCompletionTokens,
    enableThinking: enableThinking,
    extra: extra,
  );

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
  }) => _delegate.streamChatCompletion(
    model: model,
    messages: messages,
    tools: tools,
    temperature: temperature,
    topP: topP,
    topK: topK,
    repeatPenalty: repeatPenalty,
    maxTokens: maxTokens,
    maxCompletionTokens: maxCompletionTokens,
    enableThinking: enableThinking,
    extra: extra,
  );

  @override
  Future<List<iface.ModelInfo>> listModels({bool showAll = false}) async {
    return [
      for (final id in kZyphraModels)
        iface.ModelInfo(id: id, raw: {'id': id, 'provider': 'zyphra'}),
    ];
  }

  @override
  Future<iface.SpeechResult> generateSpeech({
    required String input,
    String? model,
    String voice = 'alloy',
    String responseFormat = 'mp3',
    double? speed,
  }) => _delegate.generateSpeech(
    input: input,
    model: (model == null || model.isEmpty) ? 'zyphra/ZONOS2' : model,
    voice: resolveVoice(voice),
    responseFormat: responseFormat,
    speed: speed,
  );

  /// Maps a persona voice id onto Zyphra's voice namespace. Kokoro ids (or an
  /// unset default) become [kZyphraDefaultVoice]; anything else — Zyphra
  /// default-voice names and cloned voice names — passes through unchanged.
  static String resolveVoice(String voice) {
    if (voice == kDefaultTtsVoice || voice == 'alloy') {
      return kZyphraDefaultVoice;
    }
    for (final v in kKokoroVoices) {
      if (v.id == voice) return kZyphraDefaultVoice;
    }
    return voice;
  }

  @override
  Future<iface.TranscriptionResult> transcribeAudio({
    required List<int> audioBytes,
    required String filename,
    String? model,
    String? language,
    String? prompt,
  }) {
    throw UnsupportedError(
      'Zyphra Cloud has no transcription endpoint. '
      'Pick a Lemonade/Router server for voice calls.',
    );
  }

  @override
  Future<iface.ImageGenerationResponse> generateImage({
    required String prompt,
    String? model,
    String size = '1024x1024',
    int n = 1,
    String responseFormat = 'url',
  }) {
    throw UnsupportedError('Zyphra Cloud has no image generation endpoint.');
  }
}
