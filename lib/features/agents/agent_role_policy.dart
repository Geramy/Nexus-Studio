// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'agent_role.dart';
import 'agent_tool_permissions.dart';

/// Rule engine: maps an [AgentRole] to its default **skills** and default
/// **tool permissions**. This is the single source of truth for "what can an
/// agent of this title do" — seed personas are built from it, and it can be
/// re-applied to reset an agent to its role defaults.
///
/// Model: a *skill* is a named bundle of tools, each with a permission. A role
/// holds a set of skills. A tool the role's skills don't mention is **denied**
/// (default-deny), which is safer than the catalog's lenient default.

/// Orchestration tools that don't live in [kCoordinatorToolSpecs] yet — they're
/// implemented when the spawn→submit→verify→merge loop is wired. Declared here
/// so the rule engine can already assign them per role.
const String kToolSubmitForCompletion = 'submit_for_completion';
const String kToolSubmitVerdict = 'submit_verdict';
const String kToolRunVerification = 'run_verification';
const String kToolReviewSubmission = 'review_submission';
const String kToolApproveTask = 'approve_task';
const String kToolRejectTask = 'reject_task';

const List<String> kOrchestrationToolNames = [
  kToolSubmitForCompletion,
  kToolSubmitVerdict,
  kToolRunVerification,
  kToolReviewSubmission,
  kToolApproveTask,
  kToolRejectTask,
];

/// Skill bundles: skill name → { tool → permission within this skill }.
/// Destructive tools are pinned to [ToolPerm.ask] even inside a granted skill,
/// so autonomy never silently deletes or pushes without a checkpoint.
const Map<String, Map<String, ToolPerm>> kSkillCatalog = {
  'plan-authoring': {
    'list_plans': ToolPerm.grant,
    'view_current_plan': ToolPerm.grant,
    'view_plan': ToolPerm.grant,
    'read_plan': ToolPerm.grant,
    'create_plan': ToolPerm.grant,
    'update_plan': ToolPerm.grant,
    'write_plan': ToolPerm.grant,
    'rename_plan': ToolPerm.grant,
    'delete_plan': ToolPerm.ask,
    'propose_plan_adjustment': ToolPerm.grant,
  },
  'task-management': {
    'list_tasks': ToolPerm.grant,
    'list_open_tasks': ToolPerm.grant,
    'get_task': ToolPerm.grant,
    'create_task': ToolPerm.grant,
    'update_task': ToolPerm.grant,
    'update_task_status': ToolPerm.grant,
    'set_task_dates': ToolPerm.grant,
    'link_task_to_plan': ToolPerm.grant,
    'delete_task': ToolPerm.ask,
  },
  'work-assignment': {
    'list_agents': ToolPerm.grant,
    'assign_agent_to_task': ToolPerm.grant,
  },
  'build-authoring': {
    'set_task_build_config': ToolPerm.grant,
    'scaffold_ci_workflow': ToolPerm.grant,
  },
  'review': {
    kToolReviewSubmission: ToolPerm.grant,
    kToolApproveTask: ToolPerm.grant,
    kToolRejectTask: ToolPerm.grant,
  },
  'code-read': {
    'list_files': ToolPerm.grant,
    'read_file': ToolPerm.grant,
    'list_directory': ToolPerm.grant,
    'search_directory': ToolPerm.grant,
    'search_file_content': ToolPerm.grant,
    'read_file_chunk': ToolPerm.grant,
  },
  'code-write': {
    'create_file': ToolPerm.grant,
    'edit_file': ToolPerm.grant,
    'write_file': ToolPerm.grant,
    'create_directory': ToolPerm.grant,
    'move_path': ToolPerm.ask,
    'delete_path': ToolPerm.ask,
    'delete_file': ToolPerm.ask,
    'delete_folder': ToolPerm.ask,
  },
  'vcs-local': {
    'git_status': ToolPerm.grant,
    'git_log': ToolPerm.grant,
    'git_branches': ToolPerm.grant,
    'git_create_branch': ToolPerm.grant,
    'git_checkout_branch': ToolPerm.grant,
    'git_commit': ToolPerm.grant,
  },
  'vcs-integration': {
    'git_pull': ToolPerm.grant,
    'git_merge': ToolPerm.grant,
    'git_push': ToolPerm.ask,
  },
  'build-ci': {
    'build_docker_image': ToolPerm.grant,
    'run_workflow': ToolPerm.grant,
    'scaffold_ci_workflow': ToolPerm.grant,
    'list_ci_runs': ToolPerm.grant,
    'get_ci_run': ToolPerm.grant,
  },
  'verification': {
    kToolRunVerification: ToolPerm.grant,
    kToolSubmitVerdict: ToolPerm.grant,
  },
  'completion': {kToolSubmitForCompletion: ToolPerm.grant},
  'diagramming': {'generate_diagram': ToolPerm.grant},
};

