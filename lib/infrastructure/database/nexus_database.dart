// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../inference/routed_server.dart' show kRoutedProviderType;
import '../lemonade/services/persona_model_resolver.dart'
    show defaultOmniCollectionForTitle;
import '../models/database/tables/client.dart';
import '../models/database/tables/project.dart';
import '../models/database/tables/task.dart';
import '../models/database/tables/inference_server.dart';
import '../models/database/tables/agent_persona.dart';
import '../models/database/tables/skill.dart';
import '../models/database/tables/deployment.dart';
import '../models/database/tables/activity_log.dart';
import '../models/database/tables/ci_run.dart';
import '../models/database/tables/ci_job.dart';
import '../models/database/tables/ci_step.dart';
import '../models/database/tables/chat_session.dart';
import '../models/database/tables/chat_message.dart';
import '../models/database/tables/project_tag.dart';
import '../models/database/tables/library_verification.dart';
import '../models/database/tables/call_system.dart';
import '../models/database/tables/setup_flow.dart';
import '../models/database/tables/setup_scope.dart';
import '../models/database/tables/setup_scope_option.dart';
import '../models/database/tables/user_story.dart';
import '../models/database/tables/story_note.dart';
import '../../features/project_setup/config/setup_flow_catalog.dart'
    as setup_cat;
import '../../features/agents/agent_role.dart';
import '../../features/agents/agent_role_policy.dart';
import '../../features/agents/packs/agent_pack.dart';
import '../../features/agents/packs/agent_pack_catalog.dart';
import '../../features/projects/task_workflow.dart';

part 'nexus_database.g.dart';

/// Emitted on the [NexusDatabase.taskCompleted] stream when a task is approved
/// (→ Done). Carries enough to surface a notification that deep-links to the
/// task: its pk, the owning project, and its title.
class TaskCompletedEvent {
  const TaskCompletedEvent({
    required this.taskPk,
    required this.projectPk,
    required this.title,
  });

  final int taskPk;
  final int projectPk;
  final String title;
}

/// Database definition using Drift.
///
/// All tables use integer auto-increment primary keys named `<entity>_pk`
/// (client_pk, project_pk, task_pk, agent_pk, server_pk, session_pk, …) and
/// foreign keys named `<ref>_fk` (client_fk, project_fk, task_parent_fk, …).
@DriftDatabase(
  tables: [
    Clients,
    Projects,
    Tasks,
    InferenceServers,
    AgentPersonas,
    Skills,
    Deployments,
    ActivityLogs,
    CiRuns,
    CiJobs,
    CiSteps,
    ChatSessions,
    ChatMessages,
    ProjectTags,
    LibraryVerifications,
    CallSystems,
    SetupFlows,
    SetupScopes,
    SetupScopeOptions,
    UserStories,
    StoryNotes,
  ],
)
class NexusDatabase extends _$NexusDatabase {
  NexusDatabase() : super(_openConnection()) {
    _initDriftOptions();
  }

  /// Test-only: bind to a caller-provided executor (e.g. `NativeDatabase.memory()`)
  /// so unit tests can exercise migrations/queries without touching disk.
  @visibleForTesting
  NexusDatabase.forTesting(super.executor) {
    _initDriftOptions();
  }

  /// Broadcasts a [TaskCompletedEvent] every time a task is approved (→ Done),
  /// so the app shell can surface a tappable "task complete" notification. The
  /// single completion chokepoint ([approveTask]) feeds this.
  final StreamController<TaskCompletedEvent> _taskCompletedController =
      StreamController<TaskCompletedEvent>.broadcast();
  Stream<TaskCompletedEvent> get taskCompleted =>
      _taskCompletedController.stream;

