// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nexus_projects_client/infrastructure/inference/inference_backend.dart';
import 'package:nexus_projects_client/services/audio/audio_recorder_service.dart';
import 'package:nexus_projects_client/services/audio/audio_session_service.dart';
import 'package:nexus_projects_client/services/audio/coordinator_duplex_voice_session.dart'
    show VoiceState;
import 'package:nexus_projects_client/services/audio/tts_service.dart';
import 'package:nexus_projects_client/services/audio/voice_activity_service.dart';

/// One multiple-choice question the interview is waiting on, while a voice call
/// is active. The session speaks it, then maps the user's next utterance to the
/// supplied [options]. [isAnswered] lets the session bail if the user tapped the
/// on-screen picker first (tap and voice race to fill the same answer).
class _ArmedQuestion {
  _ArmedQuestion({
    required this.question,
    required this.options,
    required this.multi,
    required this.onResolved,
    required this.isAnswered,
  });

  final String question;
  final List<String> options;
  final bool multi;
  final void Function(List<String> picks) onResolved;
  final bool Function() isAnswered;
  bool reprompted = false;
}

/// Hands-free "call mode" for the Project Setup interview. Layers Silero VAD on
/// our owned PCM stream (same lemonade_mobile pattern as the Coordinator's
/// [CoordinatorDuplexVoiceSession]) but drives the question-driven interview
/// instead of a free-text chat:
///
///   • When no question is pending, a completed utterance is transcribed and
///     handed to [onFreeUtterance] (the controller starts an interview turn).
///   • When the interview asks a multiple-choice question, the host calls
///     [armQuestion]: the session speaks the question + options, then maps the
///     next utterance onto those options and answers it. The on-screen picker
///     stays live, so the user can also just tap — whichever happens first wins.
class SetupVoiceSession {
  SetupVoiceSession({
    required this.backend,
    required this.recorder,
    required this.tts,
    this.sttModel,
    this.sttBackend,
    this.onFreeUtterance,
    this.onSystemNote,
    VoiceActivityService? vadService,
  }) : vad = vadService ?? VoiceActivityService();

  final InferenceBackend backend;

  /// Optional separate STT backend (e.g. a LAN server) used when [backend]
  /// can't transcribe (Zyphra Cloud). Falls back to [backend] when null.
  final InferenceBackend? sttBackend;
  final AudioRecorderService recorder;
  final TtsService tts;
  final VoiceActivityService vad;

  /// STT model id; null lets the server pick its default.
  final String? sttModel;

  /// Fired when a free-form utterance (no question pending) is transcribed. The
  /// returned future is awaited so the next free utterance isn't dispatched
  /// until the interview turn it kicked off has finished.
  final Future<void> Function(String transcript)? onFreeUtterance;
  final void Function(String note)? onSystemNote;

  final AudioSessionService _audioSession = AudioSessionService();
  final _stateController = StreamController<VoiceState>.broadcast();

  bool _isActive = false;
  // True while a free-form interview turn is in flight (so we don't start a
  // second one). Does NOT gate question answers — those must get through while
  // the turn is parked on a pending question.
  bool _turnInFlight = false;
  // True while we are answering an armed question (one utterance at a time).
  bool _answering = false;
  // True while TTS is playing, so we ignore our own audio echoed back by the
  // mic (no AEC on desktop).
  bool _speaking = false;

  _ArmedQuestion? _armed;
  StreamSubscription<List<double>>? _speechEndSub;

  // Serializes TTS so a spoken reply and a spoken question never overlap.
  Future<void> _speakChain = Future<void>.value();

  // Echo suppression: desktop has no acoustic echo cancellation, so the mic
  // hears our own TTS. We ignore utterances while speaking AND for a cooldown
  // afterward, because the VAD's redemption window reports speech-end a beat
  // after playback actually stops (otherwise the AI transcribes itself and
  // talks in a loop).
  static const Duration _echoCooldown = Duration(milliseconds: 500);
  DateTime? _muteUntil;
  bool get _muted =>
      _speaking || (_muteUntil != null && DateTime.now().isBefore(_muteUntil!));

  /// User-controlled mic mute (the mute button / "m" hotkey). Independent of the
  /// echo-suppression [_muted] above — when on, the user's mic is silenced to the
  /// VAD so nothing they say is transcribed until they unmute.
  bool _userMuted = false;
  bool get isMuted => _userMuted;
  void setMuted(bool value) => _userMuted = value;
  bool toggleMute() => _userMuted = !_userMuted;

