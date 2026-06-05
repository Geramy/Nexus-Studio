// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/update_provider.dart';
import '../../shared/ui/nexus_ui.dart';

/// Wraps the whole app (via `MaterialApp.router`'s `builder`) and floats a
/// non-blocking "update available / downloading" banner over the bottom-right
/// of any screen. Invisible unless the updater has something to show, so it
/// never gets in the way of normal use.
class UpdateBannerHost extends ConsumerWidget {
  const UpdateBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(updateControllerProvider);
    final visible = switch (c.phase) {
      UpdatePhase.available ||
      UpdatePhase.downloading ||
      UpdatePhase.verifying ||
      UpdatePhase.launching ||
      UpdatePhase.error => true,
      _ => false,
    };

    return Stack(
      children: [
        child,
        if (visible)
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: SafeArea(child: _UpdateBanner(controller: c)),
          ),
      ],
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.controller});
  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;

    // Never wider than the screen (minus margins) so the floating card scales
    // down on narrow windows / phones instead of overflowing off-screen.
    final maxW = math.min(
      380.0,
      MediaQuery.sizeOf(context).width - AppSpacing.lg * 2,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: NexusCard(
        glow: true,
        accent: theme.colorScheme.primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _icon(c.phase),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title(c), style: theme.textTheme.titleSmall),
                      if (_subtitle(c) != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(c)!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.nx.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (c.phase == UpdatePhase.available ||
                    c.phase == UpdatePhase.error)
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: c.dismiss,
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
            if (c.phase == UpdatePhase.downloading) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: c.progress, minHeight: 4),
            ],
            if (c.phase == UpdatePhase.available) ...[
              const SizedBox(height: AppSpacing.sm),
              // All actions reflow together with Wrap so the primary button stays
              // its natural pill size (not a full-width bar) and drops onto its
              // own line only when the card is too narrow to fit the row.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: c.skipThisVersion,
                    child: const Text('Skip'),
                  ),
                  TextButton(
                    onPressed: c.openReleaseNotes,
                    child: const Text('What\'s new'),
                  ),
                  GradientButton(
                    onPressed: c.startUpdate,
                    label: 'Update now',
                    icon: Icons.download,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _icon(UpdatePhase phase) => switch (phase) {
    UpdatePhase.downloading => Icons.cloud_download_outlined,
    UpdatePhase.verifying => Icons.verified_outlined,
    UpdatePhase.launching => Icons.rocket_launch_outlined,
    UpdatePhase.error => Icons.error_outline,
    _ => Icons.system_update_alt,
  };

  String _title(UpdateController c) => switch (c.phase) {
    UpdatePhase.available => 'Update to v${c.latest?.version}',
    UpdatePhase.downloading => 'Downloading update…',
    UpdatePhase.verifying => 'Verifying download…',
    UpdatePhase.launching => 'Launching installer…',
    UpdatePhase.error => 'Update failed',
    _ => 'Update',
  };

  String? _subtitle(UpdateController c) => switch (c.phase) {
    UpdatePhase.available =>
      'A new version of Nexus Projects is ready to install.',
    UpdatePhase.downloading =>
      c.progress != null ? '${(c.progress! * 100).toStringAsFixed(0)}%' : null,
    UpdatePhase.launching => 'The app will close to finish installing.',
    UpdatePhase.error => c.errorMessage,
    _ => null,
  };
}
