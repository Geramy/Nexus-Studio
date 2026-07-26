// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The sections of the project profile. Every tag belongs to exactly one.
/// Categories split into two families:
///   - Intent (user-led): industries, platforms, features, services.
///   - Stack (AI/resolver-derived, user confirms): languages, frameworks,
///     databases, libraries.
/// [objectives] is RETIRED (merged into [features] — the interview no longer
/// asks it) but stays in the enum so legacy projects' `objectives` tags still
/// read back; every consumer reads the union of features + objectives.
/// [databases] and [services] are curated/open so the host can capture anything
/// the user describes in conversation (PostgreSQL, Redis, Stripe, Twilio, …)
/// rather than being limited to a fixed list.
enum TagCategory {
  industries,
  platforms,
  objectives,
  features,
  languages,
  frameworks,
  databases,
  libraries,
  services,
}

/// How a section's "+ Add" picker behaves:
///   - closed:  fixed list, no invented values (languages, platforms).
///   - curated: suggested list but free entry allowed (industries, objectives,
///              frameworks).
///   - open:    free entry / registry search (libraries — verified, not vocab-bound).
enum VocabKind { closed, curated, open }

extension TagCategoryX on TagCategory {
  String get wire => name;

  static TagCategory? fromWire(String? s) {
    for (final c in TagCategory.values) {
      if (c.name == s) return c;
    }
    return null;
  }

  String get label => switch (this) {
    TagCategory.industries => 'Applicable Industries',
    TagCategory.platforms => 'Platforms',
    TagCategory.objectives => 'Objectives',
    TagCategory.features => 'Features & Capabilities',
    TagCategory.languages => 'Languages',
    TagCategory.frameworks => 'Frameworks',
    TagCategory.databases => 'Databases',
    TagCategory.libraries => 'Libraries',
    TagCategory.services => 'Services & Integrations',
  };

  /// Whether this category is part of the resolver-derived stack family.
  bool get isStack => switch (this) {
    TagCategory.languages ||
    TagCategory.frameworks ||
    TagCategory.databases ||
    TagCategory.libraries => true,
    _ => false,
  };

  VocabKind get vocab => switch (this) {
    TagCategory.languages => VocabKind.closed,
    TagCategory.platforms => VocabKind.closed,
    TagCategory.industries => VocabKind.curated,
    TagCategory.objectives => VocabKind.curated,
    TagCategory.features => VocabKind.curated,
    TagCategory.frameworks => VocabKind.curated,
    // Curated, not closed: PostgreSQL/Redis/Stripe/Twilio etc. should always
    // be taggable from the conversation even if not in the seed list.
    TagCategory.databases => VocabKind.curated,
    TagCategory.services => VocabKind.curated,
    TagCategory.libraries => VocabKind.open,
  };

  /// Suggested/allowed values for the "+ Add" picker. For [VocabKind.closed]
  /// these are the only permitted values; for [VocabKind.curated] they seed the
  /// picker but free entry is allowed; [VocabKind.open] returns empty (search).
  List<String> get vocabulary => switch (this) {
    TagCategory.languages => kLanguages,
    TagCategory.platforms => kPlatforms,
    TagCategory.industries => kIndustries,
    TagCategory.objectives => kObjectives,
    TagCategory.features => kFeatures,
    TagCategory.frameworks => kFrameworks,
    TagCategory.databases => kDatabases,
    TagCategory.services => kServices,
    TagCategory.libraries => const [],
  };
}

/// Closed vocab — the only languages the resolver/UI will stamp.
const List<String> kLanguages = [
  'Dart',
  'C',
  'C++',
  'C#',
  'Java',
  'Rust',
  'Go',
  'Python',
  'TypeScript',
  'SQL',
];

/// Closed vocab — target surfaces.
const List<String> kPlatforms = [
  'Web',
  'iOS',
  'Android',
  'macOS',
  'Windows',
  'Linux',
  'Embedded',
  'Cloud / Server',
];

/// Curated seeds — industries the app may serve.
const List<String> kIndustries = [
  'Healthcare',
  'Finance',
  'Education',
  'E-commerce',
  'Gaming',
  'Logistics',
  'Manufacturing',
  'Media',
  'Government',
  'Security',
  'Developer Tools',
  'IoT',
];

/// LEGACY curated seeds for the retired [TagCategory.objectives] section. The
/// setup interview no longer ASKS objectives — objectives and features were the
/// same axis (every capability is a feature the app must ship), so they were
/// merged into [kFeatures]. This list is kept only so existing projects whose
/// tags were captured under `objectives` still render/read correctly; new
/// projects capture everything under `features`.
const List<String> kObjectives = [
  'Customer-facing UI',
  'Admin dashboard',
  'Public API',
  'Realtime / streaming',
  'Heavy computation',
  'Highly distributed',
  'Memory-safety critical',
  'Data persistence',
  'Offline support',
  'Authentication',
  'Payments',
  'Machine learning',
];

/// Curated seeds — the app's features & capabilities. This ONE section now
/// covers BOTH concrete product features AND the higher-level system
/// capabilities that used to be a separate "objectives" section (they are the
/// same axis — every capability is a feature the app must ship). The stack
/// resolver reads these (union with any legacy `objectives` tags) to derive the
/// architecture, so the capability signals at the end (UI, dashboard, API,
/// realtime, heavy computation, distributed, ML, memory-safety) MUST stay
/// pickable here. Ordered most-common-first: the cross-cutting essentials most
/// apps/web want, then the system-level capabilities.
const List<String> kFeatures = [
  // Cross-cutting essentials (the interchangeable base most apps/web want).
  'User accounts',
  'Authentication / login',
  'Role-based access',
  'User profiles',
  'Notifications',
  'Search',
  'Settings / preferences',
  'File uploads',
  'Reporting & analytics',
  'Audit log',
  'Scheduling / calendar',
  'Offline support',
  'Payments / billing',
  // System-level capabilities (these drive the resolved architecture stack).
  'Customer-facing UI',
  'Admin dashboard',
  'Public API',
  'Realtime / streaming',
  'Data persistence',
  'Heavy computation',
  'Highly distributed',
  'Machine learning',
  'Memory-safety critical',
];

/// Curated seeds — common frameworks (free entry still allowed).
const List<String> kFrameworks = [
  'Flutter',
  'ASP.NET Core',
  'Entity Framework Core',
  'Drogon',
  'Spring Boot',
  'Actix',
  'Axum',
  'gRPC',
  'Drift',
  'Riverpod',
];

/// Curated seeds — databases & data stores (free entry encouraged: tag whatever
/// the user actually describes). This is why "PostgreSQL" now lands somewhere.
const List<String> kDatabases = [
  'PostgreSQL',
  'MySQL',
  'MariaDB',
  'SQLite',
  'SQL Server',
  'MongoDB',
  'Redis',
  'Cassandra',
  'DynamoDB',
  'Firestore',
  'Elasticsearch',
  'Neo4j',
];

/// Curated seeds — external services & integrations the product depends on
/// (payments, auth, messaging, storage, maps, …). Free entry encouraged.
const List<String> kServices = [
  'Stripe',
  'PayPal',
  'Twilio',
  'SendGrid',
  'Firebase',
  'Auth0',
  'AWS S3',
  'Google Maps',
  'Mapbox',
  'Push notifications (FCM/APNs)',
  'OpenAI / LLM API',
  'Algolia',
];
