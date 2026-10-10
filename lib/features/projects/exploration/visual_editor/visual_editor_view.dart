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
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../infrastructure/workspace/git/git_engine_provider.dart';
import '../../../../infrastructure/workspace/workspace_provider.dart';
import '../draggable_divider.dart';
import 'code_applier.dart';
import 'deterministic_edit_ops.dart';
import 'live_preview_service.dart';
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

  /// Set when a re-capture is requested while one is already running — a full
  /// catch-up pass is re-armed so quick successive edits always converge.
  bool _recapturePending = false;
  final List<VisualEditRecord> _records = [];

  /// In-memory undo store: recordId → file → original bytes.
  final Map<int, Map<String, List<int>>> _undoStore = {};
  int _capturedRevision = -1;

  /// Instant canvas overlays for applied edits — painted over the (stale)
  /// screenshot the moment an op lands, so the change is visible in real
  /// time; cleared when the true re-capture replaces it with a fresh capture.
  /// Keyed by region id.
  final Map<String, _OptOverlay> _optimistic = {};
  bool _loading = true;
  String? _cacheDirPath;
  ScreenRegion? _dragRegion;
  // Drag-resizable inner panels (screens rail, inspector).
  double _railW = 132;
  double _inspW = 292;
  // Live preview (phase 2).
  LivePreviewSession? _live;
  bool _liveStarting = false;
  String? _liveStage;
  double _liveViewW = 0;
  double _liveViewH = 0;
  StreamSubscription<Map<String, dynamic>>? _liveSub;
  ScreenRegion? _liveHover;

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
      ScreenMap? map = force
          ? null
          : await loadCachedScreenMap(projectId, head);
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
      final resolved = await _resolveSources(map);
      _capturedRevision = ref.read(workspaceRevisionProvider(projectId));
      _cacheDirPath = (await cacheDir(projectId, head)).path;
      setState(() {
        _map = resolved;
        _optimistic.clear(); // a fresh full capture supersedes any pre-paints
        _loading = false;
        _screenIdx = 0;
      });
    } catch (e) {
      print(
        '[VisualEditor] capture failed for project ${widget.projectId}: $e',
      );
      if (e is ScreenMapError && e.log.isNotEmpty) {
        final lines = e.log.split('\n');
        final tail = lines.length > 40
            ? lines.sublist(lines.length - 40)
            : lines;
        print('[VisualEditor] harness log tail:\n${tail.join('\n')}');
      }
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
  Future<ScreenMap> _resolveSources(ScreenMap map) async {
    final index = await SourceIndex.build(
      await ref.read(workspaceFsProvider(widget.projectId).future),
    );
    final screens = <CapturedScreen>[];
    for (final s in map.screens) {
      final regions = <ScreenRegion>[];
      for (final r in s.regions) {
        final loc = index.locate(s.route, r);
        regions.add(loc == null ? r : r.copyWithSource(loc.$1, loc.$2));
      }
      screens.add(
        CapturedScreen(
          route: s.route,
          label: s.label,
          pngFile: s.pngFile,
          width: s.width,
          height: s.height,
          regions: regions,
          error: s.error,
        ),
      );
    }
    return ScreenMap(
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
      final isImageOp =
          op.kind == VisualOpKind.insertImage ||
          op.kind == VisualOpKind.replaceImage ||
          op.kind == VisualOpKind.setBackground;
      if (isImageOp) {
        if (await ws.exists('/pubspec.yaml')) {
          originals['/pubspec.yaml'] = await ws.readBytes('/pubspec.yaml');
        }
      }

      // Image ops: the user picked a host file; copy its bytes into the
      // workspace assets first.
      if (isImageOp &&
          op.assetPath != null &&
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
      if (outcome.status == OpStatus.applied) {
        // Merge the region-file + pubspec originals with the ACTUAL touched
        // file(s) the applier reported — for a cross-file route reorder that
        // is the routes map, not the page the user pointed at.
        final undoFiles = {...originals, ...outcome.fileOriginals};
        if (undoFiles.isNotEmpty) _undoStore[rec.id] = undoFiles;
      }
      final repeatNote =
          outcome.status == OpStatus.applied ? _repeatNote(op) : null;
      _toast(
        switch (outcome.status) {
          OpStatus.applied => repeatNote == null
            ? 'Applied ✓ — re-capturing screens…'
            : 'Applied ✓ — $repeatNote — re-capturing…',
          OpStatus.rolledBack =>
            'Rolled back (would not compile): ${outcome.reason ?? ''}',
          OpStatus.needsAgent => 'Sent to the assistant — review & send in chat',
        },
        ok: outcome.status == OpStatus.applied,
      );

      if (outcome.status == OpStatus.needsAgent) {
        ref.read(pendingEditorPromptProvider(projectId).notifier).state =
            outcome.agentPrompt;
        widget.onOpenChat();
        return;
      }

      if (outcome.status == OpStatus.applied) {
        // Instant visual feedback: pre-paint the change on the canvas so the
        // user sees it NOW; the true re-capture replaces it shortly after.
        final ov = _optimisticFor(op);
        if (ov != null) {
          setState(() => _optimistic[op.region.id] = ov);
        }
        unawaited(_recapture(route: op.screenRoute));
        // Live preview (phase 2): rebuild the running web app and reload the
        // browser so the user sees the change on the live app.
        final live = _live;
        if (live != null && !live.isRebuilding) {
          unawaited(live.rebuildAndReload());
        }
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Edit failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// When this region's source widget renders MULTIPLE times on this screen
  /// (a list / for-loop), a one-line edit changes ALL of them — tell the user
  /// so "I recoloured one but they all changed" isn't a surprise.
  String? _repeatNote(VisualOp op) {
    // Move / reorder / image ops change ONE target (the item the user
    // pointed at), even when that item's source line is shared by many widgets
    // (e.g. a `for`-loop menu) — so "applies to all of them" would be a lie.
    // Only the style/text ops genuinely broadcast to every shared instance.
    if (op.kind == VisualOpKind.move ||
        op.kind == VisualOpKind.reorder ||
        op.kind == VisualOpKind.insertImage ||
        op.kind == VisualOpKind.replaceImage) {
      return null;
    }
    final f = op.region.sourceFile;
    final l = op.region.sourceLine;
    if (f == null || l == null) return null;
    final screen = _map?.screens
        .where((s) => s.route == op.screenRoute)
        .cast<CapturedScreen?>()
        .firstWhere((s) => s != null, orElse: () => null);
    if (screen == null) return null;
    final count = screen.regions
        .where((r) => r.sourceFile == f && r.sourceLine == l)
        .length;
    if (count > 1) {
      return 'this element repeats $count×, so the change applies to all of them';
    }
    return null;
  }

  /// The instant canvas overlay for a just-applied [op] — or null when there
  /// is nothing sensible to pre-paint (spacing / image ops).
  _OptOverlay? _optimisticFor(VisualOp op) {
    final r = op.region.rect;
    switch (op.kind) {
      case VisualOpKind.setColor:
        final hex = op.colorHex ?? '';
        if (!VisualEditorHelpers.validHex(hex)) return null;
        final isText =
            op.region.widgetType.contains('RenderParagraph') ||
            op.region.text != null;
        return _OptOverlay(
          r,
          VisualEditorHelpers.parse(hex),
          !isText,
          op.screenRoute,
        );
      case VisualOpKind.setText:
        return _OptOverlay(
          r,
          Theme.of(context).colorScheme.primary,
          false,
          op.screenRoute,
        );
      case VisualOpKind.move:
      case VisualOpKind.setPadding:
      case VisualOpKind.insertImage:
      case VisualOpKind.replaceImage:
      case VisualOpKind.setBackground:
      case VisualOpKind.clearBackground:
      case VisualOpKind.reorder:
        return null;
    }
  }

  /// Re-run the harness after a change so the canvas reflects the new code.
  /// When [route] is given, only that screen is re-pumped (the rest are
  /// seeded from the previous capture) — much faster; falls back to a full
  /// capture if the single-screen pass can't run.
  Future<void> _recapture({String? route}) async {
    if (_recapturing) {
      _recapturePending = true; // a catch-up full pass will run when this one
      return; // finishes, so this edit isn't silently skipped
    }
    setState(() => _recapturing = true);
    try {
      final projectId = widget.projectId;
      final ws = await ref.read(workspaceFsProvider(projectId).future);
      final git = await ref.read(gitEngineProvider(projectId).future);
      final head = (await git.headOid())?.substring(0, 7) ?? '';
      Future<ScreenMap> full() => buildScreenMap(
        ws: ws,
        projectId: projectId,
        head: head,
        onProgress: (s) {
          if (mounted && _map != null) setState(() {}); // no-op, keep alive
        },
      );
      ScreenMap map;
      // SAFETY NET: a single-screen recapture must never REDUCE the number of
      // screens we're showing (a lost seed would collapse the whole map to one
      // screen — the "only 1 page open" bug). If it does, do a full capture.
      final prevCount = _map?.screens.length ?? 0;
      if (route != null) {
        try {
          map = await recaptureOneScreen(
            ws: ws,
            projectId: projectId,
            head: head,
            route: route,
            onProgress: (s) {
              if (mounted && _map != null) setState(() {});
            },
          );
          if (map.screens.length < prevCount) {
            print(
              '[ScreenMap] recapture produced ${map.screens.length} screens, '
              'fewer than the current $prevCount — falling back to a full '
              'capture so we never lose the other screens.',
            );
            map = await full();
          }
        } catch (_) {
          map = await full(); // fall back to a full re-capture
        }
      } else {
        map = await full();
      }
      if (!mounted) return;
      final resolved = await _resolveSources(map);
      final newCache = (await cacheDir(projectId, head)).path;
      setState(() {
        _map = resolved;
        _cacheDirPath = newCache; // follow the new HEAD's cache dir (stale otherwise)
        // Clear only the overlays for the screen(s) now freshly captured: a
        // single-screen pass leaves the others (seeded) stale, so their
        // pre-paints stay visible until they too are re-captured.
        if (route == null) {
          _optimistic.clear();
        } else {
          _optimistic.removeWhere((_, ov) => ov.route == route);
        }
        _capturedRevision = ref.read(workspaceRevisionProvider(projectId));
      });
      _toast('Screens refreshed ✓');
    } catch (e) {
      if (mounted) _toast('Re-capture failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _recapturing = false);
      if (_recapturePending && mounted) {
        _recapturePending = false;
        unawaited(_recapture()); // full pass to converge every screen
      }
    }
  }

  Future<void> _undo(VisualEditRecord rec) async {
    final originals = _undoStore[rec.id];
    if (originals == null) {
      _toast(
        'Nothing to undo in this session (restart-safe undo is coming).',
        ok: false,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final ws = await ref.read(workspaceFsProvider(widget.projectId).future);
      final git = await ref.read(gitEngineProvider(widget.projectId).future);
      for (final e in originals.entries) {
        await ws.writeBytes(e.key, e.value);
      }
      await git.commitAll(message: 'Undo visual edit: ${rec.opSummary}');
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
      _toast(
        'No source location found for this widget — ask the assistant instead.',
        ok: false,
      );
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
        const PopupMenuItem(
          value: 0,
          child: _MenuItem('View code', Icons.code),
        ),
        const PopupMenuItem(
          value: 1,
          child: _MenuItem('Change color…', Icons.color_lens),
        ),
        const PopupMenuItem(
          value: 2,
          child: _MenuItem('Edit text…', Icons.text_fields),
        ),
        const PopupMenuItem(
          value: 3,
          child: _MenuItem('Insert image…', Icons.image_outlined),
        ),
        const PopupMenuItem(
          value: 4,
          child: _MenuItem('Replace image…', Icons.photo_outlined),
        ),
        const PopupMenuItem(
          value: 5,
          child: _MenuItem('Set spacing…', Icons.toc),
        ),
        const PopupMenuItem(
          value: 6,
          child: _MenuItem('Set background…', Icons.wallpaper),
        ),
        const PopupMenuItem(
          value: 7,
          child: _MenuItem('Move up in list', Icons.arrow_upward),
        ),
        const PopupMenuItem(
          value: 8,
          child: _MenuItem('Move down in list', Icons.arrow_downward),
        ),
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
        case 5:
          _paddingDialog(r);
        case 6:
          _backgroundDialog(r);
        case 7:
          _applyReorder(r, up: true);
        case 8:
          _applyReorder(r, up: false);
      }
    });
  }

  void _applyReorder(ScreenRegion r, {required bool up}) {
    _applyOp(
      VisualOp(
        kind: VisualOpKind.reorder,
        region: r,
        screenRoute: _currentScreen().route,
        moveUp: up,
      ),
    );
  }

  void _colorDialog(ScreenRegion r, {bool allScope = false}) {
    final current = r.colorHex;
    showDialog<void>(
      context: context,
      builder: (ctx) => _ColorDialog(
        current: current,
        onPick: (hex) => _finishColor(r, hex, allScope: allScope),
      ),
    );
  }

  void _textDialog(ScreenRegion r, {bool allScope = false}) {
    // Pre-fill with the CURRENT rendered text — either the region's own
    // text (a Text/RenderParagraph) or the first text inside it (a box) — so
    // the user can confirm they picked the right element before retyping.
    final controller = TextEditingController(text: r.text ?? r.childText ?? '');
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
              final value = controller.text;
              Navigator.pop(ctx);
              _finishText(r, value, allScope: allScope);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  /// Screen-level "set background": the user can't click the app's own
  /// background to target it, so it lives in the region menu. Colour is
  /// applied deterministically to the page's Scaffold; an image background is
  /// a structural change and goes through the assistant.
  void _backgroundDialog(ScreenRegion r) {
    final pageFile = _pageFileFor(r);
    if (pageFile == null) {
      _toast(
        "Couldn't find this screen's page to change its background.",
        ok: false,
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Set screen background'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              _backgroundColorDialog(r, pageFile);
            },
            child: const Row(
              children: [
                Icon(Icons.color_lens),
                SizedBox(width: 10),
                Text('Colour…'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              _backgroundImageDialog(r, pageFile);
            },
            child: const Row(
              children: [
                Icon(Icons.image_outlined),
                SizedBox(width: 10),
                Text('Image…'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearBackgroundImage(r, pageFile);
            },
            child: const Row(
              children: [
                Icon(Icons.image_not_supported_outlined),
                SizedBox(width: 10),
                Text('Clear background image'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Remove this screen's background image (keeps its colour). Deterministic
  /// when the body is one of our `Stack`-wrapped image backgrounds. When the
  /// page has no background image at all, this is a benign no-op — we tell the
  /// user instead of (pointlessly) sending it to the assistant.
  Future<void> _clearBackgroundImage(ScreenRegion r, String pageFile) async {
    final projectId = widget.projectId;
    final ws = await ref.read(workspaceFsProvider(projectId).future);
    final bytes = await ws.readBytes(pageFile);
    final content = utf8.decode(bytes, allowMalformed: true);
    if (clearBackgroundImageEdit(content, anchor: 1) == null) {
      _toast('This screen has no background image to clear.');
      return;
    }
    final bg = ScreenRegion(
      id: 'bglr_${_screenIdx}',
      widgetType: 'Scaffold',
      rect: const RectBox(0, 0, 0, 0),
      label: 'Screen background',
      sourceFile: pageFile,
      sourceLine: 1,
    );
    _applyOp(
      VisualOp(
        kind: VisualOpKind.clearBackground,
        region: bg,
        screenRoute: _currentScreen().route,
      ),
    );
  }

  void _backgroundColorDialog(ScreenRegion r, String pageFile) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ColorDialog(
        current: null,
        title: 'Set screen background',
        onPick: (hex) => _finishBackground(r, pageFile, hex),
      ),
    );
  }

  void _backgroundImageDialog(ScreenRegion r, String pageFile) {
    var hostPath = '';
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> browse() async {
            try {
              final picked = await FilePicker.platform.pickFiles(
                dialogTitle: 'Choose a background image',
                type: FileType.image,
              );
              final path = picked?.files.single.path;
              if (path != null && mounted) {
                controller.text = path;
                setDlg(() => hostPath = path);
              }
            } catch (_) {/* cancelled */}
          }

          final trimmed = hostPath.trim();
          final exists =
              trimmed.isNotEmpty && File(_expandHome(trimmed)).existsSync();
          return AlertDialog(
            title: const Text('Set screen background image'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick a PNG/JPG to use as this screen’s background:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Image file',
                        ),
                        onChanged: (v) => setDlg(() => hostPath = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: browse,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Browse…'),
                    ),
                  ],
                ),
                if (trimmed.isNotEmpty && !exists)
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
                onPressed: exists
                    ? () {
                        Navigator.pop(ctx);
                        _applyBackgroundImage(pageFile, _expandHome(trimmed));
                      }
                    : null,
                child: const Text('Use image'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Set the screen background to an image. The host file is copied into the
  /// workspace assets + registered in pubspec by [_applyOp] (so the asset
  /// exists even if the deterministic wrap declines), then a deterministic
  /// Stack-wrap is attempted; only on decline does it fall back to the
  /// assistant — which now has the image in-workspace to reference.
  void _applyBackgroundImage(String pageFile, String hostPath) {
    final host = File(_expandHome(hostPath));
    if (!host.existsSync()) {
      _toast('Image not found: $hostPath', ok: false);
      return;
    }
    final bg = ScreenRegion(
      id: 'bgimg_${_screenIdx}',
      widgetType: 'Scaffold',
      rect: const RectBox(0, 0, 0, 0),
      label: 'Screen background',
      sourceFile: pageFile,
      sourceLine: 1,
    );
    _applyOp(
      VisualOp(
        kind: VisualOpKind.setBackground,
        region: bg,
        screenRoute: _currentScreen().route,
        assetPath: '/host:$hostPath',
      ),
    );
  }

  void _finishBackground(ScreenRegion r, String pageFile, String hex) {
    final bg = ScreenRegion(
      id: 'bg_${_screenIdx}',
      widgetType: 'Scaffold',
      rect: const RectBox(0, 0, 0, 0),
      label: 'Screen background',
      sourceFile: pageFile,
      sourceLine: 1,
    );
    _applyOp(
      VisualOp(
        kind: VisualOpKind.setBackground,
        region: bg,
        screenRoute: _currentScreen().route,
        colorHex: hex,
      ),
    );
  }

  /// The page (source) file for the current screen — the first resolved
  /// region's sourceFile, falling back to [r]'s own.
  String? _pageFileFor(ScreenRegion r) {
    for (final reg in _currentScreen().regions) {
      final f = reg.sourceFile;
      if (reg.hasSource && f != null) return f;
    }
    return r.sourceFile;
  }

  /// Single-region or (when the widget repeats across screens) ask scope.
  void _finishColor(ScreenRegion r, String hex, {bool allScope = false}) {
    final matches = _applyAllMatches(r);
    if (matches.isEmpty || allScope) {
      _applyOp(
        VisualOp(
          kind: VisualOpKind.setColor,
          region: r,
          screenRoute: _currentScreen().route,
          colorHex: hex,
        ),
      );
      return;
    }
    _askScope(
      r,
      matches.length,
      onSingle: () {
        _applyOp(
          VisualOp(
            kind: VisualOpKind.setColor,
            region: r,
            screenRoute: _currentScreen().route,
            colorHex: hex,
          ),
        );
      },
      onAll: () {
        _applyBatch(VisualOpKind.setColor, colorHex: hex);
      },
    );
  }

  void _finishText(ScreenRegion r, String value, {bool allScope = false}) {
    final matches = _applyAllMatches(r);
    if (matches.isEmpty || allScope) {
      _applyOp(
        VisualOp(
          kind: VisualOpKind.setText,
          region: r,
          screenRoute: _currentScreen().route,
          text: value,
        ),
      );
      return;
    }
    _askScope(
      r,
      matches.length,
      onSingle: () {
        _applyOp(
          VisualOp(
            kind: VisualOpKind.setText,
            region: r,
            screenRoute: _currentScreen().route,
            text: value,
          ),
        );
      },
      onAll: () {
        _applyBatch(VisualOpKind.setText, text: value);
      },
    );
  }

  void _askScope(
    ScreenRegion r,
    int count, {
    required VoidCallback onSingle,
    required VoidCallback onAll,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply to other screens?'),
        content: Text(
          'This widget ("${r.label ?? r.widgetType}") also appears on '
          '$count other screen${count == 1 ? '' : 's'}. Apply the change '
          'everywhere, or just here?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSingle();
            },
            child: const Text('Just this one'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAll();
            },
            child: Text('All $count screens'),
          ),
        ],
      ),
    );
  }

  /// Other regions across all screens that look like the same widget as the
  /// currently selected one (same label + text + color) — "apply to all".
  /// Returns (screen route, region) pairs.
  List<(String, ScreenRegion)> _applyAllMatches(ScreenRegion r) {
    final map = _map;
    if (map == null) return const [];
    final out = <(String, ScreenRegion)>[];
    final seen = <String>{};
    for (final s in map.screens) {
      if (s.route == _currentScreen().route) continue;
      for (final other in s.regions) {
        if (other.label != r.label || other.text != r.text) continue;
        if (other.colorHex != r.colorHex) continue;
        if (!other.hasSource) continue;
        final key = '${other.sourceFile}:${other.sourceLine}';
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add((s.route, other));
      }
    }
    return out;
  }

  /// Re-apply [kind] to every matching region on every other screen.
  /// Sequential; each op is individually committed and guarded.
  Future<void> _applyBatch(
    VisualOpKind kind, {
    String? colorHex,
    String? text,
  }) async {
    final r = _selected;
    if (_busy || r == null) return;
    final matches = _applyAllMatches(r);
    if (matches.isEmpty) return;
    setState(() => _busy = true);
    var okCount = 0;
    var failCount = 0;
    try {
      final ws = await ref.read(workspaceFsProvider(widget.projectId).future);
      final git = await ref.read(gitEngineProvider(widget.projectId).future);
      for (final (route, m) in matches) {
        if (!mounted) return;
        final op = VisualOp(
          kind: kind,
          region: m,
          screenRoute: route,
          colorHex: colorHex,
          text: text,
        );
        final outcome = await applyVisualOp(ws: ws, git: git, op: op);
        if (outcome.status == OpStatus.applied) {
          okCount++;
        } else {
          failCount++;
        }
      }
      if (!mounted) return;
      ref.read(workspaceRevisionProvider(widget.projectId).notifier).state++;
      _toast(
        'Applied to $okCount of ${matches.length} matching widgets'
        '${failCount > 0 ? ' — $failCount skipped (unsafe)' : ''}',
        ok: failCount == 0,
      );
      unawaited(_recapture());
      final live = _live;
      if (live != null && !live.isRebuilding) {
        unawaited(live.rebuildAndReload());
      }
    } catch (e) {
      if (mounted) _toast('Batch edit failed: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _imageDialog(ScreenRegion r, VisualOpKind kind) {
    final controller = TextEditingController();
    var hostPath = '';
    final isInsert = kind == VisualOpKind.insertImage;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Native OS file chooser — the desktop file explorer the user expects.
          Future<void> browse() async {
            try {
              final picked = await FilePicker.platform.pickFiles(
                dialogTitle: isInsert ? 'Choose an image to insert' : 'Choose a replacement image',
                type: FileType.image,
              );
              final path = picked?.files.single.path;
              if (path != null && mounted) {
                controller.text = path;
                setDlg(() => hostPath = path);
              }
            } catch (_) {/* user cancelled the chooser */}
          }

          final trimmed = hostPath.trim();
          final exists =
              trimmed.isNotEmpty && File(_expandHome(trimmed)).existsSync();
          return AlertDialog(
            title: Text(isInsert ? 'Insert image' : 'Replace image'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInsert
                      ? 'Pick a PNG/JPG on this machine to insert:'
                      : 'Pick a PNG/JPG to replace this image with:',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Image file',
                        ),
                        onChanged: (v) => setDlg(() => hostPath = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: browse,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Browse…'),
                    ),
                  ],
                ),
                if (trimmed.isNotEmpty && !exists)
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
                onPressed: exists
                    ? () {
                        // Expand any ~ so File() can actually find it (the old
                        // code passed a raw ~/… path to File and silently
                        // produced no image).
                        final p = _expandHome(trimmed);
                        Navigator.pop(ctx);
                        _applyOp(
                          VisualOp(
                            kind: kind,
                            region: r,
                            screenRoute: _currentScreen().route,
                            assetPath: '/host:$p',
                          ),
                        );
                      }
                    : null,
                child: const Text('Use image'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _paddingDialog(ScreenRegion r) {
    final controllers = List.generate(4, (_) => TextEditingController());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set spacing (padding)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pixels for top, right, bottom, left:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (label, c) in [
                  ('T', controllers[0]),
                  ('R', controllers[1]),
                  ('B', controllers[2]),
                  ('L', controllers[3]),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 64,
                      child: TextField(
                        controller: c,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: label,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final nums = controllers
                  .map((c) => double.tryParse(c.text.trim()))
                  .toList();
              if (nums.any((n) => n == null)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a number for each side.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              _applyOp(
                VisualOp(
                  kind: VisualOpKind.setPadding,
                  region: r,
                  screenRoute: _currentScreen().route,
                  padding: (nums[0]!, nums[1]!, nums[2]!, nums[3]!),
                ),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _live?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- live preview

  Future<void> _startLive() async {
    if (_live != null || _liveStarting) return;
    setState(() => _liveStarting = true);
    try {
      final session = await startLivePreview(
        ws: await ref.read(workspaceFsProvider(widget.projectId).future),
        onProgress: (s) {
          if (mounted) setState(() => _liveStage = s);
        },
      );
      if (!mounted) {
        await session.dispose();
        return;
      }
      _live = session;
      _liveSub = session.events.stream.listen(_onLiveEvent);
      setState(() {
        _liveStarting = false;
        _liveStage = null;
      });
      await openInBrowser(session.url);
      _toast(
        'Live preview running: ${session.url} — right-click widgets in the browser.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liveStarting = false;
        _liveStage = null;
      });
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Live preview failed'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SelectableText(e.toString()),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _stopLive() async {
    final s = _live;
    _live = null;
    await _liveSub?.cancel();
    _liveSub = null;
    setState(() {
      _liveHover = null;
      _liveStarting = false;
    });
    await s?.dispose();
  }

  /// Browser → studio events (hover/rightclick in CSS px; the harness
  /// captured at 1280×800, so scale proportionally).
  void _onLiveEvent(Map<String, dynamic> e) {
    final type = e['type'];
    if (!mounted) return;
    if (type == 'viewport') {
      _liveViewW = (e['w'] as num?)?.toDouble() ?? 0;
      _liveViewH = (e['h'] as num?)?.toDouble() ?? 0;
      return;
    }
    final map = _map;
    if (map == null || _liveViewW <= 0 || _liveViewH <= 0) return;
    final screen = _currentScreen();
    final num? x = e['x'] is num ? e['x'] as num : null;
    final num? y = e['y'] is num ? e['y'] as num : null;
    if (x == null || y == null) return;
    // CSS px → harness logical px.
    final sx = x.toDouble() * (1280 / _liveViewW);
    final sy = y.toDouble() * (800 / _liveViewH);
    final point = Offset(sx, sy);
    final region = _hitTest(screen, point);
    if (type == 'hover') {
      final live = _live;
      if (region == null) {
        _liveHover = null;
        live?.send({'type': 'clear'});
      } else if (!identical(region, _liveHover)) {
        _liveHover = region;
        final scale = _liveViewW / 1280;
        live?.send({
          'type': 'highlight',
          'rects': [
            {
              'x': region.rect.x * scale,
              'y': region.rect.y * scale,
              'w': region.rect.w * scale,
              'h': region.rect.h * scale,
            },
          ],
        });
      }
      if (mounted) setState(() {});
      return;
    }
    if (type == 'rightclick') {
      if (region == null) {
        _toast(
          'No recognizable widget at that spot in the live app.',
          ok: false,
        );
        return;
      }
      setState(() => _selected = region);
      _showLivePickDialog(region);
    }
  }

  /// Deepest (smallest) region containing [p], ignoring near-fullscreen ones.
  ScreenRegion? _hitTest(CapturedScreen screen, Offset p) {
    ScreenRegion? best;
    var bestArea = double.infinity;
    final screenArea = screen.width * screen.height;
    for (final r in screen.regions) {
      if (r.rect.area > screenArea * 0.85) continue;
      if (!r.rect.contains(p.dx, p.dy)) continue;
      if (r.rect.area < bestArea) {
        bestArea = r.rect.area;
        best = r;
      }
    }
    return best;
  }

  void _showLivePickDialog(ScreenRegion r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Picked: ${r.label ?? r.widgetType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.text != null)
              Text('“${r.text}”', style: const TextStyle(fontSize: 13)),
            if (r.colorHex != null)
              Text(
                r.colorHex!,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            if (r.hasSource)
              Text(
                '${r.sourceFile}:${r.sourceLine}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionBtn(Icons.code, 'View code', () {
                  Navigator.pop(ctx);
                  _viewCode(r);
                }),
                _actionBtn(Icons.color_lens, 'Change color…', () {
                  Navigator.pop(ctx);
                  _colorDialog(r);
                }),
                _actionBtn(Icons.text_fields, 'Edit text…', () {
                  Navigator.pop(ctx);
                  _textDialog(r);
                }),
                _actionBtn(Icons.image_outlined, 'Insert image…', () {
                  Navigator.pop(ctx);
                  _imageDialog(r, VisualOpKind.insertImage);
                }),
                _actionBtn(Icons.photo_outlined, 'Replace image…', () {
                  Navigator.pop(ctx);
                  _imageDialog(r, VisualOpKind.replaceImage);
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
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
              if (_liveStarting)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _liveStage ?? 'Starting live preview…',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                ),
              if (_live == null)
                OutlinedButton.icon(
                  onPressed: _liveStarting || _busy || _recapturing
                      ? null
                      : _startLive,
                  icon: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: const Text('Live preview'),
                )
              else ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => _stopLive(),
                  icon: const Icon(Icons.stop_outlined, size: 16),
                  label: Text('Live on :${_live!.port}'),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  tooltip: 'Open in browser',
                  onPressed: () => openInBrowser(_live!.url),
                ),
              ],
              const SizedBox(width: 6),
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
                  onPressed: _busy || _recapturing
                      ? null
                      : () => _load(force: true),
                  tooltip: 'Re-capture screens',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Screens rail (drag-resizable).
              SizedBox(
                width: _railW,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: map.screens.length,
                  itemBuilder: (context, i) => _railTile(i),
                ),
              ),
              DraggableVerticalDivider(
                onDelta: (dx) => setState(() {
                  _railW = (_railW + dx).clamp(96.0, 320.0);
                }),
              ),
              // Canvas + status bar.
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: screen.error != null && screen.pngFile.isEmpty
                          ? _screenError(screen)
                          : _canvas(screen),
                    ),
                    _statusBar(screen),
                  ],
                ),
              ),
              DraggableVerticalDivider(
                onDelta: (dx) => setState(() {
                  _inspW = (_inspW + dx).clamp(220.0, 560.0);
                }),
              ),
              // Inspector + ops log (drag-resizable).
              SizedBox(width: _inspW, child: _sidePanel(context, screen)),
            ],
          ),
        ),
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
                        child: Icon(Icons.broken_image_outlined, size: 18),
                      )
                    : Image.file(
                        png,
                        width: 112,
                        height: 66,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    if (s.error != null)
                      const Icon(
                        Icons.warning_amber,
                        size: 12,
                        color: Colors.orange,
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
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
            Text(
              'This screen could not be captured.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
          child: MouseRegion(
            onExit: (_) {
              if (_hover != null) setState(() => _hover = null);
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerMove: (e) => _canvasPointerMove(screen, e.localPosition),
              onPointerDown: (e) => _canvasPointerDown(screen, e),
              onPointerUp: (_) => _shiftDragEnd(),
              onPointerCancel: (_) => _shiftDragEnd(),
              child: Stack(
                children: [
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
                  // Optimistic edit overlays — the real-time layer painted the
                  // instant an op lands, until the true re-capture replaces it.
                  ...screen.regions.where((r) => _optimistic[r.id] != null).map(
                    (r) {
                      final ov = _optimistic[r.id]!;
                      return Positioned(
                        left: ov.rect.x,
                        top: ov.rect.y,
                        width: ov.rect.w,
                        height: ov.rect.h,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ov.solid
                                ? ov.color.withValues(alpha: 0.9)
                                : ov.color.withValues(alpha: 0.32),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Hover outline (single, from canvas-level hit testing).
                  if (_hover != null)
                    Positioned(
                      left: _hover!.rect.x,
                      top: _hover!.rect.y,
                      width: _hover!.rect.w,
                      height: _hover!.rect.h,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The most specific (smallest) region containing [p] — overlapping
  /// regions (a text box inside its container) never fight over hover.
  ScreenRegion? _hitRegion(CapturedScreen screen, Offset p) {
    ScreenRegion? best;
    for (final r in screen.regions) {
      final rc = r.rect;
      if (p.dx < rc.x || p.dy < rc.y) continue;
      if (p.dx > rc.x + rc.w || p.dy > rc.y + rc.h) continue;
      if (best == null || rc.area < best.rect.area) best = r;
    }
    return best;
  }

  void _canvasPointerMove(CapturedScreen screen, Offset p) {
    if (_dragOrigin != null) {
      _shiftDragMove(p);
      return;
    }
    final hit = _hitRegion(screen, p);
    if (!identical(hit, _hover)) {
      setState(() => _hover = hit);
    }
  }

  void _canvasPointerDown(CapturedScreen screen, PointerEvent e) {
    final p = e.localPosition;
    if ((e.buttons & kSecondaryButton) != 0) {
      final r = _hitRegion(screen, p);
      if (r != null) _openRegionMenu(context, e.position, r);
      return;
    }
    if ((e.buttons & kPrimaryButton) != 0 &&
        HardwareKeyboard.instance.isShiftPressed) {
      final r = _hitRegion(screen, p);
      if (r != null) _shiftDragStart(r, p);
    }
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
    // Reset SYNCHRONOUSLY (not in the deferred setState) so a duplicate
    // pointerUp + pointerCancel — both of which call this — can't double-apply
    // the move (the item jumping by two / looking like it "applied to all").
    _dragRegion = null;
    _dragOrigin = null;
    _dragDelta = Offset.zero;
    if (mounted) setState(() {});
    if (r == null || delta.distance < 8) return;
    _applyOp(
      VisualOp(
        kind: VisualOpKind.move,
        region: r,
        screenRoute: _currentScreen().route,
        dx: delta.dx,
        dy: delta.dy,
      ),
    );
  }

  Widget _statusBar(CapturedScreen screen) {
    final hover = _hover;
    return Container(
      height: 26,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(
            hover == null ? Icons.touch_app_outlined : Icons.crop_square,
            size: 13,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _liveHover != null
                  ? 'In the live app: ${_describe(_liveHover!)}  —  right-click to edit'
                  : hover == null
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
        ],
      ),
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
    return Column(
      children: [
        // Inspector.
        Expanded(
          flex: 3,
          child: _selected == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Right-click a widget on the canvas to inspect and edit it.',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
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
                        child: Text(
                          'No edits yet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      )
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
                            child: Row(
                              children: [
                                Icon(
                                  rec.ok
                                      ? Icons.check_circle_outline
                                      : Icons.replay,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (rec.ok &&
                                    i == 0 &&
                                    _undoStore.containsKey(rec.id))
                                  IconButton(
                                    icon: const Icon(Icons.undo, size: 15),
                                    tooltip: 'Undo this edit',
                                    onPressed: () => _undo(rec),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inspector(ScreenRegion r) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
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
          ],
        ),
        _kv('Type', r.widgetType),
        if (r.text != null) _kv('Text', r.text!),
        if (r.colorHex != null)
          Row(
            children: [
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
              Text(
                r.colorHex!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ),
        _kv(
          'Box',
          '${r.rect.x.round()},${r.rect.y.round()} ${r.rect.w.round()}×${r.rect.h.round()}',
        ),
        if (r.hasSource) _kv('Source', '${r.sourceFile}:${r.sourceLine}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _actionBtn(Icons.color_lens, 'Color', () => _colorDialog(r)),
            _actionBtn(Icons.text_fields, 'Text', () => _textDialog(r)),
            _actionBtn(Icons.toc, 'Spacing', () => _paddingDialog(r)),
            _actionBtn(
              Icons.image_outlined,
              'Insert image',
              () => _imageDialog(r, VisualOpKind.insertImage),
            ),
            _actionBtn(
              Icons.photo_outlined,
              'Replace image',
              () => _imageDialog(r, VisualOpKind.replaceImage),
            ),
            if (r.colorHex != null && _applyAllMatches(r).isNotEmpty)
              _actionBtn(
                Icons.devices,
                'Color → all ${_applyAllMatches(r).length}',
                () => _colorDialog(r, allScope: true),
              ),
            if (r.text != null && _applyAllMatches(r).isNotEmpty)
              _actionBtn(
                Icons.devices,
                'Text → all ${_applyAllMatches(r).length}',
                () => _textDialog(r, allScope: true),
              ),
          ],
        ),
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
            child: Text(
              k,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontSize: 11)),
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
    return ui.Color(int.parse(h.length == 8 ? h : 'FF$h', radix: 16));
  }
}

/// (Region picking now happens at the CANVAS level — see
/// `_canvasPointerMove`/`_canvasPointerDown`/`_hitRegion` — which gives one
/// deterministic "most specific region under the pointer" instead of every
/// overlapping region's own MouseRegion fighting over hover.)

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 16), const SizedBox(width: 10), Text(label)],
    );
  }
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({
    super.key,
    required this.current,
    required this.onPick,
    this.title = 'Change color',
  });
  final String? current;
  final ValueChanged<String> onPick;
  final String title;

  static const _swatches = <String>[
    '#1E1B4B',
    '#312E81',
    '#4C1D95',
    '#134E4A',
    '#14532D',
    '#7F1D1D',
    '#713F12',
    '#422006',
    '#1F2937',
    '#111827',
    '#FFFFFF',
    '#F9FAFB',
    '#E5E7EB',
    '#D1D5DB',
    '#FDE68A',
    '#FCA5A5',
    '#BBF7D0',
    '#BFDBFE',
    '#FBCFE8',
    '#DDD6FE',
    '#F59E0B',
    '#EF4444',
    '#10B981',
    '#3B82F6',
    '#8B5CF6',
    '#EC4899',
  ];

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  int _rgb = 0x3B82F6; // RRGGBB
  double _alpha = 1.0; // 0..1
  bool _noFill = false;
  late final TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    if (c != null) {
      final h = c.replaceAll('#', '').toUpperCase();
      if (h.length == 8) {
        final a = int.tryParse(h.substring(0, 2), radix: 16) ?? 255;
        _alpha = a / 255;
        _rgb = int.tryParse(h.substring(2), radix: 16) ?? _rgb;
      } else if (h.length == 6) {
        _alpha = 1.0;
        _rgb = int.tryParse(h, radix: 16) ?? _rgb;
      }
    }
    _noFill = _alpha <= 0;
    _hexCtrl = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String get _rgbHex => _rgb.toRadixString(16).padLeft(6, '0').toUpperCase();

  String _buildHex() {
    if (_noFill || _alpha <= 0) return '#00000000';
    if (_alpha >= 1) return '#$_rgbHex';
    final a = (_alpha * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$a$_rgbHex';
  }

  /// Parse hex typed by the user (#RRGGBB or #AARRGGBB) into rgb + alpha.
  void _applyHexText(String raw) {
    final h = raw.trim().replaceAll('#', '').toUpperCase();
    if (h.isEmpty) return;
    final rgbPart =
        h.length >= 6 ? h.substring(h.length - 6) : h.padLeft(6, '0');
    final rgbVal = int.tryParse(rgbPart, radix: 16);
    if (rgbVal == null) return;
    setState(() {
      _rgb = rgbVal;
      if (h.length == 8) {
        final a = int.tryParse(h.substring(0, 2), radix: 16);
        _alpha = (a ?? 255) / 255;
      } else {
        _alpha = 1.0;
      }
      _noFill = _alpha <= 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui.Color preview =
        _noFill ? Colors.transparent : Color(0xFF000000 | _rgb)
            .withValues(alpha: _alpha.clamp(0.0, 1.0));
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live preview over a checkerboard so transparency is visible.
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: const _Checkerboard(),
                        child: ColoredBox(color: preview),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        _noFill ? 'no fill' : _buildHex(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final hex in _ColorDialog._swatches)
                  GestureDetector(
                    // Swatches are opaque presets — a one-tap quick-apply.
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPick(hex);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        decoration: BoxDecoration(
                          color: VisualEditorHelpers.parse(hex),
                          border: Border.all(
                            color: hex.toUpperCase() == '#$_rgbHex'
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.opacity, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Slider(
                    value: _noFill ? 0 : _alpha,
                    min: 0,
                    max: 1,
                    onChanged: (v) =>
                        setState(() {
                          _alpha = v;
                          _noFill = v <= 0;
                        }),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(_alpha * 100).round()}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'No fill (fully transparent)',
                style: TextStyle(fontSize: 13),
              ),
              value: _noFill,
              onChanged: (v) => setState(() => _noFill = v ?? false),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _hexCtrl,
              onChanged: _applyHexText,
              decoration: const InputDecoration(
                labelText: 'hex (#RRGGBB or #AARRGGBB)',
                isDense: true,
              ),
            ),
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
            if (_hexCtrl.text.trim().isNotEmpty) {
              _applyHexText(_hexCtrl.text);
            }
            Navigator.pop(context);
            widget.onPick(_buildHex());
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// A small white/grey checkerboard, used behind the colour preview so a
/// transparent fill is visible against both light and dark content.
class _Checkerboard extends CustomPainter {
  const _Checkerboard();

  @override
  void paint(Canvas canvas, Size size) {
    const n = 12.0;
    final white = Paint()..color = const Color(0xFFFFFFFF);
    final grey = Paint()..color = const Color(0xFFCCCCCC);
    canvas.drawRect(Offset.zero & size, white);
    for (double y = 0; y < size.height; y += n) {
      for (double x = 0; x < size.width; x += n) {
        if ((((x / n).floor() + (y / n).floor()) & 1) == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, n, n), grey);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class VisualEditorHelpers {
  static bool validHex(String s) =>
      RegExp(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(s);

  static ui.Color parse(String hex) {
    final h = hex.replaceAll('#', '');
    return ui.Color(int.parse(h.length >= 8 ? h : 'FF$h', radix: 16));
  }
}

/// A transient paint applied to the canvas the instant an edit is applied —
/// the "real-time" layer that stands in for the screenshot until the true
/// re-capture lands. [solid] → near-opaque fill (a box's new background);
/// not-solid → a translucent tint (a text region's new glyph colour).
class _OptOverlay {
  const _OptOverlay(this.rect, this.color, this.solid, this.route);
  final RectBox rect;
  final Color color;
  final bool solid;
  final String route; // the screen this overlay belongs to
}