  Stream<VoiceState> get state => _stateController.stream;
  bool get isActive => _isActive;

  Future<void> startCall() async {
    if (_isActive) return;
    await _audioSession.ensureVoiceChatSession();
    final pcmStream = await recorder.startPcmStream();
    final broadcast = pcmStream.asBroadcastStream();
    await vad.initialize();
    _isActive = true;
    _stateController.add(VoiceState.listening);
    await vad.startListeningWithStream(_gateForEcho(broadcast));
    _speechEndSub = vad.onSpeechEnd.listen(_handleUtterance);
    debugPrint(
      '[SetupVoice] call started. stt=${sttModel ?? "(server default)"}',
    );
  }

  /// Replaces mic frames with silence while we're speaking (or in the brief
  /// echo cooldown after), so the VAD never even sees — let alone accumulates —
  /// the AI's own TTS. This is what stops the AI transcribing itself and
  /// talking in a loop; the post-utterance [_muted] check is just a backstop.
  Stream<Uint8List> _gateForEcho(Stream<Uint8List> pcm) => pcm.map(
    (frame) => (_muted || _userMuted) ? Uint8List(frame.length) : frame,
  );

  /// Speak [text] (e.g. a greeting or a spoken reply between questions),
  /// serialized behind any in-flight speech. Mic input is ignored while we talk.
  Future<void> speak(String text) {
    final spoken = _sanitizeForSpeech(text);
    if (spoken.isEmpty) return Future<void>.value();
    _speakChain = _speakChain.then((_) async {
      if (!_isActive) return;
      _speaking = true;
      _stateController.add(VoiceState.speaking);
      try {
        await tts.speak(spoken);
      } catch (e) {
        debugPrint('[SetupVoice] speak failed: $e');
      } finally {
        _speaking = false;
        // Keep ignoring the mic briefly so the VAD's trailing speech-end for
        // our own audio doesn't get transcribed back as a user turn.
        _muteUntil = DateTime.now().add(_echoCooldown);
        if (_isActive) _stateController.add(VoiceState.listening);
      }
    });
    return _speakChain;
  }

  /// Speak a multiple-choice question aloud, then capture the next utterance as
  /// its answer. [onResolved] forwards the mapped picks (empty == skip), and
  /// [isAnswered] is checked so a tap on the picker cancels the voice capture.
  Future<void> armQuestion({
    required String question,
    required List<String> options,
    required bool multi,
    required void Function(List<String> picks) onResolved,
    required bool Function() isAnswered,
  }) async {
    if (!_isActive) return;
    _armed = _ArmedQuestion(
      question: question,
      options: options,
      multi: multi,
      onResolved: onResolved,
      isAnswered: isAnswered,
    );
    final spoken = options.isEmpty
        ? question
        : '$question Options are: ${options.join(', ')}.'
              '${multi ? ' You can pick more than one.' : ''}';
    await speak(spoken);
  }

  /// Cancel any pending voice capture for a question (the user tapped instead).
  void disarmQuestion() {
    _armed = null;
  }

  Future<void> _handleUtterance(List<double> samples) async {
    if (!_isActive || samples.isEmpty) return;
    if (_muted) {
      debugPrint('[SetupVoice] dropping echo utterance (speaking/cooldown)');
      return;
    }
    final armed = _armed;
    // Answering an armed question takes priority and must not be blocked by an
    // in-flight free turn (the turn is precisely what's waiting on this answer).
    if (armed != null) {
      if (_answering || armed.isAnswered()) return;
      _answering = true;
      try {
        await _answerArmed(armed, samples);
      } finally {
        _answering = false;
      }
      return;
    }
    if (_turnInFlight) return;
    _turnInFlight = true;
    try {
      final transcript = await _transcribe(samples);
      if (transcript.isEmpty) return;
      await onFreeUtterance?.call(transcript);
    } catch (e) {
      onSystemNote?.call('Voice turn error: $e');
      debugPrint('[SetupVoice] free turn error (non-fatal): $e');
    } finally {
      _turnInFlight = false;
    }
  }

