// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import '../project_plans/plan_store.dart';
import 'models/project_tag.dart';
import 'models/tag_category.dart';
import 'stack_resolver.dart';

/// Turns the resolved stack + confirmed tags into real Markdown plan files
/// under `/PLANS`. Deterministic — no AI. Each layer the resolver emits becomes
/// one file with a parseable header (Stack / Objectives / Libraries) plus a
/// `- [ ]` outline skeleton, so the file doubles as worker system-prompt context.
class PlanGenerator {
  PlanGenerator(this._store);

  final PlanStore _store;

  /// Writes Overview.md + one file per active layer. [tags] should be the
  /// project's non-rejected tags; the resolver derives layers/stack from them.
  /// Returns the workspace paths of the files written.
  Future<List<String>> generate(List<ProjectTag> tags) async {
    final active = tags.where((t) => !t.isRejected).toList();
    final resolved = const StackResolver().resolve(active);
    await _store.ensureRoot();

    final written = <String>[];

    written.add(await _write('Overview.md', _overview(active, resolved)));

    for (final layer in resolved.layers) {
      final file = '${layer.label}.md';
      written.add(await _write(file, _layerDoc(layer, active, resolved)));
    }

    return written;
  }

  Future<String> _write(String name, String content) async {
    final path = '$plansRoot/$name';
    if (await _exists(path)) {
      await _store.write(path, content);
      return path;
    }
    return _store.create(name: name, isFolder: false, content: content);
  }

  Future<bool> _exists(String path) async {
    try {
      await _store.read(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==================== Document builders ====================

  String _overview(List<ProjectTag> tags, ResolvedStack resolved) {
    final b = StringBuffer();
    b.writeln('# Project Overview');
    b.writeln();
    b.writeln(
      '> Generated from Project Setup. Edit freely — this is the '
      'project-wide context shared by every layer.',
    );
    b.writeln();

    _section(b, 'Industries', _values(tags, TagCategory.industries));
    _section(b, 'Platforms', _values(tags, TagCategory.platforms));
    _section(b, 'Features & Capabilities', _featureValues(tags));

    b.writeln('## Architecture');
    b.writeln();
    b.writeln('Topology: ${resolved.layers.map((l) => l.label).join(' ↔ ')}.');
    b.writeln();
    for (final layer in resolved.layers) {
      final langs = resolved
          .tagsForLayer(layer)
          .where((t) => t.knownCategory == TagCategory.languages)
          .map((t) => t.value)
          .toSet()
          .join(', ');
      b.writeln('- **${layer.label}**${langs.isEmpty ? '' : ' — $langs'}');
    }
    b.writeln();

    b.writeln('## Plans');
    b.writeln();
    for (final layer in resolved.layers) {
      b.writeln('- [${layer.label}](${layer.label}.md)');
    }
    b.writeln();
    return b.toString();
  }

  String _layerDoc(Layer layer, List<ProjectTag> tags, ResolvedStack resolved) {
    final layerTags = resolved.tagsForLayer(layer);
    final langs = layerTags
        .where((t) => t.knownCategory == TagCategory.languages)
        .map((t) => t.value)
        .toSet()
        .toList();
    final frameworks = <String>{
      ...layerTags
          .where((t) => t.knownCategory == TagCategory.frameworks)
          .map((t) => t.value),
      ...tags
          .where(
            (t) =>
                t.knownCategory == TagCategory.frameworks &&
                t.layerKey == layer.key,
          )
          .map((t) => t.value),
    }.toList();
    final langSet = langs.map((l) => l.toLowerCase()).toSet();
    final libraries = tags
        .where(
          (t) =>
              t.knownCategory == TagCategory.libraries &&
              (t.layerKey == layer.key ||
                  (t.forLanguage != null &&
                      langSet.contains(t.forLanguage!.toLowerCase())) ||
                  (t.layerKey == null && t.forLanguage == null)),
        )
        .map(
          (t) =>
              t.forLanguage == null ? t.value : '${t.value} (${t.forLanguage})',
        )
        .toSet()
        .toList();
    final objectives = _featureValues(tags);

    final b = StringBuffer();
    b.writeln('# ${layer.label}');
    b.writeln();
    b.writeln(
      '> Layer plan generated from Project Setup. Workers building this '
      'layer should read this file first as their system-prompt context.',
    );
    b.writeln();

    b.writeln('## Stack');
    b.writeln();
    _bullets(b, 'Languages', langs);
    _bullets(b, 'Frameworks', frameworks);
    _bullets(b, 'Libraries', libraries);
    b.writeln();

    _section(b, 'Features & Capabilities', objectives);

    if (layerTags.any((t) => t.rationale != null)) {
      b.writeln('## Rationale');
      b.writeln();
      for (final t in layerTags.where((t) => t.rationale != null)) {
        b.writeln('- **${t.value}**: ${t.rationale}');
      }
      b.writeln();
    }

    b.writeln('## Outline');
    b.writeln();
    for (final item in _outlineFor(layer)) {
      b.writeln('- [ ] $item');
    }
    b.writeln();
    return b.toString();
  }

  List<String> _outlineFor(Layer layer) => switch (layer) {
    Layer.client => const [
      'Define navigation + screen map',
      'Implement state management & data layer',
      'Wire API client to the Server',
      'Style + theming pass',
    ],
    Layer.server => const [
      'Define API surface (endpoints / contracts)',
      'Implement auth & request validation',
      'Wire persistence to the Database',
      'Integration tests for the API',
    ],
    Layer.db => const [
      'Design schema + relationships',
      'Write migrations',
      'Seed/reference data',
      'Indexing & query review',
    ],
    Layer.worker => const [
      'Define the compute job contract',
      'Implement the hot path in native code',
      'Benchmark & profile',
      'Bridge to the Server',
    ],
    Layer.module => const [
      'Define the safety-critical boundary',
      'Implement the hardened module',
      'Fuzz / property tests',
      'Expose a safe FFI surface',
    ],
  };

  // ==================== Helpers ====================

  List<String> _values(List<ProjectTag> tags, TagCategory category) => tags
      .where((t) => t.knownCategory == category)
      .map((t) => t.value)
      .toSet()
      .toList();

  /// Features + any legacy `objectives` tags, deduped. The two were merged into
  /// one axis; reading the union keeps old projects' objectives visible.
  List<String> _featureValues(List<ProjectTag> tags) => tags
      .where(
        (t) =>
            t.knownCategory == TagCategory.features ||
            t.knownCategory == TagCategory.objectives,
      )
      .map((t) => t.value)
      .toSet()
      .toList();

  void _section(StringBuffer b, String title, List<String> values) {
    b.writeln('## $title');
    b.writeln();
    if (values.isEmpty) {
      b.writeln('_None specified._');
    } else {
      for (final v in values) {
        b.writeln('- $v');
      }
    }
    b.writeln();
  }

  void _bullets(StringBuffer b, String label, List<String> values) {
    b.writeln('- **$label:** ${values.isEmpty ? '_TBD_' : values.join(', ')}');
  }
}
