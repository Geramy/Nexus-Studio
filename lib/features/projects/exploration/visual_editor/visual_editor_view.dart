// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The VISUAL EDITOR: a WYSIWYG-ish screen for the built app. Left rail of
/// captured screens, center canvas with pickable REGIONS (hover to see what a
/// widget is, right-click to edit it, shift+drag to nudge its spacing), and a
/// right inspector/ops panel. Every edit is a committed, analyzer-gated,
/// auto-rolling-back change to the real source code — then the screens are
/// re-captured so the user sees the result.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../infrastructure/workspace/git/git_engine_provider.dart';
import '../../../../infrastructure/workspace/workspace_provider.dart';
import 'code_applier.dart';
import 'region_model.dart';
import 'screen_map_service.dart';
import 'source_locator.dart';

class VisualEditorView extends ConsumerStatefulWidget {
  const VisualEditorView({
    super.key,
    required this.projectId,
    required this.onViewCode,
    required this.onOpenChat,
  });

  final int projectId;

  /// Parent switches to the Code tab (file selection is already set).
  final VoidCallback onViewCode;

  /// Parent switches to the editor chat (prompt is pre-filled via provider).
  final VoidCallback onOpenChat;

  @override
  ConsumerState<VisualEditorView> createState() => _VisualEditorViewState();
}

