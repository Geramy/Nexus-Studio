// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:drift/drift.dart';

import 'client.dart';
import 'project.dart';
import 'chat_session.dart';
import 'agent_persona.dart';
import 'user_story.dart';

/// Tasks table — supports a subtask tree and full provenance: every task links
/// back to its client, project, originating plan, and the chat session that
/// produced it, so you can backtrack "why/what happened".
class Tasks extends Table {
  IntColumn get task_pk => integer().autoIncrement()();

  IntColumn get task_client_fk => integer().references(Clients, #client_pk)();
  IntColumn get task_project_fk =>
      integer().references(Projects, #project_pk)();

  /// Subtask tree (points at the parent task).
  IntColumn get task_parent_fk =>
      integer().nullable().references(Tasks, #task_pk)();

  /// Provenance: the workspace path of the plan this task was generated from
  /// (e.g. `/PLANS/Roadmap.md`). Plans are files, not DB rows.
  TextColumn get task_plan_path => text().nullable()();

  /// Provenance: the coordinator chat session that created this task.
  @ReferenceName('creatorTasks')
  IntColumn get task_chat_session_fk =>
      integer().nullable().references(ChatSessions, #session_pk)();

  /// The agent persona responsible for this task.
  IntColumn get task_agent_fk =>
      integer().nullable().references(AgentPersonas, #agent_pk)();

  /// Provenance: the user-story item this task implements (set when tasks are
  /// generated from the exploration story tree). Lets the system trace any task
  /// back to its story, and a story to its task(s). Null for ad-hoc tasks.
  IntColumn get task_story_fk =>
      integer().nullable().references(UserStories, #story_pk)();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Todo'))();
  TextColumn get priority => text().withDefault(const Constant('MED'))();

  /// Per-task model thinking mode: 'on' | 'off' | null (inherit). Set by the
  /// Coordinator via the create_task/update_task `thinking_enabled` param.
  TextColumn get thinkingMode => text().nullable()();
  IntColumn get tokenCost => integer().withDefault(const Constant(0))();
  RealColumn get usdCost => real().withDefault(const Constant(0.0))();

  // ==================== Orchestration / verification ====================
  /// Plain-language definition of done, authored by the Project Manager.
  TextColumn get acceptanceCriteria => text().nullable()();

  /// The runnable proof: a command and its expected result (e.g.
  /// "flutter analyze -> no issues"). The Verification Agent runs this.
  TextColumn get verification => text().nullable()();

  /// Execution phase distinct from the kanban [status]:
  /// idle | queued | running | submitted | verifying | passed | failed.
  TextColumn get executionStatus =>
      text().withDefault(const Constant('idle'))();

  /// The worker's submission for review (JSON: summary, evidence, branch, etc.).
  TextColumn get submissionJson => text().nullable()();

  /// The chat session of the worker currently assigned to execute this task.
  @ReferenceName('workerTasks')
  IntColumn get worker_session_fk =>
      integer().nullable().references(ChatSessions, #session_pk)();

  /// The git branch this task is being worked on (e.g. `task/42`).
  TextColumn get workBranch => text().nullable()();

  /// Which milestone batch this task belongs to (0-based), assigned by the
  /// Templater stage when it splits the backlog into sequential, topic-grouped
  /// milestones. Workers only pick up tasks whose milestone is the project's
  /// current one. Null = unassigned (short projects / legacy tasks → batch 0).
  IntColumn get milestoneOrder => integer().nullable()();

  /// True for tasks created by the EDITOR (the post-build fast lane) rather than
  /// the original autonomous build. Purely a provenance/UI flag: edit tasks are
  /// filed under the workspace's "Edits" tab instead of bloating the main build
  /// task board. Does not affect scheduling.
  BoolColumn get isEdit => boolean().withDefault(const Constant(false))();

  // ==================== Build pipeline config ====================
  /// When true, the orchestration pipeline runs a Docker build / CI gate on this
  /// task after verification passes and before it is handed off for merge.
  BoolColumn get requiresBuild =>
      boolean().withDefault(const Constant(false))();

  /// Workspace path of the Dockerfile to build for the build gate (e.g.
  /// `/Dockerfile`). Used when [workflowPath] is null.
  TextColumn get dockerfilePath => text().nullable()();

  /// Workspace path of a GitHub-Actions workflow to run for the build gate
  /// (e.g. `/.github/workflows/ci.yml`). Takes precedence over [dockerfilePath].
  TextColumn get workflowPath => text().nullable()();

  /// Image tag to produce when building from [dockerfilePath] (e.g.
  /// `myapp:task-42`). Defaults to a task-derived tag when null.
  TextColumn get imageTag => text().nullable()();

  /// Optional scheduling (owner- or AI-set).
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
