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
  // Finalize an integration: approve a clean merge (Done) or reject a conflicted
  // one so the worker rebases. The orchestrator's merge stage drives the
  // Coordinator to call exactly these; without them every conflicting task loops
  // to the turn cap and gets Blocked instead of bouncing back for rework.
  // approve_task stays `ask` (matches the catalog default — the autonomous merge
  // stage auto-approves, the interactive Coordinator still confirms).
  'merge-integration': {
    'approve_task': ToolPerm.ask,
    'reject_task': ToolPerm.grant,
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
  // Build + maintain the user-story tree (the post-setup discovery interview) and
  // its notes. Required by whoever runs discovery (the Project Manager /
  // Coordinator) — without this skill the default-deny map blocks every story
  // tool, so discovery can't add or edit stories.
  'story-authoring': {
    'draft_stories_from_text': ToolPerm.grant,
    'add_user_story': ToolPerm.grant,
    'update_user_story': ToolPerm.grant,
    'move_user_story': ToolPerm.grant,
    'list_user_stories': ToolPerm.grant,
    'add_note': ToolPerm.grant,
    'update_note': ToolPerm.grant,
    'delete_note': ToolPerm.grant,
    'get_notes': ToolPerm.grant,
    'get_note': ToolPerm.grant,
  },
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
  'story-authoring': SkillMeta(
    'Build and maintain the user-story tree and its notes.',
    'planning',
    'low',
  ),
  'merge-integration': SkillMeta(
    'Finalize integrations: approve a clean merge or reject a conflict for rework.',
    'git',
    'medium',
  ),
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
    'story-authoring',
  ],
  AgentRole.coordinator: [
    'code-read',
    'vcs-local',
    'vcs-integration',
    'build-ci',
    'story-authoring',
    'merge-integration',
  ],
  // The post-completion Editor blends the Generalist's code authoring
  // (code-read/code-write + local git + build/CI) with the Coordinator's
  // integration + delegation (merge/push, task-management + work-assignment to
  // fan work out to worker agents, review to sign that work off). This is why it
  // can ACTUALLY edit — unlike the Coordinator, which lacks `code-write`.
  AgentRole.editor: [
    'code-read',
    'code-write',
    'vcs-local',
    'vcs-integration',
    'build-ci',
    'build-authoring',
    'task-management',
    'work-assignment',
    'merge-integration',
    'review',
    'completion',
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

/// The Generalist worker's authoritative tool permissions — a LEAN coder set:
/// read/search/edit/create files, local git (status/log/branches/create/checkout/
/// commit), read its own task, and submit. EVERYTHING else is denied — task/plan
/// authoring (PM), story/notes (discovery), image generation, CI/build (the coder
/// no longer runs CI — one end-of-project scan), the verifier/coordinator
/// orchestration tools, and remote git. Denying them keeps the worker's per-turn
/// tool payload small (the Generalist is the coder, so it determines most of the
/// project's speed and token cost) AND keeps it in its lane.
///
/// This is intentionally GENERALIST-ONLY: every other role keeps its own
/// distinct, skill-derived permissions — agent permissions are unique per agent.
/// [kGeneralistDeniedTools] derives the deny set from this map so existing
/// personas can be reconciled to it without a second hand-maintained list.
const Map<String, ToolPerm> kGeneralistToolPermissions = {
  'add_note': ToolPerm.deny,
  'add_user_story': ToolPerm.deny,
  'approve_task': ToolPerm.deny,
  'assign_agent_to_task': ToolPerm.deny,
  'build_docker_image': ToolPerm.deny,
  'create_directory': ToolPerm.grant,
  'create_file': ToolPerm.grant,
  'create_plan': ToolPerm.deny,
  'create_task': ToolPerm.deny,
  'delete_file': ToolPerm.ask,
  'delete_folder': ToolPerm.ask,
  'delete_note': ToolPerm.deny,
  'delete_path': ToolPerm.ask,
  'delete_plan': ToolPerm.deny,
  'delete_task': ToolPerm.deny,
  'draft_stories_from_text': ToolPerm.deny,
  'edit_file': ToolPerm.grant,
  'edit_image': ToolPerm.deny,
  'generate_diagram': ToolPerm.deny,
  'generate_image': ToolPerm.deny,
  'get_ci_run': ToolPerm.deny,
  'get_note': ToolPerm.deny,
  'get_notes': ToolPerm.deny,
  'get_task': ToolPerm.grant,
  'git_branches': ToolPerm.grant,
  'git_checkout_branch': ToolPerm.grant,
  'git_commit': ToolPerm.grant,
  'git_create_branch': ToolPerm.grant,
  'git_log': ToolPerm.grant,
  'git_merge': ToolPerm.deny,
  'git_pull': ToolPerm.deny,
  'git_push': ToolPerm.deny,
  'git_status': ToolPerm.grant,
  'link_task_to_plan': ToolPerm.deny,
  'list_agents': ToolPerm.deny,
  'list_ci_runs': ToolPerm.deny,
  'list_directory': ToolPerm.grant,
  'list_files': ToolPerm.grant,
  'list_open_tasks': ToolPerm.deny,
  'list_plans': ToolPerm.deny,
  'list_tasks': ToolPerm.deny,
  'list_user_stories': ToolPerm.deny,
  'move_path': ToolPerm.ask,
  'move_user_story': ToolPerm.deny,
  'propose_plan_adjustment': ToolPerm.deny,
  'read_file': ToolPerm.grant,
  'read_file_chunk': ToolPerm.grant,
  'read_plan': ToolPerm.deny,
  'reject_task': ToolPerm.deny,
  'rename_plan': ToolPerm.deny,
  'review_submission': ToolPerm.deny,
  'run_verification': ToolPerm.deny,
  'run_workflow': ToolPerm.deny,
  'scaffold_ci_workflow': ToolPerm.deny,
  'search_directory': ToolPerm.grant,
  'search_file_content': ToolPerm.grant,
  'set_task_build_config': ToolPerm.deny,
  'set_task_dates': ToolPerm.deny,
  'submit_for_completion': ToolPerm.grant,
  'submit_verdict': ToolPerm.deny,
  'sync_plans_to_tasks': ToolPerm.deny,
  'update_note': ToolPerm.deny,
  'update_plan': ToolPerm.deny,
  'update_task': ToolPerm.deny,
  'update_task_status': ToolPerm.deny,
  'update_user_story': ToolPerm.deny,
  'view_current_plan': ToolPerm.deny,
  'view_plan': ToolPerm.deny,
  'write_file': ToolPerm.grant,
  'write_plan': ToolPerm.deny,
};

/// Tools the Generalist is denied — derived from [kGeneralistToolPermissions] so
/// there is ONE source of truth. Used by the seeder to lean down existing
/// Generalist personas (seeded before the trim) to the same coder-only set.
Set<String> get kGeneralistDeniedTools => {
  for (final e in kGeneralistToolPermissions.entries)
    if (e.value == ToolPerm.deny) e.key,
};

/// Builds the full default tool-permission map for [role]. Tools outside the
/// role's skills are denied. The Generalist is the one exception: it ships with
/// the owner's hand-tuned [kGeneralistToolPermissions] verbatim (still unique to
/// the Generalist — no other role is affected).
Map<String, ToolPerm> defaultToolPermissions(AgentRole role) =>
    role == AgentRole.sdeGeneralist
    ? Map<String, ToolPerm>.from(kGeneralistToolPermissions)
    : toolPermissionsForSkills(defaultSkillNames(role));

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
- Coordinator integrates approved work: it is the only role that merges branches into the trunk.
- SDE workers each implement one task on its own git branch (task/<id>), autonomously.
- A Verification Agent proves each submission and emits a pass/fail verdict.''';

  final body = switch (role) {
    AgentRole.projectManager =>
      '''
Your role: Project Manager. You are the human's single point of contact.
Build and maintain technical plans, decompose them into well-scoped tasks, and
assign each task to the most suitable agent by its title. Write each task as a
concrete, stack-specific instruction (using the PROJECT BASELINE) with clear
acceptance criteria and a runnable verification (a command and its expected
result) so the Verification Agent can prove completion. You plan and delegate —
the SDE workers write the code and the Coordinator merges. When a task reaches
Done, summarize the outcome and its proof to the human in the chat.''',
    AgentRole.coordinator =>
      '''
Your role: Coordinator (integration). When a task passes verification, merge its
branch into main, then run the build/CI. Resolve trivial merge conflicts; when a
conflict needs real source changes, send the task back so a worker resolves it.
You are the only role that merges into the trunk. (The workspace repo is
local-only, so there is no remote to push to.)''',
    AgentRole.editor =>
      '''
Your role: Editor. The project is already built and passing. You maintain and
evolve it for the user: edit the code directly, run build/CI, and commit. For a
change big enough to parallelize, delegate: create tasks, assign them to worker
agents, and integrate their branches. Work on the project's existing stack from
the PROJECT BASELINE; make targeted changes, keep the app compiling, and commit
each coherent change.''',
    AgentRole.sdeGeneralist =>
      '''
Your role: SDE Generalist. Implement the assigned task end-to-end on its branch,
building with the project's stack from the PROJECT BASELINE (its languages and
frameworks). Work autonomously: read the code, make the changes, and commit to
your task branch. The Coordinator integrates after verification.''',
    AgentRole.sdeNetworking =>
      '''
