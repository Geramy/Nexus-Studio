// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

// End-to-end proof of the orchestrated task pipeline with a SCRIPTED (fake) LLM:
// a real worker session drives the real coordinator tools against the real DB +
// git engine on an isolated task tree — it writes a file, calls git_commit
// (which snapshots the isolated tree onto the task branch), and submits. We then
// run the deterministic merge to main and confirm the produced code is on main
// and the task reached Done. Proves "task → agent writes code → commit →
// submit → merge → Done" without burning real inference.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/agent_assignment.dart';
import 'package:nexus_projects_client/features/projects/coordinator_session.dart';
import 'package:nexus_projects_client/features/projects/orchestration/project_orchestrator.dart';
import 'package:nexus_projects_client/features/projects/task_workflow.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart';
import 'package:nexus_projects_client/infrastructure/inference/inference_backend.dart';
import 'package:nexus_projects_client/infrastructure/workspace/async_lock.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';
import 'package:nexus_projects_client/infrastructure/workspace/vhd_workspace.dart';

/// A fake backend that replays a fixed script of tool-call rounds — one per
/// `streamChatCompletion` call — then finishes with plain content.
class ScriptedBackend extends InferenceBackend {
  ScriptedBackend(this._rounds);
  final List<List<ToolCall>> _rounds;
  final List<Map<String, dynamic>?> seenExtras = [];
  final List<List<Map<String, dynamic>>?> seenTools = [];
  int _i = 0;

  @override
  String get serverId => 'fake';
  @override
  String get name => 'Fake';
  @override
  String get implementationType => 'fake';

