// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/setup_flow.dart';
import 'config/setup_flow_providers.dart';
import 'models/project_tag.dart';
import 'providers/tag_providers.dart';
import 'stack_resolver.dart';

/// The Setup board: one section per stage of the project's RESOLVED setup flow —
/// the SAME [SetupFlowDefinition] the interview prompt follows, so the steps the
/// AI runs and the sections shown never diverge (software → Industries/…/
/// Libraries; IVR → Business Context/Call Purpose/Routing/…). Chips can be
/// accepted (✓) or rejected (✗); state is DB-backed via [tagControllerProvider].
class TagBoardView extends ConsumerWidget {
  const TagBoardView({super.key, required this.projectPk});

  final int projectPk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowAsync = ref.watch(setupFlowForProjectProvider(projectPk));
    final tagsAsync = ref.watch(projectTagsProvider(projectPk));
    // Adaptive scoping derived from the selected industries (sub-axis sections +
    // scoped suggestions). Falls back to empty until it loads, so the board
    // renders immediately and fills in the moment an industry is chosen.
    final scoped =
        ref.watch(scopedBoardProvider(projectPk)).value ??
        ScopedBoard.empty;

    return flowAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load setup flow: $e')),
      data: (flow) => tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tags: $e')),
        data: (tags) => _board(context, ref, flow, tags, scoped),
      ),
    );
  }

  Widget _board(
    BuildContext context,
    WidgetRef ref,
    SetupFlowDefinition flow,
    List<ProjectTag> tags,
    ScopedBoard scoped,
  ) {
    final byCategory = <String, List<ProjectTag>>{
      for (final s in flow.stages) s.key: [],
      for (final a in scoped.subAxes) a.key: [],
    };
    for (final t in tags) {
      (byCategory[t.category] ??= []).add(t);
    }
    final subAxisKeys = scoped.subAxes.map((a) => a.key).toSet();
    // Orphan categories (tags whose section isn't in the current flow, e.g. a
    // legacy software tag on a re-typed project) get shown last so nothing is
    // silently hidden. Sub-axis sections are rendered inline, so exclude them.
    final orphans = byCategory.keys
        .where(
          (k) =>
              !flow.stages.any((s) => s.key == k) && !subAxisKeys.contains(k),
        )
        .toList();

    // The deterministic Client↔Server↔DB resolver is software-only; show its bar
    // only when this flow has the derived `languages` stage.
    final isSoftware = flow.stages.any((s) => s.key == 'languages');

    // Merge scoped suggestions (industry/sub-axis tailored) ahead of the stage's
    // static seeds, deduped case-insensitively.
    List<String> merged(String key, List<String> static_) {
      final scopedVals = scoped.scoped[key] ?? const <String>[];
      if (scopedVals.isEmpty) return static_;
      final seen = <String>{};
      final out = <String>[];
      for (final v in [...scopedVals, ...static_]) {
        if (seen.add(v.toLowerCase())) out.add(v);
      }
      return out;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isSoftware) ...[
          _ResolveBar(projectPk: projectPk),
          const SizedBox(height: 8),
        ],
        for (final s in flow.stages) ...[
          _TagSection(
            projectPk: projectPk,
            sectionKey: s.key,
            title: s.title,
            suggestions: merged(s.key, s.suggestions),
            closed: s.vocab == SetupVocab.closed,
            tags: byCategory[s.key] ?? const [],
          ),
          // Surface sub-axis sections (e.g. Genre for Gaming) right after the
          // industries section, only when an industry introduces one.
          if (s.key == 'industries')
            for (final a in scoped.subAxes)
              _TagSection(
                projectPk: projectPk,
                sectionKey: a.key,
                title: a.name,
                suggestions: a.values,
                closed: false,
                tags: byCategory[a.key] ?? const [],
              ),
        ],
        for (final k in orphans)
          _TagSection(
            projectPk: projectPk,
            sectionKey: k,
            title: _prettify(k),
            suggestions: const [],
            closed: false,
            tags: byCategory[k] ?? const [],
          ),
      ],
    );
  }

  static String _prettify(String key) => key.isEmpty
      ? key
      : key[0].toUpperCase() +
            key
                .substring(1)
                .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m.group(1)}');
}

/// Runs the deterministic resolver over the current intent tags and upserts the
/// proposed stack tags. Lets the user materialize the Client↔Server↔DB stack.
class _ResolveBar extends ConsumerStatefulWidget {
  const _ResolveBar({required this.projectPk});
  final int projectPk;

  @override
  ConsumerState<_ResolveBar> createState() => _ResolveBarState();
}

class _ResolveBarState extends ConsumerState<_ResolveBar> {
  bool _busy = false;