Your role: SDE Networking. Implement the assigned task on its branch with depth
in protocols, API clients, sockets, and transport code, using the project's
languages and frameworks from the PROJECT BASELINE. Commit to your task branch;
the Coordinator integrates after verification.''',
    AgentRole.sdePhysics =>
      '''
Your role: SDE Physics. Implement the assigned task on its branch with depth in
simulation, numerical methods, and physics, using the project's stack from the
PROJECT BASELINE. Prefer numeric/unit tests as proof. Commit to your task branch;
the Coordinator integrates after verification.''',
    AgentRole.sdeDatabase =>
      '''
Your role: SDE Database. Implement the assigned task on its branch with depth in
schema, migrations, and queries — use the Databases and languages named in the
PROJECT BASELINE. Verify with migration and query tests. Commit to your task
branch; the Coordinator integrates after verification.''',
    AgentRole.sdeUiUx =>
      '''
Your role: SDE UI/UX. Implement the assigned task on its branch with depth in the
project's UI framework from the PROJECT BASELINE (e.g. Flutter widgets, layout,
accessibility). UI correctness is hard to fully auto-prove, so state honestly
what you verified (build, widget tests) and what a human still needs to eyeball.
Commit to your task branch; the Coordinator integrates after verification.''',
    AgentRole.sdeDevOps =>
      '''