  Future<void> _answerArmed(_ArmedQuestion armed, List<double> samples) async {
    _stateController.add(VoiceState.processing);
    try {
      final transcript = await _transcribe(samples);
      if (transcript.isEmpty || armed.isAnswered()) return;

      final picks = _matchOptions(transcript, armed.options, armed.multi);
      if (picks == null) {
        // No confident match. Re-prompt once, then leave it for a manual tap.
        if (!armed.reprompted) {
          armed.reprompted = true;
          await speak(
            "Sorry, I didn't catch that. Please choose: ${armed.options.join(', ')}.",
          );
        }
        return;
      }
      if (_armed == armed && !armed.isAnswered()) {
        _armed = null;
        armed.onResolved(picks);
      }
    } finally {
      if (_isActive && !_speaking) _stateController.add(VoiceState.listening);
    }
  }

  Future<String> _transcribe(List<double> samples) async {
    final wav = _floatSamplesToWav(samples);
    final result = await (sttBackend ?? backend).transcribeAudio(
      audioBytes: wav,
      filename: 'utterance.wav',
      model: sttModel,
    );
    final text = result.text.trim();
    debugPrint('[SetupVoice] transcript: "$text"');
    return text;
  }

  /// Maps a spoken answer onto [options]. Returns the matched option labels
  /// (empty list == an explicit skip), or null when nothing matched
  /// confidently. For single-select only the first match is kept.
  List<String>? _matchOptions(
    String transcript,
    List<String> options,
    bool multi,
  ) {
    final lower = ' ${transcript.toLowerCase()} ';
    if (RegExp(
      r'\b(skip|none|no thanks|pass|not sure|nothing)\b',
    ).hasMatch(lower)) {
      return const [];
    }

    const ordinals = {
      'first': 0,
      'one': 0,
      '1st': 0,
      'second': 1,
      'two': 1,
      '2nd': 1,
      'third': 2,
      'three': 2,
      '3rd': 2,
      'fourth': 3,
      'four': 3,
      '4th': 3,
      'fifth': 4,
      'five': 4,
      '5th': 4,
      'sixth': 5,
      'six': 5,
      '6th': 5,
    };

    final matched = <String>[];
    void addOption(String opt) {
      if (!matched.contains(opt)) matched.add(opt);
    }

    for (var i = 0; i < options.length; i++) {
      final opt = options[i];
      final optLower = opt.toLowerCase();
      // Whole-option phrase match.
      if (lower.contains(' $optLower ') || lower.contains(optLower)) {
        addOption(opt);
        continue;
      }
      // Significant-token overlap (helps "I want geofencing" → "Geofencing").
      final tokens = optLower
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 4);
      if (tokens.any((t) => lower.contains(' $t'))) {
        addOption(opt);
      }
    }

    // Ordinal references ("the second one", "number three").
    ordinals.forEach((word, idx) {
      if (idx < options.length && RegExp('\\b$word\\b').hasMatch(lower)) {
        addOption(options[idx]);
      }
    });

    if (matched.isEmpty) return null;
    if (!multi && matched.length > 1) return [matched.first];
    return matched;
  }

  Future<void> pauseListening() async {
    await vad.stopListening();
    try {
      await recorder.stopPcmStream();
    } catch (_) {}
    if (_isActive) _stateController.add(VoiceState.idle);
  }

  Future<void> resumeListening() async {
    if (!_isActive) return;
    await _audioSession.ensureVoiceChatSession();
    final pcmStream = await recorder.startPcmStream();
    await vad.startListeningWithStream(
      _gateForEcho(pcmStream.asBroadcastStream()),
    );
    _stateController.add(VoiceState.listening);
  }

  Future<void> endCall() async {
    _isActive = false;
    _armed = null;
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

  Future<void> dispose() async {
    await endCall();
    await _stateController.close();
  }

  /// Strips Markdown formatting so TTS doesn't literally read "asterisk
  /// asterisk", "hash", backticks, etc. Keeps the words, drops the syntax.
  String _sanitizeForSpeech(String text) {
    var s = text;
    // Fenced + inline code: keep the inner text, drop the backticks.
    s = s.replaceAll(RegExp(r'```[a-zA-Z0-9]*'), ' ');
    s = s.replaceAll('`', '');
    // Images / links: ![alt](url) / [label](url) → alt / label.
    s = s.replaceAllMapped(
      RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );
    // Bold / italic / strikethrough emphasis markers.
    s = s.replaceAll(RegExp(r'(\*\*\*|\*\*|\*|___|__|_|~~)'), '');
    // Leading heading hashes and blockquote / list markers per line.
    s = s.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    // Collapse whitespace left behind.
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return s.trim();
  }

  /// Encodes normalized float PCM (-1..1) from the VAD into a 16 kHz mono 16-bit
  /// WAV buffer for the STT endpoint.
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
    writeU32(16);
    writeU16(1);
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
