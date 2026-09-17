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
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/providers/database_provider.dart';
import '../../../infrastructure/database/nexus_database.dart';
import '../../../infrastructure/inference/inference_backend.dart';
import '../../../infrastructure/inference/inference_backend_factory.dart';
import '../../../infrastructure/inference/routed_server.dart';
import '../../../infrastructure/inference/scoped_completion.dart';
import '../../../infrastructure/lemonade/services/persona_model_resolver.dart'
    show resolveAgentChatModel;
import '../../../infrastructure/models/ui/inference_server.dart' as ui_server;
import '../agent_assignment.dart';
import '../orchestration/orchestrator_prompts.dart';
import '../project_baseline.dart';

enum StoryGenStatus { pending, generating, done, error }

class StoryGen {
  const StoryGen(this.status, [this.tasks = 0]);
  final StoryGenStatus status;
  final int tasks;
}

const _generatedTaskVerification =
    'Inspect the task branch and confirm every acceptance criterion is fully '
    'implemented and reachable. Reject placeholders, empty implementations, '
    'or destructive regressions.';

String _generatedTaskAcceptance(
  String title,
  String description,
  String provided,
) {
  if (provided.trim().isNotEmpty) return provided.trim();
  final outcome = description.trim();
  if (outcome.isNotEmpty) {
    return 'The completed implementation delivers this user outcome end to '
        'end: $outcome';
  }
  return '$title is fully implemented, wired into the application, and has no '
      'placeholder or empty behavior.';
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
      // The single TOP root (no parent) is a condensed view of the whole project
      // — it's the Templater's base spec (the scaffold is built from it) and is
      // NOT turned into a worker task. EVERY other node, at any depth (not just
      // the leaves), becomes task(s) so mid-tree stories aren't skipped.
      final roots = stories.where((s) => s.parent_story_fk == null).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      final templaterRootPk = roots.isNotEmpty ? roots.first.story_pk : null;
      // Parent-first order so a child story's tasks can link UNDER its parent
      // story's task — the task tree then mirrors the story tree instead of
      // being a flat, seemingly-random pile.
      // Exclude EVERY parentless root story from task generation — a top-level
      // story is structural (the templater base, or a project-overview /
      // category), never a worker task; its CHILDREN are the features. Excluding
      // only roots.first left a 2nd root ("General E-commerce Store" overview)
      // to become a vague "build the whole store" mega-task that looped forever.
      final rootPks = {for (final r in roots) r.story_pk};
      var buildable = _storiesParentFirst(
        stories,
        templaterRootPk,
      ).where((s) => !rootPks.contains(s.story_pk)).toList();
      // Safety net: if the tree is degenerately FLAT (every story is a root, so
      // that filter emptied the backlog), fall back to excluding only the
      // templater base so we never drop all the features.
      if (buildable.isEmpty) {
        buildable = _storiesParentFirst(stories, templaterRootPk);
      }

      _emit(
        TaskGenProgress(
          running: true,
          totalStories: buildable.length,
          byStory: {
            for (final s in buildable)
              s.story_pk: const StoryGen(StoryGenStatus.pending),
          },
        ),
      );
      // story_pk → its first generated task, used as the parent anchor for the
      // tasks of its child stories.
      final storyRepTask = <int, int>{};

      final resolved = await _resolveBackend(db, projectId);
      final worker = await resolveDefaultWorkerPersonaId(db, projectId);
      final project = await db.getProjectById(projectId);
      final sys = OrchestratorPrompts.fromJson(
        project?.orchestratorPromptsJson,
      ).raw(OrchestratorPromptField.taskGenSystem);
      // The full, AUTHORITATIVE baseline (platforms + stack + scope) so each
      // story's tasks are generated within the project's locked tech choices.
      final profile = await buildProjectBaseline(db, projectId);

      // TOKEN LEVER (C): cluster related stories into FEWER, FATTER tasks so the
      // build spins up far fewer cold-start worker sessions (each re-establishes
      // the whole context). Falls back to the per-story path below when grouping
      // isn't worth it or the AI is unavailable.
      // Deterministic title-keyword clustering first (reliable — the routed
      // model won't emit the clustering JSON), then the story-tree structure as
      // a fallback for genuinely nested trees. Oversized groups are split so no
      // single task balloons to a monster (a 9-story group ran 34 rounds, hung,
      // and serialised everything behind it).
      final rawGroups =
          _groupStoriesByKeyword(buildable) ??
          _groupStoriesByTree(buildable, stories, templaterRootPk);
      final groups = rawGroups == null
          ? null
          : _splitOversizedGroups(rawGroups, _maxStoriesPerGroup);
      if (groups != null) {
        // ignore: avoid_print
        print(
          '[TaskGen] grouped ${buildable.length} stories → ${groups.length} '
          'feature-area task sets for project $projectId',
        );
        for (final group in groups) {
          for (final s in group) {
            _setStory(s.story_pk, const StoryGen(StoryGenStatus.generating));
          }
          final rep = group.first;
          try {
            final specs = group.length == 1
                ? await _tasksForStory(db, resolved, sys, profile, rep)
                : await _tasksForGroup(db, resolved, profile, group);
            var made = await _createTasksFromSpecs(
              db,
              specs,
              storyPk: rep.story_pk,
              parentPk: null,
              worker: worker,
            );
            if (made == 0) {
              // Never leave an area with zero tasks: one combined task, and fold
              // in every story's narrative so no context is lost.
              final combined = group
                  .map((s) => '### ${s.title}\n${s.narrative.trim()}')
                  .join('\n\n');
              await db.createTaskInProject(
                projectPk: projectId,
                title: rep.title,
                description: combined,
                acceptanceCriteria: _generatedTaskAcceptance(
                  rep.title,
                  combined,
                  '',
                ),
                verification: _generatedTaskVerification,
                agentPk: worker,
                storyPk: rep.story_pk,
              );
              made = 1;
            }
            totalTasks += made;
            for (final s in group) {
              _setStory(s.story_pk, StoryGen(StoryGenStatus.done, made));
              doneStories++;
            }
          } catch (e) {
            debugPrint('task-gen for group "${rep.title}" failed: $e');
            failedStories += group.length;
            for (final s in group) {
              _setStory(s.story_pk, const StoryGen(StoryGenStatus.error));
            }
            _emit(progress.copyWith(failedStories: failedStories, error: '$e'));
          }
          _emit(
            progress.copyWith(doneStories: doneStories, totalTasks: totalTasks),
          );
        }
      } else {
        for (final s in buildable) {
          _setStory(s.story_pk, const StoryGen(StoryGenStatus.generating));
          // The parent anchor: a child story's tasks hang under its parent story's
          // first task, so the task tree mirrors the story tree. A story whose
          // parent is the Templater root (or which has no parent) is top-level.
          final parentStoryPk = s.parent_story_fk;
          final parentTaskPk =
              (parentStoryPk != null && parentStoryPk != templaterRootPk)
              ? storyRepTask[parentStoryPk]
              : null;
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
              final description = (t['description'] ?? '').toString().trim();
              final acceptance = _generatedTaskAcceptance(
                title,
                description,
                ac,
              );
              final layer = (t['layer'] ?? '').toString().trim();
              // Route each task to a layer-appropriate specialist persona when one
              // exists (UI/UX for client, Database for db, …), else the worker.
              final agentPk = await resolveWorkerPersonaForLayer(
                db,
                projectId,
                layer,
                fallback: worker,
              );
              final taskPk = await db.createTaskInProject(
                projectPk: projectId,
                title: title,
                description: description,
                acceptanceCriteria: acceptance,
                verification: _generatedTaskVerification,
                agentPk: agentPk,
                storyPk: s.story_pk,
                parentPk: parentTaskPk,
              );
              storyRepTask.putIfAbsent(s.story_pk, () => taskPk);
              made++;
            }
            // Never leave a story with zero tasks — fall back to one task = story.
            if (made == 0) {
              final taskPk = await db.createTaskInProject(
                projectPk: projectId,
                title: s.title,
                description: s.narrative,
                acceptanceCriteria: _generatedTaskAcceptance(
                  s.title,
                  s.narrative,
                  '',
                ),
                verification: _generatedTaskVerification,
                agentPk: worker,
                storyPk: s.story_pk,
                parentPk: parentTaskPk,
              );
              storyRepTask.putIfAbsent(s.story_pk, () => taskPk);
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
      }

      // Leave the Exploration phase and start orchestration only once done.
      await db.setProjectExplorationStatus(projectId, 'complete');
      if (totalTasks > 0) {
        // Free the interactive setup/discovery Coordinator's connection before
        // the autonomous orchestrator/templater start — otherwise its lingering
        // socket keeps eating the reserved Coordinator slot and the templater +
        // workers 429 (too_many_connections).
        resetInferenceConnections();
        // Gate the run on the Templater: it scaffolds a compiling base project
        // (committed to main) and splits the backlog into sequential milestones
        // BEFORE any worker starts — so the agents don't all race to create the
        // project from an empty main at once.
        await db.setProjectTemplateStatus(projectId, 'pending');
        await db.setProjectOrchestrationState(projectId, 'running');
        // ignore: avoid_print
        print(
          '[TaskGen] done: $totalTasks task(s); set templateStatus=pending, '
          'orchestrationState=running for project $projectId',
        );
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

  /// Order stories so a PARENT always precedes its children (topological),
  /// dropping [rootPk] (the Templater's base spec). A story whose parent is the
  /// root or null is top-level. Cycle/orphan leftovers are appended as-is.
  List<UserStory> _storiesParentFirst(List<UserStory> all, int? rootPk) {
    final remaining = all.where((s) => s.story_pk != rootPk).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final out = <UserStory>[];
    final added = <int>{};
    bool parentReady(int? p) => p == null || p == rootPk || added.contains(p);
    var progressed = true;
    while (progressed && remaining.isNotEmpty) {
      progressed = false;
      remaining.removeWhere((s) {
        if (!parentReady(s.parent_story_fk)) return false;
        out.add(s);
        added.add(s.story_pk);
        progressed = true;
        return true;
      });
    }
    out.addAll(remaining); // cycle/orphan safety net
    return out;
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
    final b = StringBuffer()..writeln('STORY: ${s.title}');
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
    b.writeln('\n$profile');

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

  /// Create the DB tasks for a list of AI-produced task [specs], routing each to
  /// a layer-appropriate persona. Returns how many were created. Shared by the
  /// per-story and grouped paths.
  Future<int> _createTasksFromSpecs(
    NexusDatabase db,
    List<Map<String, dynamic>> specs, {
    required int storyPk,
    required int? parentPk,
    required int? worker,
    void Function(int firstTaskPk)? onFirstTask,
  }) async {
    var made = 0;
    for (final t in specs) {
      final title = (t['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final ac = (t['acceptance_criteria'] ?? '').toString().trim();
      final description = (t['description'] ?? '').toString().trim();
      final acceptance = _generatedTaskAcceptance(title, description, ac);
      final layer = (t['layer'] ?? '').toString().trim();
      final agentPk = await resolveWorkerPersonaForLayer(
        db,
        projectId,
        layer,
        fallback: worker,
      );
      final taskPk = await db.createTaskInProject(
        projectPk: projectId,
        title: title,
        description: description,
        acceptanceCriteria: acceptance,
        verification: _generatedTaskVerification,
        agentPk: agentPk,
        storyPk: storyPk,
        parentPk: parentPk,
      );
      if (made == 0) onFirstTask?.call(taskPk);
      made++;
    }
    return made;
  }

  /// Common words that don't identify a feature area — dropped before keyword
  /// clustering so stories group on their real subject (account, product, …).
  static const Set<String> _stopWords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'of',
    'to',
    'for',
    'in',
    'on',
    'with',
    'my',
    'their',
    'as',
    'i',
    'want',
    'so',
    'that',
    'can',
    'be',
    'able',
    'view',
    'see',
    'manage',
    'add',
    'edit',
    'create',
    'update',
    'delete',
    'remove',
    'set',
    'get',
    'use',
    'using',
    'via',
    'from',
    'is',
    'are',
    'it',
    'this',
    'page',
    'pages',
    'system',
    'feature',
    'user',
    'users',
    'app',
    'when',
    'where',
    'which',
    'into',
    'per',
    'each',
    'all',
    'any',
    'new',
    'own',
    'support',
    'ability',
    'allow',
    'let',
    'lets',
  };

  /// Deterministic title-keyword clustering — NO AI (the routed model won't
  /// reliably emit the clustering JSON). Groups stories that share a significant
  /// title word: all "…Account…" together, all "…Product…" together, etc. —
  /// exactly "scan the titles and group like ones". Each story joins the group
  /// of its MOST-SHARED title word; a story whose words are all unique stays its
  /// own group. Returns null if it can't meaningfully reduce, or would collapse
  /// nearly everything into one mega-group (so the caller falls through).
  List<List<UserStory>>? _groupStoriesByKeyword(List<UserStory> buildable) {
    if (buildable.length < 6) return null;
    String stem(String w) =>
        // Crude singularisation so "products"/"product" share a key.
        (w.length > 4 && w.endsWith('s')) ? w.substring(0, w.length - 1) : w;

    final wordsOf = <int, Set<String>>{};
    final freq = <String, int>{};
    for (final s in buildable) {
      final ws = <String>{};
      // Split on ANY non-alphanumeric so "Return/Refund", "add/list" yield their
      // real words instead of one glued token.
      for (final tok in s.title.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        final w = stem(tok);
        if (w.length < 3 || _stopWords.contains(w)) continue;
        ws.add(w);
      }
      wordsOf[s.story_pk] = ws;
      for (final w in ws) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final byTheme = <String, List<UserStory>>{};
    final order = <String>[];
    var solo = 0;
    for (final s in buildable) {
      final shared =
          wordsOf[s.story_pk]!.where((w) => (freq[w] ?? 0) >= 2).toList()
            ..sort((a, b) => (freq[b] ?? 0).compareTo(freq[a] ?? 0));
      final theme = shared.isEmpty ? '__solo${solo++}' : shared.first;
      byTheme
          .putIfAbsent(theme, () {
            order.add(theme);
            return <UserStory>[];
          })
          .add(s);
    }
    final groups = [for (final t in order) byTheme[t]!];
    final biggest = groups.fold<int>(0, (m, g) => g.length > m ? g.length : m);
    // Must reduce, and must not lump the majority into one group.
    if (groups.length < 2 ||
        groups.length >= buildable.length ||
        biggest * 10 > buildable.length * 7) {
      return null;
    }
    // ignore: avoid_print
    print(
      '[TaskGen] keyword-grouped ${buildable.length} stories → '
      '${groups.length} theme(s) (biggest area=$biggest)',
    );
    return groups;
  }

  /// Max stories a single group may cover before it's split — keeps grouped
  /// tasks from ballooning into monster sessions (a 9-story group ran 34 rounds
  /// and hung). Still well below the 33-per-project fan-out.
  static const int _maxStoriesPerGroup = 5;

  /// Split any group larger than [maxSize] into order-preserving sub-groups of at
  /// most [maxSize], so grouping can't create a task too big to finish in one
  /// session. (Two sub-groups of the same area WILL touch overlapping files, but
  /// the footprint gate serialises them and the resolver-then-redo path handles
  /// any merge conflict — far better than one task that hangs the pipeline.)
  List<List<UserStory>> _splitOversizedGroups(
    List<List<UserStory>> groups,
    int maxSize,
  ) {
    var split = false;
    final out = <List<UserStory>>[];
    for (final g in groups) {
      if (g.length <= maxSize) {
        out.add(g);
        continue;
      }
      split = true;
      for (var i = 0; i < g.length; i += maxSize) {
        out.add(g.sublist(i, i + maxSize > g.length ? g.length : i + maxSize));
      }
    }
    if (split) {
      // ignore: avoid_print
      print(
        '[TaskGen] split oversized group(s): ${groups.length} → '
        '${out.length} units (cap $maxSize/group)',
      );
    }
    return out;
  }

  /// AI clustering — kept for when the backend can reliably return the JSON
  /// (today the routed model returns empty content, so [run] uses the
  /// deterministic keyword clusterer instead). NEVER drops a story.
  // ignore: unused_element
  Future<List<List<UserStory>>?> _groupStories(
    NexusDatabase db,
    ({InferenceBackend backend, String model})? resolved,
    List<UserStory> stories,
  ) async {
    if (resolved == null || stories.length < 6)
      return null; // too few to bother
    final byPk = {for (final s in stories) s.story_pk: s};
    final b = StringBuffer()
      ..writeln('User stories to cluster (id — title — one-line):');
    for (final s in stories) {
      final oneLine = s.narrative.trim().split('\n').first;
      final snippet = oneLine.length > 110
          ? oneLine.substring(0, 110)
          : oneLine;
      b.writeln('#${s.story_pk} — ${s.title} — $snippet');
    }
    final target = (stories.length / 2.5).ceil().clamp(3, stories.length);
    const sys =
        'You group user stories into cohesive FEATURE AREAS so each area is built '
        'as ONE larger task set instead of many tiny per-story tasks. Cluster by '
        'shared subject — e.g. accounts/auth, admin, products/catalog, '
        'search & filtering, cart & checkout, orders, reviews, shipping. Put '
        'stories about the SAME area in one group; keep a genuinely standalone '
        'story in its own group. Return ONLY a JSON array (no prose, no fences): '
        '[{"title": "<feature area>", "story_pks": [<ids>]}]. Every id appears in '
        'exactly one group.';
    try {
      final raw = await scopedComplete(
        backend: resolved.backend,
        model: resolved.model,
        // Big budget: this model tends to ignore enableThinking:false and burn
        // tokens reasoning before the JSON — too small a cap returns EMPTY
        // content (observed raw=0c). Give it room for think + output.
        maxTokens: 4000,
        system: sys,
        user: 'Aim for roughly $target groups.\n\n$b',
      );
      var arr = parseJsonObjectArray(raw);
      if (arr.isEmpty) arr = parseLooseJsonObjects(raw);
      // ignore: avoid_print
      print(
        '[TaskGen] grouping: raw=${raw.length}c, parsed=${arr.length} '
        'candidate group(s) for ${stories.length} stories',
      );
      if (arr.isEmpty) {
        debugPrint(
          '[TaskGen] grouping raw (unparseable): '
          '${raw.length > 300 ? raw.substring(0, 300) : raw}',
        );
        return null;
      }
      final used = <int>{};
      final groups = <List<UserStory>>[];
      for (final g in arr) {
        final rawPks = g['story_pks'];
        if (rawPks is! List) continue;
        final grp = <UserStory>[];
        for (final e in rawPks) {
          final pk = e is num ? e.toInt() : int.tryParse('$e');
          if (pk != null && byPk.containsKey(pk) && used.add(pk)) {
            grp.add(byPk[pk]!);
          }
        }
        if (grp.isNotEmpty) groups.add(grp);
      }
      final clustered = groups.length; // groups the AI actually formed
      // Never drop a story the AI missed (each becomes its own singleton).
      for (final s in stories) {
        if (!used.contains(s.story_pk)) groups.add([s]);
      }
      // ignore: avoid_print
      print(
        '[TaskGen] grouping formed $clustered cluster(s) + '
        '${groups.length - clustered} leftover singleton(s) = '
        '${groups.length} unit(s) from ${stories.length} stories',
      );
      // Only worth it if it actually reduced the unit count.
      if (groups.isEmpty || groups.length >= stories.length) return null;
      return groups;
    } catch (e) {
      debugPrint('story grouping failed: $e');
      return null;
    }
  }

  /// Deterministic fallback grouping (no AI): the discovery interview already
  /// nests related stories under a parent (an "Accounts" parent with admin/
  /// customer children, etc.), so group each [buildable] story under its
  /// TOP-LEVEL ancestor (the direct child of the templater root). Returns null
  /// when the tree is flat (every story is top-level → no reduction), so the
  /// caller falls through to the per-story path.
  List<List<UserStory>>? _groupStoriesByTree(
    List<UserStory> buildable,
    List<UserStory> allStories,
    int? rootPk,
  ) {
    final byPk = {for (final s in allStories) s.story_pk: s};
    int topAncestor(UserStory s) {
      var cur = s;
      // Walk up until the parent is the templater root (or missing/cycle).
      final seen = <int>{};
      while (cur.parent_story_fk != null &&
          cur.parent_story_fk != rootPk &&
          seen.add(cur.story_pk)) {
        final p = byPk[cur.parent_story_fk];
        if (p == null) break;
        cur = p;
      }
      return cur.story_pk;
    }

    final byTop = <int, List<UserStory>>{};
    final order = <int>[];
    for (final s in buildable) {
      final top = topAncestor(s);
      byTop
          .putIfAbsent(top, () {
            order.add(top);
            return <UserStory>[];
          })
          .add(s);
    }
    // No grouping if flat (no reduction), collapsed to one, or one mega-group
    // holds the majority (a degenerate tree — e.g. everything under one node).
    final biggest = byTop.values.fold<int>(
      0,
      (m, g) => g.length > m ? g.length : m,
    );
    if (byTop.length < 2 ||
        byTop.length >= buildable.length ||
        biggest * 10 > buildable.length * 7) {
      return null;
    }
    // Emit groups with the top-level story first (its rep title names the area).
    final groups = <List<UserStory>>[];
    for (final top in order) {
      final members = byTop[top]!;
      members.sort((a, c) {
        if (a.story_pk == top) return -1; // rep first
        if (c.story_pk == top) return 1;
        return a.orderIndex.compareTo(c.orderIndex);
      });
      groups.add(members);
    }
    // ignore: avoid_print
    print(
      '[TaskGen] tree-grouped ${buildable.length} stories → '
      '${groups.length} subtree area(s) (AI clustering unavailable)',
    );
    return groups;
  }

  /// Like [_tasksForStory] but for a GROUP of related stories: folds ALL of them
  /// into ONE prompt and asks for the FEWEST consolidated tasks (typically one
  /// per layer covering the whole area) — no context is lost because every
  /// story's narrative + acceptance criteria are included.
  Future<List<Map<String, dynamic>>> _tasksForGroup(
    NexusDatabase db,
    ({InferenceBackend backend, String model})? resolved,
    String profile,
    List<UserStory> group,
  ) async {
    if (resolved == null) return const [];
    final b = StringBuffer()
      ..writeln(
        'FEATURE AREA — build these related user stories TOGETHER as one '
        'cohesive, consolidated set of tasks:',
      );
    for (final s in group) {
      b.writeln('\n— STORY: ${s.title}');
      if (s.narrative.trim().isNotEmpty) b.writeln('  ${s.narrative.trim()}');
      final ac = (s.acceptanceCriteria ?? '').trim();
      if (ac.isNotEmpty) b.writeln('  Acceptance:\n$ac');
      final notes = await db.getNotesForStory(s.story_pk);
      for (final n in notes) {
        b.writeln('  Note: ${n.body.trim()}');
      }
    }
    b.writeln('\n$profile');
    const sys =
        'You are a tech lead turning a FEATURE AREA (several related user stories) '
        'into the FEWEST tasks that fully build it. CONSOLIDATE: produce roughly '
        'ONE task per layer for the WHOLE area — e.g. one db task covering ALL the '
        'area\'s tables, one server task covering ALL its endpoints, one client '
        'task covering ALL its screens — NOT one task per story. Fold every '
        'story\'s requirements into these consolidated tasks so nothing is lost. '
        'Only split a layer further if it is genuinely too big for one focused '
        'session. Each task DESCRIPTION names the exact stack artifact(s) to build '
        'and MUST cover every story\'s needs for that layer; each task\'s '
        'acceptance_criteria is a testable bullet list spanning ALL those stories. '
        'Use ONLY the baseline stack. Return ONLY a JSON array (no prose, no '
        'fences): [{"title","description","acceptance_criteria","layer":"client"|'
        '"server"|"db"|"other"}].';
    try {
      final raw = await scopedComplete(
        backend: resolved.backend,
        model: resolved.model,
        system: sys,
        user: b.toString(),
        maxTokens: 1600,
      );
      return parseJsonObjectArray(raw);
    } catch (e) {
      debugPrint('group task-gen failed: $e');
      return const [];
    }
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
    // Routed Nexus Router serves the Omni collection id directly; default to it
    // rather than a raw 4B fallback. (Task-gen doesn't fetch the live model list;
    // local servers fall back to the configured selectedModel/default.)
    final model = resolveAgentChatModel(
      routed: isRoutedProviderType(chosen.providerType),
      selectedModel: chosen.selectedModel,
    );
    final uiServer = ui_server.InferenceServer(
      id: chosen.server_pk.toString(),
      name: chosen.name,
      baseUrl: chosen.baseUrl,
      apiKey: chosen.apiKey,
      providerType: chosen.providerType,
      selectedModel: chosen.selectedModel,
      availableModels: models,
    );
    return (
      backend: backendForServer(uiServer, agentName: 'TaskGen'),
      model: model,
    );
  }
}

final taskGeneratorProvider = ChangeNotifierProvider.family<TaskGenerator, int>(
  (ref, projectId) => TaskGenerator(ref, projectId),
);
