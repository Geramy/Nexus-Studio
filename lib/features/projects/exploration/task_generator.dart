// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// "Generate tasks from stories": walks the user-story tree and feeds EACH story
/// into its own small SCOPED AI session (fresh, minimal context) that breaks it
/// into 1..N engineering tasks (across the layers it touches). Exposes per-story
/// progress so the Exploration screen can show a bar on each story while it runs.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../infrastructure/database/nexus_database.dart';
import '../../../infrastructure/inference/inference_backend.dart';
import '../../../infrastructure/inference/inference_backend_factory.dart';
import '../../../infrastructure/inference/routed_server.dart';
import '../../../infrastructure/inference/scoped_completion.dart';
import '../../../infrastructure/models/ui/inference_server.dart' as ui_server;
import '../agent_assignment.dart';
import '../orchestration/orchestrator_prompts.dart';

enum StoryGenStatus { pending, generating, done, error }

class StoryGen {
  const StoryGen(this.status, [this.tasks = 0]);
  final StoryGenStatus status;
  final int tasks;
}

/// Immutable progress snapshot for the whole run.
class TaskGenProgress {
  const TaskGenProgress({
    this.running = false,
    this.done = false,
    this.byStory = const {},
    this.totalStories = 0,
    this.doneStories = 0,
    this.totalTasks = 0,
    this.failedStories = 0,
    this.error,
  });

  final bool running;
  final bool done;
  final Map<int, StoryGen> byStory; // story_pk → its generation state
  final int totalStories;
  final int doneStories;
  final int totalTasks;

  /// Stories whose task creation threw (and produced no task at all).
  final int failedStories;

  /// First fatal error that aborted the whole run (vs a single story failing),
  /// surfaced to the user instead of silently reporting "0 tasks".
  final String? error;

  double get fraction => totalStories == 0 ? 0 : doneStories / totalStories;

  TaskGenProgress copyWith({
    bool? running,
    bool? done,
    Map<int, StoryGen>? byStory,
    int? totalStories,
    int? doneStories,
    int? totalTasks,
    int? failedStories,
    String? error,
  }) => TaskGenProgress(
    running: running ?? this.running,
    done: done ?? this.done,
    byStory: byStory ?? this.byStory,
    totalStories: totalStories ?? this.totalStories,
    doneStories: doneStories ?? this.doneStories,
    totalTasks: totalTasks ?? this.totalTasks,
    failedStories: failedStories ?? this.failedStories,
    error: error ?? this.error,
  );
}

class TaskGenerator extends ChangeNotifier {
  TaskGenerator(this._ref, this.projectId);
  final Ref _ref;
  final int projectId;

  TaskGenProgress progress = const TaskGenProgress();

  void _emit(TaskGenProgress p) {
    progress = p;
    notifyListeners();
  }

  /// Walk the leaf stories and generate tasks for each via a scoped AI call.
  Future<void> run() async {
    // Re-entrancy guard set SYNCHRONOUSLY (before any await) so a double-tap
    // can't start two runs and create every task twice.
    if (progress.running) return;
    _emit(progress.copyWith(running: true));
    final db = _ref.read(nexusDatabaseProvider);

    var totalTasks = 0;
    var doneStories = 0;
    var failedStories = 0;
    try {
      final stories = await db.getUserStoriesForProject(projectId);
      final parents = <int>{
        for (final s in stories)
          if (s.parent_story_fk != null) s.parent_story_fk!,
      };
      // Leaves = concrete, buildable stories (epics are just groupings).
      final leaves = stories
          .where((s) => !parents.contains(s.story_pk))
          .toList();

      _emit(
        TaskGenProgress(
          running: true,
          totalStories: leaves.length,
          byStory: {
            for (final s in leaves)
              s.story_pk: const StoryGen(StoryGenStatus.pending),
          },
        ),
      );

      final resolved = await _resolveBackend(db, projectId);
      final worker = await resolveDefaultWorkerPersonaId(db, projectId);
      final project = await db.getProjectById(projectId);
      final sys = OrchestratorPrompts.fromJson(
        project?.orchestratorPromptsJson,
      ).raw(OrchestratorPromptField.taskGenSystem);
      final profile = await _profile(db, projectId);

      for (final s in leaves) {
        _setStory(s.story_pk, const StoryGen(StoryGenStatus.generating));
        try {
          // _tasksForStory swallows AI/parse errors and returns [] so a flaky or
          // unconfigured backend degrades to the one-task-per-story fallback
          // below rather than producing ZERO tasks for the whole run.
          final specs = await _tasksForStory(db, resolved, sys, profile, s);
          var made = 0;
          for (final t in specs) {
            final title = (t['title'] ?? '').toString().trim();
            if (title.isEmpty) continue;
            final ac = (t['acceptance_criteria'] ?? '').toString().trim();
            final layer = (t['layer'] ?? '').toString().trim();
            // Route each task to a layer-appropriate specialist persona when one
            // exists (UI/UX for client, Database for db, …), else the worker.
            final agentPk = await resolveWorkerPersonaForLayer(
              db,
              projectId,
              layer,
              fallback: worker,
            );
            await db.createTaskInProject(
              projectPk: projectId,
              title: title,
              description: (t['description'] ?? '').toString().trim(),
              acceptanceCriteria: ac.isEmpty ? null : ac,
              verification: ac.isEmpty
                  ? null
                  : 'Confirm every acceptance criterion above is satisfied; run '
                        'the project\'s build/tests where applicable.',
              agentPk: agentPk,
              storyPk: s.story_pk,
            );
            made++;
          }
          // Never leave a story with zero tasks — fall back to one task = story.
          if (made == 0) {
            await db.createTaskInProject(
              projectPk: projectId,
              title: s.title,
              description: s.narrative,
              agentPk: worker,
              storyPk: s.story_pk,
            );
            made = 1;
          }
          totalTasks += made;
          _setStory(s.story_pk, StoryGen(StoryGenStatus.done, made));
        } catch (e) {
          // A story only lands here if even the fallback task INSERT threw — a
          // real DB/code break, not just a missing AI backend. Record it so the
          // UI can report "N stories failed: <reason>" instead of a silent 0.
          debugPrint('task-gen for story #${s.story_pk} failed: $e');
          failedStories++;
          _setStory(s.story_pk, const StoryGen(StoryGenStatus.error));
          _emit(progress.copyWith(failedStories: failedStories, error: '$e'));
        }
        doneStories++;
        _emit(
          progress.copyWith(doneStories: doneStories, totalTasks: totalTasks),
        );
      }

      // Leave the Exploration phase and start orchestration only once done.
      await db.setProjectExplorationStatus(projectId, 'complete');
      if (totalTasks > 0) {
        await db.setProjectOrchestrationState(projectId, 'running');
      }
      _emit(progress.copyWith(running: false, done: true));
    } catch (e, st) {
      // Anything thrown OUTSIDE the per-story loop (backend/profile resolution,
      // status writes) would otherwise leave `running` stuck true forever and
      // the UI spinning with no error. Surface it and release the guard.
      debugPrint('task-gen run failed: $e\n$st');
      _emit(progress.copyWith(running: false, done: true, error: '$e'));
    }
  }

