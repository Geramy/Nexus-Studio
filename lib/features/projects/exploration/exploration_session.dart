// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Glue for the post-setup Exploration (discovery) phase: builds the discovery
/// Coordinator system prompt from the project's existing setup profile, and
/// turns the resulting user-story tree into linked tasks when the user is ready.
library;

import '../../../infrastructure/database/nexus_database.dart';
import '../../../infrastructure/workspace/workspace.dart' show FileEntry;
import '../orchestration/orchestrator_prompts.dart';
import '../project_baseline.dart';

/// A hidden kickoff (sent as the first turn) so the coordinator speaks first.
const String kDiscoveryAutoOpen =
    'Start the discovery interview now: greet me briefly, reflect what you '
    'already know about the project from setup, and ask your first question.';

/// Builds the discovery system prompt, seeded with the project's setup tags +
/// summary so the coordinator already knows whether it's an app, a game, etc.
Future<String> buildDiscoveryPrompt(
  NexusDatabase db,
  int projectId,
  String projectName,
) async {
  final proj = await db.getProjectById(projectId);

  // The discovery system prompt is a SYSTEM SETTING (editable in the Prompts
  // tab, per project) — the hierarchy/chaining behavior lives there, not buried
  // in code. We append the full, AUTHORITATIVE project baseline (every setup
  // decision incl. languages/frameworks/libraries) so discovery is grounded and
  // can't drift the stack — instead of the old partial profile that dropped the
  // tech stack and let stories invent a different one (e.g. a web app becoming a
  // Unity/C# game).
  final instructions = OrchestratorPrompts.fromJson(proj?.orchestratorPromptsJson)
      .raw(OrchestratorPromptField.discoverySystem)
      .replaceAll('{projectName}', projectName);
  final baseline = await buildProjectBaseline(db, projectId);

  return '''
$instructions

$baseline

Tailor your questions to this baseline: if the industry/genre reads like a GAME, ask about the core loop, mechanics, progression, and win/lose; if an APPLICATION, ask about the target users, their key workflows, the main screens, and the data involved. Every story you create must be buildable within the platforms and stack above.''';
}

/// Builds the post-completion EDITOR system prompt: the editor framing (a
/// system setting, editable per project) + the authoritative project baseline
/// (locked stack/scope) + a compact "what was built" summary (the story tree the
/// app was built from), so the maintenance agent knows the stack it must stay
/// within and can locate the features the user refers to.
Future<String> buildEditorPrompt(
  NexusDatabase db,
  int projectId,
  String projectName, {
  String fileTree = '',
}) async {
  final proj = await db.getProjectById(projectId);
  final instructions = OrchestratorPrompts.fromJson(proj?.orchestratorPromptsJson)
      .raw(OrchestratorPromptField.editorSystem)
      .replaceAll('{projectName}', projectName);
  final baseline = await buildProjectBaseline(db, projectId);
  final built = await _builtSummary(db, projectId);

  return '''
$instructions

$baseline

$built${fileTree.isEmpty ? '' : '\n\n$fileTree'}''';
}

/// A compact listing of the project's REAL files, injected into the editor
/// prompt so the agent locates code from the actual tree instead of guessing a
/// path (guessing a missing path is what sent it into "was it ever built?"
/// rumination). Directories + generated/vendor output are skipped; capped.
String buildEditorFileTree(List<FileEntry> entries) {
  final files = entries.where((e) => !e.isDirectory).map((e) => e.path).where((
    p,
  ) {
    final s = p.toLowerCase();
    return !s.endsWith('.g.dart') &&
        !s.endsWith('.freezed.dart') &&
        !s.contains('/build/') &&
        !s.contains('/.dart_tool/') &&
        !s.contains('/node_modules/') &&
        !s.contains('/.git/');
  }).toList()..sort();
  if (files.isEmpty) return '';
  final b = StringBuffer(
    '=== PROJECT FILES (the REAL current tree — locate code here; do NOT guess '
    'paths or re-list directories) ===',
  );
  const cap = 250;
  for (var i = 0; i < files.length && i < cap; i++) {
    b.write('\n${files[i]}');
  }
  if (files.length > cap) b.write('\n… (+${files.length - cap} more)');
  return b.toString();
}

/// Compact "WHAT WAS BUILT" block for the editor: the shipped user-story tree
/// (id · title, with a nesting hint), so the agent can map a request ("tweak the
/// game-over screen") to the feature it belongs to. Read-only context — the
/// editor works from the real files, not the stories.
Future<String> _builtSummary(NexusDatabase db, int projectId) async {
  final stories = await db.getUserStoriesForProject(projectId);
  final b = StringBuffer(
    '=== WHAT WAS BUILT (the shipped feature tree) ===\n'
    'This project is already built and was passing CI at completion. These are '
    'the user stories it was built from — use them to locate the feature a '
    'request refers to (the real source of truth is the code in the workspace):',
  );
  if (stories.isEmpty) {
    b.write('\n(no user-story tree was recorded for this project)');
  } else {
    final byId = {for (final s in stories) s.story_pk: s};
    for (final s in stories) {
      final nested = s.parent_story_fk != null && byId.containsKey(s.parent_story_fk);
      b.write('\n${nested ? '    ↳ ' : '- '}${s.title}');
    }
  }
  return b.toString();
}

// Task generation from the story tree lives in task_generator.dart
// (TaskGenerator) — it runs a scoped AI session per story to produce 1..N tasks.
