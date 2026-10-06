// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// A thin vertical border between two panels that the user can DRAG to resize
/// them. Reports live horizontal deltas to [onDelta] while dragging; the
/// parent owns the width state and clamping. Renders as a normal 1px divider
/// (a hairline on a wide invisible hit area) so the layout doesn't change
/// when it's added.
library;

import 'package:flutter/material.dart';

class DraggableVerticalDivider extends StatelessWidget {
  const DraggableVerticalDivider({
    super.key,
    required this.onDelta,
    this.hitWidth = 7,
    this.cursor = SystemMouseCursors.resizeColumn,
  });

  /// Called with the drag delta (positive = dragged right) on every update.
  final void Function(double dx) onDelta;

  /// Total interactive width (the visible line is 1px, centered in it).
  final double hitWidth;

  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {},
        onHorizontalDragUpdate: (d) => onDelta(d.delta.dx),
        child: Container(
          width: hitWidth,
          color: Colors.transparent,
          child: Center(
            child: Container(width: 1, color: theme.dividerColor),
          ),
        ),
      ),
    );
  }
}