/// Display metadata for each skill bundle: human description, category, and
/// risk level. Used when seeding the reusable Skill prefab rows.
class SkillMeta {
  final String description;
  final String category;
  final String riskLevel; // low, medium, high, critical
  const SkillMeta(this.description, this.category, this.riskLevel);
}

const Map<String, SkillMeta> kSkillMeta = {
  'plan-authoring': SkillMeta(
    'Create and maintain technical plans.',
    'plans',
    'low',
  ),
  'task-management': SkillMeta(
    'Create, update, and manage tasks.',
    'tasks',
    'low',
  ),
  'work-assignment': SkillMeta(
    'List agents and assign tasks to them.',
    'orchestration',
    'medium',
  ),
  'build-authoring': SkillMeta(
    'Configure a task\'s build gate and scaffold CI workflows.',
    'build',
    'medium',
  ),
  'review': SkillMeta(
    'Review submissions and approve or reject tasks.',
    'orchestration',
    'medium',
  ),
  'code-read': SkillMeta(
    'Read and search the workspace without modifying it.',
    'filesystem',
    'low',
  ),
  'code-write': SkillMeta(
    'Create, edit, and delete workspace files.',
    'filesystem',
    'high',
  ),
  'vcs-local': SkillMeta(
    'Local git: status, log, branches, commit.',
    'git',
    'medium',
  ),
  'vcs-integration': SkillMeta(
    'Integrate work: pull, merge, push.',
    'git',
    'critical',
  ),
  'build-ci': SkillMeta(
    'Build Docker images and run CI workflows.',
    'build',
    'high',
  ),
  'verification': SkillMeta(
    'Run a task verification and emit a verdict.',
    'testing',
    'low',
  ),
  'completion': SkillMeta(
    'Submit a task for completion review.',
    'workflow',
    'low',
  ),
  'diagramming': SkillMeta('Generate diagrams.', 'other', 'low'),
};

/// Default skills per role. Workers share the same builder skill set; they
/// differ by system prompt specialization, not tools.
const List<String> _workerSkills = [
  'code-read',
  'code-write',
  'vcs-local',
  'build-ci',
  'completion',
];

/// The DevOps worker adds build-authoring to the shared builder skills so it can
/// scaffold CI and set a task's build gate, on top of writing build files.
const List<String> _devOpsSkills = [
  'code-read',
  'code-write',
  'vcs-local',
  'build-ci',
  'build-authoring',
  'completion',
];

const Map<AgentRole, List<String>> kRoleSkills = {
  AgentRole.projectManager: [
    'plan-authoring',
    'task-management',
    'work-assignment',
    'build-authoring',
    'review',
    'code-read',
    'diagramming',
  ],
  AgentRole.coordinator: [
    'code-read',
    'code-write',
    'vcs-local',
    'vcs-integration',
    'build-ci',
    'plan-authoring',
    'task-management',
    'completion',
    'review',
    'work-assignment',
  ],
  AgentRole.sdeGeneralist: _workerSkills,
  AgentRole.sdeNetworking: _workerSkills,
  AgentRole.sdePhysics: _workerSkills,
  AgentRole.sdeDatabase: _workerSkills,
  AgentRole.sdeUiUx: _workerSkills,
  AgentRole.sdeDevOps: _devOpsSkills,
  AgentRole.verificationAgent: ['code-read', 'verification'],
};

