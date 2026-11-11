// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

// Thin, pure-Dart wrapper over the system OpenSSH (`ssh`/`scp`) for the
// Option-B Nextify deploy: push a local working tree to a fresh VM and drive
// the build over SSH. No Flutter dependency, so the CLI smoke test and the
// launcher both use it.

import 'dart:io';

import 'nextify_models.dart';

/// Paths to a generated ed25519 keypair. [publicKey] is the one-line
/// `ssh-ed25519 AAAA…` string to register with Nextify.
class SshKeyHandle {
  SshKeyHandle({required this.privPath, required this.pubPath});
  final String privPath;
  final String pubPath;
  String get publicKey => File(pubPath).readAsStringSync().trim();
}

/// Default home for the Nexus-managed Nextify deploy key.
String defaultSshKeyBaseDir() {
  final home =
      Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return '$home/.config/nexus-studio/nextify_ssh';
}

/// Ensure an ed25519 keypair exists under [baseDir] (generating it with
/// `ssh-keygen` on first use). The private key is chmod 0600.
Future<SshKeyHandle> ensureSshKey({String? baseDir}) async {
  final dir = baseDir ?? defaultSshKeyBaseDir();
  final priv = '$dir/id_ed25519';
  final pub = '$dir/id_ed25519.pub';
  if (!File(priv).existsSync()) {
    Directory(dir).createSync(recursive: true);
    final r = await Process.run('ssh-keygen', [
      '-q', '-t', 'ed25519', '-N', '', '-f', priv,
    ]);
    if (r.exitCode != 0) {
      throw NextifyApiException(
          0, 'ssh_keygen_failed', '${r.stdout}\n${r.stderr}');
    }
  }
  // Best-effort 0600 on the private key (ignore on failure / non-Unix).
  try {
    await Process.run('chmod', ['600', priv]);
  } catch (_) {}
  return SshKeyHandle(privPath: priv, pubPath: pub);
}

/// The non-host part of an `ssh`/`scp` invocation: identity + the hardening
/// options we always use (batch mode, no host-key prompts). Pure + testable.
List<String> sshBaseArgs({
  required String privPath,
  required String host,
  String user = 'ubuntu',
  int timeoutSeconds = 20,
  bool includeHost = true,
}) {
  final a = [
    '-i', privPath,
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=/dev/null',
    '-o', 'ConnectTimeout=$timeoutSeconds',
    '-o', 'LogLevel=ERROR',
  ];
  // For `ssh` the `user@host` is a top-level operand; for `scp` it must live
  // inside the destination spec, so callers can opt out.
  if (includeHost) a.add('$user@$host');
  return a;
}

/// Run [command] on the remote host over SSH. Returns the [ProcessResult].
Future<ProcessResult> sshRun({
  required String privPath,
  required String host,
  String user = 'ubuntu',
  required String command,
  int timeoutSeconds = 30,
}) async {
  final args = [...sshBaseArgs(privPath: privPath, host: host, user: user,
      timeoutSeconds: timeoutSeconds), command];
  return Process.run('ssh', args);
}

/// Copy a local file to the remote host.
Future<ProcessResult> scpFile({
  required String localPath,
  required String privPath,
  required String host,
  String user = 'ubuntu',
  required String remotePath,
}) async {
  // `includeHost: false` — for scp the host goes in the destination spec, not
  // as a standalone operand (a stray `user@host` operand breaks scp).
  final args = [
    '-C',
    ...sshBaseArgs(
        privPath: privPath, host: host, user: user, includeHost: false),
    localPath,
    '$user@$host:$remotePath',
  ];
  return Process.run('scp', args);
}

/// Poll until the remote host accepts SSH (sshd + key loading can lag the IP
/// appearing). Returns true when reachable within [timeout].
Future<bool> waitForSsh({
  required String privPath,
  required String host,
  String user = 'ubuntu',
  Duration timeout = const Duration(minutes: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final r = await sshRun(
      privPath: privPath,
      host: host,
      user: user,
      command: 'true',
      timeoutSeconds: 12,
    );
    if (r.exitCode == 0) return true;
    await Future<void>.delayed(const Duration(seconds: 4));
  }
  return false;
}

/// Push a local directory's contents into [remoteDir] on the VM (via a
/// tarball over scp, extracted as root). [remoteDir] is a trusted internal
/// constant (`/opt/app`) and is created if missing.
Future<void> pushDirectory({
  required String localDir,
  required String privPath,
  required String host,
  String user = 'ubuntu',
  required String remoteDir,
}) async {
  final tarName = 'nexus_push.tar';
  final tarPath = '${Directory.systemTemp.path}/$tarName';
  final tar = await Process.run('tar', ['-C', localDir, '-cf', tarPath, '.']);
  if (tar.exitCode != 0) {
    throw NextifyApiException(0, 'tar_failed', '${tar.stderr}');
  }
  try {
    final scp = await scpFile(
      localPath: tarPath,
      privPath: privPath,
      host: host,
      user: user,
      remotePath: '/tmp/$tarName',
    );
    if (scp.exitCode != 0) {
      throw NextifyApiException(0, 'scp_failed', '${scp.stderr}');
    }
    final x = await sshRun(
      privPath: privPath,
      host: host,
      user: user,
      command:
          'sudo mkdir -p $remoteDir && sudo tar -xf /tmp/$tarName -C $remoteDir '
              '&& sudo rm -f /tmp/$tarName',
      timeoutSeconds: 180,
    );
    if (x.exitCode != 0) {
      throw NextifyApiException(0, 'remote_extract_failed', '${x.stderr}');
    }
  } finally {
    try {
      File(tarPath).deleteSync();
    } catch (_) {}
  }
}

/// Fetch the output of a remote command (used to pull the deploy log).
Future<String> fetchRemote({
  required String privPath,
  required String host,
  String user = 'ubuntu',
  required String command,
  int timeoutSeconds = 30,
}) async {
  final r = await sshRun(
    privPath: privPath,
    host: host,
    user: user,
    command: command,
    timeoutSeconds: timeoutSeconds,
  );
  return '${r.stdout}\n${r.stderr}';
}
