// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

// Headless smoke test for the Nextify hosting pipeline. Uses the real API with
// your key. Two modes:
//
//   Git (Option A) — push a public repo URL:
//     dart run tools/nextify_smoke_test.dart --key=nxt_... \
//       --repo=https://github.com/<you>/<site>.git [--branch=main]
//
//   Local (Option B) — push a directory over SSH, no git host:
//     dart run tools/nextify_smoke_test.dart --key=nxt_... \
//       --local=/path/to/materialised/project
//
// Common flags: [--machine=sm1.s1-2] [--name=nexus-smoke] [--keep]
// [--print-script]. The token comes from --key=... or NEXTIFY_TOKEN. By default
// the instance is DELETED when done (billing stops on delete); --keep leaves it
// running so you can open the URL.
import 'dart:io';

import 'package:nexus_projects_client/infrastructure/nextify/nextify_client.dart';
import 'package:nexus_projects_client/infrastructure/nextify/nextify_deploy.dart';
import 'package:nexus_projects_client/infrastructure/nextify/nextify_models.dart';

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a == name) return null;
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}

bool _flag(List<String> args, String name) => args.contains(name);

Future<void> main(List<String> args) async {
  final key =
      _arg(args, '--key') ?? Platform.environment['NEXTIFY_TOKEN'];
  final repo = _arg(args, '--repo');
  final branch = _arg(args, '--branch');
  final local = _arg(args, '--local');
  final machine = _arg(args, '--machine') ?? 'sm1.s1-2';
  final name =
      _arg(args, '--name') ?? 'nexus-smoke-${DateTime.now().millisecondsSinceEpoch % 100000}';
  final keep = _flag(args, '--keep');
  final printScript = _flag(args, '--print-script');

  final isLocal = local != null && local.isNotEmpty;

  if (printScript) {
    stdout.write(nextifyNodeDeployScript(
        local: isLocal,
        repoUrl: repo ?? 'https://example.com/x.git',
        branch: branch,
        appPort: 3000));
    return;
  }

  if (key == null || key.isEmpty) {
    stderr.writeln('No token: pass --key=nxt_... or set NEXTIFY_TOKEN.');
    exit(2);
  }
  if (isLocal && !File('$local/package.json').existsSync()) {
    stderr.writeln('--local=$local does not look like a project (no package.json).');
    exit(2);
  }
  if (!isLocal && (repo == null || repo.isEmpty)) {
    stderr.writeln('Missing --repo=<git url> or --local=<dir>.');
    exit(2);
  }

  final client = NextifyClient(key);

  stdout.writeln('→ Who am I?');
  try {
    final acct = await client.me();
    final limits = await client.limitsSummary();
    stdout.writeln('  ${acct.accountName} (plan: ${acct.plan}) — $limits');
  } on NextifyApiException catch (e) {
    stderr.writeln('  Token check FAILED: $e');
    exit(1);
  }

  final deployer = NextifyDeployer(client);
  stdout.writeln(
      '\n→ Launching "$name" ${isLocal ? 'from $local (SSH push)' : 'from $repo (${branch ?? 'default'})'}');
  NextifyDeployResult res;
  try {
    if (isLocal) {
      res = await deployer.launchLocal(
        localDir: local,
        instanceName: name,
        machineType: machine,
        onProgress: (j) {
          stdout.writeln(
              '  [${j.status}] ${j.progress?.percent ?? 0}% ${j.progress?.stage ?? j.type}');
        },
      );
    } else {
      res = await deployer.launch(
        repoUrl: repo!,
        branch: branch,
        instanceName: name,
        machineType: machine,
        onProgress: (j) {
          stdout.writeln(
              '  [${j.status}] ${j.progress?.percent ?? 0}% ${j.progress?.stage ?? j.type}');
        },
      );
    }
  } on NextifyApiException catch (e) {
    stderr.writeln('  Launch FAILED: $e');
    exit(1);
  }

  stdout.writeln(
      '\n  Instance ${res.instance.id}  status=${res.instance.status}  ip=${res.instance.publicIp}');
  if (res.url == null) {
    stderr.writeln('  No public IP yet — check the instance in the portal.');
    exit(1);
  }

  stdout.writeln('\n→ Waiting for the site to answer HTTP at ${res.url}…');
  final ok = await deployer.waitForHttp(res.url!,
      timeout: const Duration(minutes: 8));
  if (ok) {
    stdout.writeln('\n✅ HOSTING WORKS — site is live at ${res.url}');
  } else {
    stdout.writeln('\n⚠️ Instance is up but the site has not answered HTTP yet.');
    stdout.writeln('   Fetching the deploy log to diagnose…');
    try {
      final log = isLocal
          ? await deployer.fetchDeployLog(res.instance.publicIp!)
          : await deployer.setupLog(res.instance.id);
      stdout.writeln(log.isEmpty ? '   (log was empty)' : log);
    } catch (e) {
      stdout.writeln('   (could not fetch log: $e)');
    }
  }

  if (keep) {
    stdout.writeln('\n--keep: leaving "$name" (${res.instance.id}) running.');
    return;
  }

  stdout.writeln('\n→ Deleting "$name" (${res.instance.id}) — billing stops on delete.');
  try {
    final jid = await deployer.delete(res.instance.id);
    if (jid.isNotEmpty) {
      try {
        await client.waitForJob(jid,
            onProgress: (j) => stdout.writeln('  delete: ${j.status}'));
      } catch (e) {
        stdout.writeln('  delete: $e');
      }
    }
    stdout.writeln('  Deleted.');
  } on NextifyApiException catch (e) {
    stderr.writeln('  Delete FAILED: $e');
  }
}