/// Every tool the rule engine knows about: the catalog plus orchestration tools
/// plus anything referenced by a skill. Used to materialize a full default-deny
/// permission map.
Set<String> get _allKnownTools => {
  for (final s in kCoordinatorToolSpecs) s.name,
  ...kOrchestrationToolNames,
  for (final skill in kSkillCatalog.values) ...skill.keys,
};

/// The skill names granted to [role].
List<String> defaultSkillNames(AgentRole role) => kRoleSkills[role] ?? const [];

/// Builds a full default-deny tool-permission map and then grants whatever the
/// given [skills] allow. Every known tool gets an explicit grant/ask/deny, so a
/// resolved permission never falls back to a lenient default; tools outside the
/// granted skills are denied. This is the skill-list primitive that both the
/// role engine and the agent-pack catalog (incl. non-software domains, which
/// have no [AgentRole]) build on.
Map<String, ToolPerm> toolPermissionsForSkills(Iterable<String> skills) {
  final perms = <String, ToolPerm>{
    for (final tool in _allKnownTools) tool: ToolPerm.deny,
  };
  for (final skill in skills) {
    final tools = kSkillCatalog[skill];
    if (tools == null) continue;
    tools.forEach((tool, perm) => perms[tool] = perm);
  }
  return perms;
}

/// Serializes a skill list into a `configJson` string, ready to store on a
/// seeded persona (the executor reads `configJson.toolPermissions`).
String configJsonForSkills(Iterable<String> skills) =>
    AgentToolPermissions.writeIntoConfigJson(
      null,
      toolPermissionsForSkills(skills),
    );

/// Builds the full default tool-permission map for [role]. Tools outside the
/// role's skills are denied.
Map<String, ToolPerm> defaultToolPermissions(AgentRole role) =>
    toolPermissionsForSkills(defaultSkillNames(role));

/// Serializes [role]'s default permissions into a `configJson` string, ready to
/// store on a seeded persona (the executor reads `configJson.toolPermissions`).
String defaultConfigJson(AgentRole role) =>
    AgentToolPermissions.writeIntoConfigJson(
      null,
      defaultToolPermissions(role),
    );

/// The tools this role may actually call (grant or ask), for the prompt's
/// "tools you should use" section.
List<String> _usableTools(AgentRole role) {
  final perms = defaultToolPermissions(role);
  final names = [
    for (final e in perms.entries)
      if (e.value != ToolPerm.deny) e.key,
  ];
  names.sort();
  return names;
}

