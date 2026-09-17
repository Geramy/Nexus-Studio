// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:nexus_projects_client/features/docker/run_container_dialog.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show NexusDatabase, CiRun, CiJob, CiStep;

/// Shared run → job → step drill-down used by both the per-project Builds & CI
/// tab and the client-scoped Builds center. Read-only; follows the live Drift
/// streams. Render a [CiRunCard] per run, or a [CiRunsEmptyState] when empty.

class CiRunCard extends StatelessWidget {
  final NexusDatabase db;
  final CiRun run;
  const CiRunCard({super.key, required this.db, required this.run});

  @override
  Widget build(BuildContext context) {
    final runLabel = switch (run.triggeredBy?.toLowerCase()) {
      'templater' => 'Scaffold validation',
      'testing' => 'Final project tests',
      'editor' => 'Edit validation',
      _ => run.name,
    };
    final subtitleParts = <String>[
      run.kind,
      run.backend,
      if (run.branch != null && run.branch!.isNotEmpty) run.branch!,
      if (run.triggeredBy != null && run.triggeredBy!.isNotEmpty)
        'triggered by ${run.triggeredBy}',
      _relativeTime(run.createdAt),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Row(
          children: [
            Expanded(
              child: Text(
                runLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: run.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitleParts.join(' • '),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          if (run.errorText != null && run.errorText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                run.errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (run.kind == 'dockerBuild' &&
              run.status == 'success' &&
              run.imageTag != null &&
              run.imageTag!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: FilledButton.icon(
                  icon: const Icon(Icons.rocket_launch, size: 16),
                  label: const Text('Launch via Docker'),
                  onPressed: () =>
                      RunContainerDialog.show(context, imageTag: run.imageTag),
                ),
              ),
            ),
          StreamBuilder<List<CiJob>>(
            stream: db.watchCiJobsForRun(run.ci_run_pk),
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? const <CiJob>[];
              if (jobs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No jobs.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: [for (final job in jobs) _JobTile(db: db, job: job)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final NexusDatabase db;
  final CiJob job;
  const _JobTile({required this.db, required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ExpansionTile(
        dense: true,
        leading: const Icon(Icons.settings_suggest, size: 18),
        title: Row(
          children: [
            Expanded(
              child: Text(job.name, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            StatusChip(status: job.status),
          ],
        ),
        subtitle: job.runsOn != null
            ? Text(
                job.runsOn!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              )
            : null,
        childrenPadding: const EdgeInsets.only(left: 12, right: 8, bottom: 6),
        children: [
          StreamBuilder<List<CiStep>>(
            stream: db.watchCiStepsForJob(job.ci_job_pk),
            builder: (context, snapshot) {
              final steps = snapshot.data ?? const <CiStep>[];
              if (steps.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No steps.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: [for (final step in steps) _StepTile(step: step)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final CiStep step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.chevron_right, size: 16),
      title: Text(step.name, style: const TextStyle(fontSize: 12)),
      trailing: StatusChip(status: step.status),
      onTap: () => _showLog(context),
    );
  }

  void _showLog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusChip(status: step.status),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (step.exitCode != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Exit code: ${step.exitCode}',
                    style: TextStyle(
                      fontSize: 12,
                      color: step.exitCode == 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      step.logText.isEmpty ? '(no output)' : step.logText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFD4D4D4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colored status chip shared across runs, jobs and steps.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final running = status == 'running';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          if (running) const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'success':
      return Colors.green;
    case 'failed':
      return Colors.red;
    case 'running':
      return Colors.blue;
    case 'cancelled':
      return Colors.amber.shade800;
    case 'skipped':
      return Colors.grey;
    case 'pending':
    default:
      return Colors.grey;
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

class CiRunsEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const CiRunsEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
