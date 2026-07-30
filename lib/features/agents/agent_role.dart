// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Canonical agent roles (titles). The persona's `title` column stores the
/// enum's [AgentRole.key] (e.g. "projectManager"); the rule engine in
/// agent_role_policy.dart maps a role to its default skills and tool
/// permissions. Keeping titles as an enum (not free text) is what lets the
/// permission rule engine be deterministic.
enum AgentRole {
  /// Human-facing planner. Builds technical plans, creates and manages tasks,
  /// assigns work. The single conversational surface for the user.
  projectManager,

  /// Integration agent. Merges passing task branches into main and runs builds.
  /// The only role allowed to push/merge.
  coordinator,

  /// Post-completion Editor. The user-facing agent for a FINISHED project: it
  /// edits the built code directly, commits, runs build/CI, and can delegate
  /// larger changes to worker agents. Blends the Generalist's code authoring
  /// with the Coordinator's integration + task delegation.
  editor,

  /// Default worker. Implements a task on its own branch, autonomously.
  sdeGeneralist,

  /// Worker specialized in protocol/API/socket/networking code.
  sdeNetworking,

  /// Worker specialized in simulation/numeric/physics code.
  sdePhysics,

  /// Worker specialized in schema/migration/query/database code.
  sdeDatabase,

  /// Worker specialized in Flutter widget/layout/accessibility code.
  sdeUiUx,

  /// Worker specialized in build/release engineering: Dockerfiles, CMakeLists,
  /// and CI workflow YAML. Authors the build files a task needs and wires its
  /// build gate.
  sdeDevOps,

  /// Proves a worker's submission against the task's verification. Read + run
  /// only — cannot edit code, so it can't make work pass by changing it.
  verificationAgent,
}

extension AgentRoleX on AgentRole {
  /// Stable string stored in the DB `title` column.
  String get key => name;

  /// Human-readable title surfaced in the UI and to the PM when assigning.
  String get displayTitle => switch (this) {
    AgentRole.projectManager => 'Project Manager',
    AgentRole.coordinator => 'Coordinator',
    AgentRole.editor => 'Editor',
    AgentRole.sdeGeneralist => 'SDE Generalist',
    AgentRole.sdeNetworking => 'SDE Networking',
    AgentRole.sdePhysics => 'SDE Physics',
    AgentRole.sdeDatabase => 'SDE Database',
    AgentRole.sdeUiUx => 'SDE UI/UX',
    AgentRole.sdeDevOps => 'SDE DevOps',
    AgentRole.verificationAgent => 'Verification Agent',
  };

  String get description => switch (this) {
    AgentRole.projectManager =>
      'Builds technical plans, decomposes them into tasks, assigns work, and reports progress. Your one live chat.',
    AgentRole.coordinator =>
      'Integrates approved task branches into main, resolves merges, and runs builds/CI.',
    AgentRole.editor =>
      'Edits and evolves a finished project: changes the code directly, runs build/CI, commits, and can delegate larger work to worker agents.',
    AgentRole.sdeGeneralist =>
      'General software engineer. Implements a task end-to-end on its own branch.',
    AgentRole.sdeNetworking =>
      'Engineer focused on networking: protocols, API clients, sockets, transport code.',
    AgentRole.sdePhysics =>
      'Engineer focused on simulation, numerical methods, and physics code.',
    AgentRole.sdeDatabase =>
      'Engineer focused on database schema, migrations, and queries.',
    AgentRole.sdeUiUx =>
      'Engineer focused on Flutter UI, layout, and accessibility.',
    AgentRole.sdeDevOps =>
      'Build/release engineer. Authors Dockerfiles, CMakeLists, and CI workflow YAML, and wires a task\'s build gate.',
    AgentRole.verificationAgent =>
      'Runs each task\'s verification and emits a pass/fail verdict with proof. Read + run only.',
  };

  /// True for the SDE worker roles that get spawned per task and die on approval.
  bool get isWorker => switch (this) {
    AgentRole.sdeGeneralist ||
    AgentRole.sdeNetworking ||
    AgentRole.sdePhysics ||
    AgentRole.sdeDatabase ||
    AgentRole.sdeUiUx ||
    AgentRole.sdeDevOps => true,
    _ => false,
  };
}

/// Parses an [AgentRole] from a stored title key. Returns null if unknown
/// (e.g. a legacy free-text title that predates the enum).
AgentRole? agentRoleFromKey(String? key) {
  if (key == null) return null;
  for (final r in AgentRole.values) {
    if (r.key == key) return r;
  }
  return null;
}
