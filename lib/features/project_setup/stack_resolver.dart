// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'models/project_tag.dart';
import 'models/tag_category.dart';

/// The architecture layers the resolver can emit. `db` is always present
/// (PostgreSQL); `client`/`server` are the baseline Client ↔ Server system;
/// `worker`/`module` appear only when objectives demand them.
enum Layer { client, server, db, worker, module }

extension LayerX on Layer {
  String get key => name;
  String get label => switch (this) {
    Layer.client => 'Client',
    Layer.server => 'Server',
    Layer.db => 'Database',
    Layer.worker => 'Worker',
    Layer.module => 'Module',
  };
}

/// Deterministic architecture resolver. Reads the (non-rejected) intent tags —
/// platforms + features (incl. legacy objectives) — and computes the layers +
/// language/framework stack
/// per the project axioms. NEVER run by the AI; the AI only proposes intent.
///
/// Axioms (see PROJECT_SETUP_PLAN.md):
///   - Always Client ↔ Server; PostgreSQL recommended DB.
///   - Any UI surface → Flutter/Dart client.
///   - Default API/server tier → C# / ASP.NET Core + Entity Framework Core.
///   - Heavy computation / highly distributed / ML → the server tier becomes
///     C/C++ (Drogon) instead (merges the old separate worker layer).
///   - Memory-safety critical → Rust module (last resort, explicit accept).
class StackResolver {
  const StackResolver();

  /// Compute the resolved stack from the project's intent tags. Returns tags
  /// stamped with `source: ai`, `origin: setup`, `status: proposed`, and a
  /// `layerKey` so the Tag Board can show them and the user can confirm.
  ResolvedStack resolve(List<ProjectTag> tags) {
    final active = tags.where((t) => !t.isRejected).toList();
    // Features and the retired "objectives" section are one axis now — read the
    // UNION so the capability signals (UI, dashboard, heavy computation,
    // distributed, ML, memory-safety) drive the stack whether a new project
    // tagged them under `features` or a legacy one under `objectives`.
    final objectives = active
        .where(
          (t) =>
              t.knownCategory == TagCategory.features ||
              t.knownCategory == TagCategory.objectives,
        )
        .map((t) => t.value.toLowerCase())
        .toSet();
    final platforms = active
        .where((t) => t.knownCategory == TagCategory.platforms)
        .map((t) => t.value.toLowerCase())
        .toSet();

    bool has(Set<String> set, String needle) =>
        set.any((v) => v.contains(needle));

    final layers = <Layer>{Layer.client, Layer.server, Layer.db};
    final resolved = <ProjectTag>[];

    void add(TagCategory category, String value, Layer layer, String why) {
      resolved.add(
        ProjectTag(
          category: category.wire,
          value: value,
          source: TagSource.ai,
          origin: 'setup',
          status: TagStatus.proposed,
          layerKey: layer.key,
          rationale: why,
        ),
      );
    }

    // ---- Client: any UI surface → Flutter/Dart ----
    final hasUi =
        platforms.isNotEmpty ||
        has(objectives, 'ui') ||
        has(objectives, 'dashboard') ||
        has(objectives, 'customer');
    if (hasUi) {
      add(
        TagCategory.languages,
        'Dart',
        Layer.client,
        'Flutter/Dart is the default frontend for any UI surface.',
      );
      add(
        TagCategory.frameworks,
        'Flutter',
        Layer.client,
        'Cross-platform UI for the selected platforms.',
      );
    }

    // ---- Server / API tier ----
    // Default to C# / ASP.NET Core + EF Core. When the objectives signal heavy
    // computation / highly distributed / ML work, the server tier becomes
    // native C/C++ (Drogon) instead — this merges the old separate worker layer.
    final heavyServer =
        has(objectives, 'heavy computation') ||
        has(objectives, 'distributed') ||
        has(objectives, 'machine learning');
    if (heavyServer) {
      add(
        TagCategory.languages,
        'C++',
        Layer.server,
        'Heavy computation / highly distributed / ML workloads warrant a native C/C++ API tier.',
      );
      add(
        TagCategory.frameworks,
        'Drogon',
        Layer.server,
        'High-performance C++ HTTP/API framework for the native server tier.',
      );
    } else {
      add(
        TagCategory.languages,
        'C#',
        Layer.server,
        'Default API/server tier — C# / ASP.NET Core for standard business backends.',
      );
      add(
        TagCategory.frameworks,
        'ASP.NET Core',
        Layer.server,
        'Default server framework for the API tier.',
      );
      add(
        TagCategory.frameworks,
        'Entity Framework Core',
        Layer.server,
        'ORM for the C# server tier talking to PostgreSQL.',
      );
    }

    // ---- Database: always PostgreSQL ----
    add(
      TagCategory.languages,
      'SQL',
      Layer.db,
      'PostgreSQL is the recommended database.',
    );
    add(
      TagCategory.frameworks,
      'PostgreSQL',
      Layer.db,
      'Recommended relational database for the server.',
    );

    // ---- Module: memory-safety critical → Rust (last resort) ----
    if (has(objectives, 'memory-safety') || has(objectives, 'memory safety')) {
      layers.add(Layer.module);
      add(
        TagCategory.languages,
        'Rust',
        Layer.module,
        'Memory-safety-critical work — Rust as a hardened last resort (confirm to enable).',
      );
    }

    return ResolvedStack(
      layers: layers.toList()..sort((a, b) => a.index.compareTo(b.index)),
      stackTags: resolved,
    );
  }
}

/// The deterministic resolver output: the active layers and the proposed
/// language/framework tags (each carrying its layerKey + rationale).
class ResolvedStack {
  const ResolvedStack({required this.layers, required this.stackTags});
  final List<Layer> layers;
  final List<ProjectTag> stackTags;

  List<ProjectTag> tagsForLayer(Layer layer) =>
      stackTags.where((t) => t.layerKey == layer.key).toList();
}