  Future<void> _resolve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final tags =
          ref.read(projectTagsProvider(widget.projectPk)).value ?? [];
      final resolved = const StackResolver().resolve(tags);
      final controller = ref.read(tagControllerProvider(widget.projectPk));
      for (final tag in resolved.stackTags) {
        await controller.upsert(tag);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Resolve the stack from your platforms & features '
                '(Client ↔ Server ↔ PostgreSQL).',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _resolve,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Resolve stack'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSection extends ConsumerWidget {
  const _TagSection({
    required this.projectPk,
    required this.sectionKey,
    required this.title,
    required this.suggestions,
    required this.closed,
    required this.tags,
  });

  final int projectPk;
  final String sectionKey;
  final String title;
  final List<String> suggestions;
  final bool closed;
  final List<ProjectTag> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tags.where((t) => !t.isRejected).length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddPicker(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (tags.isEmpty)
            Text(
              'No tags yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  _TagChip(projectPk: projectPk, tag: tag),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showAddPicker(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(tagControllerProvider(projectPk));
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _AddTagDialog(title: title, suggestions: suggestions, closed: closed),
    );
    if (value == null || value.trim().isEmpty) return;
    await controller.addManual(category: sectionKey, value: value.trim());
  }
}

class _TagChip extends ConsumerWidget {
  const _TagChip({required this.projectPk, required this.tag});

  final int projectPk;
  final ProjectTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(tagControllerProvider(projectPk));
    final pk = tag.tagPk;

    final bg = switch (tag.status) {
      TagStatus.accepted => theme.colorScheme.primaryContainer,
      TagStatus.rejected => theme.colorScheme.surfaceContainerHighest,
      TagStatus.proposed => Colors.transparent,
    };
    final border = tag.isProposed
        ? Border.all(
            color: theme.colorScheme.outlineVariant,
            style: BorderStyle.solid,
          )
        : null;

    return Tooltip(
      message: tag.rationale ?? '',
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag.verdict != null) ...[
              _VerdictDot(verdict: tag.verdict!),
              const SizedBox(width: 6),
            ],
            Text(
              tag.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: tag.isRejected ? TextDecoration.lineThrough : null,
                color: tag.isRejected ? theme.colorScheme.outline : null,
              ),
            ),
            if (tag.forLanguage != null) ...[
              const SizedBox(width: 6),
              _MetaPill(text: tag.forLanguage!, theme: theme),
            ] else if (tag.layerKey != null) ...[
              const SizedBox(width: 6),
              Text(
                tag.layerKey!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(width: 4),
            if (pk != null) ..._actions(context, controller, pk, theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    TagController controller,
    int pk,
    ThemeData theme,
  ) {
    return [
      _IconBtn(
        icon: Icons.check,
        active: tag.isAccepted,
        color: Colors.green,
        tooltip: 'Accept',
        onTap: () =>
            tag.isAccepted ? controller.reset(pk) : controller.accept(pk),
      ),
      _IconBtn(
        icon: Icons.close,
        active: tag.isRejected,
        color: theme.colorScheme.error,
        tooltip: 'Reject',
        onTap: () =>
            tag.isRejected ? controller.reset(pk) : controller.reject(pk),
      ),
      // The user can delete anything they authored — typed (user) OR picked from
      // suggestions (chosen).
      if (tag.source == TagSource.user || tag.source == TagSource.chosen)
        _IconBtn(
          icon: Icons.delete_outline,
          active: false,
          color: theme.colorScheme.outline,
          tooltip: 'Remove',
          onTap: () => controller.remove(pk),
        ),
    ];
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.active,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            icon,
            size: 16,
            color: active ? color : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

/// Small rounded label used for a library's attached language (e.g. "Dart").
class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Freshness verdict dot: fresh=green, aging=amber, stale=orange, dead=red.
class _VerdictDot extends StatelessWidget {
  const _VerdictDot({required this.verdict});
  final String verdict;

  @override
  Widget build(BuildContext context) {
    final color = switch (verdict) {
      'fresh' => Colors.green,
      'aging' => Colors.amber,
      'stale' => Colors.orange,
      'dead' => Colors.red,
      _ => Colors.grey,
    };
    return Tooltip(
      message: verdict,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Add-tag dialog. Closed/curated categories show their vocabulary as choices;
/// curated + open also allow a free-text entry.
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog({
    required this.title,
    required this.suggestions,
    required this.closed,
  });
  final String title;
  final List<String> suggestions;
  final bool closed;

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocab = widget.suggestions;
    final allowsFreeText = !widget.closed;

    return AlertDialog(
      title: Text('Add to ${widget.title}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vocab.isNotEmpty)
              // Scroll the choices when there are more than fit the dialog,
              // instead of overflowing. The text field below stays visible.
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in vocab)
                        ActionChip(
                          label: Text(v),
                          onPressed: () => Navigator.of(context).pop(v),
                        ),
                    ],
                  ),
                ),
              ),
            if (allowsFreeText) ...[
              if (vocab.isNotEmpty) const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: vocab.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Custom value',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.of(context).pop(v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (allowsFreeText)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ctrl.text),
            child: const Text('Add'),
          ),
      ],
    );
  }
}
