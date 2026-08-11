// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nexus_projects_client/features/projects/coordinator_session.dart';
import 'package:nexus_projects_client/infrastructure/inference/inference_client.dart';
import 'package:nexus_projects_client/services/audio/audio_recorder_service.dart';
import 'package:nexus_projects_client/services/audio/audio_session_service.dart';
import 'package:nexus_projects_client/services/audio/tts_service.dart';
import 'package:nexus_projects_client/services/audio/voice_activity_service.dart';

/// Duplex voice session that layers real Silero VAD (lemonade_mobile style)
/// on top of our owned PCM stream for automatic turn-taking.
///
/// Flow per turn:
///   1. We own the mic via [AudioRecorderService] (16 kHz mono PCM16 stream).
///   2. The broadcast stream is fed to the `vad` package (it does NOT open the
///      mic itself — this is the key to stable Silero v5 on macOS desktop).
///   3. When VAD reports speech end it hands us the captured utterance samples.
///      We transcribe THOSE samples (no second recording — that previously
///      caused mic contention and recorded silence), send the transcript to the
///      coordinator (with live tool execution), then speak the reply via TTS.
class CoordinatorDuplexVoiceSession {
  final ProjectCoordinatorSession coordinatorSession;
  final AudioRecorderService recorder;
  final TtsService tts;
  final VoiceActivityService vad;

  /// Optional separate STT backend (e.g. a LAN server) used when the
  /// coordinator's backend can't transcribe (Zyphra Cloud). Falls back to the
  /// coordinator client when null.
  final InferenceBackend? sttBackend;

  /// STT model id to transcribe with. When null the server/default is used
  /// (which may 404 on servers without an OpenAI-style `whisper-1`).
  final String? sttModel;

  /// UI callbacks so each voice turn shows up in the chat transcript.
  /// [onAssistantReply] receives the reply text plus the path to its synthesized
  /// audio (when available) so the session can replay it.
  final void Function(String userText)? onUserTranscript;
  final void Function(String assistantText, String? audioPath)?
  onAssistantReply;
  final void Function(String note)? onSystemNote;

  final AudioSessionService _audioSession = AudioSessionService();

  final _stateController = StreamController<VoiceState>.broadcast();

  bool _isActive = false;
  // Guards against overlapping turns (e.g. VAD firing again while we are still
  // transcribing / waiting on the model / speaking the previous reply).
  bool _busy = false;
  StreamSubscription<List<double>>? _speechEndSub;

  CoordinatorDuplexVoiceSession({
    required this.coordinatorSession,
    required this.recorder,
    required this.tts,
    this.sttModel,
    this.sttBackend,
    this.onUserTranscript,
    this.onAssistantReply,
    this.onSystemNote,
    VoiceActivityService? vadService,
  }) : vad = vadService ?? VoiceActivityService();

  Stream<VoiceState> get state => _stateController.stream;

  bool get isActive => _isActive;

  Future<void> startCall() async {
    if (_isActive) return;

    await _audioSession.ensureVoiceChatSession();

    // 1. Configure audio session (voiceChat mode for AEC on iOS, etc.).
    // 2. Start our own high-quality 16 kHz mono PCM stream.
    // 3. Pass the broadcast stream to VAD so it doesn't open the mic itself.
    final pcmStream = await recorder.startPcmStream();
    final broadcast = pcmStream.asBroadcastStream();

    await vad.initialize();

    _isActive = true;
    _stateController.add(VoiceState.listening);

    await vad.startListeningWithStream(broadcast);

    // Use the audio captured BY the VAD for the just-completed utterance.
    _speechEndSub = vad.onSpeechEnd.listen(_handleUtterance);
    debugPrint(
      '[Voice] Duplex call started. sttModel=${sttModel ?? "(server default — likely whisper-1)"}',
    );
  }