  @override
  Stream<ChatStreamEvent> streamChatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? maxCompletionTokens,
    bool? enableThinking,
    Map<String, dynamic>? extra,
  }) async* {
    seenExtras.add(extra);
    seenTools.add(tools);
    final calls = _i < _rounds.length ? _rounds[_i] : const <ToolCall>[];
    _i++;
    yield ChatStreamFinish(
      finishReason: calls.isEmpty ? 'stop' : 'tool_calls',
      toolCalls: calls,
      contentSoFar: calls.isEmpty ? 'Done.' : '',
    );
  }

  @override
  Future<ChatCompletionResponse> createChatCompletion({
    required String model,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    double temperature = 0.7,
    double? topP,
    int? topK,
    double? repeatPenalty,
    int? maxTokens,
    int? maxCompletionTokens,
    bool? enableThinking,
    Map<String, dynamic>? extra,
  }) async {
    seenExtras.add(extra);
    seenTools.add(tools);
    final calls = _i < _rounds.length ? _rounds[_i] : const <ToolCall>[];
    _i++;
    return ChatCompletionResponse(
      id: 'x',
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: '', toolCalls: calls),
          finishReason: calls.isEmpty ? 'stop' : 'tool_calls',
        ),
      ],
    );
  }

  @override
  Future<List<ModelInfo>> listModels({bool showAll = false}) async => const [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

ToolCall _tc(String id, String name, Map<String, dynamic> args) => ToolCall(
  id: id,
  type: 'function',
  function: FunctionCall(name: name, arguments: jsonEncode(args)),
);

void main() {
  test('autonomous worker metadata is pinned to its real assignment', () {
    expect(
      normalizeAutonomousWorkerToolArguments(
        toolName: 'write_file',
        arguments: const {
          'path': '/workspace/from-an-unrelated-response.dart',
          'content': 'real implementation',
        },
        workTaskId: 769,
        workerRequiredFiles: const {'/lib/task_769/core.dart'},
      ),
      {'path': '/lib/task_769/core.dart', 'content': 'real implementation'},
    );
    expect(
      normalizeAutonomousWorkerToolArguments(
        toolName: 'git_commit',
        arguments: const {},
        workTaskId: 769,
        workerRequiredFiles: const {'/lib/task_769/core.dart'},
      )['message'],
      'Implement task #769',
    );
    expect(
      normalizeAutonomousWorkerToolArguments(
        toolName: 'submit_for_completion',
        arguments: const {'task_id': 7},
        workTaskId: 769,
        workerRequiredFiles: const {'/lib/task_769/core.dart'},
      ),
      {
        'task_id': 769,
        'summary': 'Implemented and committed changes for assigned task #769.',
      },
    );
  });

  test('Flutter task batches retain dependencies and parallel siblings', () {
    expect(flutterTaskDependencyRankForTitle('Bird Physics & Controls'), 0);
    expect(flutterTaskDependencyRankForTitle('Pipe Generation & Scrolling'), 0);
    expect(flutterTaskDependencyRankForTitle('Core Game Loop'), 1);
    expect(flutterTaskDependencyRankForTitle('Classic Mode & Tiers'), 0);
    expect(flutterTaskDependencyRankForTitle('Select Level Pack'), 0);
    expect(flutterTaskDependencyRankForTitle('Main Menu & Flow Control'), 3);
  });

  test('Done and Blocked both release a milestone barrier', () {
    expect(taskStatusSettlesMilestone(TaskStatus.done), isTrue);
    expect(taskStatusSettlesMilestone(TaskStatus.blocked), isTrue);
    expect(taskStatusSettlesMilestone(TaskStatus.todo), isFalse);
    expect(taskStatusSettlesMilestone(TaskStatus.inProgress), isFalse);
    expect(taskStatusSettlesMilestone(TaskStatus.review), isFalse);
  });

  test('failed review work cannot be resubmitted as recovered work', () {
    expect(
      taskCanRecoverCommittedSubmission(
        executionStatus: TaskExecStatus.queued,
        description: 'Implement bird physics.',
        branchAheadOfBase: true,
      ),
      isTrue,
      reason: 'a first-run checkpoint should continue through review',
    );
    expect(
      taskCanRecoverCommittedSubmission(
        executionStatus: TaskExecStatus.queued,
        description:
            'Implement bird physics.\n\n[Verification FAILED now]: ticker missing',
        branchAheadOfBase: true,
      ),
      isFalse,
      reason: 'the failed commit must return to its worker for repair',
    );
    expect(
      taskCanRecoverCommittedSubmission(
        executionStatus: TaskExecStatus.queued,
        description:
            'Implement bird physics.\n\n${NexusDatabase.buildFailureMarker}: compile error',
        branchAheadOfBase: true,
      ),
      isFalse,
      reason: 'build-failed work also requires repair before resubmission',
    );
  });

  test('task review rejects erased and collapsed source files', () {
    expect(
      taskReviewStructuralProblem(
        path: '/lib/core.dart',
        baseContent: 'class Core {\n  void run() {}\n}\n',
        taskContent: '',
      ),
      contains('file was emptied'),
    );
    expect(
      taskReviewStructuralProblem(
        path: '/lib/feature.dart',
        baseContent:
            'class Feature {\n${List.filled(20, '  void behavior() {}\n').join()}}\n',
        taskContent: 'class Feature {}',
      ),
      contains('implementation collapsed'),
    );
    expect(
      taskReviewStructuralProblem(
        path: '/lib/feature.dart',
        baseContent: 'class Feature {}',
        taskContent: 'class Feature { void run() {} }',
      ),
      isNull,
    );
  });

  test(
    'scaffold mode requires a tool call while scaffold tools are offered',
    () async {
      final backend = ScriptedBackend([const <ToolCall>[]]);
      final session = ProjectCoordinatorSession(
        client: backend,
        projectId: 1,
        projectName: 'Templater',
        scaffoldMode: true,
        leanTools: false,
        systemPromptOverride: 'Create and commit the project scaffold.',
      );

      await for (final _ in session.runTurn('Begin scaffolding.')) {}

      expect(backend.seenExtras, isNotEmpty);
      expect(backend.seenExtras.first?['tool_choice'], 'required');
      final schemas = backend.seenTools.first!;
      expect(schemas, hasLength(1));
      expect((schemas.single['function'] as Map)['name'], 'write_file');
    },
  );

  test(
    'scripted worker writes code, commits to its branch, submits; merge lands it on main and the task is Done',
    () async {
      final db = NexusDatabase.forTesting(NativeDatabase.memory());
      final dir = await Directory.systemTemp.createTemp('nx-pipeline');
      final ws = await VhdWorkspace.open('${dir.path}/project.nxtprj');
      final git = await NxtprjGitEngine.open(ws);
      final lane = AsyncLock();
      addTearDown(() async {
        git.dispose();
        ws.dispose();
        await db.close();
        await dir.delete(recursive: true);
      });

      // ── Seed: client (+ default agents), project, a worker-assigned task. ──
      final clientId = await db.createClientWithDefaults(
        name: 'Test',
        isDefault: true,
      );
      final projectId = await db.createProject(
        ProjectsCompanion.insert(
          client_fk: clientId,
          name: 'Demo',
          projectType: const Value('application-development'),
        ),
      );
      final workerPk = await resolveDefaultWorkerPersonaId(db, projectId);
      expect(workerPk, isNotNull, reason: 'default worker persona must seed');
      final taskId = await db.createTaskInProject(
        projectPk: projectId,
        title: 'Add a greeting function',
        description: 'Create lib/greeting.dart with a hello() function.',
        agentPk: workerPk,
      );

      // ── Git: scaffold main, branch the task off it, hydrate an isolated tree. ──
      await ws.writeString('/README.md', '# Demo');
      await ws.writeString('/WORK_TEMPLATE.md', '#1 owns /lib/greeting.dart');
      await ws.writeString('/lib/starter.dart', '// starter');
      await git.commitAll(message: 'chore: scaffold');
      final branch = 'task/$taskId';
      final tree = await VhdWorkspace.open('${dir.path}/task.nxtprj');
      addTearDown(() => tree.dispose());
      await git.createBranchAt(branch, base: 'main');
      await git.materializeInto(branch, tree);

      // ── The scripted "worker": write a file, commit it, then submit. ──
      final backend = ScriptedBackend([
        [
          _tc('1', 'read_file', {'path': '/WORK_TEMPLATE.md'}),
          _tc('2', 'read_file', {'path': '/lib/starter.dart'}),
          _tc('3', 'read_file', {'path': '/README.md'}),
        ],
        [
          _tc('4', 'write_file', {
            'path': '/workspace/repo/notes.txt',
            'content': 'Unrelated planning notes.\n',
          }),
        ],
        [
          _tc('5', 'write_file', {
            'path': '/lib/greeting.dart',
            'content': 'String hello() => "hi";\n',
          }),
        ],
        [_tc('6', 'git_commit', {})],
        [
          _tc('7', 'submit_for_completion', {
            'task_id': 999999,
            'evidence': 'committed to $branch',
          }),
        ],
      ]);

      final session = ProjectCoordinatorSession(
        client: backend,
        projectId: projectId,
        projectName: 'Worker',
        db: db,
        workspace: tree,
        git: git,
        workBranch: branch,
        gitLane: lane,
        workTaskId: taskId,
        workerWriteRoots: const {'/lib'},
        workerRequiredFiles: const {'/lib/greeting.dart'},
        leanTools: false,
        confirmAsk: (_, _) async => true,
        agentName: 'Worker',
      );
      var activityEvents = 0;
      final activitySub = session.turnActivity.listen((_) => activityEvents++);
      addTearDown(activitySub.cancel);

      await db.markTaskRunning(taskId, workerSessionPk: 0, workBranch: branch);
      // One turn is enough: the session loops its internal tool rounds.
      await for (final _ in session.runTurn(
        'Implement the task.',
        maxToolRounds: 8,
      )) {}

      expect(
        backend.seenExtras,
        hasLength(5),
        reason: 'the successful submit ends the worker tool loop',
      );
      expect(
        activityEvents,
        greaterThanOrEqualTo(4),
        reason: 'intermediate tool-only rounds must keep the watchdog alive',
      );
      expect(
        backend.seenExtras.every(
          (extra) => extra?['tool_choice'] == 'required',
        ),
        isTrue,
        reason:
            'every autonomous worker round must perform an action: ${backend.seenExtras}',
      );
      expect(
        backend.seenExtras.every((extra) => extra?['cache_prompt'] == false),
        isTrue,
        reason:
            'untrusted/shared backends must explicitly disable unkeyed KV caching',
      );
      final workerTools = backend.seenTools
          .expand((tools) => tools!)
          .map((tool) => (tool['function'] as Map)['name'])
          .toSet();
      expect(
        workerTools,
        containsAll(['read_file', 'write_file', 'edit_file']),
      );
      expect(workerTools, containsAll(['git_commit', 'submit_for_completion']));
      expect(workerTools, isNot(contains('git_checkout_branch')));
      expect(workerTools, isNot(contains('create_task')));
      final toolNamesByRound = backend.seenTools
          .map(
            (tools) => tools!
                .map((tool) => (tool['function'] as Map)['name'])
                .cast<String>()
                .toSet(),
          )
          .toList();
      expect(toolNamesByRound[0], contains('read_file'));
      expect(toolNamesByRound[0], isNot(contains('write_file')));
      expect(toolNamesByRound[1], containsAll(['write_file', 'edit_file']));
      expect(toolNamesByRound[1], isNot(contains('read_file')));
      expect(toolNamesByRound[2], containsAll(['write_file', 'edit_file']));
      expect(toolNamesByRound[3], contains('git_commit'));
      expect(toolNamesByRound[4], {'submit_for_completion'});
      final writeTool = backend.seenTools[1]!.firstWhere(
        (tool) => (tool['function'] as Map)['name'] == 'write_file',
      );
      final writePathSchema =
          ((((writeTool['function'] as Map)['parameters'] as Map)['properties']
                  as Map)['path']
              as Map);
      expect(
        writePathSchema['enum'],
        ['/lib/greeting.dart'],
        reason: 'the Router must receive the exact Templater-owned write path',
      );

      // ── The agent produced code on its ISOLATED tree and committed it. ──
      expect(await tree.exists('/lib/greeting.dart'), isTrue);
      expect(
        await tree.exists('/workspace/repo/notes.txt'),
        isFalse,
        reason: 'the worker cannot write outside its task-owned scope',
      );
      final fresh = await db.getTaskById(taskId);
      expect(
        fresh!.executionStatus,
        TaskExecStatus.submitted,
        reason: 'worker submitted for review',
      );

      // The verifier gets a three-stage tool funnel. Hallucinated task ids and
      // paths are pinned to this review's real task and implementation file.
      final verifierBackend = ScriptedBackend([
        [
          _tc('v1', 'run_verification', {'task_id': '999999'}),
        ],
        [
          _tc('v2', 'read_file', {'path': '/unrelated/answer.txt'}),
        ],
        [
          _tc('v3', 'submit_verdict', {
            'task_id': '999999',
            'verdict': 'pass',
            'evidence': 'The task-owned implementation defines hello().',
          }),
        ],
      ]);
      final verifier = ProjectCoordinatorSession(
        client: verifierBackend,
        projectId: projectId,
        projectName: 'Verifier',
        db: db,
        workspace: tree,
        verificationTaskId: taskId,
        verificationReadFiles: const {'/lib/greeting.dart'},
        leanTools: false,
        confirmAsk: (_, _) async => true,
        agentName: 'Verifier',
      );
      await for (final _ in verifier.runTurn(
        'Verify the submitted task.',
        maxToolRounds: 6,
      )) {}

      expect(verifierBackend.seenExtras, hasLength(3));
      expect(
        verifierBackend.seenExtras.every(
          (extra) => extra?['tool_choice'] == 'required',
        ),
        isTrue,
      );
      expect(
        verifierBackend.seenTools
            .map(
              (tools) => (tools!.single['function'] as Map)['name'] as String,
            )
            .toList(),
        ['run_verification', 'read_file', 'submit_verdict'],
      );
      expect(
        (await db.getTaskById(taskId))!.executionStatus,
        TaskExecStatus.verified,
        reason: 'the bounded verifier must finish by recording its verdict',
      );

      // The commit really landed on the task branch (and NOT yet on main).
      final onBranch = await VhdWorkspace.open('${dir.path}/check.nxtprj');
      addTearDown(() => onBranch.dispose());
      await git.materializeInto(branch, onBranch);
      expect(await onBranch.exists('/lib/greeting.dart'), isTrue);

      final mainBefore = await VhdWorkspace.open('${dir.path}/main0.nxtprj');
      addTearDown(() => mainBefore.dispose());
      await git.materializeInto('main', mainBefore);
      expect(
        await mainBefore.exists('/lib/greeting.dart'),
        isFalse,
        reason: 'work is on the task branch, not main, until merge',
      );

      // ── Merge stage (deterministic): branch → main, approve the task. ──
      await git.checkoutBranch('main');
      final merge = await git.merge(branch);
      expect(merge.outcome, isNot(MergeOutcome.conflicts));
      await db.approveTask(taskId);

      // ── The produced code is now on main and the task is Done. ──
      final mainAfter = await VhdWorkspace.open('${dir.path}/main1.nxtprj');
      addTearDown(() => mainAfter.dispose());
      await git.materializeInto('main', mainAfter);
      expect(
        await mainAfter.readString('/lib/greeting.dart'),
        'String hello() => "hi";\n',
      );
      final done = await db.getTaskById(taskId);
      expect(done!.status, TaskStatus.done);
      expect(done.executionStatus, TaskExecStatus.done);
    },
  );
}
