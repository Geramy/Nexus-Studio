// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart';
// Backward-compat types (InferenceClient = InferenceBackend).
import 'package:nexus_projects_client/infrastructure/inference/inference_backend.dart';
import 'package:nexus_projects_client/infrastructure/inference/scoped_completion.dart';
import 'package:nexus_projects_client/features/agents/agent_tool_permissions.dart';
import 'package:nexus_projects_client/features/projects/agent_assignment.dart';
import 'package:nexus_projects_client/features/project_plans/plan_store.dart';
import 'package:nexus_projects_client/features/project_setup/plan_task_sync.dart';
import 'package:nexus_projects_client/infrastructure/workspace/async_lock.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';
import 'package:nexus_projects_client/infrastructure/workspace/git/nxtprj_git_engine.dart';
import 'package:nexus_projects_client/infrastructure/build/build_service.dart';
import 'package:nexus_projects_client/infrastructure/build/build_models.dart';

/// Tool schemas and executor for the Project Coordinator "main brain".
///
/// The Coordinator can call these during a conversation (text or voice) to
/// directly mutate the live project state. Tasks live in the DB; plans are
/// real files under `/PLANS` in the project workspace, addressed by their
/// workspace path. Results are fed back to the LLM so it can confirm actions
/// to the user in natural language.
///
/// One file for the tool contract + execution logic (keeps session clean).
class CoordinatorTools {
  /// Returns the OpenAI-compatible tools array the LLM should see.
  /// Pass [includePlanTools] when the conversation is focused on a plan document.
  /// [includePlannerComplete]/[includePlannerReview] add the two signal-only
  /// tools used by the deep planning run (planner says it's done; an engineer
  /// reviewer votes on the plan) — off for the normal coordinator chat.
  static List<Map<String, dynamic>> buildToolSchemas({
    bool includePlanTools = false,
    bool includePlannerComplete = false,
    bool includePlannerReview = false,
    bool includeStoryTools = false,
    bool discoveryOnly = false,
  }) {
    // The post-setup Exploration (discovery) session gets ONLY the user-story
    // tools — deliberately NO task/plan-write tools, so it can't be "eager" and
    // create work before the user presses "Generate tasks".
    if (discoveryOnly) return [..._storyToolSchemas];
    return [
      if (includePlannerComplete)
        {
          'type': 'function',
          'function': {
            'name': 'mark_planning_complete',
            'description':
                'Call this ONLY when the plans are fully fleshed out: every '
                'layer has a complete `## Outline`, every idea from the brief '
                'is covered, and each `- [ ]` item is a small, single-session '
                'job. Signals the planning loop to stop.',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
      if (includePlannerReview)
        {
          'type': 'function',
          'function': {
            'name': 'submit_plan_review',
            'description':
                'Submit your verdict on the plan from your engineering domain. '
                'Set approved=true if it is complete, coherent, and the tasks '
                'are appropriately small; otherwise approved=false and list the '
                'specific gaps to fix.',
            'parameters': {
              'type': 'object',
              'properties': {
                'approved': {
                  'type': 'boolean',
                  'description':
                      'Whether the plan is good enough to build tasks from.',
                },
                'gaps': {
                  'type': 'string',
                  'description':
                      'If not approved, the specific missing/oversized items to '
                      'address (empty when approved).',
                },
              },
              'required': ['approved'],
            },
          },
        },
      if (includePlanTools) ...[
        {
          'type': 'function',
          'function': {
            'name': 'view_plan',
            'description':
                'Read the full current contents of the plan document being edited.',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'update_plan',
            'description':
                'Replace the plan document with new contents (markdown). Provide the COMPLETE new document, not a diff.',
            'parameters': {
              'type': 'object',
              'properties': {
                'content': {
                  'type': 'string',
                  'description': 'The full new plan document (markdown)',
                },
              },
              'required': ['content'],
            },
          },
        },
      ],
      {
        'type': 'function',
        'function': {
          'name': 'create_task',
          'description':
              'Create a new task (or subtask) in the current project. Use when the user asks to add work, break down a plan, or capture an action item. Every task MUST end up assigned to a worker agent: pass agent_persona_id with the best-fit specialist (call list_agents first to get real ids). If you omit it, a default worker is auto-assigned so the task is never left unassigned.',
          'parameters': {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'Short, clear title for the task',
              },
              'description': {
                'type': 'string',
                'description': 'Optional details or acceptance criteria',
              },
              'parent_task_id': {
                'type': 'string',
                'description':
                    'Optional parent task id to create this as a subtask',
              },
              'priority': {
                'type': 'string',
                'enum': ['HIGH', 'MED', 'LOW'],
                'description': 'Priority level',
              },
              'agent_persona_id': {
                'type': 'string',
                'description':
                    'Worker persona id to assign. Strongly preferred — call list_agents first. If omitted, a default worker is auto-assigned.',
              },
              'thinking_enabled': {
                'type': 'boolean',
                'description':
                    'Optional. Enable the model\'s thinking/reasoning mode for THIS task. Only set true for small, very specific, cut-and-dry jobs. Leave unset/false for long or open-ended tasks (thinking degrades those ~15%).',
              },
            },
            'required': ['title'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'update_task_status',
          'description':
              'Change the status of an existing task. Common values: "Todo", "In Progress", "Agent Active", "Done", "Blocked".',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {
                'type': 'string',
                'description': 'The id of the task to update',
              },
              'status': {'type': 'string', 'description': 'New status string'},
              'note': {
                'type': 'string',
                'description': 'Optional short note explaining the change',
              },
            },
            'required': ['task_id', 'status'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'update_task',
          'description': 'Update title, description or priority of a task.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'title': {'type': 'string'},
              'description': {'type': 'string'},
              'priority': {
                'type': 'string',
                'enum': ['HIGH', 'MED', 'LOW'],
              },
              'thinking_enabled': {
                'type': 'boolean',
                'description':
                    'Optional. Enable the model\'s thinking/reasoning mode for THIS task. Only set true for small, very specific, cut-and-dry jobs. Leave unset/false for long or open-ended tasks (thinking degrades those ~15%).',
              },
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'generate_diagram',
          'description':
              'Generate a visual diagram or infographic for the current plan or a specific task using the server image model. Returns a URL or data reference the user can see.',
          'parameters': {
            'type': 'object',
            'properties': {
              'prompt': {
                'type': 'string',
                'description':
                    'Detailed prompt describing the diagram content and style',
              },
              'size': {
                'type': 'string',
                'description': 'e.g. 1024x1024 or 1792x1024',
              },
            },
            'required': ['prompt'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'propose_plan_adjustment',
          'description':
              'Record a high-level adjustment or addition to the overall project plan. Use when the user wants to evolve the plan itself rather than a single task. The proposal is surfaced in the chat for human review.',
          'parameters': {
            'type': 'object',
            'properties': {
              'summary': {
                'type': 'string',
                'description': 'One-sentence summary of the plan change',
              },
              'details': {
                'type': 'string',
                'description': 'Longer explanation of the proposed adjustment',
              },
            },
            'required': ['summary'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_open_tasks',
          'description':
              'List current open/in-progress tasks in the project so the coordinator can report status or suggest next actions.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'assign_agent_to_task',
          'description': 'Assign a specific agent persona to work on a task.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'agent_persona_id': {
                'type': 'string',
                'description': 'The persona id to assign',
              },
            },
            'required': ['task_id', 'agent_persona_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'view_current_plan',
          'description':
              'Retrieve the current high-level plan context for the project.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'sync_plans_to_tasks',
          'description':
              'Scan every plan document under /PLANS and create a task for each unchecked outline item ("- [ ] …") that does not already have one. Each plan item is annotated with its task id so re-running never creates duplicates. New tasks are auto-assigned to a worker. Call this to turn the plans into the task board (it runs automatically when setup completes, but you can re-run it after editing plans).',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'set_task_dates',
          'description':
              'Set or clear a task\'s start and/or due date. Dates are ISO format YYYY-MM-DD. Send an empty string to clear a date.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'start_date': {
                'type': 'string',
                'description': 'YYYY-MM-DD (empty string clears it)',
              },
              'due_date': {
                'type': 'string',
                'description': 'YYYY-MM-DD (empty string clears it)',
              },
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'set_task_build_config',
          'description':
              'Configure a task\'s build gate. When requires_build is true, the orchestrator runs a Docker/CI build after verification and before merge. Provide either a workflow_path (GitHub-Actions YAML) or a dockerfile_path. Send an empty string to clear a path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'requires_build': {
                'type': 'boolean',
                'description':
                    'Whether this task must pass a build before merge.',
              },
              'dockerfile_path': {
                'type': 'string',
                'description':
                    'Workspace-relative Dockerfile path (empty string clears it).',
              },
              'workflow_path': {
                'type': 'string',
                'description':
                    'Workspace-relative CI workflow YAML path (empty string clears it).',
              },
              'image_tag': {
                'type': 'string',
                'description':
                    'Optional image tag for the Docker build (empty string clears it).',
              },
            },
            'required': ['task_id'],
          },
        },
      },
      // ── Full SCRUD: read/search, delete, agent discovery, plan↔task links ──
      {
        'type': 'function',
        'function': {
          'name': 'list_tasks',
          'description':
              'List ALL tasks in the project (not just open ones), including subtasks, status, priority, assigned agent, and source plan path. Use this to search/review before acting.',
          'parameters': {
            'type': 'object',
            'properties': {
              'status': {
                'type': 'string',
                'description':
                    'Optional filter by exact status (e.g. "Done", "In Progress").',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_task',
          'description':
              'Read the full details of a single task by id (title, description, status, priority, dates, parent, plan, assigned agent).',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_task',
          'description':
              'Delete a task by id. Its subtasks are deleted too. This is permanent — only do it when the user clearly asks to remove the task.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'link_task_to_plan',
          'description':
              'Link an existing task to a plan (sets which plan the task came from), or pass an empty plan_path to unlink it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'plan_path': {
                'type': 'string',
                'description':
                    'The plan workspace path to link to, e.g. "/PLANS/Roadmap.md" (empty string to unlink).',
              },
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_agents',
          'description':
              'List the agent personas available to assign to tasks (their ids and names). Call this BEFORE assign_agent_to_task so you use a real agent id.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_plans',
          'description':
              'List all plan documents and folders in the project (workspace path, name, whether it is a folder, parent folder path).',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_plan',
          'description':
              'Create a new plan document (or folder) under /PLANS in the project workspace. Returns the new plan\'s workspace path, which you can then write to or create tasks under.',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'Plan or folder name (basename)',
              },
              'is_folder': {
                'type': 'boolean',
                'description':
                    'true to create a folder, false (default) for a plan document',
              },
              'parent_path': {
                'type': 'string',
                'description':
                    'Optional parent folder workspace path, e.g. "/PLANS/Sprint 1" (defaults to /PLANS)',
              },
              'content': {
                'type': 'string',
                'description':
                    'Optional initial markdown content for a plan document',
              },
            },
            'required': ['name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_plan',
          'description':
              'Read the full contents of any plan document by its workspace path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'plan_path': {
                'type': 'string',
                'description': 'Workspace path, e.g. "/PLANS/Roadmap.md"',
              },
            },
            'required': ['plan_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_plan',
          'description':
              'Replace the contents of any plan document by its workspace path with new markdown. Provide the COMPLETE new document, not a diff.',
          'parameters': {
            'type': 'object',
            'properties': {
              'plan_path': {
                'type': 'string',
                'description': 'Workspace path, e.g. "/PLANS/Roadmap.md"',
              },
              'content': {
                'type': 'string',
                'description': 'The full new plan document (markdown)',
              },
            },
            'required': ['plan_path', 'content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'rename_plan',
          'description':
              'Rename a plan document or folder by its workspace path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'plan_path': {
                'type': 'string',
                'description':
                    'Current workspace path, e.g. "/PLANS/Roadmap.md"',
              },
              'name': {'type': 'string', 'description': 'New name (basename)'},
            },
            'required': ['plan_path', 'name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_plan',
          'description':
              'Delete a plan document or folder by its workspace path (folders delete everything inside). Tasks created from it keep their history but lose the plan link. Permanent — only when the user asks.',
          'parameters': {
            'type': 'object',
            'properties': {
              'plan_path': {
                'type': 'string',
                'description': 'Workspace path, e.g. "/PLANS/Roadmap.md"',
              },
            },
            'required': ['plan_path'],
          },
        },
      },
      // ── Files: read/write the project workspace (the .nxtprj virtual disk) ──
      {
        'type': 'function',
        'function': {
          'name': 'list_files',
          'description':
              'List the files and folders in the project workspace at a directory path. Use to explore the codebase before reading or editing.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description':
                    'Workspace directory path, e.g. "/" (root) or "/src". Defaults to "/".',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_file',
          'description':
              'Read the full text contents of a file in the project workspace by its path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace file path, e.g. "/lib/main.dart"',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_file',
          'description':
              'Create or overwrite a file in the project workspace with the given text content. Creates parent folders as needed. Provide the COMPLETE new file contents.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace file path, e.g. "/src/app.js"',
              },
              'content': {
                'type': 'string',
                'description': 'The full file contents to write',
              },
            },
            'required': ['path', 'content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_directory',
          'description':
              'Create a directory (and any missing parents) in the project workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace directory path, e.g. "/src/utils"',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'move_path',
          'description':
              'Move or rename a file or folder within the project workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'from': {
                'type': 'string',
                'description': 'Existing workspace path',
              },
              'to': {'type': 'string', 'description': 'New workspace path'},
            },
            'required': ['from', 'to'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_path',
          'description':
              'Delete a file or folder (folders are removed recursively) from the project workspace. Permanent — only when the user clearly asks.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace path to delete',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_file',
          'description':
              'Delete a single file from the project workspace. Fails if the path is a directory. Permanent — only when the user clearly asks.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace path of the file to delete',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_folder',
          'description':
              'Delete a folder and all of its contents (recursive) from the project workspace. Fails if the path is a file. Permanent — only when the user clearly asks.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Workspace path of the folder to delete',
              },
            },
            'required': ['path'],
          },
        },
      },
      // ── Git: version control over the workspace's embedded repository ──
      {
        'type': 'function',
        'function': {
          'name': 'git_status',
          'description':
              'Show the git status of the project workspace: current branch and the list of changed/untracked/deleted files.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_log',
          'description':
              'Show recent commits (newest first) on the current branch.',
          'parameters': {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Max commits to return (default 20).',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_commit',
          'description':
              'Commit changes in the workspace. By default commits ALL changes; pass a list of paths to commit only those.',
          'parameters': {
            'type': 'object',
            'properties': {
              'message': {'type': 'string', 'description': 'Commit message'},
              'paths': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'Optional workspace paths to commit (omit to commit everything)',
              },
            },
            'required': ['message'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_branches',
          'description': 'List the local git branches in the workspace.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_create_branch',
          'description':
              'Create a new git branch at the current commit. Optionally switch to it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'New branch name'},
              'checkout': {
                'type': 'boolean',
                'description':
                    'Switch to the new branch after creating it (default false)',
              },
            },
            'required': ['name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_checkout_branch',
          'description':
              'Switch the workspace to an existing branch. WARNING: this overwrites uncommitted workspace changes with the branch tip. Commit first if needed.',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'Branch name to switch to',
              },
            },
            'required': ['name'],
          },
        },
      },
      // ── Build / CI: local Docker builds + GitHub-Actions-format workflows ──
      {
        'type': 'function',
        'function': {
          'name': 'build_docker_image',
          'description':
              'Build a Docker image from a Dockerfile in the project workspace. Runs locally and streams the build log into the Builds/CI view. Returns a run id you can poll with get_ci_run.',
          'parameters': {
            'type': 'object',
            'properties': {
              'dockerfile_path': {
                'type': 'string',
                'description':
                    'Workspace path to the Dockerfile (e.g. "/Dockerfile")',
              },
              'image_tag': {
                'type': 'string',
                'description':
                    'Tag for the produced image (e.g. "myapp:latest")',
              },
              'context': {
                'type': 'string',
                'description':
                    'Build context directory relative to the workspace root (default ".")',
              },
              'task_id': {
                'type': 'string',
                'description':
                    'Optional task to gate on this build: if it succeeds the task is auto-marked Done, if it fails the task returns to the board.',
              },
            },
            'required': ['dockerfile_path', 'image_tag'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'run_workflow',
          'description':
              'Run a GitHub-Actions-format workflow (.github/workflows/*.yml) locally against the project workspace. Parses the YAML and executes its jobs/steps, streaming logs into the Builds/CI view. Returns a run id.',
          'parameters': {
            'type': 'object',
            'properties': {
              'workflow_path': {
                'type': 'string',
                'description':
                    'Workspace path to the workflow YAML (e.g. "/.github/workflows/ci.yml")',
              },
              'task_id': {
                'type': 'string',
                'description':
                    'Optional task to gate on this run: a green run auto-marks the task Done, a red one sends it back to the board.',
              },
            },
            'required': ['workflow_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'scaffold_ci_workflow',
          'description':
              'Write a default GitHub-Actions-format CI workflow into the project workspace (default path /.github/workflows/ci.yml). Use this to bootstrap CI before run_workflow. Choose a template by project kind.',
          'parameters': {
            'type': 'object',
            'properties': {
              'kind': {
                'type': 'string',
                'enum': ['flutter', 'dart', 'node', 'generic'],
                'description':
                    'Project type the workflow should target (default "flutter").',
              },
              'path': {
                'type': 'string',
                'description':
                    'Workspace path to write (default "/.github/workflows/ci.yml").',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_ci_runs',
          'description':
              'List recent build / CI runs for this project (id, name, status, kind).',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_ci_run',
          'description':
              'Get the details of one build / CI run by id: its jobs, steps, statuses, exit codes, and the captured log output (so you can diagnose build errors).',
          'parameters': {
            'type': 'object',
            'properties': {
              'run_id': {
                'type': 'string',
                'description':
                    'The run id (from list_ci_runs or build_docker_image / run_workflow)',
              },
              'tail': {
                'type': 'integer',
                'description':
                    'Only include the last N lines of each step log (default 200).',
              },
            },
            'required': ['run_id'],
          },
        },
      },
      // ── Orchestration: the spawn → submit → verify → review loop ──
      {
        'type': 'function',
        'function': {
          'name': 'submit_for_completion',
          'description':
              'WORKER tool. Call when the assigned task is implemented and committed to its task branch. Moves the task to Review and records your submission so the Verification Agent can prove it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {
                'type': 'string',
                'description': 'The task you were assigned.',
              },
              'summary': {
                'type': 'string',
                'description':
                    'What you changed and how it satisfies the acceptance criteria.',
              },
              'evidence': {
                'type': 'string',
                'description':
                    'Proof you gathered: test output, build ids, diffs.',
              },
              'branch': {
                'type': 'string',
                'description':
                    'The task branch your commits are on (e.g. "task/42").',
              },
            },
            'required': ['task_id', 'summary'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'run_verification',
          'description':
              'VERIFICATION AGENT tool. Begin verifying a submitted task: marks it as verifying and returns the task\'s acceptance criteria and runnable verification command so you can execute the proof with your read/run tools.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'submit_verdict',
          'description':
              'VERIFICATION AGENT tool. Emit the pass/fail verdict for a task after running its verification. On pass the task awaits Coordinator integration; on fail it returns to the board for the same agent to re-engage.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'verdict': {
                'type': 'string',
                'enum': ['pass', 'fail'],
                'description': '"pass" or "fail".',
              },
              'evidence': {
                'type': 'string',
                'description': 'The observed proof that justifies the verdict.',
              },
            },
            'required': ['task_id', 'verdict'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'review_submission',
          'description':
              'Read a task\'s worker submission (summary, evidence, branch) and current execution state, so you can decide whether to approve or reject it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'approve_task',
          'description':
              'Approve a verified task as fully done: marks it Done and tears down the ephemeral worker session. Merge the task branch into main with git_merge BEFORE approving.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
            },
            'required': ['task_id'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'reject_task',
          'description':
              'Send a task back to the board (Todo) for rework, clearing its submission and live worker session. Use when a submission or verification is unsatisfactory.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string'},
              'reason': {
                'type': 'string',
                'description':
                    'Why it is being sent back (recorded on the task).',
              },
            },
            'required': ['task_id'],
          },
        },
      },
      // ── Files (extended): directory listing, search, chunked reads, safe edits ──
      {
        'type': 'function',
        'function': {
          'name': 'list_directory',
          'description':
              'List everything inside a workspace directory, labeling each entry as a folder or file.',
          'parameters': {
            'type': 'object',
            'properties': {
              'dir_path': {
                'type': 'string',
                'description':
                    'Workspace directory path, e.g. "/" or "/src/utils".',
              },
            },
            'required': ['dir_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_directory',
          'description':
              'Recursively search every text file under a workspace directory for a string. Returns each matching file with line numbers and a snippet.',
          'parameters': {
            'type': 'object',
            'properties': {
              'pattern': {
                'type': 'string',
                'description': 'The exact text to search for.',
              },
              'dir_path': {
                'type': 'string',
                'description':
                    'Subfolder to search within (defaults to the workspace root "/").',
              },
            },
            'required': ['pattern'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_file_content',
          'description':
              'Search for a string inside a single file. Returns the line numbers and matching text. Use to pinpoint a line before editing.',
          'parameters': {
            'type': 'object',
            'properties': {
              'file_path': {
                'type': 'string',
                'description': 'Workspace file path.',
              },
              'pattern': {'type': 'string', 'description': 'The text to find.'},
            },
            'required': ['file_path', 'pattern'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_file_chunk',
          'description':
              'Read a specific range of lines from a file (max 200 lines per call) so you do not ingest huge files. Output is labeled with line numbers.',
          'parameters': {
            'type': 'object',
            'properties': {
              'file_path': {
                'type': 'string',
                'description': 'Workspace file path.',
              },
              'start_line': {
                'type': 'integer',
                'description': 'First line to read (1-based).',
              },
              'end_line': {
                'type': 'integer',
                'description':
                    'Last line to read (capped to start_line + 200).',
              },
            },
            'required': ['file_path', 'start_line', 'end_line'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_file',
          'description':
              'Create a NEW file with the given content. Fails if a file already exists at that path (use write_file or edit_file to change existing files).',
          'parameters': {
            'type': 'object',
            'properties': {
              'file_path': {
                'type': 'string',
                'description': 'Workspace path and file name to create.',
              },
              'content': {
                'type': 'string',
                'description': 'The full text to populate the new file with.',
              },
            },
            'required': ['file_path', 'content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'edit_file',
          'description':
              'Safely edit a file with an exact search-and-replace. Reads the file, replaces the FIRST occurrence of old_text with new_text, and writes it back. Aborts if old_text is not found exactly.',
          'parameters': {
            'type': 'object',
            'properties': {
              'file_path': {
                'type': 'string',
                'description': 'Target workspace file path.',
              },
              'old_text': {
                'type': 'string',
                'description': 'The exact existing text block to replace.',
              },
              'new_text': {
                'type': 'string',
                'description': 'The replacement text block.',
              },
            },
            'required': ['file_path', 'old_text', 'new_text'],
          },
        },
      },
      // ── Git remote ops (push/pull/merge) ──
      {
        'type': 'function',
        'function': {
          'name': 'git_push',
          'description':
              'Push commits to a remote. (Not yet supported — the workspace repo is local-only with no remote configured.)',
          'parameters': {
            'type': 'object',
            'properties': {
              'remote': {'type': 'string'},
              'branch': {'type': 'string'},
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_pull',
          'description':
              'Pull commits from a remote. (Not yet supported — the workspace repo is local-only with no remote configured.)',
          'parameters': {
            'type': 'object',
            'properties': {
              'remote': {'type': 'string'},
              'branch': {'type': 'string'},
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_merge',
          'description':
              'Merge another branch into the CURRENT branch (typically a task/<id> branch into main). Fast-forwards when possible, otherwise creates a merge commit. If both sides changed the same files, it reports the conflicting paths and makes NO changes — send the task back rather than guessing. Switch to the target branch (git_checkout_branch) first.',
          'parameters': {
            'type': 'object',
            'properties': {
              'branch': {
                'type': 'string',
                'description': 'The branch to merge into the current branch.',
              },
              'message': {
                'type': 'string',
                'description':
                    'Optional merge commit message (used only when a merge commit is created).',
              },
            },
            'required': ['branch'],
          },
        },
      },
      if (includeStoryTools) ..._storyToolSchemas,
    ];
  }

  /// User-story tools for the post-setup Exploration phase. Build the discovery
  /// story tree; intentionally read/write stories only (never tasks).
  static const List<Map<String, dynamic>> _storyToolSchemas = [
    {
      'type': 'function',
      'function': {
        'name': 'draft_stories_from_text',
        'description':
            'When the user pastes/says a big chunk describing several things at '
            'once, pass their RAW text here. A focused helper splits it and '
            'REPHRASES each part into a clean user story (title + "As a… I want… '
            'so that…" description) plus a concise note, and adds them to the '
            'tree (optionally under parent_story_id). Use this instead of hand-'
            'writing many add_user_story calls — then nest/refine with '
            'move_user_story.',
        'parameters': {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'The user\'s raw description to split + rephrase.',
            },
            'parent_story_id': {
              'type': 'string',
              'description': 'Optional parent to add the drafted stories under.',
            },
          },
          'required': ['text'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_user_story',
        'description':
            'Add a user story to the project story tree during discovery. Use '
            'this to capture each distinct piece of the idea as you interview '
            'the user. Make it a child of an epic/story via parent_story_id to '
            'build the tree (epics → stories → sub-stories).',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Short node title (e.g. "Sign up").',
            },
            'narrative': {
              'type': 'string',
              'description':
                  'The story in "As a <role>, I want <goal>, so that '
                  '<benefit>" form.',
            },
            'acceptance_criteria': {
              'type': 'string',
              'description': 'Optional acceptance criteria (markdown bullets).',
            },
            'parent_story_id': {
              'type': 'string',
              'description':
                  'Optional id of the parent story/epic to nest under.',
            },
            'kind': {
              'type': 'string',
              'enum': ['epic', 'story', 'substory'],
              'description': 'Node kind (default "story").',
            },
          },
          'required': ['title'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_user_story',
        'description':
            'Update an existing user story (title, narrative, acceptance '
            'criteria, or status) as the idea is refined.',
        'parameters': {
          'type': 'object',
          'properties': {
            'story_id': {'type': 'string'},
            'title': {'type': 'string'},
            'narrative': {'type': 'string'},
            'acceptance_criteria': {'type': 'string'},
            'status': {
              'type': 'string',
              'enum': ['draft', 'confirmed', 'done'],
            },
          },
          'required': ['story_id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'move_user_story',
        'description':
            'Re-parent and/or re-order an existing story to fix the tree '
            'hierarchy (e.g. nest a story under another, chain a flow, or pull '
            'one up to the root). Set parent_story_id to the new parent, or null '
            'to make it a root. Optionally set order_index for its position '
            'among its siblings (0 = first).',
        'parameters': {
          'type': 'object',
          'properties': {
            'story_id': {'type': 'string'},
            'parent_story_id': {
              'type': 'string',
              'description': 'New parent id, or "null"/empty to make it a root.',
            },
            'order_index': {'type': 'integer'},
          },
          'required': ['story_id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'list_user_stories',
        'description':
            'List the current user-story tree (ids, titles, parents, status) so '
            'you stay grounded in what has already been captured.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_note',
        'description':
            'Attach a descriptive note to a user story (e.g. a detail, decision, '
            'constraint, or open question). Notes show as clickable pills on the '
            'story.',
        'parameters': {
          'type': 'object',
          'properties': {
            'story_id': {'type': 'string'},
            'body': {'type': 'string', 'description': 'The note text.'},
          },
          'required': ['story_id', 'body'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_note',
        'description': 'Replace the text of an existing note.',
        'parameters': {
          'type': 'object',
          'properties': {
            'note_id': {'type': 'string'},
            'body': {'type': 'string'},
          },
          'required': ['note_id', 'body'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_note',
        'description': 'Delete a note by id.',
        'parameters': {
          'type': 'object',
          'properties': {
            'note_id': {'type': 'string'},
          },
          'required': ['note_id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_notes',
        'description': 'List all notes (ids + text) on a story.',
        'parameters': {
          'type': 'object',
          'properties': {
            'story_id': {'type': 'string'},
          },
          'required': ['story_id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_note',
        'description': 'Read a single note by id.',
        'parameters': {
          'type': 'object',
          'properties': {
            'note_id': {'type': 'string'},
          },
          'required': ['note_id'],
        },
      },
    },
  ];
}

/// Executes a tool call returned by the LLM against the live database.
/// Returns a short human-readable result string that gets appended as a
/// tool message so the model can continue the conversation naturally.
class CoordinatorToolExecutor {
  final NexusDatabase db;
  final int projectId;

  /// Backend instance (used for image generation / diagram tools).
  final InferenceBackend? inference;

  /// The model id, so tools can make small SCOPED sub-calls (e.g. rephrasing a
  /// chunk of input into clean stories) without dragging the session history.
  final String? model;

  /// Provenance: the chat session and/or plan this conversation is about, so
  /// created tasks can be backtracked to why/where they came from.
  final int? chatSessionPk;

  /// Workspace path of the plan this conversation is focused on (or null).
  final String? openPlanPath;

  /// Filesystem-backed plan store for the project workspace. Required for the
  /// plan tools to function (they read/write real files under /PLANS).
  final PlanStore? planStore;

  /// Tool-safety: the active agent's effective tool permissions. Defaults to
  /// "everything granted" when no agent/config is supplied.
  final AgentToolPermissions permissions;

  /// Human-in-the-loop approval for tools set to "ask". Receives the tool name
  /// and a short human summary; returns true to allow. When null, "ask" tools
  /// are blocked (no way to get approval in this context, e.g. voice).
  final Future<bool> Function(String tool, String summary)? confirmAsk;

  /// Friendly agent name for permission messages.
  final String agentName;

  /// The project's workspace (the .nxtprj virtual disk). Required for the file
  /// tools and for materializing builds/CI runs.
  final Workspace? workspace;

  /// The workspace's embedded git engine. Required for the git tools.
  final NxtprjGitEngine? git;

  /// Build/CI orchestrator. Required for the build tools.
  final BuildService? buildService;

  /// Signal hooks for the deep planning run. When set, the matching planner
  /// tool is offered and routed here: [onPlanningComplete] fires when the
  /// planner declares the plan done; [onPlanReview] carries an engineer
  /// reviewer's verdict. Null for the normal coordinator chat.
  final void Function()? onPlanningComplete;
  final void Function(bool approved, String gaps)? onPlanReview;

  /// Per-task isolation (orchestrated worker): when set, [workspace] is an
  /// ISOLATED per-task working tree and `git_commit` snapshots it onto
  /// [workBranch] in the shared object DB, serialized through [gitLane]. The
  /// agent is pinned to its task branch (no checkout/create). Null in the
  /// interactive chat, which commits the shared tree onto HEAD.
  final String? workBranch;
  final AsyncLock? gitLane;

  CoordinatorToolExecutor({
    required this.db,
    required this.projectId,
    this.inference,
    this.model,
    this.chatSessionPk,
    this.openPlanPath,
    this.planStore,
    this.permissions = AgentToolPermissions.allDefaults,
    this.confirmAsk,
    this.agentName = 'This agent',
    this.workspace,
    this.git,
    this.buildService,
    this.onPlanningComplete,
    this.onPlanReview,
    this.workBranch,
    this.gitLane,
  });

  /// True when running as an orchestrated worker on an isolated task tree.
  bool get _isolatedTask =>
      workBranch != null && gitLane != null && workspace != null && git != null;

  /// Serialize a git WRITE through the project's shared git lane when one is
  /// available. The interactive chat commits the shared working tree onto HEAD
  /// (not an isolated task tree), so its writes must not interleave with the
  /// orchestrator's lane-serialized commits against the same object DB. When no
  /// lane is wired (e.g. tests, or a context with no concurrency), the op runs
  /// directly. Read-only git ops (status/log/branches) don't need this.
  Future<T> _withGitLane<T>(Future<T> Function() op) =>
      gitLane != null ? gitLane!.run(op) : op();

  /// A short human-readable summary of what a tool call will do (for approval).
  String _summary(String name, Map<String, dynamic> args) {
    final spec = toolSpecFor(name);
    final label = spec?.label ?? name;
    final detail =
        args['title'] ??
        args['name'] ??
        args['task_id'] ??
        args['plan_path'] ??
        '';
    return detail.toString().isEmpty ? label : '$label — "$detail"';
  }

  /// Gate a tool call against the agent's permissions. Returns null when the
  /// call may proceed, or a message string to return instead when it must not.
  Future<String?> _gate(String name, Map<String, dynamic> args) async {
    switch (permissions.permFor(name)) {
      case ToolPerm.grant:
        return null;
      case ToolPerm.deny:
        return '🚫 Blocked: $agentName is not permitted to use "$name" (Deny). Adjust this in the agent\'s Permissions.';
      case ToolPerm.ask:
        if (confirmAsk == null) {
          return '⏸ "$name" requires human approval (Ask), which isn\'t available here. Approve it from the text chat, or change the permission to Grant.';
        }
        final approved = await confirmAsk!(name, _summary(name, args));
        return approved
            ? null
            : '🙅 Declined: the user did not approve "$name".';
    }
  }

  /// Tool args arrive as JSON; ids may be numbers or numeric strings.
  int? _asInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));

  Future<String> execute({
    required String name,
    required Map<String, dynamic> args,
  }) async {
    try {
      // Tool-safety gate: respect the agent's per-tool permission (grant/ask/deny).
      final blocked = await _gate(name, args);
      if (blocked != null) return blocked;

      switch (name) {
        case 'draft_stories_from_text':
          return await _draftStoriesFromText(args);
        case 'add_user_story':
          return await _addUserStory(args);
        case 'update_user_story':
          return await _updateUserStory(args);
        case 'move_user_story':
          return await _moveUserStory(args);
        case 'list_user_stories':
          return await _listUserStories();
        case 'add_note':
          return await _addNote(args);
        case 'update_note':
          return await _updateNote(args);
        case 'delete_note':
          return await _deleteNote(args);
        case 'get_notes':
          return await _getNotes(args);
        case 'get_note':
          return await _getNote(args);
        case 'create_task':
          return await _createTask(args);
        case 'update_task_status':
          return await _updateTaskStatus(args);
        case 'update_task':
          return await _updateTask(args);
        case 'generate_diagram':
          return await _generateDiagram(args);
        case 'propose_plan_adjustment':
          return _proposePlanAdjustment(args);
        case 'list_open_tasks':
          return await _listOpenTasks();
        case 'view_current_plan':
          return await _viewCurrentPlan();
        case 'sync_plans_to_tasks':
          return await _syncPlansToTasks();
        case 'mark_planning_complete':
          onPlanningComplete?.call();
          return 'Planning marked complete.';
        case 'submit_plan_review':
          final approved = args['approved'] == true;
          final gaps = (args['gaps'] as String? ?? '').trim();
          onPlanReview?.call(approved, gaps);
          return approved
              ? 'Recorded your approval of the plan.'
              : 'Recorded your review — gaps noted.';
        case 'assign_agent_to_task':
          return await _assignAgentToTask(args);
        case 'set_task_dates':
          return await _setTaskDates(args);
        case 'set_task_build_config':
          return await _setTaskBuildConfig(args);
        case 'view_plan':
          return await _viewPlan();
        case 'update_plan':
          return await _updatePlan(args);
        case 'list_tasks':
          return await _listTasks(args);
        case 'get_task':
          return await _getTask(args);
        case 'delete_task':
          return await _deleteTask(args);
        case 'link_task_to_plan':
          return await _linkTaskToPlan(args);
        case 'list_agents':
          return await _listAgents();
        case 'list_plans':
          return await _listPlans();
        case 'create_plan':
          return await _createPlan(args);
        case 'read_plan':
          return await _readPlan(args);
        case 'write_plan':
          return await _writePlan(args);
        case 'rename_plan':
          return await _renamePlan(args);
        case 'delete_plan':
          return await _deletePlan(args);
        // Files
        case 'list_files':
          return await _listFiles(args);
        case 'read_file':
          return await _readFile(args);
        case 'write_file':
          return await _writeFile(args);
        case 'create_directory':
          return await _createDirectory(args);
        case 'move_path':
          return await _movePath(args);
        case 'delete_path':
          return await _deletePath(args);
        case 'delete_file':
          return await _deleteFile(args);
        case 'delete_folder':
          return await _deleteFolder(args);
        case 'list_directory':
          return await _listDirectory(args);
        case 'search_directory':
          return await _searchDirectory(args);
        case 'search_file_content':
          return await _searchFileContent(args);
        case 'read_file_chunk':
          return await _readFileChunk(args);
        case 'create_file':
          return await _createFile(args);
        case 'edit_file':
          return await _editFile(args);
        // Git
        case 'git_status':
          return await _gitStatus();
        case 'git_log':
          return await _gitLog(args);
        case 'git_commit':
          return await _gitCommit(args);
        case 'git_branches':
          return await _gitBranches();
        case 'git_create_branch':
          return await _gitCreateBranch(args);
        case 'git_checkout_branch':
          return await _gitCheckoutBranch(args);
        case 'git_push':
          return await _gitPush(args);
        case 'git_pull':
          return await _gitPull(args);
        case 'git_merge':
          return await _gitMerge(args);
        // Orchestration
        case 'submit_for_completion':
          return await _submitForCompletion(args);
        case 'run_verification':
          return await _runVerification(args);
        case 'submit_verdict':
          return await _submitVerdict(args);
        case 'review_submission':
          return await _reviewSubmission(args);
        case 'approve_task':
          return await _approveTask(args);
        case 'reject_task':
          return await _rejectTask(args);
        // Build / CI
        case 'build_docker_image':
          return await _buildDockerImage(args);
        case 'run_workflow':
          return await _runWorkflow(args);
        case 'scaffold_ci_workflow':
          return await _scaffoldCiWorkflow(args);
        case 'list_ci_runs':
          return await _listCiRuns();
        case 'get_ci_run':
          return await _getCiRun(args);
        default:
          return 'Unknown tool "$name". No action taken.';
      }
    } catch (e) {
      return 'Tool "$name" failed: $e';
    }
  }

  // ── User-story (Exploration discovery) tools ──────────────────────────────

  /// Split a big chunk of user text into clean stories via a SMALL SCOPED call
  /// (fresh, minimal context — no session history), each rephrased into a story
  /// + a note, then created in the tree. This keeps the heavy split/rephrase off
  /// the main discovery session.
  Future<String> _draftStoriesFromText(Map<String, dynamic> args) async {
    final text = (args['text'] as String? ?? '').trim();
    if (text.isEmpty) return 'draft_stories_from_text failed: text is required.';
    final parentId = _asInt(args['parent_story_id']);
    if (parentId != null && await db.getUserStoryById(parentId) == null) {
      return 'draft_stories_from_text failed: parent story #$parentId not found.';
    }

    // 1) Preferred path: ask the model to split + rephrase + nest into a tree.
    //    Small/local models often wrap the JSON in prose or emit one object per
    //    line, so parse LENIENTLY and retry once with a stricter nudge before
    //    giving up on the AI path.
    final backend = inference;
    final mdl = model;
    var items = const <Map<String, dynamic>>[];
    var usedAi = false;
    if (backend != null && mdl != null && mdl.isNotEmpty) {
      const system =
          'You split a product/feature description into concrete USER STORIES, '
          'rephrase each into clean wording, AND nest them into a tree. Return ONLY '
          'a JSON array (no prose, no code fences). Each item: {"title": a short '
          'title, "description": the story as "As a <role>, I want <goal>, so that '
          '<benefit>" rephrased from the input, "note": one concise extra '
          'detail/constraint/flow step from the input, "parent": the EXACT title of '
          'another item in this list that this one is a sub-step or sub-feature of '
          '(its parent in the tree), or null if it sits at the top level}. CHAIN the '
          'steps of a flow: each step\'s parent is the step it follows from, so a '
          'linear flow becomes a parent→child→grandchild chain, not a flat row. List '
          'every parent BEFORE its children. Produce 3–8 items. Keep it faithful to '
          'the input — do not invent features.';
      for (var attempt = 0; attempt < 2 && items.isEmpty; attempt++) {
        final user = attempt == 0
            ? text
            : '$text\n\nReturn ONLY a JSON array of objects — no prose, no code '
                  'fences, no trailing text.';
        try {
          final raw = await scopedComplete(
            backend: backend,
            model: mdl,
            system: system,
            user: user,
            maxTokens: 900,
          );
          items = parseLooseJsonObjects(raw);
        } catch (_) {
          // Backend hiccup — fall through to the deterministic split below.
        }
      }
      usedAi = items.isNotEmpty;
    }

    // 2) Fallback: never dead-end. Split the user's OWN words into stories so
    //    something is always captured (the coordinator can refine/rename after).
    if (items.isEmpty) items = _storyItemsFromRawText(text);
    if (items.isEmpty) {
      return 'Could not draft stories from that text — try add_user_story.';
    }

    // Build the tree as we go: resolve each item's "parent" (a title within this
    // batch) to the id we created for it; items with no in-batch parent hang
    // under the passed-in parentId (the root for this draft). Per-parent order
    // counters keep siblings in input order; existing siblings under the root
    // are counted once so the draft appends after them.
    final existing = await db.getUserStoriesForProject(projectId);
    final created = <String, int>{}; // lowercased title → new story id
    final orderByParent = <int?, int>{
      parentId: existing.where((s) => s.parent_story_fk == parentId).length,
    };
    var made = 0;
    for (final it in items) {
      final title = (it['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final desc = (it['description'] ?? '').toString().trim();
      final note = (it['note'] ?? '').toString().trim();
      final parentTitle = (it['parent'] ?? '').toString().trim().toLowerCase();
      // A child references a SIBLING-IN-BATCH by title; fall back to the root
      // parent if it's empty or its parent hasn't been created (yet).
      final effectiveParent = parentTitle.isNotEmpty
          ? (created[parentTitle] ?? parentId)
          : parentId;
      final order = orderByParent[effectiveParent] ?? 0;
      orderByParent[effectiveParent] = order + 1;
      final id = await db.createUserStory(
        UserStoriesCompanion.insert(
          project_fk: projectId,
          parent_story_fk: Value(effectiveParent),
          title: title,
          narrative: Value(desc),
          orderIndex: Value(order),
        ),
      );
      created[title.toLowerCase()] = id;
      if (note.isNotEmpty) await db.createStoryNote(id, note);
      made++;
    }
    return 'Drafted $made user stor${made == 1 ? 'y' : 'ies'} '
        '${usedAi ? '(rephrased + nested into a tree)' : '(split straight from '
              'your text — titles are literal, so tidy/rephrase + nest them with '
              'update_user_story and move_user_story)'}'
        '${parentId != null ? ' under #$parentId' : ''}. '
        'Check the shape with list_user_stories; fix any nesting with '
        'move_user_story if needed.';
  }

  /// Deterministic fallback for [_draftStoriesFromText] when no model is
  /// available or it won't return usable JSON: turn the user's raw description
  /// into a flat list of story items by splitting on bullets/lines, then on
  /// sentence boundaries. Keeps it faithful (their own words) and bounded so the
  /// draft never dead-ends. Items use the same shape the AI path returns
  /// ({title, description, note, parent}), all top-level (parent: null).
  List<Map<String, dynamic>> _storyItemsFromRawText(String text) {
    final bulletRe = RegExp(r'^\s*(?:[-*•·]|\d+[.)])\s+');
    // Prefer explicit lines/bullets; if it's one blob, split on sentence enders.
    var segments = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceFirst(bulletRe, '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (segments.length < 2) {
      segments = text
          .split(RegExp(r'(?<=[.!?;])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final items = <Map<String, dynamic>>[];
    for (final seg in segments) {
      // Skip noise — a story needs at least a few words of intent.
      if (seg.split(RegExp(r'\s+')).length < 3 || seg.length < 12) continue;
      final words = seg.split(RegExp(r'\s+'));
      final title = (words.length <= 9 ? seg : '${words.take(9).join(' ')}…')
          .replaceAll(RegExp(r'[.!?;,]+$'), '');
      items.add({'title': title, 'description': seg, 'note': '', 'parent': null});
      if (items.length >= 8) break; // bound the batch like the AI path (3–8)
    }
    return items;
  }

  Future<String> _addUserStory(Map<String, dynamic> args) async {
    final title = (args['title'] as String? ?? '').trim();
    if (title.isEmpty) return 'add_user_story failed: title is required.';
    final parentId = _asInt(args['parent_story_id']);
    if (parentId != null && await db.getUserStoryById(parentId) == null) {
      return 'add_user_story failed: parent story #$parentId not found.';
    }
    final kind = (args['kind'] as String? ?? 'story').trim();
    // Append after existing siblings so creation order is the display order.
    final existing = await db.getUserStoriesForProject(projectId);
    final siblingCount = existing
        .where((s) => s.parent_story_fk == parentId)
        .length;
    final id = await db.createUserStory(
      UserStoriesCompanion.insert(
        project_fk: projectId,
        parent_story_fk: Value(parentId),
        title: title,
        narrative: Value((args['narrative'] as String? ?? '').trim()),
        acceptanceCriteria: Value(
          (args['acceptance_criteria'] as String?)?.trim().isEmpty ?? true
              ? null
              : (args['acceptance_criteria'] as String).trim(),
        ),
        kind: Value(kind.isEmpty ? 'story' : kind),
        orderIndex: Value(siblingCount),
      ),
    );
    return 'Added user story "$title" (id: $id)'
        '${parentId != null ? ' under #$parentId' : ''}.';
  }

  /// Re-parent / re-order a story to fix the tree (cycle-safe).
  Future<String> _moveUserStory(Map<String, dynamic> args) async {
    final id = _asInt(args['story_id']);
    if (id == null) return 'move_user_story failed: story_id is required.';
    final all = await db.getUserStoriesForProject(projectId);
    if (!all.any((s) => s.story_pk == id)) {
      return 'move_user_story failed: story #$id not found.';
    }

    // Resolve the new parent: explicit null/empty → root.
    final rawParent = args['parent_story_id'];
    final parentStr = rawParent?.toString().trim().toLowerCase();
    final makeRoot =
        parentStr == null || parentStr.isEmpty || parentStr == 'null';
    final newParent = makeRoot ? null : _asInt(rawParent);
    if (newParent != null) {
      if (newParent == id) {
        return 'move_user_story failed: a story can\'t be its own parent.';
      }
      if (!all.any((s) => s.story_pk == newParent)) {
        return 'move_user_story failed: parent story #$newParent not found.';
      }
      // Reject cycles: the new parent must not be a descendant of this story.
      final childrenOf = <int, List<int>>{};
      for (final s in all) {
        if (s.parent_story_fk != null) {
          (childrenOf[s.parent_story_fk!] ??= []).add(s.story_pk);
        }
      }
      final stack = <int>[id];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (cur == newParent) {
          return 'move_user_story failed: #$newParent is below #$id — that '
              'would create a cycle.';
        }
        stack.addAll(childrenOf[cur] ?? const []);
      }
    }

    final order = _asInt(args['order_index']);
    await db.updateUserStory(
      id,
      UserStoriesCompanion(
        parent_story_fk: Value(newParent),
        orderIndex: order != null ? Value(order) : const Value.absent(),
      ),
    );
    return 'Moved story #$id ${makeRoot ? 'to root' : 'under #$newParent'}'
        '${order != null ? ' at position $order' : ''}.';
  }

  Future<String> _updateUserStory(Map<String, dynamic> args) async {
    final id = _asInt(args['story_id']);
    if (id == null) return 'update_user_story failed: story_id is required.';
    if (await db.getUserStoryById(id) == null) {
      return 'update_user_story failed: story #$id not found.';
    }
    String? s(String k) {
      final v = (args[k] as String?)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    await db.updateUserStory(
      id,
      UserStoriesCompanion(
        title: s('title') != null ? Value(s('title')!) : const Value.absent(),
        narrative: s('narrative') != null
            ? Value(s('narrative')!)
            : const Value.absent(),
        acceptanceCriteria: s('acceptance_criteria') != null
            ? Value(s('acceptance_criteria'))
            : const Value.absent(),
        status: s('status') != null ? Value(s('status')!) : const Value.absent(),
      ),
    );
    return 'Updated user story #$id.';
  }

  Future<String> _listUserStories() async {
    final stories = await db.getUserStoriesForProject(projectId);
    if (stories.isEmpty) {
      return 'No user stories captured yet.';
    }
    final b = StringBuffer('User stories (${stories.length}):\n');
    for (final s in stories) {
      final parent = s.parent_story_fk != null
          ? ' (child of #${s.parent_story_fk})'
          : '';
      b.writeln('- #${s.story_pk} [${s.kind}/${s.status}] ${s.title}$parent');
    }
    return b.toString();
  }

  // ── Story notes ───────────────────────────────────────────────────────────

  Future<String> _addNote(Map<String, dynamic> args) async {
    final storyId = _asInt(args['story_id']);
    final body = (args['body'] as String? ?? '').trim();
    if (storyId == null) return 'add_note failed: story_id is required.';
    if (body.isEmpty) return 'add_note failed: body is required.';
    if (await db.getUserStoryById(storyId) == null) {
      return 'add_note failed: story #$storyId not found.';
    }
    final id = await db.createStoryNote(storyId, body);
    return 'Added note (id: $id) to story #$storyId.';
  }

  Future<String> _updateNote(Map<String, dynamic> args) async {
    final id = _asInt(args['note_id']);
    final body = (args['body'] as String? ?? '').trim();
    if (id == null) return 'update_note failed: note_id is required.';
    if (body.isEmpty) return 'update_note failed: body is required.';
    if (await db.getStoryNote(id) == null) {
      return 'update_note failed: note #$id not found.';
    }
    await db.updateStoryNote(id, body);
    return 'Updated note #$id.';
  }

  Future<String> _deleteNote(Map<String, dynamic> args) async {
    final id = _asInt(args['note_id']);
    if (id == null) return 'delete_note failed: note_id is required.';
    if (await db.getStoryNote(id) == null) {
      return 'delete_note failed: note #$id not found.';
    }
    await db.deleteStoryNote(id);
    return 'Deleted note #$id.';
  }

  Future<String> _getNotes(Map<String, dynamic> args) async {
    final storyId = _asInt(args['story_id']);
    if (storyId == null) return 'get_notes failed: story_id is required.';
    final notes = await db.getNotesForStory(storyId);
    if (notes.isEmpty) return 'Story #$storyId has no notes.';
    final b = StringBuffer('Notes on story #$storyId (${notes.length}):\n');
    for (final n in notes) {
      b.writeln('- #${n.note_pk}: ${n.body}');
    }
    return b.toString();
  }

  Future<String> _getNote(Map<String, dynamic> args) async {
    final id = _asInt(args['note_id']);
    if (id == null) return 'get_note failed: note_id is required.';
    final n = await db.getStoryNote(id);
    if (n == null) return 'get_note failed: note #$id not found.';
    return 'Note #${n.note_pk} (story #${n.story_fk}): ${n.body}';
  }

  Future<String> _createTask(Map<String, dynamic> args) async {
    final title = (args['title'] as String? ?? '').trim();
    if (title.isEmpty) return 'create_task failed: title is required.';

    final description = args['description'] as String? ?? '';
    final parentId = _asInt(args['parent_task_id']);
    final priority = args['priority'] as String? ?? 'MED';
    final thinkingMode = args['thinking_enabled'] == true
        ? 'on'
        : (args['thinking_enabled'] == false ? 'off' : null);

    // A task is never left unassigned: use the persona the coordinator named if
    // it resolves, otherwise fall back to the project's default worker. An
    // unassigned task is skipped forever by the orchestrator, so this guarantee
    // is load-bearing, not cosmetic.
    final requested = _asInt(args['agent_persona_id']);
    int? assignee;
    if (requested != null && await db.resolveAgentPersona(requested) != null) {
      assignee = requested;
    } else {
      assignee = await resolveDefaultWorkerPersonaId(db, projectId);
    }

    final newId = await db.createTaskInProject(
      projectPk: projectId,
      title: title,
      description: description,
      priority: priority,
      parentPk: parentId,
      planPath: openPlanPath,
      chatSessionPk: chatSessionPk,
      agentPk: assignee,
      thinkingMode: thinkingMode,
    );

    if (assignee == null) {
      return 'Created task "$title" (id: $newId), but NO agent persona exists to '
          'assign it to — create a worker agent in the Agents hub so it can be '
          'picked up.';
    }
    final persona = await db.resolveAgentPersona(assignee);
    final who = persona?.name ?? 'agent #$assignee';
    return 'Created task "$title" (id: $newId), assigned to "$who".';
  }

  Future<String> _updateTaskStatus(Map<String, dynamic> args) async {
    final taskId = _asInt(args['task_id']);
    final status = args['status'] as String?;
    final note = args['note'] as String? ?? '';

    if (taskId == null || status == null) {
      return 'update_task_status failed: task_id and status required.';
    }

    final existing = await db.getTaskById(taskId);
    if (existing == null) {
      return 'Task $taskId not found in this project.';
    }

    await db.updateTaskStatus(taskId, status);

    if (note.isNotEmpty) {
      final updatedDesc =
          '${existing.description ?? ''}\n\n[Coordinator ${DateTime.now().toIso8601String().substring(0, 16)}]: $note'
              .trim();
      await db.patchTask(
        taskId,
        TasksCompanion(description: Value(updatedDesc)),
      );
    }

    return 'Updated task "${existing.title}" status to "$status".${note.isNotEmpty ? ' Note recorded.' : ''}';
  }

  Future<String> _updateTask(Map<String, dynamic> args) async {
    final taskId = _asInt(args['task_id']);
    if (taskId == null) return 'update_task failed: task_id required.';

    final existing = await db.getTaskById(taskId);
    if (existing == null) return 'Task $taskId not found.';

    final newTitle = (args['title'] as String?)?.trim();
    final newDesc = args['description'] as String?;
    final newPrio = args['priority'] as String?;
    final newThinking = args['thinking_enabled'] == true
        ? 'on'
        : (args['thinking_enabled'] == false ? 'off' : null);

    await db.patchTask(
      taskId,
      TasksCompanion(
        title: (newTitle != null && newTitle.isNotEmpty)
            ? Value(newTitle)
            : const Value.absent(),
        description: newDesc != null ? Value(newDesc) : const Value.absent(),
        priority: newPrio != null ? Value(newPrio) : const Value.absent(),
        thinkingMode: newThinking != null
            ? Value(newThinking)
            : const Value.absent(),
      ),
    );

    return 'Updated task "${newTitle ?? existing.title}". Changes are live in the UI.';
  }

  Future<String> _generateDiagram(Map<String, dynamic> args) async {
    final prompt = args['prompt'] as String? ?? 'Project plan diagram';
    final size = args['size'] as String? ?? '1024x1024';

    if (inference == null) {
      return 'Diagram request noted: "$prompt". (No inference server configured for image generation right now.)';
    }

    try {
      final resp = await inference!.generateImage(prompt: prompt, size: size);
      final url = resp.data.isNotEmpty
          ? (resp.data.first.url ?? 'generated image')
          : 'generated image';
      return 'Generated diagram for the plan. Image available at: $url (or embedded in chat if supported).';
    } catch (e) {
      return 'Image generation attempted for prompt "$prompt" but failed: $e';
    }
  }

  Future<String> _listOpenTasks() async {
    final tasks = await db.getTasksForProject(projectId);
    final open = tasks.where((t) => t.status.toLowerCase() != 'done').toList();
    if (open.isEmpty) {
      return tasks.isEmpty
          ? 'There are no tasks in this project yet.'
          : 'There are no open tasks — everything is marked Done.';
    }
    final b = StringBuffer('Open tasks (${open.length}):\n');
    for (final t in open) {
      b.writeln(
        '- ${t.title} (id: ${t.task_pk}) — ${t.status} [${t.priority}]',
      );
    }
    return b.toString().trim();
  }

  Future<String> _viewCurrentPlan() async {
    final tasks = await db.getTasksForProject(projectId);
    if (tasks.isEmpty) {
      return 'No plan/tasks yet for this project. The user is likely starting planning.';
    }
    final b = StringBuffer('Current project plan (${tasks.length} tasks):\n');
    for (final t in tasks.take(20)) {
      final parent = t.task_parent_fk != null
          ? ' (subtask of ${t.task_parent_fk})'
          : '';
      b.writeln('- ${t.title} — ${t.status}$parent');
    }
    if (tasks.length > 20) b.writeln('... and ${tasks.length - 20} more.');
    return b.toString().trim();
  }

  Future<String> _syncPlansToTasks() async {
    if (planStore == null) {
      return 'Plan storage is unavailable in this context, so plans can\'t be '
          'synced to tasks.';
    }
    final result = await PlanTaskSync(
      db: db,
      planStore: planStore!,
      projectId: projectId,
      chatSessionPk: chatSessionPk,
    ).sync();
    return result.describe();
  }

  /// Runs the idempotent plan→task sync after a plan write so any new outline
  /// items become tasks immediately (existing ones are marker-skipped, so this
  /// never double-creates). Returns a short suffix to append to the tool result,
  /// or '' when nothing new was created. Best-effort: never throws.
  Future<String> _autoSyncAfterPlanWrite() async {
    if (planStore == null) return '';
    try {
      final result = await PlanTaskSync(
        db: db,
        planStore: planStore!,
        projectId: projectId,
        chatSessionPk: chatSessionPk,
      ).sync();
      return result.created == 0 ? '' : ' ${result.describe()}';
    } catch (_) {
      return '';
    }
  }

  Future<String> _assignAgentToTask(Map<String, dynamic> args) async {
    final taskId = _asInt(args['task_id']);
    final personaId = _asInt(args['agent_persona_id']);
    if (taskId == null || personaId == null) {
      return 'assign_agent_to_task failed: task_id and agent_persona_id are required.';
    }
    final task = await db.getTaskById(taskId);
    if (task == null) return 'Task $taskId not found.';
    final persona = await db.resolveAgentPersona(personaId);
    final personaName = persona?.name ?? 'agent #$personaId';
    await db.assignTaskAgent(taskId, personaId);
    return 'Assigned agent "$personaName" to task "${task.title}".';
  }

  Future<String> _setTaskDates(Map<String, dynamic> args) async {
    final taskId = _asInt(args['task_id']);
    if (taskId == null) return 'set_task_dates failed: task_id is required.';
    final task = await db.getTaskById(taskId);
    if (task == null) return 'Task $taskId not found.';

    Value<DateTime?>? start;
    Value<DateTime?>? due;
    if (args.containsKey('start_date')) {
      final s = args['start_date'];
      start = Value(
        s is String && s.trim().isNotEmpty ? DateTime.tryParse(s.trim()) : null,
      );
    }
    if (args.containsKey('due_date')) {
      final d = args['due_date'];
      due = Value(
        d is String && d.trim().isNotEmpty ? DateTime.tryParse(d.trim()) : null,
      );
    }
    if (start == null && due == null) {
      return 'set_task_dates: nothing to change (provide start_date and/or due_date).';
    }
    // Enforce start <= due against the EFFECTIVE dates (the patch merged over
    // whatever the task already has), so the AI can't set an invalid range.
    final effStart = start != null ? start.value : task.startDate;
    final effDue = due != null ? due.value : task.dueDate;
    if (effStart != null && effDue != null && effStart.isAfter(effDue)) {
      return 'set_task_dates failed: start date (${effStart.toIso8601String().substring(0, 10)}) '
          'cannot be after the due date (${effDue.toIso8601String().substring(0, 10)}).';
    }
    await db.setTaskDates(taskId, start: start, due: due);
    final parts = <String>[];
    if (start != null)
      parts.add(
        'start=${(args['start_date'] as String?)?.isEmpty ?? true ? 'cleared' : args['start_date']}',
      );
    if (due != null)
      parts.add(
        'due=${(args['due_date'] as String?)?.isEmpty ?? true ? 'cleared' : args['due_date']}',
      );
    return 'Updated dates for "${task.title}" (${parts.join(', ')}).';
  }

  Future<String> _setTaskBuildConfig(Map<String, dynamic> args) async {
    final taskId = _asInt(args['task_id']);
    if (taskId == null)
      return 'set_task_build_config failed: task_id is required.';
    final task = await db.getTaskById(taskId);
    if (task == null) return 'Task $taskId not found.';

    Value<bool>? requiresBuild;
    Value<String?>? dockerfilePath;
    Value<String?>? workflowPath;
    Value<String?>? imageTag;

    if (args.containsKey('requires_build')) {
      final v = args['requires_build'];
      requiresBuild = Value(v == true || v == 'true');
    }
    String? clearable(dynamic v) =>
        (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    if (args.containsKey('dockerfile_path')) {
      dockerfilePath = Value(clearable(args['dockerfile_path']));
    }
    if (args.containsKey('workflow_path')) {
      workflowPath = Value(clearable(args['workflow_path']));
    }
    if (args.containsKey('image_tag')) {
      imageTag = Value(clearable(args['image_tag']));
    }
    if (requiresBuild == null &&
        dockerfilePath == null &&
        workflowPath == null &&
        imageTag == null) {
      return 'set_task_build_config: nothing to change (provide requires_build, dockerfile_path, workflow_path, and/or image_tag).';
    }
    await db.setTaskBuildConfig(
      taskId,
      requiresBuild: requiresBuild,
      dockerfilePath: dockerfilePath,
      workflowPath: workflowPath,
      imageTag: imageTag,
    );
    final parts = <String>[];
    if (requiresBuild != null)
      parts.add('requires_build=${requiresBuild.value}');
    if (dockerfilePath != null)
      parts.add('dockerfile=${dockerfilePath.value ?? 'cleared'}');
    if (workflowPath != null)
      parts.add('workflow=${workflowPath.value ?? 'cleared'}');
    if (imageTag != null) parts.add('image_tag=${imageTag.value ?? 'cleared'}');
    return 'Updated build config for "${task.title}" (${parts.join(', ')}).';
  }

  Future<String> _viewPlan() async {
    if (openPlanPath == null) return 'No plan is currently open.';
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    try {
      final content = await planStore!.read(openPlanPath!);
      return 'Plan "${_basename(openPlanPath!)}" contents:\n"""\n$content\n"""';
    } catch (e) {
      return 'Could not read the open plan: $e';
    }
  }

  Future<String> _updatePlan(Map<String, dynamic> args) async {
    if (openPlanPath == null) return 'No plan is currently open to update.';
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final content = args['content'] as String?;
    if (content == null) return 'update_plan failed: content is required.';
    await planStore!.write(openPlanPath!, content);
    final synced = await _autoSyncAfterPlanWrite();
    return 'Updated the plan "${_basename(openPlanPath!)}". The new version is saved.$synced';
  }

  String _proposePlanAdjustment(Map<String, dynamic> args) {
    final summary = args['summary'] as String? ?? 'Plan adjustment proposed';
    final details = args['details'] as String? ?? '';
    // In a future version this would persist to a Plans table or project metadata.
    // For now we just confirm so the LLM can tell the user.
    return 'Plan adjustment recorded in conversation: $summary. ${details.isNotEmpty ? 'Details: $details. ' : ''}User can review and we can turn this into concrete tasks.';
  }

  // ── Full SCRUD helpers ──────────────────────────────────────────────

  Future<String> _listTasks(Map<String, dynamic> args) async {
    final filter = (args['status'] as String?)?.trim().toLowerCase();
    var rows = await db.getTasksForProject(projectId);
    if (filter != null && filter.isNotEmpty) {
      rows = rows.where((t) => t.status.toLowerCase() == filter).toList();
    }
    if (rows.isEmpty) {
      return 'No tasks${filter != null && filter.isNotEmpty ? ' with status "$filter"' : ''} in this project.';
    }
    final b = StringBuffer('Tasks (${rows.length}):\n');
    for (final t in rows) {
      final parent = t.task_parent_fk != null
          ? ' subtask-of=${t.task_parent_fk}'
          : '';
      final plan = t.task_plan_path != null ? ' plan=${t.task_plan_path}' : '';
      final agent = t.task_agent_fk != null ? ' agent=${t.task_agent_fk}' : '';
      b.writeln(
        '- id=${t.task_pk} "${t.title}" [${t.priority}] ${t.status}$parent$plan$agent',
      );
    }
    return b.toString().trim();
  }

  Future<String> _getTask(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'get_task failed: task_id required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    final all = await db.getTasksForProject(projectId);
    final subs = all.where((x) => x.task_parent_fk == id).toList();
    final b = StringBuffer();
    b.writeln('Task id=${t.task_pk}: "${t.title}"');
    b.writeln('Status: ${t.status} | Priority: ${t.priority}');
    if ((t.description ?? '').isNotEmpty)
      b.writeln('Description: ${t.description}');
    if (t.startDate != null)
      b.writeln('Start: ${t.startDate!.toIso8601String().substring(0, 10)}');
    if (t.dueDate != null)
      b.writeln('Due: ${t.dueDate!.toIso8601String().substring(0, 10)}');
    if (t.task_parent_fk != null) b.writeln('Parent task: ${t.task_parent_fk}');
    if (t.task_plan_path != null) b.writeln('From plan: ${t.task_plan_path}');
    if (t.task_agent_fk != null)
      b.writeln('Assigned agent: ${t.task_agent_fk}');
    if (subs.isNotEmpty) {
      b.writeln(
        'Subtasks: ${subs.map((s) => '${s.task_pk} "${s.title}" (${s.status})').join(', ')}',
      );
    }
    return b.toString().trim();
  }

  Future<String> _deleteTask(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'delete_task failed: task_id required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    final all = await db.getTasksForProject(projectId);
    final subs = all.where((x) => x.task_parent_fk == id).toList();
    for (final s in subs) {
      await db.deleteTask(s.task_pk);
    }
    await db.deleteTask(id);
    return 'Deleted task "${t.title}" (id: $id)${subs.isNotEmpty ? ' and ${subs.length} subtask(s)' : ''}.';
  }

  Future<String> _linkTaskToPlan(Map<String, dynamic> args) async {
    final taskId = _asInt(args['task_id']);
    if (taskId == null) return 'link_task_to_plan failed: task_id required.';
    final t = await db.getTaskById(taskId);
    if (t == null) return 'Task $taskId not found.';
    final raw = args['plan_path'];
    final planPath = (raw is String && raw.trim().isNotEmpty)
        ? raw.trim()
        : null;
    if (planPath != null) {
      if (planStore != null) {
        try {
          if (await planStore!.isFolder(planPath)) {
            return 'Item "$planPath" is a folder, not a plan document.';
          }
        } catch (e) {
          return 'Plan "$planPath" not found.';
        }
      }
      await db.patchTask(
        taskId,
        TasksCompanion(task_plan_path: Value(planPath)),
      );
      return 'Linked task "${t.title}" to plan "${_basename(planPath)}".';
    }
    await db.patchTask(
      taskId,
      const TasksCompanion(task_plan_path: Value(null)),
    );
    return 'Unlinked task "${t.title}" from any plan.';
  }

  Future<String> _listAgents() async {
    final agents = await db.getAgentPersonasForProject(projectId);
    if (agents.isEmpty)
      return 'No agent personas exist yet. Create one in the Agents hub.';
    final b = StringBuffer('Available agents (${agents.length}):\n');
    for (final a in agents) {
      final role = (a.title ?? '').isNotEmpty ? ' — ${a.title}' : '';
      final desc = (a.description ?? '').isNotEmpty
          ? ' (${a.description})'
          : '';
      b.writeln('- id=${a.agent_pk} "${a.name}"$role$desc');
    }
    b.writeln('Use the id with assign_agent_to_task.');
    return b.toString().trim();
  }

  Future<String> _listPlans() async {
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final plans = await planStore!.list();
    if (plans.isEmpty) return 'No plans or folders in this project yet.';
    final b = StringBuffer('Plans (${plans.length}):\n');
    for (final p in plans) {
      final kind = p.isFolder ? 'folder' : 'plan';
      b.writeln('- [$kind] "${p.name}" path=${p.path}');
    }
    return b.toString().trim();
  }

  Future<String> _createPlan(Map<String, dynamic> args) async {
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return 'create_plan failed: name is required.';
    final isFolder = args['is_folder'] == true;
    final parentRaw = args['parent_path'];
    final parent = (parentRaw is String && parentRaw.trim().isNotEmpty)
        ? parentRaw.trim()
        : null;
    final content = args['content'] as String? ?? '';
    final path = await planStore!.create(
      parent: parent,
      name: name,
      isFolder: isFolder,
      content: content,
    );
    final synced = isFolder ? '' : await _autoSyncAfterPlanWrite();
    return 'Created ${isFolder ? 'folder' : 'plan'} "$name" (path: $path).$synced';
  }

  Future<String> _readPlan(Map<String, dynamic> args) async {
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final path = (args['plan_path'] as String? ?? '').trim();
    if (path.isEmpty) return 'read_plan failed: plan_path required.';
    try {
      if (await planStore!.isFolder(path)) {
        return 'Item "$path" is a folder, not a plan document.';
      }
      final content = await planStore!.read(path);
      return 'Plan "${_basename(path)}" (path: $path) contents:\n"""\n$content\n"""';
    } catch (e) {
      return 'Plan "$path" not found.';
    }
  }

  Future<String> _writePlan(Map<String, dynamic> args) async {
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final path = (args['plan_path'] as String? ?? '').trim();
    final content = args['content'] as String?;
    if (path.isEmpty || content == null)
      return 'write_plan failed: plan_path and content required.';
    await planStore!.write(path, content);
    final synced = await _autoSyncAfterPlanWrite();
    return 'Updated plan "${_basename(path)}" (path: $path). The new version is saved.$synced';
  }

  Future<String> _renamePlan(Map<String, dynamic> args) async {
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final path = (args['plan_path'] as String? ?? '').trim();
    final name = (args['name'] as String? ?? '').trim();
    if (path.isEmpty || name.isEmpty)
      return 'rename_plan failed: plan_path and name required.';
    final newPath = await planStore!.rename(path, name);
    return 'Renamed "${_basename(path)}" to "$name" (path: $newPath).';
  }

  Future<String> _deletePlan(Map<String, dynamic> args) async {
    if (planStore == null)
      return 'Plan storage is unavailable in this context.';
    final path = (args['plan_path'] as String? ?? '').trim();
    if (path.isEmpty) return 'delete_plan failed: plan_path required.';
    await planStore!.delete(path);
    return 'Deleted "${_basename(path)}" (path: $path).';
  }

  // ── Files ───────────────────────────────────────────────────────────

  Future<String> _listFiles(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String?)?.trim();
    final dir = (path == null || path.isEmpty) ? '/' : path;
    try {
      final entries = await workspace!.list(dir);
      if (entries.isEmpty) return 'Directory "$dir" is empty.';
      final b = StringBuffer('Contents of "$dir" (${entries.length}):\n');
      for (final e in entries) {
        b.writeln(
          e.isDirectory ? '- ${e.name}/' : '- ${e.name} (${e.size} bytes)',
        );
      }
      return b.toString().trim();
    } catch (e) {
      return 'list_files failed for "$dir": $e';
    }
  }

  Future<String> _readFile(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    if (path.isEmpty) return 'read_file failed: path is required.';
    try {
      if (await workspace!.isProbablyBinary(path)) {
        return 'File "$path" looks binary; not reading as text.';
      }
      final content = await workspace!.readString(path);
      return 'File "$path" contents:\n"""\n$content\n"""';
    } catch (e) {
      return 'read_file failed for "$path": $e';
    }
  }

  Future<String> _writeFile(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    final content = args['content'] as String?;
    if (path.isEmpty || content == null)
      return 'write_file failed: path and content are required.';
    try {
      final existed = await workspace!.exists(path);
      await workspace!.writeString(path, content);
      return '${existed ? 'Updated' : 'Created'} file "$path" (${content.length} chars).';
    } catch (e) {
      return 'write_file failed for "$path": $e';
    }
  }

  Future<String> _createDirectory(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    if (path.isEmpty) return 'create_directory failed: path is required.';
    try {
      await workspace!.createDirectory(path);
      return 'Created directory "$path".';
    } catch (e) {
      return 'create_directory failed for "$path": $e';
    }
  }

  Future<String> _movePath(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final from = (args['from'] as String? ?? '').trim();
    final to = (args['to'] as String? ?? '').trim();
    if (from.isEmpty || to.isEmpty)
      return 'move_path failed: from and to are required.';
    try {
      await workspace!.move(from, to);
      return 'Moved "$from" → "$to".';
    } catch (e) {
      return 'move_path failed: $e';
    }
  }

  Future<String> _deletePath(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    if (path.isEmpty) return 'delete_path failed: path is required.';
    try {
      if (!await workspace!.exists(path))
        return 'Nothing to delete at "$path".';
      await workspace!.delete(path);
      return 'Deleted "$path".';
    } catch (e) {
      return 'delete_path failed for "$path": $e';
    }
  }

  Future<String> _deleteFile(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    if (path.isEmpty) return 'delete_file failed: path is required.';
    try {
      if (!await workspace!.exists(path))
        return 'Nothing to delete at "$path".';
      final entry = await workspace!.stat(path);
      if (entry.isDirectory) {
        return 'delete_file failed: "$path" is a folder. Use delete_folder instead.';
      }
      await workspace!.delete(path, recursive: false);
      return 'Deleted file "$path".';
    } catch (e) {
      return 'delete_file failed for "$path": $e';
    }
  }

  Future<String> _deleteFolder(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    if (path.isEmpty) return 'delete_folder failed: path is required.';
    try {
      if (!await workspace!.exists(path))
        return 'Nothing to delete at "$path".';
      final entry = await workspace!.stat(path);
      if (!entry.isDirectory) {
        return 'delete_folder failed: "$path" is a file. Use delete_file instead.';
      }
      await workspace!.delete(path, recursive: true);
      return 'Deleted folder "$path" and its contents.';
    } catch (e) {
      return 'delete_folder failed for "$path": $e';
    }
  }

  Future<String> _listDirectory(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String?)?.trim();
    final dir = (path == null || path.isEmpty) ? '/' : path;
    try {
      final entries = await workspace!.list(dir);
      if (entries.isEmpty) return 'Directory "$dir" is empty.';
      final b = StringBuffer('Contents of "$dir":\n');
      for (final e in entries) {
        b.writeln(e.isDirectory ? '[DIR] ${e.name}' : '[FILE] ${e.name}');
      }
      return b.toString().trim();
    } catch (e) {
      return 'list_directory failed for "$dir": $e';
    }
  }

  Future<String> _searchDirectory(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final query = (args['query'] as String? ?? '').trim();
    if (query.isEmpty) return 'search_directory failed: query is required.';
    final path = (args['path'] as String?)?.trim();
    final root = (path == null || path.isEmpty) ? '/' : path;
    final maxResults = _asInt(args['max_results']) ?? 100;
    try {
      final entries = await workspace!.walk(from: root);
      final matches = <String>[];
      for (final e in entries) {
        if (e.isDirectory) continue;
        if (await workspace!.isProbablyBinary(e.path)) continue;
        String content;
        try {
          content = await workspace!.readString(e.path);
        } catch (_) {
          continue;
        }
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(query)) {
            matches.add('${e.path} - Line ${i + 1}: ${lines[i].trim()}');
            if (matches.length >= maxResults) break;
          }
        }
        if (matches.length >= maxResults) break;
      }
      if (matches.isEmpty) return 'No matches for "$query" under "$root".';
      return 'Matches for "$query" (${matches.length}):\n${matches.join('\n')}';
    } catch (e) {
      return 'search_directory failed: $e';
    }
  }

  Future<String> _searchFileContent(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    final query = (args['query'] as String? ?? '').trim();
    if (path.isEmpty || query.isEmpty) {
      return 'search_file_content failed: path and query are required.';
    }
    try {
      if (await workspace!.isProbablyBinary(path)) {
        return 'File "$path" looks binary; cannot search as text.';
      }
      final content = await workspace!.readString(path);
      final lines = content.split('\n');
      final matches = <String>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(query)) {
          matches.add('Line ${i + 1}: ${lines[i]}');
        }
      }
      if (matches.isEmpty) return 'No matches for "$query" in "$path".';
      return 'Matches for "$query" in "$path" (${matches.length}):\n${matches.join('\n')}';
    } catch (e) {
      return 'search_file_content failed for "$path": $e';
    }
  }

  Future<String> _readFileChunk(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    if (path.isEmpty) return 'read_file_chunk failed: path is required.';
    final startLine = _asInt(args['start_line']) ?? 1;
    final endLineArg = _asInt(args['end_line']);
    try {
      if (await workspace!.isProbablyBinary(path)) {
        return 'File "$path" looks binary; not reading as text.';
      }
      final content = await workspace!.readString(path);
      final lines = content.split('\n');
      final total = lines.length;
      final start = startLine < 1 ? 1 : startLine;
      if (start > total) {
        return 'read_file_chunk: start_line $start is past end of "$path" ($total lines).';
      }
      var end = endLineArg ?? (start + 199);
      if (end < start) end = start;
      if (end - start + 1 > 200) end = start + 199;
      if (end > total) end = total;
      final b = StringBuffer('"$path" lines $start-$end of $total:\n');
      for (var i = start; i <= end; i++) {
        b.writeln('$i: ${lines[i - 1]}');
      }
      return b.toString().trimRight();
    } catch (e) {
      return 'read_file_chunk failed for "$path": $e';
    }
  }

  Future<String> _createFile(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    final content = args['content'] as String? ?? '';
    if (path.isEmpty) return 'create_file failed: path is required.';
    try {
      if (await workspace!.exists(path)) {
        return 'create_file failed: "$path" already exists. Use edit_file or write_file to modify it.';
      }
      await workspace!.writeString(path, content);
      return 'Created file "$path" (${content.length} chars).';
    } catch (e) {
      return 'create_file failed for "$path": $e';
    }
  }

  Future<String> _editFile(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final path = (args['path'] as String? ?? '').trim();
    final oldText = args['old_text'] as String?;
    final newText = args['new_text'] as String?;
    if (path.isEmpty || oldText == null || newText == null) {
      return 'edit_file failed: path, old_text and new_text are required.';
    }
    try {
      if (!await workspace!.exists(path)) {
        return 'edit_file failed: "$path" does not exist. Use create_file first.';
      }
      final content = await workspace!.readString(path);
      if (!content.contains(oldText)) {
        return 'edit_file aborted: old_text was not found in "$path". No changes made.';
      }
      final updated = content.replaceFirst(oldText, newText);
      await workspace!.writeString(path, updated);
      return 'Edited "$path" (replaced first occurrence of old_text).';
    } catch (e) {
      return 'edit_file failed for "$path": $e';
    }
  }

  // ── Git ─────────────────────────────────────────────────────────────

  Future<String> _gitStatus() async {
    if (git == null) return 'Git is unavailable in this context.';
    if (_isolatedTask) {
      // The shared git status reflects the project tree, not this task's
      // isolated tree — report the task context instead so the worker commits.
      final files = await workspace!.walk();
      final n = files.where((e) => !e.isDirectory).length;
      return 'On task branch "$workBranch" with $n file(s) in your working '
          'tree. Edits are uncommitted until you call git_commit.';
    }
    try {
      final snap = await git!.status();
      if (!snap.hasRepo) return 'This workspace has no git repository yet.';
      final b = StringBuffer('Branch: ${snap.branch ?? '(unborn)'}\n');
      if (snap.isClean || snap.byPath.isEmpty) {
        b.writeln('Working tree is clean.');
      } else {
        b.writeln('Changes (${snap.byPath.length}):');
        for (final e in snap.byPath.entries) {
          b.writeln('- ${e.value.name}: ${e.key}');
        }
      }
      return b.toString().trim();
    } catch (e) {
      return 'git_status failed: $e';
    }
  }

  Future<String> _gitLog(Map<String, dynamic> args) async {
    if (git == null) return 'Git is unavailable in this context.';
    final limit = _asInt(args['limit']) ?? 20;
    try {
      final commits = await git!.log(limit: limit);
      if (commits.isEmpty) return 'No commits yet.';
      final b = StringBuffer('Recent commits (${commits.length}):\n');
      for (final c in commits) {
        final shortOid = c.oid.length >= 8 ? c.oid.substring(0, 8) : c.oid;
        final firstLine = c.message.split('\n').first;
        b.writeln('- $shortOid  $firstLine  (${c.author})');
      }
      return b.toString().trim();
    } catch (e) {
      return 'git_log failed: $e';
    }
  }

  Future<String> _gitCommit(Map<String, dynamic> args) async {
    if (git == null) return 'Git is unavailable in this context.';
    final message = (args['message'] as String? ?? '').trim();
    if (message.isEmpty) return 'git_commit failed: message is required.';
    // Orchestrated worker: snapshot the ISOLATED task tree onto its branch in
    // the shared object DB, serialized so concurrent agents never interleave.
    if (_isolatedTask) {
      try {
        final oid = await gitLane!.run(
          () => git!.commitFrom(
            workspace!,
            branch: workBranch!,
            message: message,
            authorName: agentName,
          ),
        );
        final shortOid = oid.length >= 8 ? oid.substring(0, 8) : oid;
        return 'Committed your working tree to "$workBranch" as $shortOid: "$message".';
      } catch (e) {
        return 'git_commit failed: $e';
      }
    }
    final rawPaths = args['paths'];
    final paths = (rawPaths is List)
        ? rawPaths.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    try {
      final oid = await _withGitLane(
        () => paths.isEmpty
            ? git!.commitAll(message: message, authorName: agentName)
            : git!.commitFiles(
                paths: paths,
                message: message,
                authorName: agentName,
              ),
      );
      final shortOid = oid.length >= 8 ? oid.substring(0, 8) : oid;
      return 'Committed ${paths.isEmpty ? 'all changes' : '${paths.length} path(s)'} as $shortOid: "$message".';
    } catch (e) {
      return 'git_commit failed: $e';
    }
  }

  Future<String> _gitBranches() async {
    if (git == null) return 'Git is unavailable in this context.';
    try {
      final branches = await git!.branches();
      final current = await git!.currentBranch();
      if (branches.isEmpty) return 'No branches yet (commit something first).';
      final b = StringBuffer('Branches (${branches.length}):\n');
      for (final name in branches) {
        b.writeln('${name == current ? '* ' : '  '}$name');
      }
      return b.toString().trim();
    } catch (e) {
      return 'git_branches failed: $e';
    }
  }

  Future<String> _gitCreateBranch(Map<String, dynamic> args) async {
    if (git == null) return 'Git is unavailable in this context.';
    if (_isolatedTask) {
      return 'Branching is managed for you — stay on your task branch '
          '"$workBranch", edit files, and git_commit.';
    }
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return 'git_create_branch failed: name is required.';
    final checkout = args['checkout'] == true;
    try {
      await _withGitLane(() => git!.createBranch(name, checkout: checkout));
      return 'Created branch "$name"${checkout ? ' and switched to it' : ''}.';
    } catch (e) {
      return 'git_create_branch failed: $e';
    }
  }

  Future<String> _gitCheckoutBranch(Map<String, dynamic> args) async {
    if (git == null) return 'Git is unavailable in this context.';
    if (_isolatedTask) {
      return 'You are pinned to your task branch "$workBranch" — branch '
          'switching is managed for you. Just edit files and git_commit.';
    }
    final name = (args['name'] as String? ?? '').trim();
    if (name.isEmpty) return 'git_checkout_branch failed: name is required.';
    try {
      await _withGitLane(() => git!.checkoutBranch(name));
      return 'Switched workspace to branch "$name".';
    } catch (e) {
      return 'git_checkout_branch failed: $e';
    }
  }

  Future<String> _gitPush(Map<String, dynamic> args) async {
    return 'git_push is not yet supported: this workspace uses a local-only '
        'repository inside the project virtual disk, with no remote configured.';
  }

  Future<String> _gitPull(Map<String, dynamic> args) async {
    return 'git_pull is not yet supported: this workspace uses a local-only '
        'repository inside the project virtual disk, with no remote configured.';
  }

  Future<String> _gitMerge(Map<String, dynamic> args) async {
    if (git == null) return 'Git is unavailable in this context.';
    final branch = (args['branch'] as String? ?? '').trim();
    if (branch.isEmpty) return 'git_merge failed: branch is required.';
    final message = (args['message'] as String?)?.trim();
    try {
      final current = await git!.currentBranch();
      final result = await _withGitLane(
        () => git!.merge(
          branch,
          authorName: agentName,
          message: (message == null || message.isEmpty) ? null : message,
        ),
      );
      final into = current ?? 'the current branch';
      switch (result.outcome) {
        case MergeOutcome.upToDate:
          return 'Already up to date: "$into" already contains "$branch". Nothing to merge.';
        case MergeOutcome.fastForward:
          final short = (result.oid ?? '').isNotEmpty && result.oid!.length >= 8
              ? result.oid!.substring(0, 8)
              : result.oid ?? '';
          return 'Fast-forwarded "$into" to "$branch" ($short). Workspace updated to match.';
        case MergeOutcome.merged:
          final short = (result.oid ?? '').isNotEmpty && result.oid!.length >= 8
              ? result.oid!.substring(0, 8)
              : result.oid ?? '';
          return 'Merged "$branch" into "$into" as merge commit $short. Workspace updated.';
        case MergeOutcome.conflicts:
          final list = result.conflicts.map((p) => '- $p').join('\n');
          return 'Merge conflict: "$branch" and "$into" changed the same file(s). '
              'No commit was made and nothing moved. Send the task back to be '
              'rebased/resolved rather than editing it here.\nConflicting paths:\n$list';
      }
    } catch (e) {
      return 'git_merge failed: $e';
    }
  }

  // ── Orchestration ─────────────────────────────────────────────────────

  Future<String> _submitForCompletion(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'submit_for_completion failed: task_id is required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    final summary = (args['summary'] as String? ?? '').trim();
    if (summary.isEmpty)
      return 'submit_for_completion failed: summary is required.';
    final submission = <String, dynamic>{
      'summary': summary,
      'evidence': (args['evidence'] as String? ?? '').trim(),
      'branch': (args['branch'] as String? ?? t.workBranch ?? '').trim(),
      'submittedBy': agentName,
      'submittedAt': DateTime.now().toIso8601String(),
    };
    await db.submitTaskForCompletion(
      id,
      submissionJson: jsonEncode(submission),
    );
    return 'Submitted task "${t.title}" (id: $id) for completion. It is now in Review awaiting verification.';
  }

  Future<String> _runVerification(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'run_verification failed: task_id is required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    await db.markTaskVerifying(id);
    final b = StringBuffer('Verifying task "${t.title}" (id: $id).\n');
    b.writeln(
      'Acceptance criteria: ${(t.acceptanceCriteria ?? '').isEmpty ? '(none specified)' : t.acceptanceCriteria}',
    );
    b.writeln(
      'Verification to run: ${(t.verification ?? '').isEmpty ? '(none specified — judge against the acceptance criteria)' : t.verification}',
    );
    if ((t.submissionJson ?? '').isNotEmpty) {
      b.writeln('Worker submission: ${t.submissionJson}');
    }
    b.writeln(
      'Run the verification with your read/run tools, then call submit_verdict.',
    );
    return b.toString().trim();
  }

  Future<String> _submitVerdict(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'submit_verdict failed: task_id is required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    final verdict = (args['verdict'] as String? ?? '').trim().toLowerCase();
    if (verdict != 'pass' && verdict != 'fail') {
      return 'submit_verdict failed: verdict must be "pass" or "fail".';
    }
    final passed = verdict == 'pass';
    await db.recordTaskVerdict(id, passed: passed);
    final evidence = (args['evidence'] as String? ?? '').trim();
    if (passed) {
      return 'Verdict PASS recorded for "${t.title}" (id: $id). It awaits Coordinator integration (merge → approve).${evidence.isNotEmpty ? ' Evidence: $evidence' : ''}';
    }
    return 'Verdict FAIL recorded for "${t.title}" (id: $id). It has been sent back to the board for the same agent to re-engage.${evidence.isNotEmpty ? ' Evidence: $evidence' : ''}';
  }

  Future<String> _reviewSubmission(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'review_submission failed: task_id is required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    final b = StringBuffer('Submission review for "${t.title}" (id: $id):\n');
    b.writeln('Status: ${t.status} | Execution: ${t.executionStatus}');
    if ((t.workBranch ?? '').isNotEmpty) b.writeln('Branch: ${t.workBranch}');
    if ((t.acceptanceCriteria ?? '').isNotEmpty)
      b.writeln('Acceptance criteria: ${t.acceptanceCriteria}');
    if ((t.verification ?? '').isNotEmpty)
      b.writeln('Verification: ${t.verification}');
    if ((t.submissionJson ?? '').isEmpty) {
      b.writeln('No submission recorded yet.');
    } else {
      try {
        final s = jsonDecode(t.submissionJson!) as Map<String, dynamic>;
        b.writeln('Summary: ${s['summary'] ?? ''}');
        if ('${s['evidence'] ?? ''}'.isNotEmpty)
          b.writeln('Evidence: ${s['evidence']}');
        if ('${s['submittedBy'] ?? ''}'.isNotEmpty)
          b.writeln(
            'Submitted by: ${s['submittedBy']} at ${s['submittedAt'] ?? ''}',
          );
      } catch (_) {
        b.writeln('Submission: ${t.submissionJson}');
      }
    }
    return b.toString().trim();
  }

  Future<String> _approveTask(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'approve_task failed: task_id is required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    await db.approveTask(id);
    return 'Approved "${t.title}" (id: $id) — marked Done and the worker session is released. Make sure its branch was merged into its target branch first (the parent task\'s branch for a subtask, otherwise main).';
  }

  Future<String> _rejectTask(Map<String, dynamic> args) async {
    final id = _asInt(args['task_id']);
    if (id == null) return 'reject_task failed: task_id is required.';
    final t = await db.getTaskById(id);
    if (t == null) return 'Task $id not found.';
    final reason = (args['reason'] as String? ?? '').trim();
    if (reason.isNotEmpty) {
      final note =
          '${t.description ?? ''}\n\n[Sent back ${DateTime.now().toIso8601String().substring(0, 16)} by $agentName]: $reason'
              .trim();
      await db.patchTask(id, TasksCompanion(description: Value(note)));
    }
    await db.reopenTask(id);
    return 'Sent "${t.title}" (id: $id) back to the board (Todo).${reason.isNotEmpty ? ' Reason recorded.' : ''}';
  }

  // ── Build / CI ──────────────────────────────────────────────────────

  Future<int?> _clientPk() async =>
      (await db.getProjectById(projectId))?.client_fk;

  Future<String> _buildDockerImage(Map<String, dynamic> args) async {
    if (buildService == null || workspace == null) {
      return 'Builds are unavailable in this context.';
    }
    final dockerfile = (args['dockerfile_path'] as String? ?? '').trim();
    final imageTag = (args['image_tag'] as String? ?? '').trim();
    if (dockerfile.isEmpty || imageTag.isEmpty) {
      return 'build_docker_image failed: dockerfile_path and image_tag are required.';
    }
    final context = (args['context'] as String?)?.trim();
    final taskPk = _asInt(args['task_id']);
    final clientPk = await _clientPk();
    if (clientPk == null)
      return 'build_docker_image failed: project not found.';

    final unavailable = await buildService!.backendUnavailableReason(
      _localDockerKind,
    );
    if (unavailable != null) return 'Cannot start build: $unavailable';

    if (!await workspace!.exists(dockerfile)) {
      return 'build_docker_image failed: no file at "$dockerfile".';
    }
    final dfRel = dockerfile.startsWith('/')
        ? dockerfile.substring(1)
        : dockerfile;
    final started = await buildService!.startDockerBuild(
      clientPk: clientPk,
      projectPk: projectId,
      ws: workspace!,
      dockerfilePath: dfRel,
      imageTag: imageTag,
      buildContext: (context == null || context.isEmpty) ? '.' : context,
      triggeredBy: agentName,
      taskPk: taskPk,
    );
    final gate = taskPk != null
        ? ' Task $taskPk will auto-complete on success (or return to the board on failure).'
        : '';
    return 'Started Docker build of "$imageTag" (run id: ${started.runPk}). It runs in the background — call get_ci_run with run_id ${started.runPk} to see progress and logs.$gate';
  }

  Future<String> _runWorkflow(Map<String, dynamic> args) async {
    if (buildService == null || workspace == null) {
      return 'CI runs are unavailable in this context.';
    }
    final workflowPath = (args['workflow_path'] as String? ?? '').trim();
    if (workflowPath.isEmpty)
      return 'run_workflow failed: workflow_path is required.';
    final taskPk = _asInt(args['task_id']);
    final clientPk = await _clientPk();
    if (clientPk == null) return 'run_workflow failed: project not found.';
    if (!await workspace!.exists(workflowPath)) {
      return 'run_workflow failed: no workflow file at "$workflowPath".';
    }
    try {
      final started = await buildService!.startWorkflowRun(
        clientPk: clientPk,
        projectPk: projectId,
        ws: workspace!,
        workflowPath: workflowPath,
        triggeredBy: agentName,
        taskPk: taskPk,
      );
      final gate = taskPk != null
          ? ' Task $taskPk will auto-complete on success (or return to the board on failure).'
          : '';
      return 'Started workflow run from "$workflowPath" (run id: ${started.runPk}). Call get_ci_run with run_id ${started.runPk} to follow its jobs, steps, and logs.$gate';
    } catch (e) {
      return 'run_workflow failed: $e';
    }
  }

  Future<String> _scaffoldCiWorkflow(Map<String, dynamic> args) async {
    if (workspace == null) return 'File access is unavailable in this context.';
    final kind = (args['kind'] as String? ?? 'flutter').trim().toLowerCase();
    final path = (args['path'] as String? ?? '/.github/workflows/ci.yml')
        .trim();
    final yaml = _ciWorkflowTemplate(kind);
    try {
      final existed = await workspace!.exists(path);
      await workspace!.writeString(path, yaml);
      return '${existed ? 'Updated' : 'Created'} a "$kind" CI workflow at "$path". '
          'Run it with run_workflow (optionally pass task_id to gate a task on it).';
    } catch (e) {
      return 'scaffold_ci_workflow failed for "$path": $e';
    }
  }

  /// Default GitHub-Actions-format workflow body for [kind]. The local workflow
  /// runner executes `run:` steps; `uses:` steps are recorded but skipped.
  static String _ciWorkflowTemplate(String kind) {
    switch (kind) {
      case 'dart':
        return '''name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: dart pub get
      - run: dart analyze
      - run: dart test
''';
      case 'node':
        return '''name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: npm ci
      - run: npm run build --if-present
      - run: npm test
''';
      case 'generic':
        return '''name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Add your build commands here"
      - run: echo "Add your test commands here"
''';
      case 'flutter':
      default:
        return '''name: CI
on: [push, pull_request]
jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
''';
    }
  }

  Future<String> _listCiRuns() async {
    final clientPk = await _clientPk();
    if (clientPk == null) return 'Project not found.';
    final runs = (await db.getCiRunsForClient(
      clientPk,
    )).where((r) => r.project_fk == projectId).toList();
    if (runs.isEmpty) return 'No build / CI runs for this project yet.';
    final b = StringBuffer('Build / CI runs (${runs.length}):\n');
    for (final r in runs) {
      b.writeln('- id=${r.ci_run_pk} "${r.name}" [${r.kind}] ${r.status}');
    }
    return b.toString().trim();
  }

  Future<String> _getCiRun(Map<String, dynamic> args) async {
    final runPk = _asInt(args['run_id']);
    if (runPk == null) return 'get_ci_run failed: run_id is required.';
    final tail = _asInt(args['tail']) ?? 200;
    final run = await db.getCiRun(runPk);
    if (run == null) return 'Run $runPk not found.';
    if (run.project_fk != projectId)
      return 'Run $runPk does not belong to this project.';

    final b = StringBuffer();
    b.writeln(
      'Run id=${run.ci_run_pk} "${run.name}" [${run.kind}] — ${run.status}',
    );
    if ((run.errorText ?? '').isNotEmpty) b.writeln('Error: ${run.errorText}');
    final jobs = await db.getCiJobsForRun(runPk);
    for (final job in jobs) {
      b.writeln(
        'Job "${job.name}" — ${job.status}${job.runsOn != null ? ' (runs-on: ${job.runsOn})' : ''}',
      );
      final steps = await db.getCiStepsForJob(job.ci_job_pk);
      for (final step in steps) {
        final code = step.exitCode != null ? ' exit=${step.exitCode}' : '';
        b.writeln('  • ${step.name} — ${step.status}$code');
        final log = step.logText.trim();
        if (log.isNotEmpty) {
          final lines = log.split('\n');
          final shown = lines.length > tail
              ? lines.sublist(lines.length - tail)
              : lines;
          b.writeln(
            '    log${lines.length > tail ? ' (last $tail of ${lines.length} lines)' : ''}:',
          );
          for (final l in shown) {
            b.writeln('    | $l');
          }
        }
      }
    }
    return b.toString().trim();
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }
}

/// Local-docker backend kind, referenced without importing the build models enum
/// directly into the tool layer.
const _localDockerKind = CiBackendKind.localDocker;
