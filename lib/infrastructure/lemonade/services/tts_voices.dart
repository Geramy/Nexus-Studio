// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Selectable TTS voices for Lemonade's Kokoro speech model.
///
/// Lemonade exposes no "list voices" endpoint, so we ship the standard Kokoro
/// v1 English voice set (same family lemonade_mobile uses). The [id] is what we
/// send as `voice` to `POST /v1/audio/speech`.
class TtsVoice {
  final String id;
  final String label;
  const TtsVoice(this.id, this.label);
}

/// Default voice — matches lemonade_mobile (a neutral US female). Users can
/// pick any other voice per persona.
const String kDefaultTtsVoice = 'af_heart';

const List<TtsVoice> kKokoroVoices = [
  // American — Female
  TtsVoice('af_heart', 'Heart — US Female (default)'),
  TtsVoice('af_bella', 'Bella — US Female'),
  TtsVoice('af_nicole', 'Nicole — US Female'),
  TtsVoice('af_aoede', 'Aoede — US Female'),
  TtsVoice('af_kore', 'Kore — US Female'),
  TtsVoice('af_sarah', 'Sarah — US Female'),
  TtsVoice('af_nova', 'Nova — US Female'),
  TtsVoice('af_sky', 'Sky — US Female'),
  TtsVoice('af_river', 'River — US Female'),
  // American — Male
  TtsVoice('am_adam', 'Adam — US Male'),
  TtsVoice('am_michael', 'Michael — US Male'),
  TtsVoice('am_echo', 'Echo — US Male'),
  TtsVoice('am_eric', 'Eric — US Male'),
  TtsVoice('am_fenrir', 'Fenrir — US Male'),
  TtsVoice('am_liam', 'Liam — US Male'),
  TtsVoice('am_onyx', 'Onyx — US Male'),
  TtsVoice('am_puck', 'Puck — US Male'),
  // British — Female
  TtsVoice('bf_emma', 'Emma — UK Female'),
  TtsVoice('bf_isabella', 'Isabella — UK Female'),
  TtsVoice('bf_alice', 'Alice — UK Female'),
  TtsVoice('bf_lily', 'Lily — UK Female'),
  // British — Male
  TtsVoice('bm_george', 'George — UK Male'),
  TtsVoice('bm_daniel', 'Daniel — UK Male'),
  TtsVoice('bm_fable', 'Fable — UK Male'),
  TtsVoice('bm_lewis', 'Lewis — UK Male'),
];

/// Selectable TTS voices for Zyphra Cloud's ZONOS2 speech model (served from
/// `GET /audio/default-voices`). The [id] is what we send as `voice` to
/// `POST /audio/speech`.
const List<TtsVoice> kZyphraVoices = [
  TtsVoice('american-female-2', 'American Female 2 — Zyphra (default)'),
  TtsVoice('american-female', 'American Female — Zyphra'),
  TtsVoice('american-female-3', 'American Female 3 — Zyphra'),
  TtsVoice('american-male', 'American Male — Zyphra'),
  TtsVoice('american-male-2', 'American Male 2 — Zyphra'),
  TtsVoice('british-female', 'British Female — Zyphra'),
  TtsVoice('british-male', 'British Male — Zyphra'),
  TtsVoice('irish-male', 'Irish Male — Zyphra'),
  TtsVoice('japanese-female', 'Japanese Female — Zyphra'),
  TtsVoice('japanese-male', 'Japanese Male — Zyphra'),
  TtsVoice('anime-girl', 'Anime Girl — Zyphra'),
  TtsVoice('energetic-boy', 'Energetic Boy — Zyphra'),
  TtsVoice('energetic-girl', 'Energetic Girl — Zyphra'),
];

/// Every voice the app can send to a TTS backend (Kokoro for Lemonade, Zyphra
/// for Zyphra Cloud). Ids don't collide across the two namespaces.
const List<TtsVoice> kAllTtsVoices = [...kKokoroVoices, ...kZyphraVoices];

/// Human label for a voice id (falls back to the raw id).
String ttsVoiceLabel(String id) {
  for (final v in kAllTtsVoices) {
    if (v.id == id) return v.label;
  }
  return id;
}
