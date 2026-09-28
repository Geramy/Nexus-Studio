// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:async';
import 'dart:io';

/// Launches a verified installer with the OS's native installer UI, reveals a
/// file in the file manager, or opens a URL — all via `dart:io` Process so we
/// add no plugin. The macOS app is NOT sandboxed (see Release.entitlements), so
/// spawning `open`/`installer` and exiting to let the bundle be replaced is fine.
class UpdateInstaller {
  const UpdateInstaller();

  /// Hands the downloaded installer to the platform's installer UI. Returns true
  /// if the launch was issued; the caller then quits the app so file locks
  /// release and the installer can overwrite the running binary.
  Future<bool> launchInstaller(File installer) async {
    final path = installer.path;
    try {
      if (Platform.isMacOS) {
        // Opens the signed/notarized .pkg in Installer.app.
        await Process.run('open', [path]);
        return true;
      }
      if (Platform.isWindows) {
        // Detached so the Inno Setup installer outlives our process.
        await Process.start(path, const [], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isLinux) {
        // Hand the .deb to the desktop's graphical package installer.
        final r = await Process.run('xdg-open', [path]);
        if (r.exitCode == 0) return true;
        // Fall back to just showing the file so the user can install manually.
        return await revealInFolder(installer);
      }
    } catch (_) {
      // Last resort: reveal the file.
      return revealInFolder(installer);
    }
    return false;
  }

  /// Opens the platform file manager with [file] selected.
  Future<bool> revealInFolder(File file) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
        return true;
      }
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', file.path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Opens [url] in the default browser (used for "What's new").
  Future<void> openExternal(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  /// Quits the app so the just-launched installer can replace it. A short delay
  /// lets the spawned process detach first.
  Future<void> quitForInstall() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    exit(0);
  }
}