/// Default system prompt for [role]. Every agent is told the team model, its own
/// job, the tools it should use, the branch-per-task rule, and how it finishes.
/// Generated from the role so it stays in sync with the rule engine rather than
/// being stored as stale text.
String defaultSystemPrompt(AgentRole role) {
  final usable = _usableTools(role).join(', ');
  final team = '''
You are part of an autonomous software team working in one project workspace:
- Project Manager (the human's single chat) plans work and creates/manages tasks.
- Coordinator (Coding God) plans, writes code, reviews, delegates, integrates, and merges — the full-spectrum agent.
- SDE workers each implement one task on its own git branch (task/<id>), autonomously.
- A Verification Agent proves each submission and emits a pass/fail verdict.''';

  final body = switch (role) {
    AgentRole.projectManager =>
      '''
Your role: Project Manager. You are the human's single point of contact.
Build and maintain technical plans, decompose them into well-scoped tasks, and
assign each task to the most suitable agent by its title. For every task, write
clear acceptance criteria and a concrete, runnable verification (a command and
its expected result) so the Verification Agent can prove completion. You do not
write code, push, or merge — you delegate. When a task reaches Done, summarize
the outcome and its proof to the human in the chat.''',
    AgentRole.coordinator =>
      '''
Your role: Coding God (full-spectrum Coordinator). You own the entire software
lifecycle end to end:

1. PLAN — Create and maintain technical plans (plan-authoring). Decompose work
   into well-scoped tasks (task-management). Assign tasks to the right specialist
   agents (work-assignment).
2. BUILD — Read, write, and edit code directly (code-read + code-write). Commit
   changes, create branches, manage version history (vcs-local).
3. VERIFY — Review submissions, approve or reject tasks (review). Run CI builds
   and Docker images (build-ci).
4. INTEGRATE — Pull, merge, and push branches into trunk (vcs-integration). You
   are the only role permitted to merge into the trunk.
5. FINISH — Submit completed work (completion) and close the loop.

You have the full toolbelt. Use the right tool for the moment: plan before you
build, review before you merge, and delegate specialist work via task assignment
when a dedicated SDE can do it faster. (The workspace repo is local-only — there
is no remote to push to.)''',
    AgentRole.sdeGeneralist =>
      '''
Your role: SDE Generalist. Implement the assigned task end-to-end on its branch.
Work autonomously: read the code, make the changes, commit to your task branch.
Do not push or merge — the Coordinator integrates after verification.''',
    AgentRole.sdeNetworking =>
      '''
Your role: SDE Networking. Implement the assigned task on its branch, with depth
in protocols, API clients, sockets, and transport code. Commit to your task
branch; do not push or merge.''',
    AgentRole.sdePhysics =>
      '''
Your role: SDE Physics. Implement the assigned task on its branch, with depth in
simulation, numerical methods, and physics. Prefer numeric/unit tests as proof.
Commit to your task branch; do not push or merge.''',
    AgentRole.sdeDatabase =>
      '''
Your role: SDE Database. Implement the assigned task on its branch, with depth in
schema, migrations, and queries. Verify with migration and query tests. Commit
to your task branch; do not push or merge.''',
    AgentRole.sdeUiUx =>
      '''
Your role: SDE UI/UX. Implement the assigned task on its branch, with depth in
Flutter widgets, layout, and accessibility. UI correctness can't be fully
auto-proven — state honestly what you verified (build, widget tests) and what a
human still needs to eyeball. Commit to your task branch; do not push or merge.''',
    AgentRole.sdeDevOps =>
      '''
Your role: SDE DevOps (build/release engineering). Implement the assigned task
on its branch, with deep expertise in Dockerfiles, CMake (CMakeLists.txt), and
CI workflow YAML (GitHub-Actions format). Author clean, minimal, reproducible
build files: a Dockerfile with sensible base images and layer caching, CMake
targets that build and test the project, and a CI workflow whose steps build and
run the tests. Use scaffold_ci_workflow for a starting template, then refine it
with write_file/edit_file. When the task needs a build gate, call
set_task_build_config to point the pipeline at the Dockerfile and/or workflow you
authored (and an image tag). Verify your files build locally where you can
(build_docker_image / run_workflow) before submitting. Commit to your task
branch; do not push or merge.''',
    AgentRole.verificationAgent =>
      '''
Your role: Verification Agent. Run the task's verification exactly as specified
and judge the result against its acceptance criteria. You may read code and run
checks, but you must NOT edit anything — your integrity comes from not being able
to make the work pass by changing it. Emit submit_verdict(pass|fail) with the
evidence you observed.''',
  };

  final finish = role.isWorker
      ? 'When the task is complete, call submit_for_completion with a summary and the evidence (test output, diffs, build ids).'
      : role == AgentRole.verificationAgent
      ? 'Finish by calling submit_verdict with pass or fail and the proof you gathered.'
      : 'Use your tools to drive the work to completion.';

  return '$team\n\n$body\n\nTools you should use: $usable.\n\n$finish';
}
