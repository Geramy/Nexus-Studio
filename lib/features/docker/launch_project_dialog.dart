// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_projects_client/infrastructure/build/workspace_materializer.dart';
import 'package:nexus_projects_client/infrastructure/database/nexus_database.dart'
    show NexusDatabase;
import 'package:nexus_projects_client/infrastructure/docker/docker_context_tar.dart';
import 'package:nexus_projects_client/infrastructure/docker/docker_models.dart';
import 'package:nexus_projects_client/infrastructure/docker/docker_providers.dart';
import 'package:nexus_projects_client/infrastructure/exec/captured_run.dart';
import 'package:nexus_projects_client/infrastructure/workspace/workspace_provider.dart';

import 'dockerfile_templates.dart';
import 'platform_launch.dart';

/// Launch a green project. The target is chosen at the top: a **web** build runs
/// as a local Docker container (and opens in the browser); a **Windows** build
/// compiles the desktop app and launches the `.exe`. Which targets are offered
/// depends on the platforms picked for the project at setup (its `platforms`
/// tags), so a Windows app offers a Windows launch, a web app a container, etc.
class LaunchProjectDialog extends ConsumerStatefulWidget {
  final int projectPk;
  final NexusDatabase db;
  const LaunchProjectDialog({
    super.key,
    required this.projectPk,
    required this.db,
  });

  static Future<void> show(
    BuildContext context, {
    required int projectPk,
    required NexusDatabase db,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LaunchProjectDialog(projectPk: projectPk, db: db),
    );
  }

  @override
  ConsumerState<LaunchProjectDialog> createState() =>
      _LaunchProjectDialogState();
}

enum _Target { dockerWeb, windowsExe }

String _targetLabel(_Target t) => switch (t) {
  _Target.dockerWeb => 'Web — Docker container',
  _Target.windowsExe => 'Windows app — .exe',
};

enum _Phase { preparing, ready, working, done, error }

class _LaunchProjectDialogState extends ConsumerState<LaunchProjectDialog> {
  final _tag = TextEditingController();
  final _dockerfileName = TextEditingController(text: 'Dockerfile');
  final _dockerfile = TextEditingController();
  final _containerName = TextEditingController();
  final _containerPort = TextEditingController(text: '80');
  final _hostPort = TextEditingController();
  final _saveName = TextEditingController(); // windows: output folder/app name
  final _saveLocation = TextEditingController(); // windows: where to save it
  final _scroll = ScrollController();

  final List<DockerBuildEvent> _log = [];
  StreamSubscription<DockerBuildEvent>? _sub;
  _Phase _phase = _Phase.preparing;
  String _kind = '';
  String _subdir = ''; // project folder holding the manifest ('' = repo root)
  List<_Target> _targets = const [_Target.dockerWeb];
  _Target _target = _Target.dockerWeb;

  // Post-launch actions.
  String? _openUrl; // web container → open in browser
  String? _exePath; // windows build → reveal the .exe