  void _setStory(int storyPk, StoryGen g) {
    _emit(progress.copyWith(byStory: {...progress.byStory, storyPk: g}));
  }

  /// One scoped AI call → the task specs for a single story (or [] on no backend).
  Future<List<Map<String, dynamic>>> _tasksForStory(
    NexusDatabase db,
    ({InferenceBackend backend, String model})? resolved,
    String system,
    String profile,
    UserStory s,
  ) async {
    if (resolved == null) return const [];
    final notes = await db.getNotesForStory(s.story_pk);
    final ac = (s.acceptanceCriteria ?? '').trim();
    final b = StringBuffer()
      ..writeln('STORY: ${s.title}');
    if (s.narrative.trim().isNotEmpty) {
      b.writeln('Narrative: ${s.narrative.trim()}');
    }
    if (ac.isNotEmpty) b.writeln('Acceptance criteria:\n$ac');
    if (notes.isNotEmpty) {
      b.writeln('Notes:');
      for (final n in notes) {
        b.writeln('- ${n.body.trim()}');
      }
    }
    b.writeln('\nPROJECT TECH PROFILE:\n$profile');

    // A backend that's down, unauthorized, or returns junk must NOT abort the
    // story (which would skip the one-task-per-story fallback in run() and yield
    // zero tasks). Degrade to [] and let the fallback create the story-as-task.
    try {
      final raw = await scopedComplete(
        backend: resolved.backend,
        model: resolved.model,
        system: system,
        user: b.toString(),
        maxTokens: 900,
      );
      return parseJsonObjectArray(raw);
    } catch (e) {
      debugPrint('task-gen scoped call for story #${s.story_pk} failed: $e');
      return const [];
    }
  }

  Future<String> _profile(NexusDatabase db, int projectId) async {
    final tags = await db.getTagsForProject(projectId);
    final byCat = <String, List<String>>{};
    for (final t in tags) {
      if (t.status == 'rejected') continue;
      (byCat[t.category] ??= <String>[]).add(t.value);
    }
    String c(String k) => (byCat[k] ?? const []).join(', ');
    return 'Platforms: ${c('platforms')}\nLanguages: ${c('languages')}\n'
        'Frameworks: ${c('frameworks')}\nDatabases: ${c('databases')}\n'
        'Services: ${c('services')}';
  }

  /// Resolve the project's routed inference backend + model (the configured
  /// selectedModel — i.e. the Omni collection — like the rest of the app).
  Future<({InferenceBackend backend, String model})?> _resolveBackend(
    NexusDatabase db,
    int projectId,
  ) async {
    final project = await db.getProjectById(projectId);
    if (project == null) return null;
    final servers = await db.getInferenceServersForClient(project.client_fk);
    if (servers.isEmpty) return null;
    final chosen = servers.firstWhere(
      (s) => isRoutedProviderType(s.providerType),
      orElse: () => servers.first,
    );
    var models = const <String>[];
    try {
      models = (jsonDecode(chosen.availableModelsJson) as List).cast<String>();
    } catch (_) {}
    final model =
        (chosen.selectedModel != null && chosen.selectedModel!.trim().isNotEmpty)
        ? chosen.selectedModel!.trim()
        : (models.isNotEmpty ? models.first : 'default-coordinator');
    final uiServer = ui_server.InferenceServer(
      id: chosen.server_pk.toString(),
      name: chosen.name,
      baseUrl: chosen.baseUrl,
      apiKey: chosen.apiKey,
      providerType: 'lemonade',
      selectedModel: chosen.selectedModel,
      availableModels: models,
    );
    return (
      backend: backendForServer(uiServer, agentName: 'TaskGen'),
      model: model,
    );
  }
}

final taskGeneratorProvider =
    ChangeNotifierProvider.family<TaskGenerator, int>(
      (ref, projectId) => TaskGenerator(ref, projectId),
    );
