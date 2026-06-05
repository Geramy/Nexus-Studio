// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The three selectable app themes.
///
///   - [nebula]   — the signature NexusRouter "website" look: a vibrant
///                  purple-black aesthetic with a pink→orange→violet→cyan
///                  gradient. This is the DEFAULT on first run.
///   - [daylight] — a clean light theme.
///   - [midnight] — a neutral dark theme.
///
/// All three share one rounded, glassy component language (see [_themed]) so
/// the app feels cohesive regardless of which palette is active.
enum AppThemeChoice {
  nebula,
  daylight,
  midnight;

  /// Human-readable label for pickers.
  String get label => switch (this) {
    AppThemeChoice.nebula => 'Nebula',
    AppThemeChoice.daylight => 'Daylight',
    AppThemeChoice.midnight => 'Midnight',
  };

  /// Short description shown beside the label in the picker.
  String get description => switch (this) {
    AppThemeChoice.nebula => 'Signature NexusRouter gradient (default)',
    AppThemeChoice.daylight => 'Clean light theme',
    AppThemeChoice.midnight => 'Neutral dark theme',
  };

  /// The default theme on first launch — the website-style "Nebula".
  static const AppThemeChoice defaultChoice = AppThemeChoice.nebula;

  /// Parse from a persisted name, falling back to the default.
  static AppThemeChoice fromName(String? name) {
    for (final c in AppThemeChoice.values) {
      if (c.name == name) return c;
    }
    return defaultChoice;
  }
}

class AppTheme {
  // ── Brand palette (from NexusRouter.Web site.css) ───────────────────────
  static const Color brandPink = Color(0xFFFF4D8D);
  static const Color brandOrange = Color(0xFFFF8A3D);
  static const Color brandViolet = Color(0xFF8B5CFF);
  static const Color brandCyan = Color(0xFF2FD9FF);

  // Nebula (website) surfaces & text.
  static const Color _nebulaBg = Color(0xFF0B0613); // very dark purple-black
  static const Color _nebulaSurface = Color(0xFF140C20);
  static const Color _nebulaText = Color(0xFFF4F0FB); // near-white lavender
  static const Color _nebulaTextMuted = Color(0xFFB7A9D0);

  /// The signature site gradient: pink → orange → violet → cyan.
  /// Reuse for buttons, headers and accents to mirror the marketing site.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment(-1.0, -0.2),
    end: Alignment(1.0, 0.2),
    colors: [brandPink, brandOrange, brandViolet, brandCyan],
    stops: [0.0, 0.38, 0.74, 1.0],
  );

  /// A softer two-stop accent (violet → cyan) for subtle highlights.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandViolet, brandCyan],
  );

  /// Resolve a [ThemeData] for the given [choice].
  static ThemeData of(AppThemeChoice choice) => switch (choice) {
    AppThemeChoice.nebula => nebulaTheme,
    AppThemeChoice.daylight => daylightTheme,
    AppThemeChoice.midnight => midnightTheme,
  };

  // ── Nebula: the website-style default ───────────────────────────────────
  static ThemeData get nebulaTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandViolet,
          brightness: Brightness.dark,
        ).copyWith(
          primary: brandViolet,
          secondary: brandPink,
          tertiary: brandCyan,
          surface: _nebulaSurface,
          onSurface: _nebulaText,
          onSurfaceVariant: _nebulaTextMuted,
          outline: const Color(0x33FFFFFF), // rgba(255,255,255,0.20)
          outlineVariant: const Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
        );
    return _themed(
      scheme: scheme,
      scaffold: _nebulaBg,
      cardColor: const Color(0x0FFFFFFF), // glassy white 6%
    );
  }

  // ── Daylight: clean light theme ─────────────────────────────────────────
  static ThemeData get daylightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandViolet,
      brightness: Brightness.light,
    );
    return _themed(
      scheme: scheme,
      scaffold: const Color(0xFFF6F4FB),
      cardColor: Colors.white,
    );
  }

  // ── Midnight: neutral dark theme ────────────────────────────────────────
  static ThemeData get midnightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandViolet,
      brightness: Brightness.dark,
    );
    return _themed(
      scheme: scheme,
      scaffold: const Color(0xFF101014),
      cardColor: const Color(0x0FFFFFFF),
    );
  }

  // ── Shared rounded / glassy component language ──────────────────────────
  //
  // Every theme runs through here so buttons (pill-shaped), cards (large
  // radius + hairline border), inputs, chips, tabs and dialogs all share the
  // same shape rhythm defined in [AppRadius].
  static ThemeData _themed({
    required ColorScheme scheme,
    required Color scaffold,
    required Color cardColor,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final hairline = scheme.outlineVariant;

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'SF Pro',
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
    );

    // Pill button padding + label weight, shared by all button kinds.
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    );
    const buttonLabel = TextStyle(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    const pill = StadiumBorder();

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: scheme.primary.withValues(alpha: 0.25),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: hairline),
        ),
      ),

      dividerColor: hairline,
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 1,
        space: AppSpacing.lg,
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),

      // ── Buttons: pill / stadium shaped ────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: isDark ? Colors.white : scheme.onPrimary,
          padding: buttonPadding,
          textStyle: buttonLabel,
          shape: pill,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: isDark ? Colors.white : scheme.onPrimary,
          padding: buttonPadding,
          textStyle: buttonLabel,
          shape: pill,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          padding: buttonPadding,
          textStyle: buttonLabel,
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          textStyle: buttonLabel,
          shape: pill,
        ),
      ),
      // NB: don't force a global foregroundColor here. A plain IconButton's M3
      // default is already onSurfaceVariant, but pinning it would override the
      // FILLED/tonal variants too — painting a muted icon over the primary fill
      // (the "purple send icon on a purple button" bug). Letting each variant
      // resolve its own default keeps filled buttons at onPrimary contrast.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: const CircleBorder()),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: StadiumBorder(),
      ),

      // ── Inputs ────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      // ── Chips: rounded pills ──────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : scheme.surfaceContainerHighest,
        side: BorderSide(color: hairline),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const StadiumBorder(),
      ),

      // ── Tabs ──────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
      ),

      // ── Surfaces ──────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? scheme.surface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: hairline),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isDark ? scheme.surface : Colors.white,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppRadius.lgAll,
              side: BorderSide(color: hairline),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        // Dark themes were inheriting a light surface + the framework's default
        // (dark) tooltip text → unreadable grey-on-black. Pin a dark-grey chip
        // with white text in dark mode (and the standard inverse-surface chip in
        // light mode) so tooltips read clearly in every theme.
        textStyle: base.textTheme.bodySmall?.copyWith(
          color: isDark ? Colors.white : scheme.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A30) : scheme.inverseSurface,
          borderRadius: AppRadius.smAll,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: const StadiumBorder()),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
    );
  }

  // ── Back-compat aliases (older call sites referenced light/dark) ─────────
  @Deprecated('Use daylightTheme')
  static ThemeData get lightTheme => daylightTheme;
  @Deprecated('Use midnightTheme')
  static ThemeData get darkTheme => midnightTheme;
}