  /// Processes one completed utterance: STT → coordinator (with tools) → TTS.
  Future<void> _handleUtterance(List<double> samples) async {
    debugPrint(
      '[Voice] _handleUtterance: ${samples.length} samples (active=$_isActive busy=$_busy)',
    );
    if (!_isActive || _busy || samples.isEmpty) {
      debugPrint(
        '[Voice] utterance skipped (active=$_isActive busy=$_busy empty=${samples.isEmpty})',
      );
      return;
    }
    _busy = true;

    try {
      _stateController.add(VoiceState.processing);

      final wav = _floatSamplesToWav(samples);
      debugPrint(
        '[Voice] transcribing ${wav.length} WAV bytes with model=${sttModel ?? "(server default)"}',
      );
      final stt = await (sttBackend ?? coordinatorSession.client)
          .transcribeAudio(
            audioBytes: wav,
            filename: 'utterance.wav',
            model: sttModel,
          );
      final transcript = stt.text.trim();
      debugPrint('[Voice] transcript: "$transcript"');

      if (transcript.isNotEmpty) {
        onUserTranscript?.call(transcript);

        final reply = StringBuffer();

        debugPrint(
          '[Voice] sending transcript to coordinator (model=${coordinatorSession.model ?? "(default)"})…',
        );
        // runTurn handles the tool loop internally and produces a spoken answer.
        await for (final event in coordinatorSession.runTurn(
          transcript,
          onToolResult: (r) {
            debugPrint('[Voice] tool result: $r');
            onSystemNote?.call(r);
          },
        )) {
          if (event is ChatContentDelta) {
            reply.write(event.text);
          }
        }
        debugPrint('[Voice] coordinator replied: ${reply.length} chars');

        final spoken = reply.toString().trim();
        if (spoken.isNotEmpty) {
          // Synthesize first (retains the file) so the reply bubble can carry
          // its audio for replay, then play it.
          String? audioPath;
          if (_isActive) {
            _stateController.add(VoiceState.speaking);
            debugPrint('[Voice] synthesizing reply (${spoken.length} chars)…');
            audioPath = await tts.synthesize(spoken);
          }
          onAssistantReply?.call(spoken, audioPath);
          if (audioPath != null && _isActive) {
            debugPrint('[Voice] playing reply audio…');
            await tts.playFile(audioPath);
          }
        } else {
          debugPrint('[Voice] no spoken reply produced by the model');
          onSystemNote?.call(
            '(No spoken reply produced. Check that the chat model is valid.)',
          );
        }
      }
    } catch (e, st) {
      onSystemNote?.call('Voice turn error: $e');
      // Keep the call alive on error; the user can still end it with the button.
      debugPrint('[Voice] Duplex voice turn error (non-fatal): $e\n$st');
    } finally {
      _busy = false;
      if (_isActive) {
        _stateController.add(VoiceState.listening);
      }
    }
  }

  Future<void> endCall() async {
    _isActive = false;
    await _speechEndSub?.cancel();
    _speechEndSub = null;
    await vad.stopListening();
    try {
      await recorder.stopPcmStream();
    } catch (_) {}
    await tts.stop();
    await _audioSession.deactivate();
    _stateController.add(VoiceState.idle);
  }

  /// Temporarily pause listening (for mute) without ending the whole call.
  Future<void> pauseListening() async {
    await vad.stopListening();
    try {
      await recorder.stopPcmStream();
    } catch (_) {}
    if (_isActive) {
      _stateController.add(VoiceState.idle);
    }
  }

  /// Resume listening after mute. Restart the stream + VAD feed (matching startCall order).
  Future<void> resumeListening() async {
    if (!_isActive) return;
    await _audioSession.ensureVoiceChatSession();
    final pcmStream = await recorder.startPcmStream();
    await vad.startListeningWithStream(pcmStream.asBroadcastStream());
    _stateController.add(VoiceState.listening);
  }

  Future<void> dispose() async {
    await endCall();
    await _stateController.close();
  }

  /// Encodes normalized float PCM samples (range -1..1) from the VAD into a
  /// 16 kHz mono 16-bit WAV byte buffer suitable for the STT endpoint.
  Uint8List _floatSamplesToWav(List<double> samples, {int sampleRate = 16000}) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var s = samples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      pcm[i] = (s * 32767).round();
    }
    final dataBytes = pcm.buffer.asUint8List(0, pcm.length * 2);
    final dataLen = dataBytes.length;
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    const blockAlign = channels * (bitsPerSample ~/ 8);

    final builder = BytesBuilder();
    void writeStr(String s) => builder.add(s.codeUnits);
    void writeU32(int v) => builder.add([
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ]);
    void writeU16(int v) => builder.add([v & 0xff, (v >> 8) & 0xff]);

    writeStr('RIFF');
    writeU32(36 + dataLen);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16); // PCM fmt chunk size
    writeU16(1); // audio format = PCM
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeStr('data');
    writeU32(dataLen);
    builder.add(dataBytes);
    return builder.toBytes();
  }
}

/// Shared voice UI state used by the Coordinator call screens.
enum VoiceState { idle, listening, processing, speaking, error }