  bool get _busy => _phase == _Phase.working;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tag.dispose();
    _dockerfileName.dispose();
    _dockerfile.dispose();
    _containerName.dispose();
    _containerPort.dispose();
    _hostPort.dispose();
    _saveName.dispose();
    _saveLocation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _sanitize(String s) {
    final out = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '-');
    final trimmed = out.replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
    return trimmed.isEmpty ? 'app' : trimmed;
  }

  /// The host port Docker binds to [cport] is published a beat AFTER the container
  /// starts, so a single read right after `runContainer` usually comes back null —
  /// which is why the launch found "no port" and never opened the browser even
  /// though the container was up (`0.0.0.0:63986->80/tcp`). Poll briefly for it.
  Future<String?> _hostPortWithRetry(String id, String cport) async {
    final client = ref.read(dockerEngineClientProvider);
    for (var i = 0; i < 15; i++) {
      final hp = await client.containerHostPort(id, cport);
      if (hp != null && hp.isNotEmpty) return hp;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return null;
  }

  Future<void> _prepare() async {
    try {
      final project = await widget.db.getProjectById(widget.projectPk);
      final base = _sanitize(project?.name ?? 'app');
      _tag.text = '$base:latest';
      _containerName.text = '$base-app';
      // Windows save: default the app/folder name to the project name (folder-safe)
      // and the location to the Desktop.
      final folderName = (project?.name ?? 'app')
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .trim();
      _saveName.text = folderName.isEmpty ? 'app' : folderName;
      _saveLocation.text = await desktopDir();

      // Offered targets come from the project's platform tags.
      final tags = await widget.db.getTagsForProject(widget.projectPk);
      final platforms = tags
          .where((t) => t.category == 'platforms' && t.status != 'rejected')
          .map((t) => t.value.toLowerCase())
          .toList();
      final hasWindows = platforms.any((p) => p.contains('windows'));
      final hasWeb =
          platforms.any((p) => p.contains('web')) || platforms.isEmpty;

      final targets = <_Target>[];
      if (Platform.isWindows && hasWindows) targets.add(_Target.windowsExe);
      if (hasWeb || targets.isEmpty) targets.add(_Target.dockerWeb);
      _targets = targets;
      _target = targets.first;

      final ws = await ref.read(
        workspaceFsProvider(widget.projectPk).future,
      );
      final info = await detectDockerProject(ws);
      final tpl = dockerLaunchTemplate(
        info.kind,
        subdir: info.subdir,
        dotnetAssembly: info.dotnetAssembly,
      );
      _kind = info.kind;
      _subdir = info.subdir;
      _containerPort.text = '${tpl.containerPort}';
      _dockerfile.text = tpl.dockerfile.trim();

      if (mounted) setState(() => _phase = _Phase.ready);
    } catch (e) {
      _append(DockerBuildEvent('Could not prepare launch: $e', isError: true));
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  void _append(DockerBuildEvent e) {
    if (!mounted) return;
    setState(() => _log.add(e));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _launch() async {
    _openUrl = null;
    _exePath = null;
    setState(() {
      _phase = _Phase.working;
      _log.clear();
    });
    switch (_target) {
      case _Target.dockerWeb:
        await _launchDocker();
      case _Target.windowsExe:
        await _launchWindows();
    }
  }

  // ── Web → Docker container ──────────────────────────────────────────────
  Future<void> _launchDocker() async {
    final tag = _tag.text.trim();
    final dfName = _dockerfileName.text.trim().isEmpty
        ? 'Dockerfile'
        : _dockerfileName.text.trim();
    if (tag.isEmpty) {
      _append(
        const DockerBuildEvent('An image tag is required.', isError: true),
      );
      setState(() => _phase = _Phase.error);
      return;
    }

    // REUSE vs REBUILD: a container named the same already exists on most
    // re-launches. If it was created AFTER the latest CI run, the code hasn't
    // changed since — just (re)start and open it (no rebuild). If it's OLDER
    // than the last CI run, the code moved on: remove it and rebuild fresh.
    final containerName = _containerName.text.trim();
    final cport = _containerPort.text.trim().isEmpty
        ? '80'
        : _containerPort.text.trim();
    debugPrint(
      '[Launch p${widget.projectPk}] launch docker: tag="${_tag.text.trim()}" '
      'kind=$_kind container="$containerName" cport=$cport',
    );
    if (containerName.isNotEmpty) {
      try {
        final client = ref.read(dockerEngineClientProvider);
        final existing = (await client.listContainers()).firstWhere(
          (c) => c.names.contains(containerName),
          orElse: () => const DockerContainer(
            id: '',
            names: [],
            image: '',
            state: '',
            status: '',
          ),
        );
        if (existing.id.isNotEmpty) {
          final ciRun = await widget.db.getLatestCiRunForProject(
            widget.projectPk,
          );
          final ciTime = ciRun?.completedAt ?? ciRun?.createdAt;
          var upToDate =
              existing.created != null &&
              ciTime != null &&
              existing.created!.isAfter(ciTime);
          // A container that has EXITED with a non-zero code crashed (e.g. a
          // broken image: Next.js started without `next build` dies in a second).
          // Re-starting it just crashes it again — rebuild instead so the user
          // isn't pointed at a dead port with no explanation.
          if (upToDate && !existing.isRunning) {
            try {
              final st = await client.containerState(existing.id);
              if (!st.running && (st.exitCode ?? 0) != 0) {
                upToDate = false;
                _append(
                  DockerBuildEvent(
                    '"$containerName" has exited (crashed, code ${st.exitCode}) '
                    '— rebuilding rather than re-starting a broken container.',
                  ),
                );
              }
            } catch (_) {}
          }
          if (upToDate) {
            _append(
              DockerBuildEvent(
                'Reusing "$containerName" — it was built after the last CI run.',
              ),
            );
            if (!existing.isRunning) await client.startContainer(existing.id);
            ref.invalidate(dockerContainersProvider);
            final hp = await _hostPortWithRetry(existing.id, cport);
            if (hp != null && hp.isNotEmpty) {
              final url = 'http://localhost:$hp';
              _openUrl = url;
              _append(DockerBuildEvent('Opening $url'));
              unawaited(openUrl(url));
            } else {
              _append(const DockerBuildEvent('Container is running.'));
            }
            if (mounted) setState(() => _phase = _Phase.done);
            return;
          }
          _append(
            DockerBuildEvent(
              'Replacing "$containerName" — it predates the last CI run.',
            ),
          );
          await client.removeContainer(existing.id, force: true);
          ref.invalidate(dockerContainersProvider);
        }
      } catch (e) {
        // Reuse is best-effort; fall through to a fresh build+run.
        _append(DockerBuildEvent('(reuse check skipped: $e)'));
      }
    }

    _append(DockerBuildEvent('Saving $dfName and building "$tag"…'));
    try {
      final ws = await ref.read(
        workspaceFsProvider(widget.projectPk).future,
      );
      final dfPath = dfName.startsWith('/') ? dfName : '/$dfName';
      await ws.writeString(dfPath, '${_dockerfile.text.trimRight()}\n');
      ref.read(workspaceRevisionProvider(widget.projectPk).notifier).state++;

      final tar = await const DockerContextTar().fromWorkspace(ws);
      final client = ref.read(dockerEngineClientProvider);

      _sub = client
          .buildImage(
            contextTar: tar,
            imageTag: tag,
            dockerfile: dfPath.substring(1),
          )
          .listen(
            _append,
            onError: (e) {
              _append(DockerBuildEvent('$e', isError: true));
              if (mounted) setState(() => _phase = _Phase.error);
            },
            onDone: () {
              ref.invalidate(dockerImagesProvider);
              unawaited(_runContainer(tag));
            },
          );
    } catch (e) {
      _append(DockerBuildEvent('Build failed to start: $e', isError: true));
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _runContainer(String tag) async {
    if (!mounted) return;
    if (_log.any((e) => e.isError)) {
      setState(() => _phase = _Phase.error);
      return;
    }
    _append(const DockerBuildEvent('Image built — starting container…'));
    final cport = _containerPort.text.trim().isEmpty
        ? '80'
        : _containerPort.text.trim();
    final requestedHost = _hostPort.text.trim(); // '' → Docker auto-assigns
    try {
      final client = ref.read(dockerEngineClientProvider);
      String id;
      try {
        id = await client.runContainer(
          imageTag: tag,
          name: _containerName.text.trim().isEmpty
              ? null
              : _containerName.text.trim(),
          portBindings: {cport: requestedHost},
        );
      } catch (e) {
        // Host port already taken (e.g. another service on 8080) — retry with an
        // auto-assigned free port so a collision never blocks the launch.
        final msg = '$e'.toLowerCase();
        if (requestedHost.isNotEmpty &&
            (msg.contains('already allocated') ||
                msg.contains('already in use') ||
                msg.contains('port is already'))) {
          _append(
            DockerBuildEvent(
              'Host port $requestedHost is in use — picking a free port…',
            ),
          );
          id = await client.runContainer(
            imageTag: tag,
            name: _containerName.text.trim().isEmpty
                ? null
                : _containerName.text.trim(),
            portBindings: {cport: ''},
          );
        } else {
          rethrow;
        }
      }
      ref.invalidate(dockerContainersProvider);

      // Discover the port Docker actually bound (polling — it publishes a beat
      // after start), then open it in the browser.
      final hostPort = (await _hostPortWithRetry(id, cport)) ?? requestedHost;
      final shortId = id.length > 12 ? id.substring(0, 12) : id;
      final launchUrl = hostPort.isNotEmpty ? 'http://localhost:$hostPort' : '';
      debugPrint(
        '[Launch p${widget.projectPk}] container started: id=$shortId '
        'name="${_containerName.text.trim()}" image=$tag '
        'url=${launchUrl.isEmpty ? '(no host port)' : launchUrl}',
      );
      if (hostPort.isNotEmpty) {
        final url = 'http://localhost:$hostPort';
        _openUrl = url;
        _append(DockerBuildEvent('Container started — opening $url'));
        unawaited(openUrl(url));
      } else {
        _append(
          DockerBuildEvent('Container started (id $shortId).'),
        );
      }
      // A broken image (e.g. a Next.js app launched without `next build`) starts
      // and crashes within a second, so the browser opens on a dead port with
      // nothing to explain why. Verify the container actually stayed up; if it
      // exited, surface the last lines of its log.
      unawaited(_verifyContainerUp(id));
      if (mounted) setState(() => _phase = _Phase.done);
    } catch (e) {
      _append(DockerBuildEvent('Could not start container: $e', isError: true));
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  /// Verify a just-started launch container stayed up. A broken image (e.g. a
  /// Next.js app started without `next build`) crashes within a second, leaving
  /// the browser on a dead port with no explanation. Poll once after a short
  /// grace period; if it exited, tail its log so the real error is visible in
  /// both the dialog and the console.
  Future<void> _verifyContainerUp(String id) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    try {
      final client = ref.read(dockerEngineClientProvider);
      final st = await client.containerState(id);
      if (st.running) {
        debugPrint(
          '[Launch p${widget.projectPk}] container $id still up after 3s ✓',
        );
        return;
      }
      final logs = await client.containerLogs(id, tail: 50);
      final tail = _tailLines(logs, 14);
      _append(
        DockerBuildEvent(
          'Container exited (code ${st.exitCode}) shortly after start — the '
          'site may not work. Last log lines:\n$tail',
          isError: true,
        ),
      );
      debugPrint(
        '[Launch p${widget.projectPk}] container $id EXITED (code '
        '${st.exitCode}, status ${st.status}). Last log lines:\n$tail',
      );
    } catch (e) {
      debugPrint('[Launch p${widget.projectPk}] post-launch check failed: $e');
    }
  }

  /// The last [n] non-empty lines of [s] (compact error tailing).
  String _tailLines(String s, int n) {
    final lines =
        s.split('\n').where((l) => l.trim().isNotEmpty).toList(growable: false);
    if (lines.length <= n) return lines.join('\n');
    return lines.sublist(lines.length - n).join('\n');
  }

  // ── Windows → native .exe ───────────────────────────────────────────────
  Future<void> _launchWindows() async {
    _append(
      const DockerBuildEvent(
        'Building the Windows app (flutter build windows --release)… '
        'the first build can take a few minutes.',
      ),
    );
    MaterializedWorkspace? mat;
    try {
      final ws = await ref.read(
        workspaceFsProvider(widget.projectPk).future,
      );
      mat = await const WorkspaceMaterializer().materialize(ws, tag: 'winlaunch');
      // Build in the app directory (the folder holding pubspec.yaml — often a
      // nested `client/`), not the materialized root, or `flutter create .` would
      // scaffold a default app at the root instead of building the real project.
      final appDir = _subdir.isEmpty
          ? mat.path
          : '${mat.path}${Platform.pathSeparator}'
                '${_subdir.replaceAll('/', Platform.pathSeparator)}';
      // Ensure the Windows platform files exist, then build. `flutter create`
      // only adds the missing windows/ shell — it never touches lib/ source.
      final res = await runCaptured(
        'flutter create . --platforms windows && '
        'flutter pub get && '
        'flutter build windows --release',
        workingDirectory: appDir,
      );
      // Persist the FULL build output to a stable file so a failure stays
      // diagnosable after the (ephemeral) dialog log closes.
      String? logPath;
      try {
        logPath =
            '${Directory.systemTemp.path}${Platform.pathSeparator}nexus_windows_launch.log';
        await File(logPath).writeAsString(res.output);
      } catch (_) {
        logPath = null;
      }
      if (logPath != null) {
        _append(DockerBuildEvent('Full build log saved: $logPath'));
      }
      for (final line in res.output.split('\n')) {
        if (line.trim().isEmpty) continue;
        _append(DockerBuildEvent(line, isError: false));
      }
      if (res.exitCode != 0) {
        _append(
          const DockerBuildEvent('Build failed (see log above).', isError: true),
        );
        if (mounted) setState(() => _phase = _Phase.error);
        await mat.dispose();
        return;
      }

      final exe = await _findWindowsExe(Directory(appDir));
      if (exe == null) {
        _append(
          const DockerBuildEvent(
            'Build succeeded but no .exe was found under build/windows.',
            isError: true,
          ),
        );
        if (mounted) setState(() => _phase = _Phase.error);
        await mat.dispose();
        return;
      }
      // A Flutter Windows app is the WHOLE Release folder (exe + DLLs + data/),
      // not a lone .exe. SAVE that bundle out of the temp build dir into the
      // user's chosen location, named after the app — permanent + clickable —
      // then add a Desktop shortcut. Do NOT auto-launch: the user runs it.
      final releaseDir = File(exe).parent; // <build>/…/Release
      final exeName = exe.split(Platform.pathSeparator).last;
      final name = _saveName.text.trim().isEmpty ? 'app' : _saveName.text.trim();
      final loc = _saveLocation.text.trim().isEmpty
          ? await desktopDir()
          : _saveLocation.text.trim();
      final destDir = '$loc${Platform.pathSeparator}$name';
      _append(DockerBuildEvent('Saving the app to "$destDir"…'));
      try {
        await copyDirectory(releaseDir, Directory(destDir));
      } catch (e) {
        _append(
          DockerBuildEvent('Could not save to "$destDir": $e', isError: true),
        );
        if (mounted) setState(() => _phase = _Phase.error);
        await mat.dispose();
        return;
      }
      final savedExe = '$destDir${Platform.pathSeparator}$exeName';
      // Best-effort Desktop shortcut named after the app.
      try {
        final desk = await desktopDir();
        if (desk.isNotEmpty) {
          await createShortcut(
            '$desk${Platform.pathSeparator}$name.lnk',
            savedExe,
            workingDir: destDir,
          );
          _append(DockerBuildEvent('Desktop shortcut created: $name'));
        }
      } catch (_) {}
      // The saved copy is self-contained, so the temp build dir can be removed.
      await mat.dispose();
      _exePath = savedExe;
      _append(
        const DockerBuildEvent(
          'Done — the app is saved and NOT running. Double-click the Desktop '
          'shortcut (or the .exe in the folder) to launch it.',
        ),
      );
      if (mounted) setState(() => _phase = _Phase.done);
    } catch (e) {
      _append(DockerBuildEvent('Windows build failed: $e', isError: true));
      if (mounted) setState(() => _phase = _Phase.error);
      await mat?.dispose();
    }
  }

  /// Find the built runner .exe under `<dir>/build/windows/**/Release/*.exe`.
  Future<String?> _findWindowsExe(Directory dir) async {
    final buildWin = Directory(
      '${dir.path}${Platform.pathSeparator}build'
      '${Platform.pathSeparator}windows',
    );
    if (!await buildWin.exists()) return null;
    String? candidate;
    await for (final e in buildWin.list(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.toLowerCase().endsWith('.exe')) continue;
      final lower = e.path.toLowerCase();
      // Prefer a Release runner exe; skip plugin/CMake helper exes.
      if (lower.contains('${Platform.pathSeparator}release${Platform.pathSeparator}')) {
        return e.path;
      }
      candidate ??= e.path;
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final preparing = _phase == _Phase.preparing;
    final isDocker = _target == _Target.dockerWeb;
    return AlertDialog(
      title: const Text('Launch'),
      content: SizedBox(
        width: 640,
        child: preparing
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Target: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        DropdownButton<_Target>(
                          value: _target,
                          onChanged: _busy
                              ? null
                              : (t) => setState(() {
                                  if (t != null) _target = t;
                                }),
                          items: [
                            for (final t in _targets)
                              DropdownMenuItem(
                                value: t,
                                child: Text(_targetLabel(t)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isDocker) ..._dockerFields() else ..._windowsFields(),
                    if (_log.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        // Per-line SelectableText — NOT a SelectionArea wrapping a
                        // lazy ListView: that combination crashes on paragraph
                        // selection (dart:ui/math.dart assertion in
                        // selectable_region.dart) when the user drags to copy the
                        // log. Each line is independently selectable/copyable.
                        child: ListView.builder(
                          controller: _scroll,
                          itemCount: _log.length,
                          itemBuilder: (c, i) {
                            final e = _log[i];
                            return SelectableText(
                              e.text,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: e.isError
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFFD4D4D4),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (_phase == _Phase.done && _openUrl != null)
          TextButton.icon(
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('Open in browser'),
            onPressed: () => openUrl(_openUrl!),
          ),
        if (_phase == _Phase.done && _exePath != null)
          TextButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Show saved app'),
            onPressed: () => revealInFileManager(_exePath!),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(_phase == _Phase.done ? 'Close' : 'Cancel'),
        ),
        FilledButton.icon(
          onPressed: (_busy || preparing || _phase == _Phase.done)
              ? null
              : _launch,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rocket_launch, size: 16),
          label: Text(
            switch (_phase) {
              _Phase.working => 'Working…',
              _Phase.done => isDocker ? 'Launched' : 'Saved',
              _Phase.error => 'Retry',
              _ => isDocker ? 'Launch' : 'Build & save',
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _dockerFields() {
    return [
      if (_kind.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Detected stack: $_kind — a starter Dockerfile is prefilled. Leave '
            'the host port blank to auto-pick a free one.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _tag,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Image tag',
                hintText: 'myapp:latest',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _dockerfileName,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Dockerfile',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _containerName,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Container name',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _containerPort,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Port',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(':'),
          ),
          Expanded(
            child: TextField(
              controller: _hostPort,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: 'auto',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Dockerfile',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: _dockerfile,
        enabled: !_busy,
        maxLines: 9,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    ];
  }

  List<Widget> _windowsFields() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Compiles the Windows desktop app (flutter build windows --release), '
          'SAVES it to the folder below (it is NOT auto-launched), and adds a '
          'Desktop shortcut you can double-click. Requires the Flutter Windows '
          'toolchain (Visual Studio) on this machine.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
      TextField(
        controller: _saveName,
        enabled: !_busy,
        decoration: const InputDecoration(
          labelText: 'App name (folder + Desktop shortcut)',
          hintText: 'My App',
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _saveLocation,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Save location',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final picked = await pickFolder('Save the app to…');
                    if (picked != null && picked.isNotEmpty && mounted) {
                      setState(() => _saveLocation.text = picked);
                    }
                  },
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Browse'),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    final d = await desktopDir();
                    if (d.isNotEmpty && mounted) {
                      setState(() => _saveLocation.text = d);
                    }
                  },
            child: const Text('Desktop'),
          ),
        ],
      ),
    ];
  }
}
