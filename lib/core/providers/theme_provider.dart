// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/ui/app_theme.dart';

part 'theme_provider.g.dart';

/// The user's selected app theme, persisted in SharedPreferences.
///
/// Defaults to [AppThemeChoice.defaultChoice] (the website-style "Nebula") on
/// first run, then hydrates the saved choice asynchronously — mirroring the
/// persistence pattern used by [PanelLayoutNotifier] in app_shell_provider.dart.
@riverpod
class AppThemeNotifier extends _$AppThemeNotifier {
  static const _prefsKey = 'app_theme_choice';

  @override
  AppThemeChoice build() {
    // Kick off async hydration; the default is returned synchronously so the
    // very first frame already renders the Nebula theme.
    _hydrate();
    return AppThemeChoice.defaultChoice;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = AppThemeChoice.fromName(prefs.getString(_prefsKey));
    if (!ref.mounted) return; // provider disposed during the await (riverpod 3)
    if (saved != state) state = saved;
  }

  /// Select and persist a theme.
  Future<void> setChoice(AppThemeChoice choice) async {
    state = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, choice.name);
  }
}