Your role: SDE DevOps (build/release engineering). Implement the assigned task on
its branch, with deep expertise in Dockerfiles, CMake (CMakeLists.txt), and CI
workflow YAML (GitHub-Actions format), targeting the project's stack from the
PROJECT BASELINE. Author clean, minimal, reproducible build files: a Dockerfile
with sensible base images and layer caching, CMake targets that build and test
the project, and a CI workflow whose steps build and run the tests. Use
scaffold_ci_workflow for a starting template, then refine it with
write_file/edit_file. When the task needs a build gate, call set_task_build_config
to point the pipeline at the Dockerfile and/or workflow you authored (and an image
tag). Verify your files build locally where you can (build_docker_image /
run_workflow) before submitting. Commit to your task branch; the Coordinator
integrates after verification.''',
    AgentRole.verificationAgent =>
      '''
Your role: Verification Agent. Run the task's verification exactly as specified
and judge the result against its acceptance criteria. Your tools are read-and-run
only by design, so you judge the work exactly as submitted — that read-only stance
is what makes your verdict trustworthy. Emit submit_verdict(pass|fail) with the
evidence you observed.''',
  };

  final finish = role.isWorker
      ? 'When the task is complete, call submit_for_completion with a summary and the evidence (test output, diffs, build ids).'
      : role == AgentRole.verificationAgent
      ? 'Finish by calling submit_verdict with pass or fail and the proof you gathered.'
      : 'Use your tools to drive the work to completion.';

  return '$team\n\n$body\n\nTools you should use: $usable.\n\n$finish';
}
