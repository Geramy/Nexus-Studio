// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// PHASE 2 — LIVE PREVIEW for the Visual Editor: build the generated app for
/// web (debug), serve it on a loopback port with a small injected EDIT BRIDGE
/// (a script tag in the preview copy of index.html — the committed workspace
/// is never touched), and open it in the user's browser. The browser is the
/// canvas; this studio window is the tooling panel. The two talk over a
/// localhost WebSocket:
///
///   browser → studio: {type:hello|viewport|hover|rightclick, x?, y?, w?, h?}
///   studio → browser: {type:highlight, rects:[...]} | {type:clear} | {type:reload}
///
/// After a visual edit is committed, [LivePreviewSession.rebuildAndReload]
/// re-runs the (debug) web build and tells the browser to reload — the user
/// sees the change on the actually-running app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../infrastructure/build/workspace_materializer.dart';import '../../../../infrastructure/exec/captured_run.dart';
import '../../../../infrastructure/workspace/workspace.dart';
import 'screen_map_service.dart' show findFlutterAppDir;

/// A running live-preview session. Keep one per project while the preview is
/// open; [dispose] stops the server and releases the materialized copy.
class LivePreviewSession {
  LivePreviewSession._(this._server, this._mat, this._appDir, this.port);

  final HttpServer _server;
  final MaterializedWorkspace _mat;
  final String _appDir;
  final int port;
  final List<WebSocket> _sockets = [];
  bool _disposed = false;
  bool _rebuilding = false;

  String get url => 'http://127.0.0.1:$port/';

  /// Events coming from the bridge in the browser, decoded as JSON maps.
  final StreamController<Map<String, dynamic>> events =
      StreamController.broadcast();

  /// true while a rebuild-and-reload is in flight.
  bool get isRebuilding => _rebuilding;

  /// Studio → browser broadcast.
  void send(Map<String, dynamic> message) {
    final data = utf8.encode(jsonEncode(message));
    for (final s in List.of(_sockets)) {
      try {
        s.add(data);
      } catch (_) {}
    }
  }

  /// Re-run the debug web build (the committed code may have changed since
  /// the last build) and reload the browser.
  Future<void> rebuildAndReload({void Function(String)? onProgress}) async {
    if (_disposed || _rebuilding) return;
    _rebuilding = true;
    try {
      onProgress?.call('Rebuilding the web app…');
      final run = await runCaptured(
        'flutter pub get >/dev/null 2>&1; flutter build web --debug',
        workingDirectory: _appDir,
        timeout: const Duration(minutes: 15),
      );
      if (run.exitCode != 0) {
        events.add({'type': 'rebuildFailed', 'log': run.output});
        return;
      }
      onProgress?.call('Reloading the browser…');
      send({'type': 'reload'});
    } finally {
      _rebuilding = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _sockets) {
      try {
        await s.close();
      } catch (_) {}
    }
    _sockets.clear();
    try {
      await _server.close(force: true);
    } catch (_) {}
    try {
      await events.close();
    } catch (_) {}
    await _mat.dispose();
  }
}

/// The injected bridge. [port] is baked in at preview time. Kept small and
/// dependency-free; it only reports pointer events and renders highlight
/// boxes / reloads on command.
String _bridgeScript(int port) => '''
<script>
(function () {
  try {
    var ws = new WebSocket('ws://127.0.0.1:$port/ws');
    var layer = document.createElement('div');
    layer.style.cssText =
      'position:fixed;left:0;top:0;width:100%;height:100%;' +
      'pointer-events:none;z-index:2147483647;box-sizing:border-box;';
    function attach() { document.body.appendChild(layer); }
    if (document.body) attach();
    else document.addEventListener('DOMContentLoaded', attach);
    function send(m) { if (ws.readyState === 1) ws.send(JSON.stringify(m)); }
    ws.onopen = function () {
      send({type: 'hello'});
      send({type: 'viewport', w: innerWidth, h: innerHeight});
    };
    ws.onmessage = function (ev) {
      var m;
      try { m = JSON.parse(ev.data); } catch (e) { return; }
      if (m.type === 'highlight' && m.rects) {
        layer.innerHTML = '';
        for (var i = 0; i < m.rects.length; i++) {
          var r = m.rects[i];
          var d = document.createElement('div');
          d.style.cssText =
            'position:absolute;left:' + r.x + 'px;top:' + r.y + 'px;' +
            'width:' + r.w + 'px;height:' + r.h + 'px;' +
            'border:2px solid #4FC3F7;box-sizing:border-box;';
          layer.appendChild(d);
        }
      } else if (m.type === 'clear') {
        layer.innerHTML = '';
      } else if (m.type === 'reload') {
        location.reload();
      }
    };
    document.addEventListener('pointermove', function (e) {
      send({type: 'hover', x: e.clientX, y: e.clientY});
    });
    document.addEventListener('contextmenu', function (e) {
      send({type: 'rightclick', x: e.clientX, y: e.clientY});
    });
    window.addEventListener('resize', function () {
      send({type: 'viewport', w: innerWidth, h: innerHeight});
    });
  } catch (e) {}
})();
</script>
''';

