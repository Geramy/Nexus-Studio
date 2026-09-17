// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:typed_data';

/// Clean interface for all inference backends.
///
/// LemonadeApiClient (the rich ported client) implements this for local
/// self-managed Lemonade servers (the ones with omni collections / full admin).
///
/// Future implementations:
///   - GrokInferenceBackend
///   - OpenAIInferenceBackend
///   - OpenRouterInferenceBackend
///   - RoutedNexusBackend (talks to nexus-projects-server, which synthesizes collections)
///
/// "Collections" (curated bundles of models with specific capabilities) are
/// synthesized differently by each implementation. The interface just needs
/// to surface models + chat + tool calling + optional audio/image in a
/// consistent way.
abstract class InferenceBackend {
  /// Stable identifier for this server row (from the DB).
  String get serverId;

  /// Human name.
  String get name;

  /// The implementation type / provider key (e.g. 'lemonade', 'openai', 'grok', 'routed').
  /// This matches the `providerType` (or future `implementationType`) column in the DB.
  String get implementationType;

  /// Whether `cache_prompt` is isolated safely for this backend. Remote routers
  /// may multiplex sessions across shared model slots; enabling an unkeyed KV
  /// cache there can leak stale prompt state into unrelated requests.
  bool get allowsPromptKvCache => false;

  /// High-level chat (non-streaming).
  Future<ChatCompletionResponse> createChatCompletion({
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
  });

  /// Streaming chat with incremental tool call deltas.
  Stream<ChatStreamEvent> streamChatCompletion({
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
  });

  /// List available models. For Lemonade this can return the rich set
  /// (including collections) when showAll=true.
  Future<List<ModelInfo>> listModels({bool showAll = false});

  /// Audio transcription (STT).
  Future<TranscriptionResult> transcribeAudio({
    required List<int> audioBytes,
    required String filename,
    String? model,
    String? language,
    String? prompt,
  });

  /// Text-to-speech.
  Future<SpeechResult> generateSpeech({
    required String input,
    String? model,
    String voice = 'alloy',
    String responseFormat = 'mp3',
    double? speed,
  });

  /// Image generation.
  Future<ImageGenerationResponse> generateImage({
    required String prompt,
    String? model,
    String size = '1024x1024',
    int n = 1,
    String responseFormat = 'url',
  });

  /// Image editing — modify [imageBytes] per [prompt] (POST /v1/images/edits).
  /// Concrete default so backends that don't support editing still satisfy the
  /// interface; override it where the API supports edits (see LemonadeBackend).
  Future<ImageGenerationResponse> generateImageEdit({
    required List<int> imageBytes,
    required String prompt,
    String imageMime = 'image/png',
    String? model,
    String size = '1024x1024',
    String responseFormat = 'b64_json',
  }) => throw UnimplementedError(
    'Image editing is not supported by this backend.',
  );
}

// -----------------------------------------------------------------------------
// Supporting types (minimal shared contract — implementations can extend)
// -----------------------------------------------------------------------------

class ChatCompletionResponse {
  final String id;
  final List<Choice> choices;
  final Usage? usage;

  ChatCompletionResponse({required this.id, required this.choices, this.usage});

  factory ChatCompletionResponse.fromJson(Map<String, dynamic> json) {
    return ChatCompletionResponse(
      id: json['id'] ?? '',
      choices: (json['choices'] as List? ?? [])
          .map((c) => Choice.fromJson(c as Map<String, dynamic>))
          .toList(),
      usage: json['usage'] != null ? Usage.fromJson(json['usage']) : null,
    );
  }
}

class Choice {
  final int index;
  final Message message;
  final String? finishReason;

  Choice({required this.index, required this.message, this.finishReason});

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      index: json['index'] ?? 0,
      message: Message.fromJson(json['message'] as Map<String, dynamic>),
      finishReason: json['finish_reason'],
    );
  }
}

class Message {
  final String role;
  final String? content;
  final List<ToolCall>? toolCalls;

  /// Reasoning/thinking text when the model exposes it (OpenAI-compatible
  /// servers surface it as `reasoning_content` or `reasoning`). Null when the
  /// model doesn't emit a separate reasoning channel.
  final String? reasoning;

  Message({required this.role, this.content, this.toolCalls, this.reasoning});

  factory Message.fromJson(Map<String, dynamic> json) {
    final reasoning = json['reasoning_content'] ?? json['reasoning'];
    return Message(
      role: json['role'] ?? 'assistant',
      content: json['content'],
      reasoning: (reasoning is String && reasoning.trim().isNotEmpty)
          ? reasoning
          : null,
      toolCalls: (json['tool_calls'] as List? ?? [])
          .map((t) => ToolCall.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ToolCall {
  final String id;
  final String type;
  final FunctionCall function;

  ToolCall({required this.id, required this.type, required this.function});

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'],
      type: json['type'],
      function: FunctionCall.fromJson(json['function'] as Map<String, dynamic>),
    );
  }
}

class FunctionCall {
  final String name;
  final String arguments;

  FunctionCall({required this.name, required this.arguments});

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(
      name: json['name'] ?? '',
      arguments: json['arguments'] ?? '{}',
    );
  }
}

class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      promptTokens: json['prompt_tokens'] ?? 0,
      completionTokens: json['completion_tokens'] ?? 0,
      totalTokens: json['total_tokens'] ?? 0,
    );
  }
}

// Streaming events
abstract class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatContentDelta extends ChatStreamEvent {
  final String text;
  const ChatContentDelta(this.text);
}

/// Reasoning ("thinking") tokens from a reasoning model, streamed separately
/// from the visible answer (OpenAI `reasoning_content` / `reasoning` delta).
/// Surfaced in the UI as a collapsible "Thinking…" block so a long think isn't
/// an opaque spinner.
class ChatReasoningDelta extends ChatStreamEvent {
  final String text;
  const ChatReasoningDelta(this.text);
}

class ChatToolCallDelta extends ChatStreamEvent {
  final List<PartialToolCall> partials;
  const ChatToolCallDelta(this.partials);
}

class ChatStreamFinish extends ChatStreamEvent {
  final String? finishReason;
  final List<ToolCall> toolCalls;
  final String contentSoFar;

  const ChatStreamFinish({
    required this.finishReason,
    required this.toolCalls,
    required this.contentSoFar,
  });
}

class PartialToolCall {
  final int index;
  final String? id;
  final String? name;
  final String argumentsAccum;

  const PartialToolCall({
    required this.index,
    this.id,
    this.name,
    required this.argumentsAccum,
  });
}

// Model info (lightweight)
class ModelInfo {
  final String id;
  final Map<String, dynamic> raw;

  const ModelInfo({required this.id, this.raw = const {}});

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(id: json['id'] as String, raw: json);
  }
}

// Audio / Image result types (minimal)
class TranscriptionResult {
  final String text;
  TranscriptionResult({required this.text});
}

class SpeechResult {
  final Uint8List audioBytes;
  final String contentType;
  SpeechResult({required this.audioBytes, required this.contentType});
}

class ImageGenerationResponse {
  final List<ImageData> data;
  ImageGenerationResponse({required this.data});

  factory ImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    return ImageGenerationResponse(
      data: (json['data'] as List? ?? [])
          .map((e) => ImageData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ImageData {
  final String? url;
  final String? b64Json;
  final String? revisedPrompt;

  ImageData({this.url, this.b64Json, this.revisedPrompt});

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      url: json['url'] as String?,
      b64Json: json['b64_json'] as String?,
      revisedPrompt: json['revised_prompt'] as String?,
    );
  }
}