class _VisualEditorViewState extends ConsumerState<VisualEditorView> {
  ScreenMap? _map;
  String? _loadStage;
  String? _loadError;
  String? _loadLog;
  int _screenIdx = 0;
  ScreenRegion? _hover;
  ScreenRegion? _selected;
  Offset? _dragOrigin;
  Offset _dragDelta = Offset.zero;
  bool _busy = false;
  bool _recapturing = false;
  final List<VisualEditRecord> _records = [];
  /// In-memory undo store: recordId → file → original bytes.
  final Map<int, Map<String, List<int>>> _undoStore = {};
  int _capturedRevision = -1;
  bool _loading = true;
  String? _cacheDirPath;
  ScreenRegion? _dragRegion;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _loadError = null;
      _loadLog = null;
      _loadStage = 'Reading project state…';
    });
    try {
      final projectId = widget.projectId;
      final git = await ref.read(gitEngineProvider(projectId).future);
      final head = (await git.headOid())?.substring(0, 7) ?? '';
      ScreenMap? map = force ? null : await loadCachedScreenMap(projectId, head);
      if (map == null) {
        map = await buildScreenMap(
          ws: await ref.read(workspaceFsProvider(projectId).future),
          projectId: projectId,
          head: head,
          onProgress: (stage) {
            if (mounted) setState(() => _loadStage = stage);
          },
        );
      }
      if (!mounted) return;
      await _resolveSources(map);
      _capturedRevision =
          ref.read(workspaceRevisionProvider(projectId));
      _cacheDirPath = (await cacheDir(projectId, head)).path;
      setState(() {
        _map = map;
        _loading = false;
        _screenIdx = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
        _loadLog = e is ScreenMapError ? e.log : null;
      });
    }
  }

  /// Reverse-map every region to a source file:line using the workspace
  /// sources (text / color / widget-chain heuristics).
  Future<void> _resolveSources(ScreenMap map) async {
    final index =
        await SourceIndex.build(await ref.read(workspaceFsProvider(widget.projectId).future));
    final screens = <CapturedScreen>[];
    for (final s in map.screens) {
      final regions = <ScreenRegion>[];
      for (final r in s.regions) {
        final loc = index.locate(s.route, r);
        regions.add(loc == null
            ? r
            : r.copyWithSource(loc.$1, loc.$2));
      }
      screens.add(CapturedScreen(
        route: s.route,
        label: s.label,
        pngFile: s.pngFile,
        width: s.width,
        height: s.height,
        regions: regions,
        error: s.error,
      ));
    }
    _map = ScreenMap(
      projectId: map.projectId,
      head: map.head,
      screens: screens,
      log: map.log,
    );
  }

  // ------------------------------------------------------------------ ops

  Future<void> _applyOp(VisualOp op) async {
    if (_busy) return;
    setState(() => _busy = true);
    final projectId = widget.projectId;
    try {
      final ws = await ref.read(workspaceFsProvider(projectId).future);
      final git = await ref.read(gitEngineProvider(projectId).future);

      // Collect the originals for UNDO (deterministic ops touch exactly the
      // region's file; image ops also touch pubspec.yaml).
      final originals = <String, List<int>>{};
      final regionFile = op.region.sourceFile;
      if (regionFile != null) {
        originals[regionFile] = await ws.readBytes(regionFile);
      }
      final isImageOp = op.kind == VisualOpKind.insertImage ||
          op.kind == VisualOpKind.replaceImage;
      if (isImageOp) {
        if (await ws.exists('/pubspec.yaml')) {
          originals['/pubspec.yaml'] = await ws.readBytes('/pubspec.yaml');
        }
      }

      // Image ops: the user picked a host file; copy its bytes into the
      // workspace assets first.
      if (isImageOp && op.assetPath != null &&
          op.assetPath!.startsWith('/host:')) {
        final hostFile = File(op.assetPath!.substring('/host:'.length));
        final bytes = await hostFile.readAsBytes();
        final wsPath =
            '/assets/visual_${DateTime.now().millisecondsSinceEpoch}.png';
        await ws.writeBytes(wsPath, bytes);
        await ensureAssetInPubspec(ws, wsPath);
        op = VisualOp(
          kind: op.kind,
          region: op.region,
          screenRoute: op.screenRoute,
          assetPath: wsPath,
          dx: op.dx,
          dy: op.dy,
        );
      }

      final outcome = await applyVisualOp(ws: ws, git: git, op: op);
      if (!mounted) return;

      ref.read(workspaceRevisionProvider(projectId).notifier).state++;
      final rec = outcome.record;
      _records.insert(0, rec);
      if (outcome.status == OpStatus.applied && regionFile != null) {
        _undoStore[rec.id] = originals;
      }
      _toast(
        switch (outcome.status) {
          OpStatus.applied => 'Applied ✓ — re-capturing screens…',
          OpStatus.rolledBack =>
            'Rolled back (would not compile): ${outcome.reason ?? ''}',
          OpStatus.needsAgent => 'Sent to the assistant — review & send in chat',
        },
        ok: outcome.status == OpStatus.applied,
      );

      if (outcome.status == OpStatus.needsAgent) {
        ref
            .read(pendingEditorPromptProvider(projectId).notifier)
            .state = outcome.agentPrompt;
        widget.onOpenChat();
        return;
      }

      if (outcome.status == OpStatus.applied) {
        unawaited(_recapture());
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Edit failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Re-run the harness after a change so the canvas reflects the new code.
  Future<void> _recapture() async {
    if (_recapturing) return;
    setState(() => _recapturing = true);
    try {
      final projectId = widget.projectId;
      final git = await ref.read(gitEngineProvider(projectId).future);
      final head = (await git.headOid())?.substring(0, 7) ?? '';
      final map = await buildScreenMap(
        ws: await ref.read(workspaceFsProvider(projectId).future),
        projectId: projectId,
        head: head,
        onProgress: (s) {
          if (mounted && _map != null) setState(() {}); // no-op, keep alive
        },
      );
      if (!mounted) return;
      await _resolveSources(map);
      setState(() {
        _map = map;
        _capturedRevision = ref.read(workspaceRevisionProvider(projectId));
      });
      _toast('Screens refreshed ✓');
    } catch (e) {
      if (mounted) _toast('Re-capture failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _recapturing = false);
    }
  }

  Future<void> _undo(VisualEditRecord rec) async {
    final originals = _undoStore[rec.id];
    if (originals == null) {
      _toast('Nothing to undo in this session (restart-safe undo is coming).',
          ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      final ws = await ref.read(workspaceFsProvider(widget.projectId).future);
      final git = await ref.read(gitEngineProvider(widget.projectId).future);
      for (final e in originals.entries) {
        await ws.writeBytes(e.key, e.value);
      }
      await git.commitAll(
        message: 'Undo visual edit: ${rec.opSummary}',
      );
      ref.read(workspaceRevisionProvider(widget.projectId).notifier).state++;
      _toast('Undone ✓ — re-capturing…');
      unawaited(_recapture());
    } catch (e) {
      if (mounted) _toast('Undo failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ pick/ops

  void _viewCode(ScreenRegion r) {
    final f = r.sourceFile;
    if (f == null || r.sourceLine == null) {
      _toast('No source location found for this widget — ask the assistant instead.',
          ok: false);
      return;
    }
    ref.read(selectedWorkspaceFileProvider(widget.projectId).notifier).state =
        f;
    ref.read(workspaceJumpLineProvider(widget.projectId).notifier).state =
        r.sourceLine;
    widget.onViewCode();
  }

  void _openRegionMenu(BuildContext context, Offset global, ScreenRegion r) {
    setState(() => _selected = r);
    showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        global & const Size(1, 1),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        const PopupMenuItem(value: 0, child: _MenuItem('View code', Icons.code)),
        const PopupMenuItem(value: 1, child: _MenuItem('Change color…', Icons.color_lens)),
        const PopupMenuItem(value: 2, child: _MenuItem('Edit text…', Icons.text_fields)),
        const PopupMenuItem(value: 3, child: _MenuItem('Insert image…', Icons.image_outlined)),
        const PopupMenuItem(value: 4, child: _MenuItem('Replace image…', Icons.photo_outlined)),
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 0:
          _viewCode(r);
        case 1:
          _colorDialog(r);
        case 2:
          _textDialog(r);
        case 3:
          _imageDialog(r, VisualOpKind.insertImage);
        case 4:
          _imageDialog(r, VisualOpKind.replaceImage);
      }
    });
  }

  void _colorDialog(ScreenRegion r) {
    final current = r.colorHex;
    showDialog<void>(
      context: context,
      builder: (ctx) => _ColorDialog(
        current: current,
        onPick: (hex) {
          _applyOp(VisualOp(
            kind: VisualOpKind.setColor,
            region: r,
            screenRoute: _currentScreen().route,
            colorHex: hex,
          ));
        },
      ),
    );
  }

  void _textDialog(ScreenRegion r) {
    final controller = TextEditingController(text: r.text ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyOp(VisualOp(
                kind: VisualOpKind.setText,
                region: r,
                screenRoute: _currentScreen().route,
                text: controller.text,
              ));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _imageDialog(ScreenRegion r, VisualOpKind kind) {
    String? hostPath;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(kind == VisualOpKind.insertImage
              ? 'Insert image'
              : 'Replace image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the path of a PNG/JPG on this machine (e.g. ~/Pictures/bg.png):',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (v) => setDlg(() => hostPath = v.trim()),
                  ),
                ),
              ],),
              if (controller.text.trim().isNotEmpty &&
                  !File(_expandHome(controller.text.trim())).existsSync())
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '⚠ that file does not exist',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (hostPath == null || hostPath!.isEmpty)
                  ? null
                  : () {
                      final p = hostPath!;
                      Navigator.pop(ctx);
                      _applyOp(VisualOp(
                        kind: kind,
                        region: r,
                        screenRoute: _currentScreen().route,
                        assetPath: '/host:$p',
                      ));
                    },
              child: const Text('Use image'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 4),
    ));
  }

  CapturedScreen _currentScreen() =>
      _map!.screens[math.min(_screenIdx, _map!.screens.length - 1)];

  static String _expandHome(String p) {
    if (p == '~') return Platform.environment['HOME'] ?? '';
    if (p.startsWith('~/')) {
      return '${Platform.environment['HOME'] ?? ''}${p.substring(1)}';
    }
    return p;
  }

  static String _lastLines(String s, int n) {
    final lines = s.split('\n');
    return lines.skip(math.max(0, lines.length - n)).join('\n');
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_loadStage ?? 'Loading…', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }
    if (_map == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                _loadError ?? 'Could not build the screen map.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              if (_loadLog != null && _loadLog!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SelectableText(
                    _lastLines(_loadLog!, 30),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final map = _map!;
    final screen = _currentScreen();
    final rev = ref.watch(workspaceRevisionProvider(widget.projectId));
    final stale = rev != _capturedRevision;

    return Column(
      children: [
        // Top bar.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(children: [
            const Icon(Icons.photo_library_outlined, size: 18),
            const SizedBox(width: 8),
            Text('Visual Editor', style: theme.textTheme.titleSmall),
            const SizedBox(width: 16),
            if (stale && !_recapturing)
              TextButton.icon(
                onPressed: () => _recapture(),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Screens stale — refresh'),
              ),
            const Spacer(),
            if (_recapturing)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Tooltip(
              message: 'Capture the screens again from the current code',
              child: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _busy || _recapturing ? null : () => _load(force: true),
                tooltip: 'Re-capture screens',
              ),
            ),
          ]),
        ),
        Row(children: [
          // Screens rail.
          Container(
            width: 132,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: theme.dividerColor)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: map.screens.length,
              itemBuilder: (context, i) => _railTile(i),
            ),
          ),
          // Canvas + status bar.
          Expanded(
            child: Column(children: [
              Expanded(
                child: screen.error != null && screen.pngFile.isEmpty
                    ? _screenError(screen)
                    : _canvas(screen),
              ),
              _statusBar(screen),
            ]),
          ),
          // Inspector + ops log.
          Container(
            width: 292,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.dividerColor)),
            ),
            child: _sidePanel(context, screen),
          ),
        ]),
      ],
    );
  }

  Widget _railTile(int i) {
    final map = _map!;
    final s = map.screens[i];
    final selected = i == _screenIdx;
    final png = _pngPath(s);
    return GestureDetector(
      onTap: () => setState(() => _screenIdx = i),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 66,
                child: s.pngFile.isEmpty
                    ? const Center(
                        child: Icon(Icons.broken_image_outlined, size: 18))
                    : Image.file(
                        png,
                        width: 112,
                        height: 66,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: Row(children: [
                  if (s.error != null)
                    const Icon(Icons.warning_amber,
                        size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  File _pngPath(CapturedScreen s) {
    return File('${_cacheDirPath}${Platform.pathSeparator}${s.pngFile}');
  }

  Widget _screenError(CapturedScreen s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 32),
            const SizedBox(height: 8),
            Text('This screen could not be captured.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              (s.error ?? '').length > 160
                  ? '${(s.error!).substring(0, 160)}…'
                  : s.error ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas(CapturedScreen screen) {
    final w = screen.width.toDouble();
    final h = screen.height.toDouble();
    if (w <= 0 || h <= 0) return const Center(child: Text('No image'));
    final dragging = _dragOrigin != null;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(children: [
            Positioned(
              left: 0,
              top: 0,
              child: Image.file(
                _pngPath(screen),
                width: w,
                height: h,
                gaplessPlayback: true,
              ),
            ),
            // Regions — shallow (big) first, deep (specific) last = on top.
            for (final r in screen.regions)
              _RegionOverlay(
                region: r,
                isDragActive: _dragOrigin != null,
                onHover: (reg) => setState(() => _hover = reg),
                onUnhover: () => setState(() {
                  if (_hover == r) _hover = null;
                }),
                onRightClick: (ctx, pos, reg) => _openRegionMenu(ctx, pos, reg),
                onShiftDragStart: (reg, pos) => _shiftDragStart(reg, pos),
                onShiftDragMove: (pos) => _shiftDragMove(pos),
                onShiftDragEnd: () => _shiftDragEnd(),
              ),
            // Hover outline (drawn above all regions).
            if (_hover != null)
              Positioned(
                left: _hover!.rect.x,
                top: _hover!.rect.y,
                width: _hover!.rect.w,
                height: _hover!.rect.h,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
              ),
            // Move preview.
            if (dragging && _selected != null)
              Positioned(
                left: _selected!.rect.x + _dragDelta.dx,
                top: _selected!.rect.y + _dragDelta.dy,
                width: _selected!.rect.w,
                height: _selected!.rect.h,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.blue, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _shiftDragStart(ScreenRegion r, Offset screenPos) {
    setState(() {
      _selected = r;
      _dragRegion = r;
      _dragOrigin = screenPos;
      _dragDelta = Offset.zero;
    });
  }

  void _shiftDragMove(Offset screenPos) {
    if (_dragOrigin == null) return;
    setState(() {
      _dragDelta = screenPos - _dragOrigin!;
    });
  }

  void _shiftDragEnd() {
    final r = _dragRegion;
    final delta = _dragDelta;
    setState(() {
      _dragRegion = null;
      _dragOrigin = null;
      _dragDelta = Offset.zero;
    });
    if (r == null || delta.distance < 8) return;
    _applyOp(VisualOp(
      kind: VisualOpKind.move,
      region: r,
      screenRoute: _currentScreen().route,
      dx: delta.dx,
      dy: delta.dy,
    ));
  }

  Widget _statusBar(CapturedScreen screen) {
    final hover = _hover;
    return Container(
      height: 26,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        Icon(
          hover == null ? Icons.touch_app_outlined : Icons.crop_square,
          size: 13,
          color: Theme.of(context).hintColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hover == null
                ? 'Hover a widget to inspect it · right-click to edit · shift+drag to move (spacing)'
                : _describe(hover),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        Text(
          '${screen.regions.length} widgets',
          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
        ),
        const SizedBox(width: 10),
      ]),
    );
  }

  String _describe(ScreenRegion r) {
    final src = r.hasSource ? '  ·  ${r.sourceFile}:${r.sourceLine}' : '';
    final txt = r.text != null ? '  “${r.text}”' : '';
    final color = r.colorHex != null ? '  ·  ${r.colorHex}' : '';
    return '${r.label ?? r.widgetType}$txt$color$src';
  }

  Widget _sidePanel(BuildContext context, CapturedScreen screen) {
    final theme = Theme.of(context);
    return Column(children: [
      // Inspector.
      Expanded(
        flex: 3,
        child: _selected == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Right-click a widget on the canvas to inspect and edit it.',
                    style: TextStyle(
                        fontSize: 12, color: theme.hintColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _inspector(_selected!),
      ),
      const Divider(height: 1),
      // Ops log.
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('Edit history', style: theme.textTheme.titleSmall),
            ),
            Expanded(
              child: _records.isEmpty
                  ? Center(
                      child: Text('No edits yet.',
                          style: TextStyle(
                              fontSize: 12, color: theme.hintColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _records.length,
                      itemBuilder: (context, i) {
                        final rec = _records[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: rec.ok
                                ? theme.colorScheme.surfaceContainerLow
                                : theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(children: [
                            Icon(
                              rec.ok
                                  ? Icons.check_circle_outline
                                  : Icons.replay,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rec.opSummary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  if (rec.detail != null)
                                    Text(
                                      rec.detail!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                            if (rec.ok && i == 0 &&
                                _undoStore.containsKey(rec.id))
                              IconButton(
                                icon: const Icon(Icons.undo, size: 15),
                                tooltip: 'Undo this edit',
                                onPressed: () => _undo(rec),
                              ),
                          ]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _inspector(ScreenRegion r) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          Expanded(
            child: Text(
              r.label ?? r.widgetType,
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (r.hasSource)
            Tooltip(
              message: 'Open in the code editor',
              child: IconButton(
                icon: const Icon(Icons.code, size: 16),
                tooltip: 'View code',
                onPressed: () => _viewCode(r),
              ),
            ),
        ]),
        _kv('Type', r.widgetType),
        if (r.text != null) _kv('Text', r.text!),
        if (r.colorHex != null)
          Row(children: [
            const SizedBox(width: 34),
            SizedBox(
              width: 14,
              height: 14,
              child: ColoredBox(
                color: _parseColor(r.colorHex!),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(r.colorHex!,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11)),
          ]),
        _kv('Box',
            '${r.rect.x.round()},${r.rect.y.round()} ${r.rect.w.round()}×${r.rect.h.round()}'),
        if (r.hasSource) _kv('Source', '${r.sourceFile}:${r.sourceLine}'),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _actionBtn(Icons.color_lens, 'Color', () => _colorDialog(r)),
          _actionBtn(Icons.text_fields, 'Text', () => _textDialog(r)),
          _actionBtn(Icons.image_outlined, 'Insert image',
              () => _imageDialog(r, VisualOpKind.insertImage)),
          _actionBtn(Icons.photo_outlined, 'Replace image',
              () => _imageDialog(r, VisualOpKind.replaceImage)),
        ]),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(k, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: _busy ? null : onTap,
    );
  }

  ui.Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return ui.Color(
      int.parse(h.length == 8 ? h : 'FF$h', radix: 16),
    );
  }
}

/// A pickable region overlay.
class _RegionOverlay extends StatefulWidget {
  const _RegionOverlay({
    required this.region,
    required this.isDragActive,
    required this.onHover,
    required this.onUnhover,
    required this.onRightClick,
    required this.onShiftDragStart,
    required this.onShiftDragMove,
    required this.onShiftDragEnd,
  });

  final ScreenRegion region;
  final bool isDragActive;
  final ValueChanged<ScreenRegion?> onHover;
  final VoidCallback onUnhover;
  final void Function(BuildContext, Offset, ScreenRegion) onRightClick;
  final void Function(ScreenRegion, Offset) onShiftDragStart;
  final ValueChanged<Offset> onShiftDragMove;
  final VoidCallback onShiftDragEnd;

  @override
  State<_RegionOverlay> createState() => _RegionOverlayState();
}

class _RegionOverlayState extends State<_RegionOverlay> {
  bool _dragging = false;

  bool get _shiftDown => HardwareKeyboard.instance.isShiftPressed;

  /// Region-local → screen-space position.
  Offset _screenPos(PointerEvent e) =>
      e.localPosition + Offset(widget.region.rect.x, widget.region.rect.y);

  @override
  Widget build(BuildContext context) {
    final r = widget.region;
    return Positioned(
      left: r.rect.x,
      top: r.rect.y,
      width: r.rect.w,
      height: r.rect.h,
      child: MouseRegion(
        onEnter: (_) => widget.onHover(r),
        onExit: (_) {
          if (!_dragging) widget.onUnhover();
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if ((e.buttons & kSecondaryButton) != 0) {
              widget.onRightClick(context, e.position, r);
              return;
            }
            if (!_shiftDown) return;
            if ((e.buttons & kPrimaryButton) == 0) return;
            _dragging = true;
            widget.onShiftDragStart(r, _screenPos(e));
          },
          onPointerMove: (e) {
            if (_dragging) widget.onShiftDragMove(_screenPos(e));
          },
          onPointerUp: (e) {
            if (_dragging) {
              _dragging = false;
              widget.onShiftDragEnd();
            }
          },
          onPointerCancel: (e) {
            if (_dragging) {
              _dragging = false;
              widget.onShiftDragEnd();
            }
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16),
      const SizedBox(width: 10),
      Text(label),
    ]);
  }
}

class _ColorDialog extends StatelessWidget {
  const _ColorDialog({required this.current, required this.onPick});
  final String? current;
  final ValueChanged<String> onPick;

  static const _swatches = <String>[
    '#1E1B4B', '#312E81', '#4C1D95', '#134E4A', '#14532D',
    '#7F1D1D', '#713F12', '#422006', '#1F2937', '#111827',
    '#FFFFFF', '#F9FAFB', '#E5E7EB', '#D1D5DB', '#FDE68A',
    '#FCA5A5', '#BBF7D0', '#BFDBFE', '#FBCFE8', '#DDD6FE',
    '#F59E0B', '#EF4444', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: current ?? '');
    return StatefulBuilder(
      builder: (context, setDlg) => AlertDialog(
        title: const Text('Change color'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.count(
                crossAxisCount: 8,
                shrinkWrap: true,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final hex in _swatches)
                    GestureDetector(
                      onTap: () => setDlg(() {}),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          color: VisualEditorHelpers.parse(hex),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: (current ?? '').toUpperCase() ==
                                      hex.toUpperCase()
                                  ? Colors.blue
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'or type a hex (#RRGGBB)',
                      isDense: true,
                    ),
                  ),
                ),
              ],),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              final hex = v.startsWith('#') ? v : '#$v';
              if (VisualEditorHelpers.validHex(hex)) {
                Navigator.pop(context);
                onPick(hex.toUpperCase());
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class VisualEditorHelpers {
  static bool validHex(String s) =>
      RegExp(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(s);

  static ui.Color parse(String hex) {
    final h = hex.replaceAll('#', '');
    return ui.Color(int.parse(
        h.length >= 8 ? h : 'FF$h',
        radix: 16));
  }
}
