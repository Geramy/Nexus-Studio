// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

// Note: This file is used by both UI and database layers.
// We accept the Drift-generated AgentPersona here for the resolver.

/// Represents the diff between a Prefab and one of its instances.
///
/// This makes Agents (and later Skills) "diffable" so the UI can show
/// exactly what has been customized locally vs inherited from the prefab.
class PersonaDiff {
  final String prefabId;
  final String instanceId;

  /// List of fields that differ between the prefab and this instance.
  final List<PersonaFieldChange> changes;

  const PersonaDiff({
    required this.prefabId,
    required this.instanceId,
    required this.changes,
  });

  bool get hasChanges => changes.isNotEmpty;
}

/// A single field that has been overridden on an instance relative to its prefab.
class PersonaFieldChange {
  final String
  fieldName; // e.g. "primaryModel", "costPerMillionTokens", "capabilities"
  final dynamic baseValue; // value from the prefab
  final dynamic localValue; // value on the instance (the override)

  const PersonaFieldChange({
    required this.fieldName,
    required this.baseValue,
    required this.localValue,
  });

  /// Human-friendly description of the change.
  String get description {
    return '$fieldName: ${baseValue ?? '∅'} → ${localValue ?? '∅'}';
  }
}

/// Combined result when loading a persona that may come from a prefab.
///
/// Note: `effective` and `basePrefab` are the raw Drift rows from the database.
/// UI layers should map them to `ui_model.AgentPersona` when needed.
class ResolvedPersona {
  final dynamic effective; // Drift AgentPersona row (final merged values)
  final dynamic basePrefab; // Drift AgentPersona row (the source prefab)
  final PersonaDiff? diff; // Structured diff of local overrides

  /// True if this persona is derived from a prefab.
  bool get isFromPrefab => basePrefab != null;

  /// True if the user has made local changes on top of the prefab.
  bool get hasLocalOverrides => diff?.hasChanges ?? false;

  const ResolvedPersona({required this.effective, this.basePrefab, this.diff});
}