  @override
  int get schemaVersion => 33;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
      onUpgrade: (Migrator m, int from, int to) async {
        // From v17 onward we migrate incrementally. v17 moved plans out of the
        // DB into the project workspace (/PLANS files), which re-typed the
        // task/chat plan foreign keys to text paths — a structural change that
        // can't be done with addColumn, so anything below v17 gets a clean
        // reset (no real plan/file data existed yet).
        if (from < 17) {
          for (final table in allTables) {
            await customStatement(
              'DROP TABLE IF EXISTS "${table.actualTableName}"',
            );
          }
          await m.createAll();
          return;
        }
        // v17 → v18: builds/CI grew a runs→jobs→steps hierarchy. Add the two new
        // tables and the new CiRuns columns (kind/backend/commit/paths/error/timing).
        if (from < 18) {
          await m.createTable(ciJobs);
          await m.createTable(ciSteps);
          await m.addColumn(ciRuns, ciRuns.kind);
          await m.addColumn(ciRuns, ciRuns.backend);
          await m.addColumn(ciRuns, ciRuns.commitOid);
          await m.addColumn(ciRuns, ciRuns.dockerfilePath);
          await m.addColumn(ciRuns, ciRuns.imageTag);
          await m.addColumn(ciRuns, ciRuns.workflowPath);
          await m.addColumn(ciRuns, ciRuns.errorText);
          await m.addColumn(ciRuns, ciRuns.startedAt);
        }
        // v18 → v19: tasks grew orchestration/verification fields.
        if (from < 19) {
          await m.addColumn(tasks, tasks.acceptanceCriteria);
          await m.addColumn(tasks, tasks.verification);
          await m.addColumn(tasks, tasks.executionStatus);
          await m.addColumn(tasks, tasks.submissionJson);
          await m.addColumn(tasks, tasks.worker_session_fk);
          await m.addColumn(tasks, tasks.workBranch);
        }
        // v19 → v20: a build/CI run can be attached to a task so a green
        // build/CI auto-completes it (and a red one sends it back).
        if (from < 20) {
          await m.addColumn(ciRuns, ciRuns.task_fk);
        }
        // v20 → v21: projects gained orchestration control (run state +
        // working-hours window) for the autonomous worker-spawn loop.
        if (from < 21) {
          await m.addColumn(projects, projects.orchestrationState);
          await m.addColumn(projects, projects.workHoursEnabled);
          await m.addColumn(projects, projects.workHoursStart);
          await m.addColumn(projects, projects.workHoursEnd);
          await m.addColumn(projects, projects.workDaysMask);
        }
        // v21 → v22: tasks gained per-task build-pipeline config so the
        // orchestrator can run a Docker/CI build gate between verify and merge.
        if (from < 22) {
          await m.addColumn(tasks, tasks.requiresBuild);
          await m.addColumn(tasks, tasks.dockerfilePath);
          await m.addColumn(tasks, tasks.workflowPath);
          await m.addColumn(tasks, tasks.imageTag);
        }
        // v22 → v23: projects can override the orchestrator's prompt templates
        // (worker/verify/merge framing + kickoff text) per project.
        if (from < 23) {
          await m.addColumn(projects, projects.orchestratorPromptsJson);
        }
        // v23 → v24: Project Setup workflow. Projects gain setup/summary fields,
        // plus a structured tag profile (ProjectTags) and a freshness-check cache
        // (LibraryVerifications) for the setup's library/framework research.
        if (from < 24) {
          await m.addColumn(projects, projects.setupStatus);
          await m.addColumn(projects, projects.setupTranscriptJson);
          await m.addColumn(projects, projects.projectSummaryMd);
          await m.addColumn(projects, projects.summaryUpdatedAt);
          await m.createTable(projectTags);
          await m.createTable(libraryVerifications);
        }
        // v24 → v25: library tags can attach to the language they're used with
        // (e.g. a Dart package vs. a C# NuGet), so the board can group them.
        if (from < 25) {
          await m.addColumn(projectTags, projectTags.forLanguage);
        }
        if (from < 26) {
          await m.addColumn(tasks, tasks.thinkingMode);
        }
        // v26 → v27: extensible project types (capability-gated UI/tools).
        if (from < 27) {
          await m.addColumn(projects, projects.projectType);
          await m.addColumn(projects, projects.subCategory);
          await m.addColumn(projects, projects.experienceMode);
        }
        // v27 → v28: per-project IVR/Call-Systems document (portable JSON).
        if (from < 28) {
          await m.createTable(callSystems);
        }
        // v28 → v29: configurable, DB-stored setup-interview flows.
        if (from < 29) {
          await m.createTable(setupFlows);
        }
        if (from < 30) {
          await m.createTable(setupScopes);
          await m.createTable(setupScopeOptions);
        }
        if (from < 31) {
          // Post-setup Exploration phase: the user-story tree, the task→story
          // backlink, and the project exploration-phase flag.
          await m.createTable(userStories);
          await m.addColumn(tasks, tasks.task_story_fk);
          await m.addColumn(projects, projects.explorationStatus);
        }
        if (from < 32) {
          // Descriptive notes attached to user-story items.
          await m.createTable(storyNotes);
        }
        if (from < 33) {
          // Templater stage + sequential, topic-grouped milestones: a per-task
          // milestone batch index and the project-level templating/milestone
          // bookkeeping that gates workers until a base project is scaffolded.
          //
          // IDEMPOTENT: SQLite auto-commits DDL, so if a crash interrupts this
          // step AFTER a column was added but BEFORE Drift commits the new
          // schemaVersion, the next launch re-runs this block and the ADD COLUMN
          // fails with "duplicate column" — which would brick the DB (it never
          // opens, so no projects/account data show). Skip any column already
          // present instead of crashing.
          Future<void> addCol(Future<void> Function() add) async {
            try {
              await add();
            } on Object catch (e) {
              if (!'$e'.toLowerCase().contains('duplicate column')) rethrow;
            }
          }

          await addCol(() => m.addColumn(tasks, tasks.milestoneOrder));
          await addCol(() => m.addColumn(projects, projects.templateStatus));
          await addCol(() => m.addColumn(projects, projects.currentMilestone));
          await addCol(() => m.addColumn(projects, projects.milestoneCount));
        }
      },
    );
  }

  // ==================== Setup flows (configurable interviews) ===========
  /// Idempotently seed the built-in setup flows (software + IVR sub-categories).
  /// Editable in the DB afterward; safe to call on every launch.
  Future<void> seedSetupFlows() async {
    for (final flow in setup_cat.kBuiltinSetupFlows) {
      final json = jsonEncode(flow.toJson());
      final existing =
          await (select(setupFlows)..where(
                (f) =>
                    f.projectType.equals(flow.projectType) &
                    (flow.subCategory == null
                        ? f.subCategory.isNull()
                        : f.subCategory.equals(flow.subCategory!)),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await into(setupFlows).insert(
          SetupFlowsCompanion.insert(
            projectType: flow.projectType,
            subCategory: Value(flow.subCategory),
            json: json,
          ),
        );
        continue;
      }
      // RECONCILE built-ins: when the SHIPPED definition changes (e.g. the
      // objectives stage was merged into features), overwrite the cached row so
      // existing installs pick it up — otherwise the stale stored flow keeps
      // driving the interview (and its required-gate). Only writes on an actual
      // drift, so unchanged launches do nothing. (There is no in-app flow editor
      // yet; if one is added, gate this behind an `isBuiltin`/edited flag.)
      if (existing.json != json) {
        await (update(setupFlows)
              ..where((f) => f.setup_flow_pk.equals(existing.setup_flow_pk)))
            .write(
              SetupFlowsCompanion(
                json: Value(json),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    }
  }

  /// Resolve the setup-flow JSON for a project (exact type+subCategory → type-
  /// generic → null if neither stored). The provider layer falls back to the
  /// built-in catalog when this returns null.
  Future<String?> resolveSetupFlowJson(
    String projectType,
    String? subCategory,
  ) async {
    if (subCategory != null) {
      final exact =
          await (select(setupFlows)..where(
                (f) =>
                    f.projectType.equals(projectType) &
                    f.subCategory.equals(subCategory),
              ))
              .getSingleOrNull();
      if (exact != null) return exact.json;
    }
    final generic =
        await (select(setupFlows)..where(
              (f) => f.projectType.equals(projectType) & f.subCategory.isNull(),
            ))
            .getSingleOrNull();
    return generic?.json;
  }

  /// Persist/override a setup flow definition (upsert on type+subCategory).
  Future<void> upsertSetupFlow(
    String projectType,
    String? subCategory,
    String json,
  ) async {
    final existing =
        await (select(setupFlows)..where(
              (f) =>
                  f.projectType.equals(projectType) &
                  (subCategory == null
                      ? f.subCategory.isNull()
                      : f.subCategory.equals(subCategory)),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await into(setupFlows).insert(
        SetupFlowsCompanion.insert(
          projectType: projectType,
          subCategory: Value(subCategory),
          json: json,
        ),
      );
    } else {
      await (update(
        setupFlows,
      )..where((f) => f.setup_flow_pk.equals(existing.setup_flow_pk))).write(
        SetupFlowsCompanion(
          json: Value(json),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // ==================== Setup scopes (adaptive scoped vocabulary) ========
  /// Catalog version stored in the DB (null if never seeded). Kept as a sentinel
  /// `__catalog_meta__` scope row so it's transactional with the data and needs
  /// no extra table. The query helpers filter on `axis='industry'`/sub-axis keys,
  /// so this sentinel row is never surfaced to the interview or board.
  static const String _scopeMetaAxis = '__catalog_meta__';

  /// Cross-cutting "base" features every project can want, appended to the
  /// industry-scoped `features` options so the interchangeable essentials are
  /// always on offer even when a domain catalog is thin. Ordered deliberately
  /// (most-common first). Mirrors the leading block of `kFeatures` in
  /// tag_category.dart — keep the two roughly in sync.
  static const List<String> _kBaseFeatureOptions = [
    'User accounts',
    'Authentication / login',
    'Role-based access',
    'User profiles',
    'Notifications',
    'Search',
    'Settings / preferences',
    'File uploads',
    'Reporting & analytics',
    'Offline support',
  ];

  Future<int?> scopedCatalogVersion() async {
    final row =
        await (select(setupScopes)
              ..where((s) => s.axis.equals(_scopeMetaAxis))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  /// Reconcile the scoped-vocabulary catalog (the research-generated
  /// `assets/setup/scoped_vocab.json`) into the DB. INSERTS industries that
  /// don't exist yet and UPDATES (replaces the subtree of) those that do, so a
  /// bumped catalog propagates to existing installs. The caller version-gates
  /// this (see the seeder), so on an unchanged launch it never runs and nothing
  /// is wiped; only a changed catalog triggers the upsert.
  Future<void> seedSetupScopes(
    List<dynamic> packs, {
    required int version,
  }) async {
    await transaction(() async {
      for (final raw in packs) {
        if (raw is! Map) continue;
        final pack = raw.cast<String, dynamic>();
        final industry = (pack['industry'] ?? '').toString().trim();
        if (industry.isEmpty) continue;

        // Replace this industry's subtree: existing records get updated, new
        // ones inserted. Scope rows are catalog-owned (no user data), so a
        // delete-then-insert is a clean per-industry update.
        await _deleteIndustrySubtree(industry);

        final subAxis = (pack['subAxis'] as Map?)?.cast<String, dynamic>();
        final subName = subAxis?['name']?.toString();
        final subKey = subAxis?['key']?.toString();

        final industryPk = await into(setupScopes).insert(
          SetupScopesCompanion.insert(
            axis: 'industry',
            value: industry,
            subAxisName: Value(subName),
            subAxisKey: Value(subKey),
          ),
        );

        await _insertScopeOptions(industryPk, pack);

        final values = (subAxis?['values'] as List?) ?? const [];
        for (final v in values) {
          if (v is! Map) continue;
          final valueMap = v.cast<String, dynamic>();
          final valueName = (valueMap['value'] ?? '').toString().trim();
          if (valueName.isEmpty || subKey == null) continue;
          final childPk = await into(setupScopes).insert(
            SetupScopesCompanion.insert(
              axis: subKey,
              value: valueName,
              parent_scope_fk: Value(industryPk),
            ),
          );
          await _insertScopeOptions(childPk, valueMap);
        }
      }

      // Stamp the catalog version so unchanged launches skip re-seeding.
      await (delete(
        setupScopes,
      )..where((s) => s.axis.equals(_scopeMetaAxis))).go();
      await into(setupScopes).insert(
        SetupScopesCompanion.insert(
          axis: _scopeMetaAxis,
          value: version.toString(),
        ),
      );
    });
  }

  /// Delete an industry scope, its child (sub-axis) scopes, and every option row
  /// belonging to any of them. Used to replace an industry on a catalog update.
  Future<void> _deleteIndustrySubtree(String industry) async {
    final ind =
        await (select(setupScopes)..where(
              (s) =>
                  s.axis.equals('industry') &
                  s.value.equals(industry) &
                  s.parent_scope_fk.isNull(),
            ))
            .getSingleOrNull();
    if (ind == null) return;
    final children = await (select(
      setupScopes,
    )..where((s) => s.parent_scope_fk.equals(ind.setup_scope_pk))).get();
    final pks = [ind.setup_scope_pk, ...children.map((c) => c.setup_scope_pk)];
    await (delete(
      setupScopeOptions,
    )..where((o) => o.setup_scope_fk.isIn(pks))).go();
    await (delete(
      setupScopes,
    )..where((s) => s.parent_scope_fk.equals(ind.setup_scope_pk))).go();
    await (delete(
      setupScopes,
    )..where((s) => s.setup_scope_pk.equals(ind.setup_scope_pk))).go();
  }

  /// Insert the option rows for one scope from its catalog map: plain
  /// objectives/features/platforms/libraries (platform-agnostic) plus any
  /// platform-conditional `stacks` (languages/frameworks/libraries tagged with
  /// their platform).
  Future<void> _insertScopeOptions(
    int scopePk,
    Map<String, dynamic> map,
  ) async {
    var sort = 0;
    // Seed-time normalization for the research-generated catalog, which has real
    // defects: duplicate values (e.g. C#, C#, C#), and paragraph-length "values"
    // that are unusable as a ≤5-word option label (and would be rejected by the
    // propose_tags length guard anyway). Dedupe per (category+platform+lang) and
    // drop anything too long to be a label, so only clean short options are seeded.
    final seenValues = <String>{};
    bool tooLongForLabel(String v) =>
        v.split(RegExp(r'\s+')).length > 6 || v.length > 64;
    Future<void> add(
      String category,
      String value, {
      String? platform,
      String? forLanguage,
    }) async {
      final v = value.trim();
      if (v.isEmpty) return;
      if (tooLongForLabel(v)) return; // skip paragraph-length catalog junk
      final dedupKey = '$category|${platform ?? ''}|${forLanguage ?? ''}|'
          '${v.toLowerCase()}';
      if (!seenValues.add(dedupKey)) return; // skip catalog duplicates
      await into(setupScopeOptions).insert(
        SetupScopeOptionsCompanion.insert(
          setup_scope_fk: scopePk,
          category: category,
          value: v,
          platform: Value(platform),
          forLanguage: Value(forLanguage),
          sort: Value(sort++),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    for (final c in const ['objectives', 'features', 'platforms']) {
      for (final e in (map[c] as List?) ?? const []) {
        await add(c, e.toString());
      }
    }
    for (final lib in (map['libraries'] as List?) ?? const []) {
      if (lib is Map) {
        await add(
          'libraries',
          (lib['value'] ?? '').toString(),
          forLanguage: lib['forLanguage']?.toString(),
        );
      } else {
        await add('libraries', lib.toString());
      }
    }
    for (final s in (map['stacks'] as List?) ?? const []) {
      if (s is! Map) continue;
      final stack = s.cast<String, dynamic>();
      final platform = stack['platform']?.toString();
      for (final lang in (stack['languages'] as List?) ?? const []) {
        await add('languages', lang.toString(), platform: platform);
      }
      for (final fw in (stack['frameworks'] as List?) ?? const []) {
        await add('frameworks', fw.toString(), platform: platform);
      }
      for (final lib in (stack['libraries'] as List?) ?? const []) {
        if (lib is Map) {
          await add(
            'libraries',
            (lib['value'] ?? '').toString(),
            platform: platform,
            forLanguage: lib['forLanguage']?.toString(),
          );
        } else {
          await add('libraries', lib.toString(), platform: platform);
        }
      }
    }
  }

  /// The sub-axes (e.g. Genre) introduced by the given selected [industries],
  /// each with its display name, category key, and the available values.
  Future<List<({String name, String key, List<String> values})>>
  subAxesForIndustries(List<String> industries) async {
    if (industries.isEmpty) return const [];
    final inds =
        await (select(setupScopes)..where(
              (s) =>
                  s.axis.equals('industry') &
                  s.value.isIn(industries) &
                  s.subAxisKey.isNotNull(),
            ))
            .get();
    final out = <({String name, String key, List<String> values})>[];
    for (final ind in inds) {
      final values =
          await (select(setupScopes)
                ..where((s) => s.parent_scope_fk.equals(ind.setup_scope_pk))
                ..orderBy([(s) => OrderingTerm(expression: s.value)]))
              .get();
      out.add((
        name: ind.subAxisName ?? ind.subAxisKey!,
        key: ind.subAxisKey!,
        values: values.map((s) => s.value).toList(),
      ));
    }
    return out;
  }

  /// Scoped suggestion values for [category], given the user's selected
  /// [industries] and any selected sub-axis values [subValues] (e.g. genres).
  /// Returns the deepest (sub-axis) options first, then industry-level, deduped.
  /// When [platform] is given, platform-conditional entries for that platform
  /// are included alongside platform-agnostic ones (used for languages /
  /// frameworks / libraries); otherwise only platform-agnostic entries.
  Future<List<String>> scopeOptions({
    required List<String> industries,
    required List<String> subValues,
    required String category,
    String? platform,
  }) async {
    if (industries.isEmpty) return const [];
    final industryScopes =
        await (select(setupScopes)..where(
              (s) => s.axis.equals('industry') & s.value.isIn(industries),
            ))
            .get();
    if (industryScopes.isEmpty) {
      // No catalog for these industries — still offer the cross-cutting base for
      // features so every project gets the interchangeable essentials.
      return category == 'features' ? List.of(_kBaseFeatureOptions) : const [];
    }
    final industryPks = industryScopes.map((s) => s.setup_scope_pk).toList();

    // Child (sub-axis) scopes under those industries whose value is selected.
    final childScopes = subValues.isEmpty
        ? <SetupScope>[]
        : await (select(setupScopes)..where(
                (s) =>
                    s.parent_scope_fk.isIn(industryPks) &
                    s.value.isIn(subValues),
              ))
              .get();
    final childPks = childScopes.map((s) => s.setup_scope_pk).toList();

    // Features and the retired "objectives" section are ONE axis now, but the
    // research catalog still splits them into two arrays per scope — so when the
    // caller asks for `features`, read BOTH categories' rows (union). Any other
    // category reads only itself.
    final wantCats = category == 'features'
        ? const ['features', 'objectives']
        : [category];

    Future<List<SetupScopeOption>> opts(List<int> pks) async {
      if (pks.isEmpty) return const [];
      final q = select(setupScopeOptions)
        ..where((o) => o.setup_scope_fk.isIn(pks) & o.category.isIn(wantCats));
      if (platform != null) {
        q.where((o) => o.platform.equals(platform) | o.platform.isNull());
      } else {
        q.where((o) => o.platform.isNull());
      }
      q.orderBy([(o) => OrderingTerm(expression: o.sort)]);
      return q.get();
    }

    final seen = <String>{};
    final result = <String>[];
    // Deepest (sub-axis) options first, then industry-level — most specific
    // leads. For features, append the cross-cutting base last so the essentials
    // are always offered even when the domain catalog is thin.
    final rows = [...await opts(childPks), ...await opts(industryPks)];
    for (final row in rows) {
      if (seen.add(row.value.toLowerCase())) result.add(row.value);
    }
    if (category == 'features') {
      for (final v in _kBaseFeatureOptions) {
        if (seen.add(v.toLowerCase())) result.add(v);
      }
    }
    return result;
  }

  /// True once any scoped vocabulary has been seeded.
  Future<bool> hasSetupScopes() async {
    final row = await (selectOnly(
      setupScopes,
    )..addColumns([setupScopes.setup_scope_pk])).get();
    return row.isNotEmpty;
  }

  // ==================== Clients ====================
  Future<List<Client>> getAllClients() => select(clients).get();

  Stream<List<Client>> watchAllClients() =>
      (select(clients)..orderBy([
            (c) =>
                OrderingTerm(expression: c.isDefault, mode: OrderingMode.desc),
            (c) => OrderingTerm(expression: c.name),
          ]))
          .watch();

  Future<Client?> getDefaultClient() {
    return (select(
      clients,
    )..where((c) => c.isDefault.equals(true))).getSingleOrNull();
  }

  /// Heuristic for "this install has already been used": any project exists, or
  /// there's more than the single built-in Default client. Used to auto-skip
  /// first-run onboarding for existing users (a fresh install seeds only the
  /// Default client and no projects).
  Future<bool> hasExistingUserContent() async {
    final anyProject = await (select(projects)..limit(1)).get();
    if (anyProject.isNotEmpty) return true;
    final allClients = await select(clients).get();
    return allClients.length > 1;
  }

  /// Inserts a client and returns its new integer pk.
  Future<int> createClient(ClientsCompanion entry) =>
      into(clients).insert(entry);

  /// Deletes a client and all its dependent data.
  Future<bool> deleteClient(int clientPk) async {
    await (delete(
      deployments,
    )..where((d) => d.client_fk.equals(clientPk))).go();
    await (delete(
      activityLogs,
    )..where((a) => a.client_fk.equals(clientPk))).go();
    await (delete(ciRuns)..where((c) => c.client_fk.equals(clientPk))).go();
    final projectRows = await (select(
      projects,
    )..where((p) => p.client_fk.equals(clientPk))).get();
    for (final proj in projectRows) {
      final sessions = await (select(
        chatSessions,
      )..where((s) => s.project_fk.equals(proj.project_pk))).get();
      for (final s in sessions) {
        await (delete(
          chatMessages,
        )..where((m) => m.session_fk.equals(s.session_pk))).go();
      }
      await (delete(
        chatSessions,
      )..where((s) => s.project_fk.equals(proj.project_pk))).go();
      await (delete(
        tasks,
      )..where((t) => t.task_project_fk.equals(proj.project_pk))).go();
    }
    await (delete(projects)..where((p) => p.client_fk.equals(clientPk))).go();
    await (delete(
      agentPersonas,
    )..where((p) => p.client_fk.equals(clientPk))).go();
    await (delete(
      inferenceServers,
    )..where((s) => s.client_fk.equals(clientPk))).go();
    await (delete(skills)..where((s) => s.client_fk.equals(clientPk))).go();
    final result = await (delete(
      clients,
    )..where((c) => c.client_pk.equals(clientPk))).go();
    return result > 0;
  }

  /// Creates a client and seeds a default Inference Server + starter personas.
  /// Returns the new client pk.
  /// Creates a client with its built-in infrastructure: a Local Lemonade server,
  /// the reusable Skill prefabs, and the agents from the chosen [packKeys]
  /// (defaulting to the [kDefaultAgentPackKey] pack when none are given).
  Future<int> createClientWithDefaults({
    required String name,
    bool isDefault = false,
    List<String>? packKeys,
  }) async {
    final clientPk = await createClient(
      ClientsCompanion.insert(name: name, isDefault: Value(isDefault)),
    );

    await createInferenceServer(
      InferenceServersCompanion.insert(
        client_fk: clientPk,
        name: 'Local Lemonade',
        // Bare host (no /v1): ServerConfig.apiUrl normalizes this to the correct
        // Lemonade base `…/api/v1`. A stored `…/v1` is kept as-is by the
        // normalizer and would hit the wrong `/v1/models` path (404).
        baseUrl: 'http://localhost:13305',
        providerType: const Value('lemonade'),
        maxConcurrency: const Value(4),
        maxAgents: const Value(8),
      ),
    );

    await seedSkillPrefabs(clientPk);

    final keys = (packKeys == null || packKeys.isEmpty)
        ? const [kDefaultAgentPackKey]
        : packKeys;
    await provisionAgentPack(clientPk, agentsForPackKeys(keys));

    return clientPk;
  }

  /// Seeds the reusable Skill prefabs (one row per bundle in [kSkillCatalog]).
  /// These are the tool bundles agent packs grant; they're client-scoped so each
  /// client owns its own prefab library.
  Future<void> seedSkillPrefabs(int clientPk) async {
    for (final entry in kSkillCatalog.entries) {
      final meta = kSkillMeta[entry.key];
      await createSkill(
        SkillsCompanion.insert(
          client_fk: clientPk,
          name: entry.key,
          description: Value(meta?.description),
          category: Value(meta?.category ?? 'general'),
          riskLevel: Value(meta?.riskLevel ?? 'medium'),
          configJson: Value(
            jsonEncode({
              'tools': {
                for (final t in entry.value.entries) t.key: t.value.name,
              },
            }),
          ),
          isPrefab: const Value(true),
        ),
      );
    }
  }

  /// Provisions a set of pack agents into a client as prefab personas. Dedupes
  /// against the client's existing personas by `title`, so re-provisioning or
  /// selecting overlapping packs (which may share a role) never duplicates an
  /// agent. Each persona defaults to the product Omni Collection so voice/
  /// vision/image work out of the box (it decomposes into per-modality models).
  Future<void> provisionAgentPack(int clientPk, List<PackAgent> agents) async {
    final existing = await (select(
      agentPersonas,
    )..where((p) => p.client_fk.equals(clientPk))).get();
    final titles = <String?>{for (final p in existing) p.title};
    for (final a in agents) {
      if (titles.contains(a.title)) continue;
      await createAgentPersona(
        AgentPersonasCompanion.insert(
          client_fk: clientPk,
          name: a.name,
          title: Value(a.title),
          description: Value(a.description),
          capabilitiesJson: Value(jsonEncode(a.skills)),
          configJson: Value(a.configJson),
          // Each role gets its purpose-built default collection: Project Manager
          // → Interview, Coordinator → Discovery, everyone else → the product
          // default. (Decomposes into per-modality models out of the box.)
          omniCollectionModel: Value(defaultOmniCollectionForTitle(a.title)),
          isPrefab: const Value(true),
        ),
      );
      titles.add(a.title);
    }
  }

  Future<int> createSkill(SkillsCompanion entry) => into(skills).insert(entry);

  // ==================== Projects ====================
  Future<List<Project>> getProjectsForClient(int clientPk) {
    return (select(projects)..where((p) => p.client_fk.equals(clientPk))).get();
  }

  Stream<List<Project>> watchProjectsForClient(int clientPk) {
    return (select(
      projects,
    )..where((p) => p.client_fk.equals(clientPk))).watch();
  }

  Future<int> createProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  // ==================== Call Systems (IVR) ====================
  /// Reactive call-system document for a project (null until first saved).
  Stream<CallSystem?> watchCallSystem(int projectPk) => (select(
    callSystems,
  )..where((c) => c.project_fk.equals(projectPk))).watchSingleOrNull();

  Future<CallSystem?> getCallSystem(int projectPk) => (select(
    callSystems,
  )..where((c) => c.project_fk.equals(projectPk))).getSingleOrNull();

  /// Insert-or-update the portable call-system JSON for a project (one per
  /// project; upsert keyed on project_fk).
  Future<void> upsertCallSystem(int projectPk, String json) async {
    final existing = await getCallSystem(projectPk);
    if (existing == null) {
      await into(callSystems).insert(
        CallSystemsCompanion.insert(project_fk: projectPk, json: Value(json)),
      );
    } else {
      await (update(
        callSystems,
      )..where((c) => c.call_system_pk.equals(existing.call_system_pk))).write(
        CallSystemsCompanion(
          json: Value(json),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Deletes a project and all its tasks + chat sessions.
  Future<bool> deleteProject(int projectPk) async {
    final sessions = await (select(
      chatSessions,
    )..where((s) => s.project_fk.equals(projectPk))).get();
    for (final s in sessions) {
      await (delete(
        chatMessages,
      )..where((m) => m.session_fk.equals(s.session_pk))).go();
    }
    await (delete(
      chatSessions,
    )..where((s) => s.project_fk.equals(projectPk))).go();
    await (delete(
      tasks,
    )..where((t) => t.task_project_fk.equals(projectPk))).go();
    final result = await (delete(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).go();
    return result > 0;
  }

  /// The agent persona assigned to a project's Coordinator (or null).
  Future<int?> getProjectAgentPersonaId(int projectPk) async {
    final row = await (select(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).getSingleOrNull();
    return row?.agent_persona_fk;
  }

  Future<void> setProjectAgentPersona(int projectPk, int? personaPk) async {
    await (update(projects)..where((p) => p.project_pk.equals(projectPk)))
        .write(ProjectsCompanion(agent_persona_fk: Value(personaPk)));
  }

  /// The persona id the project's Coordinator should use: the explicitly
  /// assigned agent, or — when none is set — the seeded Project Manager persona
  /// for the project's client. The fallback is persisted so the choice sticks
  /// and the UI reflects it. Returns null only if no Project Manager exists.
  Future<int?> getOrAssignCoordinatorPersonaId(int projectPk) async {
    final existing = await getProjectAgentPersonaId(projectPk);
    if (existing != null) return existing;

    final proj = await (select(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).getSingleOrNull();
    if (proj == null) return null;

    final pm =
        await (select(agentPersonas)
              ..where(
                (p) =>
                    p.client_fk.equals(proj.client_fk) &
                    p.title.equals(AgentRole.projectManager.key),
              )
              ..limit(1))
            .getSingleOrNull();
    if (pm == null) return null;

    await setProjectAgentPersona(projectPk, pm.agent_pk);
    return pm.agent_pk;
  }

  /// The client's persona for a given role `title` (an [AgentRole] key), or null.
  /// Lets a screen bind to a SPECIFIC role (Setup → Project Manager, Discovery →
  /// Coordinator) independently of the project's single assigned-agent FK.
  Future<int?> getPersonaIdByRole(int clientPk, String roleKey) async {
    final p =
        await (select(agentPersonas)
              ..where(
                (p) => p.client_fk.equals(clientPk) & p.title.equals(roleKey),
              )
              ..limit(1))
            .getSingleOrNull();
    return p?.agent_pk;
  }

  /// Resolve the persona for [roleKey] under the project's client. Returns null
  /// if the project (or that role's persona) doesn't exist.
  Future<int?> getProjectRolePersonaId(int projectPk, String roleKey) async {
    final proj = await (select(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).getSingleOrNull();
    if (proj == null) return null;
    return getPersonaIdByRole(proj.client_fk, roleKey);
  }

  /// Reactive single-project query — the project controls watch this so the
  /// Start/Pause state and working-hours edits reflect immediately.
  Stream<Project?> watchProject(int projectPk) {
    return (select(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).watchSingleOrNull();
  }

  /// Set the orchestration run state: 'stopped' | 'running' | 'paused'.
  Future<void> setProjectOrchestrationState(int projectPk, String state) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        orchestrationState: Value(state),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Set (or clear) the project's working-hours window. [start]/[end] are
  /// minutes from midnight; [daysMask] is a Mon..Sun weekday bitmask (0 = all).
  Future<void> setProjectWorkingHours(
    int projectPk, {
    required bool enabled,
    int? start,
    int? end,
    int? daysMask,
  }) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        workHoursEnabled: Value(enabled),
        workHoursStart: Value(start),
        workHoursEnd: Value(end),
        workDaysMask: Value(daysMask),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== Tasks (tree + full provenance) ====================
  Future<List<Task>> getTasksForProject(int projectPk) {
    return (select(
      tasks,
    )..where((t) => t.task_project_fk.equals(projectPk))).get();
  }

  Future<Project?> getProjectById(int projectPk) {
    return (select(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).getSingleOrNull();
  }

  /// Rename a project (the user can fix a name set wrong at creation).
  Future<void> setProjectName(int projectPk, String name) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  /// Persist a project's orchestrator prompt-template overrides (JSON), or null
  /// to clear all overrides back to the built-in defaults.
  Future<void> setProjectOrchestratorPrompts(
    int projectPk,
    String? json,
  ) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        orchestratorPromptsJson: Value(json),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== Project Setup ====================
  /// Update a project's setup workflow state (notStarted|inProgress|skipped|complete).
  Future<void> setProjectSetupStatus(int projectPk, String status) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        setupStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Post-setup Exploration phase: none | active | complete.
  Future<void> setProjectExplorationStatus(int projectPk, String status) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        explorationStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== Templater / milestones ====================
  /// Set the Templater phase state: none | pending | scaffolding | ready | failed.
  Future<void> setProjectTemplateStatus(int projectPk, String status) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        templateStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Record the milestone plan computed by the Templater: the total batch count
  /// and the starting (current) batch — defaulting to batch 0.
  Future<void> setProjectMilestonePlan(
    int projectPk, {
    required int count,
    int current = 0,
  }) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        milestoneCount: Value(count),
        currentMilestone: Value(current),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Open the next milestone batch (current += 1). Returns the new current index.
  Future<int> advanceProjectMilestone(int projectPk) async {
    final project = await getProjectById(projectPk);
    final next = (project?.currentMilestone ?? 0) + 1;
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        currentMilestone: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return next;
  }

  /// Assign a task to its milestone batch (0-based).
  Future<void> setTaskMilestone(int taskPk, int order) async {
    await (update(
      tasks,
    )..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        milestoneOrder: Value(order),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Persist the setup interview transcript (JSON), or null to clear it.
  Future<void> setProjectSetupTranscript(int projectPk, String? json) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        setupTranscriptJson: Value(json),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Persist the AI-compiled project summary (markdown) + its timestamp.
  Future<void> setProjectSummary(int projectPk, String? markdown) async {
    await (update(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).write(
      ProjectsCompanion(
        projectSummaryMd: Value(markdown),
        summaryUpdatedAt: Value(markdown == null ? null : DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== Project Tags ====================
  /// Live tag profile for a project, ordered by category then creation.
  Stream<List<ProjectTag>> watchTagsForProject(int projectPk) {
    return (select(projectTags)
          ..where((t) => t.project_fk.equals(projectPk))
          ..orderBy([
            (t) => OrderingTerm(expression: t.category),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<List<ProjectTag>> getTagsForProject(int projectPk) {
    return (select(
      projectTags,
    )..where((t) => t.project_fk.equals(projectPk))).get();
  }

  /// Insert a tag if (project, category, value) is new; returns the existing or
  /// new row's pk. Keeps the profile free of duplicate values per section.
  /// Wrapped in a transaction so concurrent upserts of the same tag (e.g. the
  /// workspace observer scanning while the AI proposes the same library) can't
  /// interleave their select+insert and produce a duplicate row.
  Future<int> upsertTag(ProjectTagsCompanion entry) async {
    return transaction(() async {
      final existing =
          await (select(projectTags)..where(
                (t) =>
                    t.project_fk.equals(entry.project_fk.value) &
                    t.category.equals(entry.category.value) &
                    t.value.equals(entry.value.value),
              ))
              .get();
      if (existing.isNotEmpty) {
        final pk = existing.first.tag_pk;
        await (update(
          projectTags,
        )..where((t) => t.tag_pk.equals(pk))).write(entry);
        return pk;
      }
      return into(projectTags).insert(entry);
    });
  }

  Future<void> setTagStatus(int tagPk, String status) async {
    await (update(projectTags)..where((t) => t.tag_pk.equals(tagPk))).write(
      ProjectTagsCompanion(status: Value(status)),
    );
  }

  Future<void> deleteTag(int tagPk) async {
    await (delete(projectTags)..where((t) => t.tag_pk.equals(tagPk))).go();
  }

  // ==================== User stories (Exploration phase) ====================
  /// Insert a user story; returns its new pk.
  Future<int> createUserStory(UserStoriesCompanion entry) =>
      into(userStories).insert(entry);

  /// All stories for a project (the whole tree, flat), ordered for stable layout.
  Future<List<UserStory>> getUserStoriesForProject(int projectPk) {
    return (select(userStories)
          ..where((s) => s.project_fk.equals(projectPk))
          ..orderBy([
            (s) => OrderingTerm(expression: s.orderIndex),
            (s) => OrderingTerm(expression: s.story_pk),
          ]))
        .get();
  }

  /// Live story tree for the canvas (rebuilds as the Coordinator adds stories).
  Stream<List<UserStory>> watchUserStoriesForProject(int projectPk) {
    return (select(userStories)
          ..where((s) => s.project_fk.equals(projectPk))
          ..orderBy([
            (s) => OrderingTerm(expression: s.orderIndex),
            (s) => OrderingTerm(expression: s.story_pk),
          ]))
        .watch();
  }

  Future<UserStory?> getUserStoryById(int storyPk) {
    return (select(
      userStories,
    )..where((s) => s.story_pk.equals(storyPk))).getSingleOrNull();
  }

  /// Patch a story (any subset of fields); always bumps `updatedAt`.
  Future<void> updateUserStory(int storyPk, UserStoriesCompanion patch) async {
    await (update(userStories)..where((s) => s.story_pk.equals(storyPk))).write(
      patch.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Persist a node's canvas position (after a drag / auto-layout).
  Future<void> setUserStoryPosition(int storyPk, double x, double y) async {
    await (update(userStories)..where((s) => s.story_pk.equals(storyPk))).write(
      UserStoriesCompanion(posX: Value(x), posY: Value(y)),
    );
  }

  /// Delete a story and all of its descendants (depth-first), plus their notes.
  /// Wrapped in a transaction so a crash/concurrent write can't orphan rows.
  Future<void> deleteUserStory(int storyPk) =>
      transaction(() => _deleteUserStoryRec(storyPk));

  Future<void> _deleteUserStoryRec(int storyPk) async {
    final kids = await (select(
      userStories,
    )..where((s) => s.parent_story_fk.equals(storyPk))).get();
    for (final k in kids) {
      await _deleteUserStoryRec(k.story_pk);
    }
    await (delete(storyNotes)..where((n) => n.story_fk.equals(storyPk))).go();
    await (delete(userStories)..where((s) => s.story_pk.equals(storyPk))).go();
  }

  // ── Story notes (descriptive notes attached to a story item) ──────────────
  Future<int> createStoryNote(int storyPk, String body) =>
      into(storyNotes).insert(
        StoryNotesCompanion.insert(story_fk: storyPk, body: body),
      );

  Future<List<StoryNote>> getNotesForStory(int storyPk) {
    return (select(storyNotes)
          ..where((n) => n.story_fk.equals(storyPk))
          ..orderBy([(n) => OrderingTerm(expression: n.note_pk)]))
        .get();
  }

  Stream<List<StoryNote>> watchNotesForStory(int storyPk) {
    return (select(storyNotes)
          ..where((n) => n.story_fk.equals(storyPk))
          ..orderBy([(n) => OrderingTerm(expression: n.note_pk)]))
        .watch();
  }

  Future<StoryNote?> getStoryNote(int notePk) {
    return (select(
      storyNotes,
    )..where((n) => n.note_pk.equals(notePk))).getSingleOrNull();
  }

  Future<void> updateStoryNote(int notePk, String body) async {
    await (update(storyNotes)..where((n) => n.note_pk.equals(notePk))).write(
      StoryNotesCompanion(body: Value(body), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteStoryNote(int notePk) async {
    await (delete(storyNotes)..where((n) => n.note_pk.equals(notePk))).go();
  }

  /// Tasks generated from a given story item (story → task(s)).
  Future<List<Task>> getTasksForStory(int storyPk) {
    return (select(
      tasks,
    )..where((t) => t.task_story_fk.equals(storyPk))).get();
  }

  // ==================== Library verification cache ====================
  /// Cached freshness check for (ecosystem, name), or null if absent.
  Future<LibraryVerification?> getCachedVerification(
    String ecosystem,
    String name,
  ) {
    return (select(libraryVerifications)
          ..where((v) => v.ecosystem.equals(ecosystem) & v.name.equals(name)))
        .getSingleOrNull();
  }

  /// Insert or replace the cached verification for (ecosystem, name). Wrapped in
  /// a transaction so concurrent verifications of the same package (lookup +
  /// propose) can't both insert and duplicate the cache row.
  Future<void> upsertVerification(LibraryVerificationsCompanion entry) async {
    await transaction(() async {
      final existing =
          await (select(libraryVerifications)..where(
                (v) =>
                    v.ecosystem.equals(entry.ecosystem.value) &
                    v.name.equals(entry.name.value),
              ))
              .get();
      if (existing.isNotEmpty) {
        await (update(libraryVerifications)..where(
              (v) => v.verification_pk.equals(existing.first.verification_pk),
            ))
            .write(entry);
      } else {
        await into(libraryVerifications).insert(entry);
      }
    });
  }

  /// Agent personas available to a project (scoped via its client).
  Future<List<AgentPersona>> getAgentPersonasForProject(int projectPk) async {
    final proj = await getProjectById(projectPk);
    if (proj == null) return const [];
    return getAgentPersonasForClient(proj.client_fk);
  }

  Stream<List<Task>> watchTasksForProject(int projectPk) {
    return (select(
      tasks,
    )..where((t) => t.task_project_fk.equals(projectPk))).watch();
  }

  /// Watch root tasks (no parent) for a project.
  Stream<List<Task>> watchRootTasksForProject(int projectPk) {
    return (select(tasks)..where(
          (t) =>
              t.task_project_fk.equals(projectPk) & t.task_parent_fk.isNull(),
        ))
        .watch();
  }

  /// Tasks generated from a specific plan file (provenance backtrack).
  Future<List<Task>> getTasksForPlanPath(String planPath) {
    return (select(
      tasks,
    )..where((t) => t.task_plan_path.equals(planPath))).get();
  }

  Future<int> createTask(TasksCompanion entry) => into(tasks).insert(entry);

  /// Create a task with provenance, auto-filling task_client_fk from the project.
  /// This is the preferred creation path so every task can be backtracked.
  Future<int> createTaskInProject({
    required int projectPk,
    required String title,
    int? parentPk,
    String? planPath,
    int? chatSessionPk,
    int? agentPk,
    int? storyPk,
    String description = '',
    String? acceptanceCriteria,
    String? verification,
    String status = 'Todo',
    String priority = 'MED',
    String? thinkingMode,
  }) async {
    // Hard guard against duplicates: never create a second task with the same
    // title in the same project. Returns the existing task's id instead, so a
    // re-run (e.g. re-finalizing setup) is idempotent and can't loop by piling
    // up identical tasks. When the task belongs to a user STORY, scope the
    // guard to that story — two different stories may each legitimately yield a
    // generically-titled task (e.g. "Add database migration") without the
    // second silently collapsing into (and mis-attributing to) the first.
    final dupe =
        await (select(tasks)
              ..where(
                (t) =>
                    t.task_project_fk.equals(projectPk) &
                    t.title.equals(title) &
                    (storyPk != null
                        ? t.task_story_fk.equals(storyPk)
                        : t.task_story_fk.isNull()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (dupe != null) return dupe.task_pk;

    final proj = await (select(
      projects,
    )..where((p) => p.project_pk.equals(projectPk))).getSingleOrNull();
    final clientPk = proj?.client_fk ?? 0;
    return into(tasks).insert(
      TasksCompanion.insert(
        task_client_fk: clientPk,
        task_project_fk: projectPk,
        title: title,
        task_parent_fk: parentPk != null
            ? Value(parentPk)
            : const Value.absent(),
        task_plan_path: planPath != null
            ? Value(planPath)
            : const Value.absent(),
        task_chat_session_fk: chatSessionPk != null
            ? Value(chatSessionPk)
            : const Value.absent(),
        task_agent_fk: agentPk != null ? Value(agentPk) : const Value.absent(),
        task_story_fk: storyPk != null ? Value(storyPk) : const Value.absent(),
        description: Value(description),
        acceptanceCriteria: (acceptanceCriteria != null &&
                acceptanceCriteria.trim().isNotEmpty)
            ? Value(acceptanceCriteria.trim())
            : const Value.absent(),
        verification: (verification != null && verification.trim().isNotEmpty)
            ? Value(verification.trim())
            : const Value.absent(),
        status: Value(status),
        priority: Value(priority),
        thinkingMode: thinkingMode != null
            ? Value(thinkingMode)
            : const Value.absent(),
      ),
    );
  }

  Future<bool> updateTask(TasksCompanion entry) => update(tasks).replace(entry);

  Future<int> deleteTask(int taskPk) {
    return (delete(tasks)..where((t) => t.task_pk.equals(taskPk))).go();
  }

  /// Partial status update (used by Kanban drag-drop).
  ///
  /// A manual board move also reconciles the orchestration [executionStatus] so
  /// the change is authoritative and sticks: dragging a card to **Done** marks
  /// it `done` (the orchestrator never re-touches it), and back to **Todo**
  /// resets it to `idle`. Without this, a card dropped on Done kept a stale
  /// exec status (e.g. `running`/`submitted`) and an in-flight or next-tick
  /// orchestrator pass could clobber the status straight back. Columns with no
  /// clean 1:1 mapping (In Progress / Review) leave exec untouched.
  Future<void> updateTaskStatus(int taskPk, String newStatus) async {
    final exec = switch (newStatus) {
      TaskStatus.done => const Value(TaskExecStatus.done),
      TaskStatus.todo => const Value(TaskExecStatus.idle),
      _ => const Value<String>.absent(),
    };
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        status: Value(newStatus),
        executionStatus: exec,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Assign (or clear, with null) the agent persona responsible for a task.
  Future<void> assignTaskAgent(int taskPk, int? personaPk) async {
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        task_agent_fk: Value(personaPk),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Partial update of a task — only fields present in [patch] change.
  Future<void> patchTask(int taskPk, TasksCompanion patch) async {
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      patch.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Set/clear a task's start and/or due dates.
  Future<void> setTaskDates(
    int taskPk, {
    Value<DateTime?>? start,
    Value<DateTime?>? due,
  }) async {
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        startDate: start ?? const Value.absent(),
        dueDate: due ?? const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setTaskBuildConfig(
    int taskPk, {
    Value<bool>? requiresBuild,
    Value<String?>? dockerfilePath,
    Value<String?>? workflowPath,
    Value<String?>? imageTag,
  }) async {
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        requiresBuild: requiresBuild ?? const Value.absent(),
        dockerfilePath: dockerfilePath ?? const Value.absent(),
        workflowPath: workflowPath ?? const Value.absent(),
        imageTag: imageTag ?? const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Task?> getTaskById(int taskPk) async {
    return (select(
      tasks,
    )..where((t) => t.task_pk.equals(taskPk))).getSingleOrNull();
  }

  // ==================== Orchestration state machine ====================
  // Both the kanban [status] and the orchestration [executionStatus] advance
  // together via [applyEvent] (task_workflow.dart), the single source of truth
  // for transitions. These helpers persist the resulting pair plus any
  // event-specific fields (assigned worker session, branch, submission, etc.).

  /// Persist the (status, executionStatus) a [TaskEvent] produces, merging any
  /// extra column changes in [extra].
  Future<void> _applyTaskEvent(
    int taskPk,
    TaskEvent event, [
    TasksCompanion? extra,
  ]) async {
    final next = applyEvent(event);
    var patch = TasksCompanion(
      status: Value(next.status),
      executionStatus: Value(next.exec),
      updatedAt: Value(DateTime.now()),
    );
    if (extra != null) {
      patch = patch.copyWith(
        task_agent_fk: extra.task_agent_fk,
        worker_session_fk: extra.worker_session_fk,
        workBranch: extra.workBranch,
        submissionJson: extra.submissionJson,
        acceptanceCriteria: extra.acceptanceCriteria,
        verification: extra.verification,
      );
    }
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(patch);
  }

  /// The orchestrator picked the task up and is preparing its workspace. Stays
  /// on the Todo board (exec `queued`) so "In Progress" still means a live agent.
  Future<void> markTaskQueued(int taskPk) {
    return _applyTaskEvent(taskPk, TaskEvent.enqueue);
  }

  /// A worker session is now actively executing the task on [workBranch]. This
  /// is the moment the task becomes "In Progress" — call it right before the
  /// worker's first turn, not at pickup.
  Future<void> markTaskRunning(
    int taskPk, {
    required int workerSessionPk,
    String? workBranch,
  }) {
    return _applyTaskEvent(
      taskPk,
      TaskEvent.startWork,
      TasksCompanion(
        worker_session_fk: Value(workerSessionPk),
        workBranch: workBranch != null
            ? Value(workBranch)
            : const Value.absent(),
      ),
    );
  }

  /// A worker run ended without submitting (turn cap, paused project, error).
  /// Return the task to the board instead of leaving it stuck "In Progress".
  Future<void> markTaskYieldedBack(int taskPk) {
    return _applyTaskEvent(taskPk, TaskEvent.yieldBack);
  }

  /// The orchestrator gave up on a task after exhausting its retry budget.
  /// Move it to the **Blocked** column (exec `failed`) so it surfaces to the
  /// user for a look instead of silently parking on Todo and being skipped.
  Future<void> markTaskBlocked(int taskPk) async {
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        status: const Value(TaskStatus.blocked),
        executionStatus: const Value(TaskExecStatus.failed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Return every Blocked task in a project to the Todo board (exec `idle`) so a
  /// fresh orchestration run retries it. Blocking is only meant to surface tasks
  /// that exhausted their retry budget within ONE run — it must not permanently
  /// strand work, so (re)starting the loop gives blocked tasks another chance.
  /// Returns how many tasks were requeued.
  Future<int> requeueBlockedTasks(int projectPk) async {
    return (update(tasks)
          ..where(
            (t) =>
                t.task_project_fk.equals(projectPk) &
                t.status.equals(TaskStatus.blocked),
          ))
        .write(
          TasksCompanion(
            status: const Value(TaskStatus.todo),
            executionStatus: const Value(TaskExecStatus.idle),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// The worker called submit_for_completion; store its submission payload.
  Future<void> submitTaskForCompletion(
    int taskPk, {
    required String submissionJson,
  }) {
    return _applyTaskEvent(
      taskPk,
      TaskEvent.submit,
      TasksCompanion(submissionJson: Value(submissionJson)),
    );
  }

  /// The Verification Agent began running the proof.
  Future<void> markTaskVerifying(int taskPk) {
    return _applyTaskEvent(taskPk, TaskEvent.beginVerify);
  }

  /// Record the verifier's verdict. On pass the task waits for the Coordinator
  /// to merge; on fail it returns to the board for the same agent to re-engage.
  Future<void> recordTaskVerdict(int taskPk, {required bool passed}) {
    return _applyTaskEvent(
      taskPk,
      passed ? TaskEvent.verdictPass : TaskEvent.verdictFail,
    );
  }

  /// The Coordinator merged the branch — task is fully done. Clears the live
  /// worker session so its (ephemeral) context can be torn down.
  Future<void> approveTask(int taskPk) async {
    final t = await getTaskById(taskPk);
    await _applyTaskEvent(
      taskPk,
      TaskEvent.approve,
      const TasksCompanion(worker_session_fk: Value(null)),
    );
    if (t != null) {
      _taskCompletedController.add(
        TaskCompletedEvent(
          taskPk: taskPk,
          projectPk: t.task_project_fk,
          title: t.title,
        ),
      );
    }
  }

  /// Send a task back to the board (PM/Coordinator reject), clearing its live
  /// worker session and submission.
  Future<void> reopenTask(int taskPk) {
    return _applyTaskEvent(
      taskPk,
      TaskEvent.reject,
      const TasksCompanion(
        worker_session_fk: Value(null),
        submissionJson: Value(null),
      ),
    );
  }

  /// Pipeline build gate started running on this task.
  Future<void> beginTaskBuild(int taskPk) {
    return _applyTaskEvent(taskPk, TaskEvent.beginBuild);
  }

  /// Record the pipeline build gate's outcome: green advances the task to
  /// `built` (awaiting merge); red sends it back to the board for rework.
  Future<void> recordTaskBuildOutcome(int taskPk, {required bool passed}) {
    return _applyTaskEvent(
      taskPk,
      passed ? TaskEvent.buildPass : TaskEvent.buildFail,
    );
  }

  /// Marker that delimits the auto-generated build-gate failure block at the end
  /// of a task description, so it can be replaced (not accumulated) across retries.
  static const String buildFailureMarker =
      '[Build gate FAILED — fix ALL of these before resubmitting]';

  /// Attach the full set of CI/analyze diagnostics from a red build gate to the
  /// task description so the worker sees EVERY error at once on its next attempt
  /// (instead of one-per-cycle). Any previous build-failure block is stripped
  /// first, so the note always reflects the latest run rather than piling up.
  Future<void> attachTaskBuildFailure(int taskPk, String detail) async {
    final t = await getTaskById(taskPk);
    if (t == null) return;
    var base = t.description ?? '';
    final idx = base.indexOf(buildFailureMarker);
    if (idx >= 0) base = base.substring(0, idx).trimRight();
    final note = '$base\n\n$buildFailureMarker:\n${detail.trim()}'.trim();
    await patchTask(taskPk, TasksCompanion(description: Value(note)));
  }

  /// The Coordinator started merging this task's branch into main.
  Future<void> beginTaskMerge(int taskPk) {
    return _applyTaskEvent(taskPk, TaskEvent.beginMerge);
  }

  /// Apply an attached build/CI run's result to its task: a green run approves
  /// the task (→ Done, worker released); a red run sends it back to the board
  /// (→ Todo) so the same agent re-engages. This is the auto-Done-on-CI rule
  /// for ad-hoc (human/Coordinator-triggered) builds — the autonomous pipeline
  /// instead uses [recordTaskBuildOutcome] so a green build flows into merge.
  Future<void> recordTaskBuildResult(int taskPk, {required bool passed}) async {
    final t = await getTaskById(taskPk);
    if (t == null) return;
    if (passed) {
      await approveTask(taskPk);
    } else {
      await _applyTaskEvent(taskPk, TaskEvent.verdictFail);
    }
  }

  /// Set the Project-Manager-authored definition of done and the runnable proof
  /// the Verification Agent will execute.
  Future<void> setTaskAcceptance(
    int taskPk, {
    String? acceptanceCriteria,
    String? verification,
  }) async {
    await (update(tasks)..where((t) => t.task_pk.equals(taskPk))).write(
      TasksCompanion(
        acceptanceCriteria: acceptanceCriteria != null
            ? Value(acceptanceCriteria)
            : const Value.absent(),
        verification: verification != null
            ? Value(verification)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== Inference Servers (AI Providers) ====================
  Future<List<InferenceServer>> getInferenceServersForClient(int clientPk) {
    return (select(
      inferenceServers,
    )..where((s) => s.client_fk.equals(clientPk))).get();
  }

  Stream<List<InferenceServer>> watchInferenceServersForClient(int clientPk) {
    return (select(
      inferenceServers,
    )..where((s) => s.client_fk.equals(clientPk))).watch();
  }

  Future<int> createInferenceServer(InferenceServersCompanion entry) =>
      into(inferenceServers).insert(entry);

  Future<bool> updateInferenceServer(InferenceServersCompanion entry) =>
      update(inferenceServers).replace(entry);

  Future<int> deleteInferenceServer(int serverPk) {
    return (delete(
      inferenceServers,
    )..where((s) => s.server_pk.equals(serverPk))).go();
  }

  /// Upserts the managed Nexus Router (subscription) server for a client. The
  /// row is detected by its `routed` providerType; its apiKey is the account
  /// token the gateway mints on login (which rotates), and [maxAgents] /
  /// [maxConcurrency] come from the account's current subscription entitlements.
  ///
  /// Change-aware: when the row already matches, nothing is written, so the
  /// periodic poll that calls this never churns the InferenceServers stream.
  Future<void> upsertRoutedServer({
    required int clientPk,
    required String name,
    required String baseUrl,
    required String apiKey,
    int? maxAgents,
    int? maxConcurrency,
  }) async {
    final existing =
        await (select(inferenceServers)..where(
              (s) =>
                  s.client_fk.equals(clientPk) &
                  s.providerType.equals(kRoutedProviderType),
            ))
            .get();
    if (existing.isEmpty) {
      await createInferenceServer(
        InferenceServersCompanion.insert(
          client_fk: clientPk,
          name: name,
          baseUrl: baseUrl,
          apiKey: Value(apiKey),
          providerType: const Value(kRoutedProviderType),
          maxAgents: maxAgents == null
              ? const Value.absent()
              : Value(maxAgents),
          maxConcurrency: maxConcurrency == null
              ? const Value.absent()
              : Value(maxConcurrency),
        ),
      );
      return;
    }
    final row = existing.first;
    // Collapse any accidental duplicates so the list never shows two routers.
    for (final extra in existing.skip(1)) {
      await deleteInferenceServer(extra.server_pk);
    }
    final unchanged =
        row.name == name &&
        row.baseUrl == baseUrl &&
        row.apiKey == apiKey &&
        (maxAgents == null || row.maxAgents == maxAgents) &&
        (maxConcurrency == null || row.maxConcurrency == maxConcurrency);
    if (unchanged) return;
    await (update(
      inferenceServers,
    )..where((s) => s.server_pk.equals(row.server_pk))).write(
      InferenceServersCompanion(
        name: Value(name),
        baseUrl: Value(baseUrl),
        apiKey: Value(apiKey),
        maxAgents: maxAgents == null ? const Value.absent() : Value(maxAgents),
        maxConcurrency: maxConcurrency == null
            ? const Value.absent()
            : Value(maxConcurrency),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Removes the managed Nexus Router server(s) for a client (on sign-out).
  Future<int> removeRoutedServersForClient(int clientPk) {
    return (delete(inferenceServers)..where(
          (s) =>
              s.client_fk.equals(clientPk) &
              s.providerType.equals(kRoutedProviderType),
        ))
        .go();
  }

  Future<void> updateInferenceServerSelectedModel(
    int serverPk,
    String? modelId,
  ) async {
    await (update(inferenceServers)..where((s) => s.server_pk.equals(serverPk)))
        .write(InferenceServersCompanion(selectedModel: Value(modelId)));
  }

  Future<void> updateInferenceServerAvailableModels(
    int serverPk,
    List<String> models,
  ) async {
    await (update(
      inferenceServers,
    )..where((s) => s.server_pk.equals(serverPk))).write(
      InferenceServersCompanion(
        availableModelsJson: Value(json.encode(models)),
      ),
    );
  }

  // ==================== Agent Personas ====================
  Future<List<AgentPersona>> getAgentPersonasForClient(int clientPk) {
    return (select(
      agentPersonas,
    )..where((p) => p.client_fk.equals(clientPk))).get();
  }

  Stream<List<AgentPersona>> watchAgentPersonasForClient(int clientPk) {
    return (select(
      agentPersonas,
    )..where((p) => p.client_fk.equals(clientPk))).watch();
  }

  /// Every persona across all clients (used by launch-time reconciliation that
  /// repairs role-default tool permissions on already-seeded personas).
  Future<List<AgentPersona>> getAllAgentPersonas() => select(agentPersonas).get();

  Future<int> createAgentPersona(AgentPersonasCompanion entry) =>
      into(agentPersonas).insert(entry);

  Future<bool> updateAgentPersona(AgentPersonasCompanion entry) =>
      update(agentPersonas).replace(entry);

  Future<int> deleteAgentPersona(int agentPk) {
    return (delete(
      agentPersonas,
    )..where((p) => p.agent_pk.equals(agentPk))).go();
  }

  Future<AgentPersona?> resolveAgentPersona(int agentPk) async {
    return (select(
      agentPersonas,
    )..where((p) => p.agent_pk.equals(agentPk))).getSingleOrNull();
  }

  // ==================== Deployments (placeholder) ====================
  Future<List<Deployment>> getDeploymentsForClient(int clientPk) {
    return (select(
      deployments,
    )..where((d) => d.client_fk.equals(clientPk))).get();
  }

  Stream<List<Deployment>> watchDeploymentsForClient(int clientPk) {
    return (select(
      deployments,
    )..where((d) => d.client_fk.equals(clientPk))).watch();
  }

  Future<int> createDeployment(DeploymentsCompanion entry) =>
      into(deployments).insert(entry);

  // ==================== Coordinator Chat Sessions ====================
  Stream<List<ChatSession>> watchChatSessionsForProject(int projectPk) {
    return (select(chatSessions)
          ..where((s) => s.project_fk.equals(projectPk))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<ChatSession>> getChatSessionsForProject(int projectPk) {
    return (select(chatSessions)
          ..where((s) => s.project_fk.equals(projectPk))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Inserts a session and returns its new integer pk.
  Future<int> createChatSession(ChatSessionsCompanion entry) =>
      into(chatSessions).insert(entry);

  /// Resolves the chat session for a project — and, when [planPath] is given, the
  /// session tied to that specific plan file (creating one if none exists yet).
  /// This keeps a plan's conversation distinct from the general project chat and
  /// records the plan link so work can be backtracked to it. Returns its pk.
  Future<int> getOrCreateChatSession(int projectPk, {String? planPath}) async {
    final query = select(chatSessions)
      ..where((s) => s.project_fk.equals(projectPk));
    query.where(
      (s) => planPath == null
          ? s.plan_path.isNull()
          : s.plan_path.equals(planPath),
    );
    query.orderBy([
      (s) => OrderingTerm(expression: s.updatedAt, mode: OrderingMode.desc),
    ]);
    final existing = await query.get();
    if (existing.isNotEmpty) return existing.first.session_pk;
    return createChatSession(
      ChatSessionsCompanion.insert(
        project_fk: projectPk,
        plan_path: planPath != null ? Value(planPath) : const Value.absent(),
      ),
    );
  }

  /// Scope marker stored in [ChatSessions.plan_path] for an agent's dedicated
  /// session. Lets all of one agent's autonomous task work show up as a SINGLE
  /// ongoing conversation (keyed by agent) instead of a brand-new session per
  /// task/stage. It can't collide with the general project chat (plan_path IS
  /// NULL) or a plan chat (a real `/PLANS/...` path), so [getOrCreateChatSession]
  /// keeps returning the human's project-level session untouched.
  static String agentSessionScope(int agentPk) => '#agent:$agentPk';

  /// The one chat session that belongs to [agentPk] within a project: created
  /// once (titled [agentName] so it reads nicely in the sidebar) and reused for
  /// every task that agent runs, so the board no longer spawns a fresh session
  /// on each task update. Returns its pk.
  Future<int> getOrCreateAgentChatSession(
    int projectPk,
    int agentPk,
    String agentName,
  ) {
    final scope = agentSessionScope(agentPk);
    // Transaction so two concurrent orchestrator stages for the SAME agent
    // (cap up to 12) can't both find none and both insert → duplicate sessions.
    return transaction(() async {
      final existing =
          await (select(chatSessions)
                ..where(
                  (s) =>
                      s.project_fk.equals(projectPk) &
                      s.plan_path.equals(scope),
                )
                ..orderBy([
                  (s) => OrderingTerm(
                    expression: s.updatedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      if (existing.isNotEmpty) return existing.first.session_pk;
      return createChatSession(
        ChatSessionsCompanion.insert(
          project_fk: projectPk,
          plan_path: Value(scope),
          title: Value(agentName.trim().isEmpty ? 'Agent' : agentName.trim()),
        ),
      );
    });
  }

  Future<void> touchChatSession(int sessionPk, {String? title}) async {
    await (update(
      chatSessions,
    )..where((s) => s.session_pk.equals(sessionPk))).write(
      ChatSessionsCompanion(
        updatedAt: Value(DateTime.now()),
        title: title != null ? Value(title) : const Value.absent(),
      ),
    );
  }

  Future<bool> deleteChatSession(int sessionPk) async {
    await (delete(
      chatMessages,
    )..where((m) => m.session_fk.equals(sessionPk))).go();
    final r = await (delete(
      chatSessions,
    )..where((s) => s.session_pk.equals(sessionPk))).go();
    return r > 0;
  }

  Stream<List<ChatMessage>> watchChatMessagesForSession(int sessionPk) {
    return (select(chatMessages)
          ..where((m) => m.session_fk.equals(sessionPk))
          ..orderBy([
            (m) => OrderingTerm(expression: m.seq),
            (m) => OrderingTerm(expression: m.createdAt),
          ]))
        .watch();
  }

  Future<List<ChatMessage>> getChatMessagesForSession(int sessionPk) {
    return (select(chatMessages)
          ..where((m) => m.session_fk.equals(sessionPk))
          ..orderBy([
            (m) => OrderingTerm(expression: m.seq),
            (m) => OrderingTerm(expression: m.createdAt),
          ]))
        .get();
  }

  Future<int> countChatMessages(int sessionPk) async {
    final rows = await (select(
      chatMessages,
    )..where((m) => m.session_fk.equals(sessionPk))).get();
    return rows.length;
  }

  /// Inserts a chat message and returns its message_pk.
  Future<int> addChatMessage(ChatMessagesCompanion entry) =>
      into(chatMessages).insert(entry);

  /// Removes a single chat message (used to drop a failed turn's user message
  /// so it can't reload as orphaned, role-breaking history).
  Future<void> deleteChatMessage(int messagePk) =>
      (delete(chatMessages)..where((m) => m.message_pk.equals(messagePk))).go();

  // ==================== Training data (Export Tracking) ====================
  // Stored in plain SQLite tables managed by raw SQL (no drift codegen) so the
  // Account → Export Tracking exporters can read full conversation traces +
  // per-message ratings. Created on launch by [ensureTrainingTables].

  /// Idempotently create the training/rating tables. Safe to call every launch.
  Future<void> ensureTrainingTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS training_traces ('
      'trace_pk INTEGER PRIMARY KEY AUTOINCREMENT, '
      'project_fk INTEGER NOT NULL, '
      'ai_kind TEXT NOT NULL, '
      'conversation_id TEXT NOT NULL UNIQUE, '
      "messages_json TEXT NOT NULL DEFAULT '[]', "
      'updated_at TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS ai_ratings ('
      'rating_pk INTEGER PRIMARY KEY AUTOINCREMENT, '
      'project_fk INTEGER NOT NULL, '
      'ai_kind TEXT NOT NULL, '
      'conversation_id TEXT NOT NULL, '
      'message_ref TEXT NOT NULL, '
      'stars INTEGER NOT NULL, '
      'reasons_json TEXT, '
      'created_at TEXT NOT NULL, '
      'updated_at TEXT NOT NULL, '
      'UNIQUE(conversation_id, message_ref))',
    );
    // Migrate older coordinator/discovery ratings to the STABLE stories id so
    // they survive the discovery → coordinator phase switch (the id used to flip
    // from `discovery:<pid>` to `coordinator:<pid>:<sessionId>`, orphaning them).
    // Idempotent — already-stable rows are excluded by the WHERE.
    await customStatement(
      "UPDATE ai_ratings SET ai_kind = 'stories', "
      "conversation_id = 'stories:' || project_fk "
      "WHERE (ai_kind = 'stories' OR ai_kind = 'coordinator') "
      "AND conversation_id <> 'stories:' || project_fk",
    );
  }

  /// Upsert one conversation trace, keeping the LONGEST version — re-posting a
  /// growing conversation collapses to its final, complete form (no prefix spam).
  Future<void> upsertTrainingTrace({
    required int projectPk,
    required String aiKind,
    required String conversationId,
    required String messagesJson,
  }) async {
    int countOf(String json) {
      try {
        final v = jsonDecode(json);
        return v is List ? v.length : 0;
      } catch (_) {
        return 0;
      }
    }

    final now = DateTime.now().toIso8601String();
    final existing = await customSelect(
      'SELECT messages_json FROM training_traces WHERE conversation_id = ?',
      variables: [Variable<String>(conversationId)],
    ).get();
    if (existing.isEmpty) {
      await customInsert(
        'INSERT INTO training_traces '
        '(project_fk, ai_kind, conversation_id, messages_json, updated_at) '
        'VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable<int>(projectPk),
          Variable<String>(aiKind),
          Variable<String>(conversationId),
          Variable<String>(messagesJson),
          Variable<String>(now),
        ],
      );
      return;
    }
    if (countOf(messagesJson) <
        countOf(existing.first.read<String>('messages_json'))) {
      return;
    }
    await customUpdate(
      'UPDATE training_traces SET messages_json = ?, ai_kind = ?, '
      'project_fk = ?, updated_at = ? WHERE conversation_id = ?',
      variables: [
        Variable<String>(messagesJson),
        Variable<String>(aiKind),
        Variable<int>(projectPk),
        Variable<String>(now),
        Variable<String>(conversationId),
      ],
    );
  }

  /// All trace rows for the given projects, optionally filtered to one [aiKind].
  /// Each row is a raw map (conversation_id, project_fk, ai_kind, messages_json,
  /// updated_at).
  Future<List<Map<String, Object?>>> getTrainingTraces(
    List<int> projectPks, {
    String? aiKind,
  }) async {
    if (projectPks.isEmpty) return const [];
    final placeholders = List.filled(projectPks.length, '?').join(',');
    final vars = <Variable>[for (final p in projectPks) Variable<int>(p)];
    var sql =
        'SELECT project_fk, ai_kind, conversation_id, messages_json, updated_at '
        'FROM training_traces WHERE project_fk IN ($placeholders)';
    if (aiKind != null) {
      sql += ' AND ai_kind = ?';
      vars.add(Variable<String>(aiKind));
    }
    sql += ' ORDER BY project_fk';
    final rows = await customSelect(sql, variables: vars).get();
    return [for (final r in rows) r.data];
  }

  /// The current star rating for a single message, or null.
  Future<int?> getAiRating(String conversationId, String messageRef) async {
    final rows = await customSelect(
      'SELECT stars FROM ai_ratings WHERE conversation_id = ? AND '
      'message_ref = ?',
      variables: [
        Variable<String>(conversationId),
        Variable<String>(messageRef),
      ],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<int>('stars');
  }

  /// Insert or update a per-message rating (one per conversation + messageRef).
  Future<void> upsertAiRating({
    required int projectPk,
    required String aiKind,
    required String conversationId,
    required String messageRef,
    required int stars,
    String? reasonsJson,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existing = await customSelect(
      'SELECT rating_pk FROM ai_ratings WHERE conversation_id = ? AND '
      'message_ref = ?',
      variables: [
        Variable<String>(conversationId),
        Variable<String>(messageRef),
      ],
    ).get();
    if (existing.isEmpty) {
      await customInsert(
        'INSERT INTO ai_ratings (project_fk, ai_kind, conversation_id, '
        'message_ref, stars, reasons_json, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<int>(projectPk),
          Variable<String>(aiKind),
          Variable<String>(conversationId),
          Variable<String>(messageRef),
          Variable<int>(stars),
          Variable<String>(reasonsJson),
          Variable<String>(now),
          Variable<String>(now),
        ],
      );
      return;
    }
    await customUpdate(
      'UPDATE ai_ratings SET stars = ?, reasons_json = ?, updated_at = ? '
      'WHERE conversation_id = ? AND message_ref = ?',
      variables: [
        Variable<int>(stars),
        Variable<String>(reasonsJson),
        Variable<String>(now),
        Variable<String>(conversationId),
        Variable<String>(messageRef),
      ],
    );
  }

  /// All rating rows for the given conversations (for export).
  Future<List<Map<String, Object?>>> getAiRatingsForProjects(
    List<int> projectPks, {
    String? aiKind,
  }) async {
    if (projectPks.isEmpty) return const [];
    final placeholders = List.filled(projectPks.length, '?').join(',');
    final vars = <Variable>[for (final p in projectPks) Variable<int>(p)];
    var sql =
        'SELECT project_fk, ai_kind, conversation_id, message_ref, stars, '
        'reasons_json, updated_at FROM ai_ratings WHERE project_fk IN '
        '($placeholders)';
    if (aiKind != null) {
      sql += ' AND ai_kind = ?';
      vars.add(Variable<String>(aiKind));
    }
    final rows = await customSelect(sql, variables: vars).get();
    return [for (final r in rows) r.data];
  }

  // ==================== Activity Logs (placeholder) ====================
  Future<List<ActivityLog>> getActivityLogsForClient(int clientPk) {
    return (select(
      activityLogs,
    )..where((a) => a.client_fk.equals(clientPk))).get();
  }

  Stream<List<ActivityLog>> watchActivityLogsForClient(int clientPk) {
    return (select(
      activityLogs,
    )..where((a) => a.client_fk.equals(clientPk))).watch();
  }

  Future<int> createActivityLog(ActivityLogsCompanion entry) =>
      into(activityLogs).insert(entry);

  // ==================== CI / Build Runs ====================
  Future<List<CiRun>> getCiRunsForClient(int clientPk) {
    return (select(ciRuns)
          ..where((c) => c.client_fk.equals(clientPk))
          ..orderBy([
            (c) =>
                OrderingTerm(expression: c.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<List<CiRun>> watchCiRunsForClient(int clientPk) {
    return (select(ciRuns)
          ..where((c) => c.client_fk.equals(clientPk))
          ..orderBy([
            (c) =>
                OrderingTerm(expression: c.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<CiRun>> watchCiRunsForProject(int projectPk) {
    return (select(ciRuns)
          ..where((c) => c.project_fk.equals(projectPk))
          ..orderBy([
            (c) =>
                OrderingTerm(expression: c.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// The most recent CI run for a project (newest by createdAt), or null.
  Future<CiRun?> getLatestCiRunForProject(int projectPk) => (select(ciRuns)
        ..where((c) => c.project_fk.equals(projectPk))
        ..orderBy([
          (c) => OrderingTerm(expression: c.createdAt, mode: OrderingMode.desc),
        ])
        ..limit(1))
      .getSingleOrNull();

  Future<CiRun?> getCiRun(int runPk) => (select(
    ciRuns,
  )..where((c) => c.ci_run_pk.equals(runPk))).getSingleOrNull();

  Stream<CiRun?> watchCiRun(int runPk) => (select(
    ciRuns,
  )..where((c) => c.ci_run_pk.equals(runPk))).watchSingleOrNull();

  Future<int> createCiRun(CiRunsCompanion entry) => into(ciRuns).insert(entry);

  Future<void> patchCiRun(int runPk, CiRunsCompanion patch) async {
    await (update(
      ciRuns,
    )..where((c) => c.ci_run_pk.equals(runPk))).write(patch);
  }

  /// Removes a run and its full jobs→steps subtree.
  Future<bool> deleteCiRun(int runPk) async {
    final jobs = await (select(
      ciJobs,
    )..where((j) => j.ci_run_fk.equals(runPk))).get();
    for (final j in jobs) {
      await (delete(
        ciSteps,
      )..where((s) => s.ci_job_fk.equals(j.ci_job_pk))).go();
    }
    await (delete(ciJobs)..where((j) => j.ci_run_fk.equals(runPk))).go();
    final r = await (delete(
      ciRuns,
    )..where((c) => c.ci_run_pk.equals(runPk))).go();
    return r > 0;
  }

  // ==================== CI Jobs ====================
  Future<List<CiJob>> getCiJobsForRun(int runPk) {
    return (select(ciJobs)
          ..where((j) => j.ci_run_fk.equals(runPk))
          ..orderBy([(j) => OrderingTerm(expression: j.orderIndex)]))
        .get();
  }

  Stream<List<CiJob>> watchCiJobsForRun(int runPk) {
    return (select(ciJobs)
          ..where((j) => j.ci_run_fk.equals(runPk))
          ..orderBy([(j) => OrderingTerm(expression: j.orderIndex)]))
        .watch();
  }

  Future<int> createCiJob(CiJobsCompanion entry) => into(ciJobs).insert(entry);

  Future<void> patchCiJob(int jobPk, CiJobsCompanion patch) async {
    await (update(
      ciJobs,
    )..where((j) => j.ci_job_pk.equals(jobPk))).write(patch);
  }

  // ==================== CI Steps ====================
  Future<List<CiStep>> getCiStepsForJob(int jobPk) {
    return (select(ciSteps)
          ..where((s) => s.ci_job_fk.equals(jobPk))
          ..orderBy([(s) => OrderingTerm(expression: s.orderIndex)]))
        .get();
  }

  Stream<List<CiStep>> watchCiStepsForJob(int jobPk) {
    return (select(ciSteps)
          ..where((s) => s.ci_job_fk.equals(jobPk))
          ..orderBy([(s) => OrderingTerm(expression: s.orderIndex)]))
        .watch();
  }

  Future<int> createCiStep(CiStepsCompanion entry) =>
      into(ciSteps).insert(entry);

  Future<void> patchCiStep(int stepPk, CiStepsCompanion patch) async {
    await (update(
      ciSteps,
    )..where((s) => s.ci_step_pk.equals(stepPk))).write(patch);
  }

  /// Appends a chunk of captured output to a step's running log.
  Future<void> appendCiStepLog(int stepPk, String chunk) async {
    // ATOMIC append. The log sink fires this UNAWAITED, once per line, so a
    // read-modify-write (`row.logText + chunk`) raced dozens of concurrent
    // callers that each read the same value and clobbered one another — only the
    // last line (the "N issues found" summary) survived, dropping every actual
    // diagnostic. A single SQL `||` concatenation can't lose updates.
    await customStatement(
      'UPDATE ci_steps SET log_text = log_text || ? WHERE ci_step_pk = ?',
      [chunk, stepPk],
    );
  }
}

// Helper to suppress noisy Drift multiple-DB warning in debug during heavy development.
void _initDriftOptions() {
  if (kDebugMode) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }
}

/// Platform-specific database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'nexus_projects.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
