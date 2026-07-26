// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The PROJECT BASELINE: a single, authoritative summary of every decision the
/// setup interview captured (industries, sub-axes like genre, platforms,
/// objectives, features, languages, frameworks, databases, libraries, services)
/// plus the project summary. It is injected as HARD CONSTRAINTS into every
/// downstream AI surface — the discovery (stories) interview, per-story task
/// generation, and the worker agents — so the stack and scope chosen at setup
/// are never silently overridden later (e.g. a web+desktop app turning into a
/// C#/Unity game during discovery).
library;

import 'dart:convert';

import '../../infrastructure/database/nexus_database.dart';

/// The standard setup categories, in display order. Anything else captured
/// (e.g. an industry sub-axis like `genre`) is surfaced after Industries.
const List<String> _standardCategories = [
  'industries',
  'platforms',
  'objectives',
  'features',
  'languages',
  'frameworks',
  'databases',
  'libraries',
  'services',
];

String _titleCase(String key) =>
    key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}';

/// The user's OWN words from the setup interview transcript (their initial idea
/// + answers), oldest-first and length-capped. This gives downstream AIs the
/// concrete description — e.g. "a Flappy Bird clone …" — even when the captured
/// tag set is sparse, so discovery never starts "fresh" with no context.
String _setupNarrative(String? transcriptJson) {
  if (transcriptJson == null || transcriptJson.trim().isEmpty) return '';
  try {
    final turns = jsonDecode(transcriptJson) as List;
    final userMsgs = <String>[];
    for (final t in turns) {
      if (t is Map && t['role'] == 'user' && t['content'] is String) {
        final c = (t['content'] as String).trim();
        if (c.isNotEmpty) userMsgs.add(c);
      }
    }
    if (userMsgs.isEmpty) return '';
    var text = userMsgs.join('\n');
    const cap = 1500;
    if (text.length > cap) text = '${text.substring(0, cap).trimRight()}…';
    return text;
  } catch (_) {
    return '';
  }
}

/// Build the authoritative baseline block for [projectId] from its accepted +
/// proposed setup tags (rejected ones excluded) and project summary. Returns a
/// ready-to-inject system-prompt section.
Future<String> buildProjectBaseline(NexusDatabase db, int projectId) async {
  final tags = await db.getTagsForProject(projectId);
  final byCat = <String, List<String>>{};
  for (final t in tags) {
    if (t.status == 'rejected') continue;
    (byCat[t.category] ??= <String>[]).add(t.value);
  }
  String cat(String k) {
    final v = byCat[k] ?? const [];
    return v.isEmpty ? '—' : v.join(', ');
  }

  // Features and the retired `objectives` section are one axis now — present
  // their UNION under a single "Features & capabilities" line (deduped,
  // case-insensitive) so legacy projects' objectives tags still show.
  String featuresLine() {
    final seen = <String>{};
    final merged = <String>[
      for (final v in [...?byCat['features'], ...?byCat['objectives']])
        if (seen.add(v.toLowerCase())) v,
    ];
    return merged.isEmpty ? '—' : merged.join(', ');
  }

  // Industry sub-axes / any non-standard categories (e.g. `genre`), shown right
  // after Industries so the domain reads correctly.
  final extras =
      byCat.keys.where((k) => !_standardCategories.contains(k)).toList()..sort();

  final lines = <String>[
    '- Industries: ${cat('industries')}',
    for (final k in extras) '- ${_titleCase(k)}: ${cat(k)}',
    '- Target platforms: ${cat('platforms')}',
    '- Features & capabilities: ${featuresLine()}',
    '- Languages: ${cat('languages')}',
    '- Frameworks / engines: ${cat('frameworks')}',
    '- Databases: ${cat('databases')}',
    '- Libraries: ${cat('libraries')}',
    '- External services: ${cat('services')}',
  ];

  final proj = await db.getProjectById(projectId);
  final summary = (proj?.projectSummaryMd ?? '').trim();
  final described = _setupNarrative(proj?.setupTranscriptJson);

  return '''
=== PROJECT BASELINE — locked from the setup interview (AUTHORITATIVE) ===
These decisions were made with the user during setup and are the single source of
truth for this project. Every user story, task, and line of code MUST conform to
them. Do NOT introduce a platform, language, framework, engine, or major scope
that is not listed here; if something genuinely seems missing, ASK the user — do
NOT silently substitute a different technology.
${described.isEmpty ? '' : '\nWhat the user described at setup (their own words):\n$described\n'}
${lines.join('\n')}
${summary.isEmpty ? '' : '\nProject summary:\n$summary\n'}
HARD RULES:
- Build for EVERY one of the Target platforms above — the app must actually RUN on
  each. If WEB is one of them, the app MUST work in a browser: NEVER use a
  native-only API on a code path that runs on web — no `dart:io` (File/Directory/
  Platform/Process), no native path_provider paths, no FFI, and no native-only
  database connection (e.g. drift's `NativeDatabase`/sqlite3 FFI). These throw
  "Unsupported operation" on web and leave a BLANK screen. Instead use a
  cross-platform setup: a `kIsWeb` guard or conditional imports
  (`import 'x_native.dart' if (dart.library.js_interop) 'x_web.dart'`) that pick a
  web backend on web (e.g. drift's `WasmDatabase`/IndexedDB + the sqlite3 wasm +
  drift worker assets, or `shared_preferences`/`hive` which already support web),
  and declare the web dependencies/assets in the manifest. A web-targeted app that
  renders blank is a FAILED build, not done.
- Write code ONLY in the listed Languages, using the listed Frameworks / engines —
  do NOT swap in a different stack. (e.g. if the platforms/frameworks describe a
  WEB or DESKTOP app, do not choose a native game engine like Unity/C#; and
  vice-versa.)
- Use the listed Databases, Libraries, and External services; don't invent others.
- Keep scope to the Features & capabilities above.''';
}
