// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';

/// Voice Activity Detection service using the real Silero VAD from the `vad` package.
///
/// This now follows the proven lemonade_mobile pattern:
///   1. We own the mic via AudioRecorderService (PCM16 16 kHz mono stream).
///   2. We turn the stream into a broadcast.
///   3. We explicitly pass that broadcast to the vad package via the
///      `audioStream:` parameter in startListening().
///
/// This prevents the package from opening its own capture session and gives
/// the Silero v5 ONNX model the correctly-framed audio it expects, avoiding
/// the LSTM tensor shape corruption that used to occur on macOS desktop.
///
/// The public streams (onSpeechStart / onSpeechEnd / onVADMisfire) are still
/// provided for the rest of the app. All error paths are defensive.
class VoiceActivityService {
  VadHandler? _vadHandler;
  bool _isInitialized = false;
  bool _isListening = false;

  final _speechStartController = StreamController<void>.broadcast();
  final _speechEndController = StreamController<List<double>>.broadcast();
  final _vadMisfireController = StreamController<void>.broadcast();

  Stream<void> get onSpeechStart => _speechStartController.stream;
  Stream<List<double>> get onSpeechEnd => _speechEndController.stream;
  Stream<void> get onVADMisfire => _vadMisfireController.stream;

  bool get isListening => _isListening;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _vadHandler = VadHandler.create(isDebug: false);

      _vadHandler!.onSpeechStart.listen((_) {
        debugPrint('[Voice] VAD onSpeechStart');
        if (!_speechStartController.isClosed) _speechStartController.add(null);
      });

      _vadHandler!.onSpeechEnd.listen((audio) {
        debugPrint('[Voice] VAD onSpeechEnd: ${audio.length} samples');
        if (!_speechEndController.isClosed) _speechEndController.add(audio);
      });

      _vadHandler!.onVADMisfire.listen((_) {
        debugPrint('[Voice] VAD onVADMisfire (speech too short — no turn)');
        if (!_vadMisfireController.isClosed) _vadMisfireController.add(null);
      });
    } catch (e, st) {
      debugPrint('VAD initialize failed (non-fatal): $e');
      debugPrintStack(stackTrace: st);
    }

    _isInitialized = true;
  }

  /// Starts the Silero VAD, feeding it the PCM stream we already own.
  ///
  /// This is the critical "lemonade_mobile pattern": we pass `audioStream: pcmStream`
  /// so the vad package consumes frames from our controlled recorder instead of
  /// opening the mic itself. This produces the correct tensor shapes for the v5 model
  /// even on macOS desktop.
  Future<void> startListeningWithStream(Stream<Uint8List> pcmStream) async {
    if (!_isInitialized) await initialize();
    if (_isListening) return;

    try {
      await _vadHandler!.startListening(
        audioStream: pcmStream, // ← the key line (lemonade_mobile pattern)
        positiveSpeechThreshold: 0.45,
        negativeSpeechThreshold: 0.30,
        minSpeechFrames: 3,
        redemptionFrames: 24,
        model: 'v5',
      );
      _isListening = true;
      debugPrint(
        '[Voice] VAD now listening (Silero v5) — feeding our PCM stream',
      );
    } catch (e, st) {
      debugPrint('VAD startListening failed (non-fatal): $e');
      debugPrintStack(stackTrace: st);
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      _vadHandler?.stopListening();
    } catch (_) {}
    _isListening = false;
  }

  Future<void> dispose() async {
    await stopListening();
    try {
      _vadHandler?.dispose();
    } catch (_) {}
    await _speechStartController.close();
    await _speechEndController.close();
    await _vadMisfireController.close();
  }
}
