// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// A configurable, DB-stored definition of a project-setup interview, keyed by
/// project type + sub-category. It replaces the hardcoded software stages
/// (Industries → … → Libraries) with an ordered list of [SetupStage]s so each
/// project specification (software, IVR/phone systems, …) can drive its own
/// guided interview. The setup host's prompt, the `propose_tags` category vocab,
/// and the tag board's sections all read from this.
library;

/// How a stage collects input.
enum SetupStageInput { choices, freeform, mixed }

/// How free the stage's values are (mirrors the legacy VocabKind so the software
/// flow round-trips unchanged).
enum SetupVocab { closed, curated, open }

SetupStageInput _inputFromKey(String? k) => SetupStageInput.values.firstWhere(
  (e) => e.name == k,
  orElse: () => SetupStageInput.mixed,
);
SetupVocab _vocabFromKey(String? k) => SetupVocab.values.firstWhere(
  (e) => e.name == k,
  orElse: () => SetupVocab.curated,
);

/// One stage of a setup interview. [key] is the tag category the stage feeds
/// (stored on ProjectTags.category); [guidance] tells the host what to ask and
/// propose in this stage.
class SetupStage {
  final String key;
  final String title;
  final String guidance;
  final SetupStageInput input;
  final SetupVocab vocab;

  /// Seed/allowed values. For [SetupVocab.closed] these are the only permitted
  /// values; for curated they seed the picker; for open it's empty (free entry).
  final List<String> suggestions;

  /// Whether this stage MUST have at least one tag before setup can be finalized
  /// (the plan generated / hand-off to user stories). Defaults to true — most
  /// stages are mandatory; mark optional ones (e.g. databases/services for a
  /// project that has none) `required: false`. Sub-axes a chosen industry
  /// introduces (e.g. Gaming → Genre) are enforced separately at finalize time.
  final bool required;

  const SetupStage({
    required this.key,
    required this.title,
    required this.guidance,
    this.input = SetupStageInput.mixed,
    this.vocab = SetupVocab.curated,
    this.suggestions = const [],
    this.required = true,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'guidance': guidance,
    'input': input.name,
    'vocab': vocab.name,
    'suggestions': suggestions,
    'required': required,
  };

  factory SetupStage.fromJson(Map<String, dynamic> j) => SetupStage(
    key: j['key'] as String,
    title: (j['title'] as String?) ?? '',
    guidance: (j['guidance'] as String?) ?? '',
    input: _inputFromKey(j['input'] as String?),
    vocab: _vocabFromKey(j['vocab'] as String?),
    suggestions: ((j['suggestions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    // Back-compat: stages persisted before this flag existed are mandatory.
    required: (j['required'] as bool?) ?? true,
  );
}

/// A full setup interview for a (projectType, subCategory). [intro] frames the
/// host; [stages] are walked in order; [finalizeGuidance] describes what the
/// `finalize_setup` step should produce for this kind of project.
class SetupFlowDefinition {
  static const int schemaVersion = 1;

  final String projectType;
  final String? subCategory;
  final String name;
  final String intro;
  final List<SetupStage> stages;
  final String finalizeGuidance;

  const SetupFlowDefinition({
    required this.projectType,
    required this.name,
    required this.intro,
    required this.stages,
    required this.finalizeGuidance,
    this.subCategory,
  });

  SetupStage? stageByKey(String key) {
    for (final s in stages) {
      if (s.key == key) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'projectType': projectType,
    'subCategory': subCategory,
    'name': name,
    'intro': intro,
    'stages': stages.map((s) => s.toJson()).toList(),
    'finalizeGuidance': finalizeGuidance,
  };

  factory SetupFlowDefinition.fromJson(Map<String, dynamic> j) =>
      SetupFlowDefinition(
        projectType: (j['projectType'] as String?) ?? 'application-development',
        subCategory: j['subCategory'] as String?,
        name: (j['name'] as String?) ?? 'Setup',
        intro: (j['intro'] as String?) ?? '',
        stages: ((j['stages'] as List?) ?? const [])
            .map(
              (e) => SetupStage.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        finalizeGuidance: (j['finalizeGuidance'] as String?) ?? '',
      );
}
