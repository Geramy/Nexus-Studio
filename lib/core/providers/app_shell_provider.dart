// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_provider.dart';
import '../../infrastructure/inference/inference_backend_factory.dart'
    show resetInferenceConnections;

part 'app_shell_provider.g.dart';

enum MainView {
  projectPlans,
  tasks,
  agents,
  aiProviders,
  activity,
  launch,
  code,
  callFlow,
  account,
}

@riverpod
class CurrentMainView extends _$CurrentMainView {
  @override
  MainView build() => MainView.projectPlans;

  void setView(MainView view) {
    state = view;
  }
}

@riverpod
class SelectedTaskIdNotifier extends _$SelectedTaskIdNotifier {
  @override
  int? build() => 1; // Default seeded master task (task_pk 1)

  void selectTask(int id) {
    state = id;
  }
}

/// Current selected client (top level of the hierarchy)
@riverpod
class CurrentClientId extends _$CurrentClientId {
  @override
  int build() => 1; // Default client on startup (client_pk 1 after seeding)

  void selectClient(int clientId) {
    state = clientId;
  }
}

/// Current selected project (part of Client → Projects → Tasks hierarchy)
@riverpod
class CurrentProjectId extends _$CurrentProjectId {
  @override
  int build() => 1; // Default seeded project on startup (project_pk 1)

  void selectProject(int projectId) {
    final previous = state;
    if (projectId == previous) return;
    state = projectId;
    // Leaving a project: STOP its autonomous loop and free ALL inference
    // connections so the NEW project gets the full concurrent-connection budget
    // immediately. Without this the old project's worker agents AND the
    // reserved Coordinator slot keep their sockets open, and the new project
    // 429s (too_many_connections). The old project resumes when you Start it.
    resetInferenceConnections();
    final db = ref.read(nexusDatabaseProvider);
    unawaited(() async {
      try {
        final proj = await db.getProjectById(previous);
        if (proj?.orchestrationState == 'running') {
          await db.setProjectOrchestrationState(previous, 'paused');
        }
      } catch (_) {}
    }());
  }
}

@riverpod
class ConnectionModeNotifier extends _$ConnectionModeNotifier {
  @override
  String build() => 'local'; // 'local' | 'remote'

  void toggle() {
    state = state == 'local' ? 'remote' : 'local';
  }

  void setMode(String mode) {
    state = mode;
  }
}

/// Holds the currently editing persona (opens in right panel, like AI Providers admin console).
class EditingPersona {
  final int id; // agent_pk of the persona row
  final String name;
  const EditingPersona({required this.id, required this.name});
}

@riverpod
class SelectedPersonaNotifier extends _$SelectedPersonaNotifier {
  @override
  EditingPersona? build() => null;

  void select(EditingPersona persona) {
    state = persona;
  }

  void clear() {
    state = null;
  }
}

/// The active Coordinator chat session id for a given project (right-panel
/// selection). Family keyed by projectId so each project has its own active
/// session. The coordinator chat screen opens this session; the Chat Sessions
/// sidebar selects/creates it.
@riverpod
class CurrentChatSession extends _$CurrentChatSession {
  @override
  int? build(int projectId) => null;

  void select(int? sessionId) {
    state = sessionId;
  }
}

/// The plan currently opened in the Project Plans workspace (workspace path,
/// e.g. `/PLANS/Roadmap.md`), set by clicking a plan file in the explorer.
/// Null = nothing open.
@riverpod
class OpenPlanNotifier extends _$OpenPlanNotifier {
  @override
  String? build() => null;

  void open(String? planPath) {
    state = planPath;
  }
}

/// Edit vs Chat mode for the opened plan in the workspace.
enum PlanMode { edit, chat }

@riverpod
class PlanModeNotifier extends _$PlanModeNotifier {
  @override
  PlanMode build() => PlanMode.edit;

  void set(PlanMode mode) {
    state = mode;
  }
}

/// Persistent right-panel width per MainView.
/// Stored in SharedPreferences so layout survives app restarts.
@riverpod
class PanelLayoutNotifier extends _$PanelLayoutNotifier {
  static const _prefix = 'panel_right_width_';
  static const _collapsedPrefix = 'panel_right_collapsed_';
  static const double defaultWidth = 520.0;

  @override
  Map<MainView, double> build() => {};

  /// Get the saved width for a view, falling back to the default.
  double getWidth(MainView view) {
    return state[view] ?? defaultWidth;
  }

  /// Set and persist the width for a view.
  Future<void> setWidth(MainView view, double width) async {
    state = {...state, view: width};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_prefix${view.name}', width);
  }

  /// Load all saved widths from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <MainView, double>{};
    for (final view in MainView.values) {
      final w = prefs.getDouble('$_prefix${view.name}');
      if (w != null && w >= 160) {
        loaded[view] = w;
      }
    }
    // Riverpod 3 throws if `state` is set after the provider was disposed/rebuilt
    // during the await; bail out instead of crashing (the new build re-loads).
    if (!ref.mounted) return;
    state = loaded;
  }

  // ---------------------------------------------------------------------------
  // Right-panel collapsed/expanded state (persisted per MainView).
  // Kept out of [state] (which holds widths) so this notifier's build()
  // signature is unchanged; the shell drives the UI from local state and uses
  // these only for persistence — exactly like the width logic above.
  // ---------------------------------------------------------------------------

  /// Persist the collapsed/expanded state for a view.
  Future<void> setCollapsed(MainView view, bool collapsed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_collapsedPrefix${view.name}', collapsed);
  }

  /// Load saved collapsed flags for every view (absent → expanded).
  Future<Map<MainView, bool>> loadCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <MainView, bool>{};
    for (final view in MainView.values) {
      final c = prefs.getBool('$_collapsedPrefix${view.name}');
      if (c != null) loaded[view] = c;
    }
    return loaded;
  }
}