/// Start a live preview for [ws]. Progress messages via [onProgress].
/// Throws a [LivePreviewError] with the build log on failure.
Future<LivePreviewSession> startLivePreview({
  required Workspace ws,
  void Function(String)? onProgress,
}) async {
  void stage(String s) => onProgress?.call(s);

  final materializer = WorkspaceMaterializer();
  final mat = await materializer.materialize(ws, tag: 'livepreview');
  HttpServer? server;
  try {
    final appDir = findFlutterAppDir(mat.path);
    if (appDir == null) {
      throw const LivePreviewError(
        'No Flutter app (pubspec.yaml) found in the project workspace.',
      );
    }

    // Bind first so the bridge script knows the port.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    stage('Preparing the web build…');
    final webDir = Directory('$appDir${Platform.pathSeparator}web');
    if (!await webDir.exists()) {
      final create = await runCaptured(
        'flutter create . --platforms web',
        workingDirectory: appDir,
        timeout: const Duration(minutes: 5),
      );
      if (create.exitCode != 0) {
        throw LivePreviewError('flutter create (web) failed.\n${create.output}');
      }
    }

    // Inject the bridge into the PREVIEW copy of index.html (this is a
    // materialized throwaway; the committed workspace is untouched).
    final indexFile = File('$appDir${Platform.pathSeparator}web${Platform.pathSeparator}index.html');
    if (await indexFile.exists()) {
      var html = await indexFile.readAsString();
      const marker = 'NEXUS_BRIDGE_INJECTED';
      if (!html.contains(marker)) {
        final script = '<!-- $marker -->\n${_bridgeScript(port)}';
        if (html.contains('</body>')) {
          html = html.replaceFirst('</body>', '$script\n</body>');
        } else {
          html = '$html\n$script';
        }
        await indexFile.writeAsString(html);
      }
    }

    stage('Building the web app (first build takes a few minutes)…');
    final build = await runCaptured(
      'flutter pub get >/dev/null 2>&1; flutter build web --debug',
      workingDirectory: appDir,
      timeout: const Duration(minutes: 20),
    );
    final outDir = Directory(
      '$appDir${Platform.pathSeparator}build${Platform.pathSeparator}web',
    );
    if (build.exitCode != 0 || !await outDir.exists()) {
      final outLines = build.output.split('\n');
      final tail = outLines.length > 40
          ? outLines.sublist(outLines.length - 40)
          : outLines;
      throw LivePreviewError('The web build failed.\n${tail.join('\n')}');
    }

    final webRoot = outDir.path;
    final session = LivePreviewSession._(server, mat, appDir, port);
    server.listen((request) async {
      try {
        if (request.uri.path == '/ws') {
          final socket = await WebSocketTransformer.upgrade(request);
          session._sockets.add(socket);
          socket.listen(
            (data) {
              try {
                final dyn = jsonDecode(data is String ? data : utf8.decode(data));
                if (dyn is Map<String, dynamic>) {
                  session.events.add(dyn);
                }
              } catch (_) {}
            },
            onDone: () => session._sockets.remove(socket),
            onError: (_) => session._sockets.remove(socket),
          );
          return;
        }
        await _serveStatic(request, webRoot);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    });
    return session;
  } catch (e) {
    await server?.close(force: true);
    await mat.dispose();
    if (e is LivePreviewError) rethrow;
    throw LivePreviewError('Live preview failed: $e');
  }
}

class LivePreviewError implements Exception {
  const LivePreviewError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Open [url] in the OS default browser (no new platform deps).
Future<void> openInBrowser(String url) async {
  if (Platform.isLinux) {
    await Process.run('xdg-open', [url]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', url]);
  }
}

Future<void> _serveStatic(HttpRequest request, String root) async {
  try {
    var rel = Uri.decodeComponent(request.uri.path);
    if (rel == '/' || rel.isEmpty) rel = '/index.html';
    var file = File(
      '$root${rel.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!await file.exists()) {
      file = File('$root${Platform.pathSeparator}index.html');
    }
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = _contentTypeFor(file.path);
    await request.response.addStream(file.openRead());
    await request.response.close();
  } catch (_) {
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    } catch (_) {}
  }
}

ContentType _contentTypeFor(String path) {
  final p = path.toLowerCase();
  if (p.endsWith('.html')) return ContentType('text', 'html');
  if (p.endsWith('.js') || p.endsWith('.mjs')) {
    return ContentType('application', 'javascript');
  }
  if (p.endsWith('.json')) return ContentType('application', 'json');
  if (p.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (p.endsWith('.css')) return ContentType('text', 'css');
  if (p.endsWith('.png')) return ContentType('image', 'png');
  if (p.endsWith('.jpg') || p.endsWith('.jpeg')) {
    return ContentType('image', 'jpeg');
  }
  if (p.endsWith('.svg')) return ContentType('image', 'svg+xml');
  if (p.endsWith('.ttf')) return ContentType('font', 'ttf');
  if (p.endsWith('.otf')) return ContentType('font', 'otf');
  if (p.endsWith('.woff')) return ContentType('font', 'woff');
  if (p.endsWith('.woff2')) return ContentType('font', 'woff2');
  return ContentType('application', 'octet-stream');
}
