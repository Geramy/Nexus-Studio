// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import '../../infrastructure/database/nexus_database.dart' hide ProjectTag;
import '../../infrastructure/registry/registry_models.dart';
import '../../infrastructure/registry/verification_service.dart';
import '../project_plans/plan_store.dart';
import 'models/project_tag.dart';
import 'models/tag_category.dart';
import 'plan_generator.dart';
import 'providers/tag_providers.dart';

/// How the user answered an inline `ask_question`. The setup interview is
/// conversation-first: the user can just TYPE a reply ([SetupAnswer.text]) and
/// only optionally expand the pre-made choices to click them ([SetupAnswer.picks]).
/// An empty result of either kind is a skip.
class SetupAnswer {
  const SetupAnswer.picks(this.picks) : freeText = null;
  const SetupAnswer.text(String text) : picks = const [], freeText = text;
  const SetupAnswer.skipped() : picks = const [], freeText = null;

  /// Chip/checkbox selections (when the user expanded and clicked the options).
  final List<String> picks;

  /// A typed, free-form reply (when the user answered in their own words).
  final String? freeText;

  bool get isSkip =>
      picks.isEmpty && (freeText == null || freeText!.trim().isEmpty);
}

/// The bounded toolset the setup-interview AI may call. The AI hosts the
/// conversation, but it can only: ask the user a multiple-choice question,
/// verify a package/repo against the registries, propose tags (always
/// `proposed`), or finalize (resolve stack + generate plans). It can never
/// invent a freshness verdict or silently mutate the confirmed stack.
class SetupTools {
  /// [categories] are the tag categories the active setup flow proposes into
  /// (the flow's stage keys). Defaults to the software profile's seven sections.
  static List<Map<String, dynamic>> buildToolSchemas({
    List<String>? categories,
  }) {
    final cats = (categories == null || categories.isEmpty)
        ? const [
            'industries',
            'platforms',
            'objectives',
            'features',
            'languages',
            'frameworks',
            'databases',
            'libraries',
            'services',
          ]
        : categories;
    return [
      {
        'type': 'function',
        'function': {
          'name': 'ask_question',
          'description':
              'OPTIONAL guardrail: ask ONE bounded multiple-choice question when '
              'picking from options helps the user decide or confirms a '
              'direction. You can also just talk in plain text — use this only '
              'when bounded choices are genuinely useful, not every turn. The '
              'user answers by picking from the options you provide.',
          'parameters': {
            'type': 'object',
            'properties': {
              'question': {'type': 'string'},
              'options': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'The selectable choices (2-8).',
              },
              'multi': {
                'type': 'boolean',
                'description':
                    'Whether the user may pick more than one option. DEFAULTS '
                    'TO TRUE — most setup questions (platforms, languages, '
                    'frameworks, libraries, industries, objectives) are '
                    'additive and the user should be able to choose several. '
                    'Set this to false ONLY for a strict single-choice '
                    'question such as a yes/no or an end-of-stage '
                    '"continue vs. add more" confirmation.',
              },
            },
            'required': ['question', 'options'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'scope_status',
          'description':
              'Read the adaptive scope for THIS project from the user\'s current '
              'selections. Call it right AFTER proposing `industries`, and '
              'again after `platforms`. It reports the selected industries, '
              'any sub-axis the chosen industry introduces (e.g. Gaming → '
              '"Genre") that you should ask NEXT, whether that sub-axis is '
              'already answered, and the selected platforms. Use the returned '
              'sub-axis + values as the options for your next ask_question.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'scope_options',
          'description':
              'Get vocabulary tailored to the user\'s selected industry + '
              'sub-axis (e.g. genre) for a category. Call this BEFORE asking '
              'objectives or features (use the returned values as the '
              'options), and when deriving languages/frameworks/libraries '
              '(pass the relevant platform). Platform-conditional: for '
              'languages/frameworks/libraries pass `platform` so you get the '
              'stack appropriate for that surface (e.g. Desktop games → '
              'C#/C++ engines; Mobile games → Flutter/Flame).',
          'parameters': {
            'type': 'object',
            'properties': {
              'category': {
                'type': 'string',
                'enum': [
                  'objectives',
                  'features',
                  'languages',
                  'frameworks',
                  'libraries',
                  'platforms',
                ],
              },
              'platform': {
                'type': 'string',
                'description':
                    'Optional platform bucket for stack categories: Mobile, '
                    'Desktop, Web, Console, Embedded, Cloud/Server.',
              },
            },
            'required': ['category'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'lookup_package',
          'description':
              'Verify a library/framework against pub.dev or GitHub and get a '
              'deterministic freshness verdict (fresh|aging|stale|dead). '
              'Use before proposing any library tag.',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'Package name (pub.dev) or owner/repo (GitHub).',
              },
              'ecosystem': {
                'type': 'string',
                'enum': ['pubdev', 'github'],
              },
            },
            'required': ['name', 'ecosystem'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'propose_tags',
          'description':
              'Propose one or more tags for the project profile. Batch as many as '
              'you like in ONE call, across categories (e.g. a database + a '
              'service + features together) — no need to call this after every '
              'single message. Saved as `proposed` for the user to accept/'
              'reject. Languages and platforms must use the allowed vocab; '
              'databases/services/frameworks accept free entry.',
          'parameters': {
            'type': 'object',
            'properties': {
              'tags': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'category': {
                      'type': 'string',
                      'description':
                          'One of the flow categories (${cats.join(', ')}), OR a '
                          'sub-axis category reported by scope_status '
                          '(e.g. `genre`).',
                    },
                    'value': {'type': 'string'},
                    'layerKey': {
                      'type': 'string',
                      'enum': ['client', 'server', 'db', 'worker', 'module'],
                    },
                    'forLanguage': {
                      'type': 'string',
                      'description':
                          'Libraries ONLY: the language this package is used '
                          'with (e.g. "Dart", "C#"). Must be an allowed '
                          'Languages value. Omit for non-library tags.',
                    },
                    'rationale': {'type': 'string'},
                    'sourceUrl': {'type': 'string'},
                  },
                  'required': ['category', 'value'],
                },
              },
            },
            'required': ['tags'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'finalize_setup',
          'description':
              'Resolve the architecture from the confirmed tags and generate the '
              '/PLANS layer files. PRECONDITION: every REQUIRED section must have '
              'at least one tag first (and any industry sub-axis like Genre must '
              'be answered) — if it is not ready this returns the list of what is '
              'still missing instead of finalizing, so cover those first. Call '
              'only when the profile is complete and the user is satisfied.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
    ];
  }

  /// The toolset for the post-finalize REFINE phase. The plans already exist as
  /// `/PLANS/*.md` files; here the host enriches them from the user's free-text
  /// descriptions. It can list the plans, read one, and overwrite one with an
  /// expanded version (edits apply directly).
  static List<Map<String, dynamic>> buildRefineToolSchemas() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'list_plans',
          'description':
              'List the generated plan files under /PLANS (path + name) so you '
              'can decide which one a piece of detail belongs in.',
          'parameters': {'type': 'object', 'properties': {}},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_plan',
          'description':
              'Read the full Markdown of one plan file. ALWAYS read a plan '
              'before updating it so you preserve its existing content.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Full workspace path, e.g. /PLANS/Client.md.',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'update_plan',
          'description':
              'Overwrite a plan file with an expanded version that folds the '
              "user's description into the right section. Preserve the "
              'existing headings and checkbox skeleton — ADD detail, never '
              'delete what is there. The change is applied immediately.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Full workspace path under /PLANS to overwrite.',
              },
              'content': {
                'type': 'string',
                'description':
                    'The complete new Markdown for the file (existing content '
                    'plus your additions).',
              },
            },
            'required': ['path', 'content'],
          },
        },
      },
    ];
  }
}

/// Executes the bounded setup tools against the live DB + registries.
class SetupToolExecutor {
  SetupToolExecutor({
    required this.db,
    required this.projectPk,
    required this.verification,
    required this.planStore,
    this.askQuestion,
    this.onPlansChanged,
    this.requiredCategories = const {},
  });

  final NexusDatabase db;
  final int projectPk;
  final VerificationService verification;

  /// Flow stage key → human label for the stages that MUST each have at least
  /// one (non-rejected) tag before `finalize_setup` is allowed. Empty disables
  /// the completeness gate (e.g. a background-only plan write, not a user
  /// finalize). Populated from the active flow's required stages so the gate is
  /// flow-aware (software vs IVR propose entirely different categories).
  final Map<String, String> requiredCategories;

  /// Resolved plan store for the project workspace; null disables finalize's
  /// file generation (the resolver still runs and the status is set).
  final PlanStore? planStore;

  /// Called after a refine-phase plan edit writes a file, so the UI can re-walk
  /// the /PLANS tree (the Plan explorer + open Plan tab refresh).
  final void Function()? onPlansChanged;

  /// UI hook: presents [question] with [options] and returns the user's
  /// answer — typed free text or chip picks (see [SetupAnswer]). When null,
  /// ask_question reports that input isn't available.
  final Future<SetupAnswer> Function(
    String question,
    List<String> options,
    bool multi,
  )?
  askQuestion;

  Future<String> execute(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'ask_question':
        return _ask(args);
      case 'scope_status':
        return _scopeStatus();
      case 'scope_options':
        return _scopeOptions(args);
      case 'lookup_package':
        return _lookup(args);
      case 'propose_tags':
        return _propose(args);
      case 'finalize_setup':
        return _finalize();
      case 'list_plans':
        return _listPlans();
      case 'read_plan':
        return _readPlan(args);
      case 'update_plan':
        return _updatePlan(args);
      default:
        return 'Unknown setup tool "$name".';
    }
  }

  Future<String> _ask(Map<String, dynamic> args) async {
    final question = (args['question'] ?? '').toString();
    final options = ((args['options'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    // Default to multi-select: setup questions (platforms, languages,
    // frameworks, libraries, …) are additive, so the picker allows multiple
    // unless the host explicitly marks the question a single-choice confirmation
    // (multi:false). This guarantees e.g. Platform renders as checkboxes even if
    // the model omits the flag.
    final multi = args['multi'] != false;
    if (askQuestion == null) {
      return 'Cannot ask the user here (no input channel). Proceed with sensible defaults.';
    }
    final answer = await askQuestion!(question, options, multi);
    // Conversation-first: a typed reply is returned verbatim so the host reacts
    // to what the user actually said (not a canned "User selected: …"); chip
    // picks come back as the chosen labels; either being empty is a skip.
    if (answer.freeText != null && answer.freeText!.trim().isNotEmpty) {
      return 'User answered: "${answer.freeText!.trim()}"';
    }
    if (answer.picks.isEmpty) return 'User skipped the question.';
    return 'User selected: ${answer.picks.join(', ')}.';
  }

  /// Map a target-surface label (a selected platform like "iOS"/"macOS", or a
  /// bucket the model passes) to the stack bucket used by the scoped vocab
  /// (Mobile/Desktop/Web/Console/Embedded/Cloud/Server).
  String _platformBucket(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'ios':
      case 'android':
      case 'mobile':
        return 'Mobile';
      case 'macos':
      case 'windows':
      case 'linux':
      case 'desktop':
        return 'Desktop';
      case 'web':
        return 'Web';
      case 'console':
        return 'Console';
      case 'embedded':
        return 'Embedded';
      case 'cloud':
      case 'server':
      case 'cloud/server':
      case 'cloud / server':
        return 'Cloud/Server';
      default:
        return raw.trim();
    }
  }

  /// Current selections + the sub-axis (if any) the chosen industry introduces.
  Future<
    ({
      List<String> industries,
      List<String> platforms,
      List<({String name, String key, List<String> values, bool answered})>
      subAxes,
    })
  >
  _readScope() async {
    final tags = await db.getTagsForProject(projectPk);
    List<String> byCat(String c) =>
        tags.where((t) => t.category == c).map((t) => t.value).toList();
    final industries = byCat('industries');
    final platforms = byCat('platforms');
    final axes = await db.subAxesForIndustries(industries);
    final subAxes = [
      for (final a in axes)
        (
          name: a.name,
          key: a.key,
          values: a.values,
          answered: byCat(a.key).isNotEmpty,
        ),
    ];
    return (industries: industries, platforms: platforms, subAxes: subAxes);
  }

  /// Compact snapshot of the project's current selections (proposed + accepted,
  /// excluding rejected), grouped by category. Injected into the interview
  /// system prompt so the host knows what's already chosen WITHOUT replaying the
  /// whole transcript — the board (DB) is the source of truth.
  Future<String> setupStateSummary() async {
    final tags = await db.getTagsForProject(projectPk);
    final byCat = <String, List<String>>{};
    for (final t in tags) {
      if (t.status == 'rejected') continue;
      (byCat.putIfAbsent(t.category, () => <String>[])).add(t.value);
    }
    if (byCat.isEmpty) {
      return 'BOARD STATE: nothing selected yet.';
    }
    final b = StringBuffer(
      'BOARD STATE (the source of truth — do NOT re-ask what is already '
      'chosen; build on it):',
    );
    byCat.forEach((cat, vals) => b.write('\n- $cat: ${vals.join(', ')}'));
    return b.toString();
  }

  Future<String> _scopeStatus() async {
    final s = await _readScope();
    if (s.industries.isEmpty) {
      return 'No industry selected yet. Ask the industries question first, then '
          'propose_tags(industries), then call scope_status again.';
    }
    final b = StringBuffer('Selected industries: ${s.industries.join(', ')}.');
    if (s.platforms.isNotEmpty) {
      b.write(' Selected platforms: ${s.platforms.join(', ')}.');
    }
    final pending = s.subAxes.where((a) => !a.answered).toList();
    if (pending.isEmpty) {
      b.write(
        ' No sub-axis pending. Proceed to objectives/features '
        '(call scope_options first for tailored options).',
      );
    } else {
      for (final a in pending) {
        b.write(
          '\nSub-axis to ask NEXT: "${a.name}" (category `${a.key}`). '
          'Ask the user which ${a.name.toLowerCase()}(s) apply, using these '
          'options: ${a.values.join(', ')}. Then propose_tags with category '
          '`${a.key}`.',
        );
      }
    }
    return b.toString();
  }

  Future<String> _scopeOptions(Map<String, dynamic> args) async {
    final category = (args['category'] ?? '').toString().trim();
    if (category.isEmpty) return 'scope_options needs a category.';
    final s = await _readScope();
    if (s.industries.isEmpty) {
      return 'No industry selected yet — cannot scope $category.';
    }
    final subValues = <String>[];
    final tags = await db.getTagsForProject(projectPk);
    for (final a in s.subAxes) {
      subValues.addAll(
        tags.where((t) => t.category == a.key).map((t) => t.value),
      );
    }
    final rawPlatform = args['platform']?.toString();
    final platform = (rawPlatform != null && rawPlatform.trim().isNotEmpty)
        ? _platformBucket(rawPlatform)
        : null;
    final values = await db.scopeOptions(
      industries: s.industries,
      subValues: subValues,
      category: category,
      platform: platform,
    );
    if (values.isEmpty) {
      return 'No scoped $category found for ${s.industries.join(', ')}'
          '${subValues.isEmpty ? '' : ' / ${subValues.join(', ')}'}'
          '${platform == null ? '' : ' on $platform'}. '
          'Use sensible defaults for this domain.';
    }
    final scope = subValues.isEmpty
        ? s.industries.join(', ')
        : '${s.industries.join(', ')} / ${subValues.join(', ')}';
    return 'Scoped $category for $scope'
        '${platform == null ? '' : ' ($platform)'}: ${values.join(', ')}.';
  }

  Future<String> _lookup(Map<String, dynamic> args) async {
    final name = (args['name'] ?? '').toString().trim();
    final ecosystem = (args['ecosystem'] ?? 'pubdev').toString();
    if (name.isEmpty) return 'lookup_package needs a name.';
    try {
      final r = await verification.verify(name: name, ecosystem: ecosystem);
      final parts = <String>[
        'verdict=${r.verdict.wire}',
        if (r.lastCommit != null) 'lastCommit=${_d(r.lastCommit!)}',
        if (r.lastRelease != null) 'lastRelease=${_d(r.lastRelease!)}',
        if (r.archived) 'ARCHIVED',
        if (r.popularity != null) 'popularity=${r.popularity}',
        if (r.owner != null) 'owner=${r.owner}',
        if (r.isTrusted) 'trusted-org',
      ];
      return '$name ($ecosystem): ${parts.join(', ')}.'
          '${r.repoUrl != null ? ' repo=${r.repoUrl}' : ''}';
    } catch (e) {
      return 'Could not verify $name: $e';
    }
  }

  Future<String> _propose(Map<String, dynamic> args) async {
    final raw = (args['tags'] as List?) ?? const [];
    final controller = TagController(db, projectPk);
    final accepted = <String>[];
    final skipped = <String>[];
    final proposedIndustries = <String>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      // Category is a setup-flow stage key (raw string). For known software
      // categories we keep the legacy enum semantics (closed-vocab, library
      // verification); non-software (IVR) categories pass through as-is.
      final catStr = (entry['category'] ?? '').toString().trim();
      final value = (entry['value'] ?? '').toString().trim();
      if (catStr.isEmpty || value.isEmpty) continue;
      final known = TagCategoryX.fromWire(catStr);

      // Enforce closed vocab for known closed categories (languages/platforms).
      if (known != null &&
          known.vocab == VocabKind.closed &&
          !known.vocabulary
              .map((v) => v.toLowerCase())
              .contains(value.toLowerCase())) {
        skipped.add('$value (not an allowed ${known.label} value)');
        continue;
      }

      // Libraries can attach to the language they're used with (closed vocab).
      String? forLanguage;
      if (known == TagCategory.libraries) {
        final raw = entry['forLanguage']?.toString().trim();
        if (raw != null && raw.isNotEmpty) {
          for (final lang in kLanguages) {
            if (lang.toLowerCase() == raw.toLowerCase()) {
              forLanguage = lang;
              break;
            }
          }
        }
      }

      // Library tags must carry a verified verdict.
      String? verdict;
      DateTime? verifiedAt;
      final sourceUrl = entry['sourceUrl']?.toString();
      if (known == TagCategory.libraries) {
        try {
          final eco = (sourceUrl != null && sourceUrl.contains('github.com'))
              ? 'github'
              : 'pubdev';
          final r = await verification.verify(name: value, ecosystem: eco);
          verdict = r.verdict.wire;
          verifiedAt = r.checkedAt;
        } catch (_) {}
      }

      await controller.upsert(
        ProjectTag(
          category: catStr,
          value: value,
          source: TagSource.ai,
          origin: 'setup',
          status: TagStatus.proposed,
          layerKey: entry['layerKey']?.toString(),
          forLanguage: forLanguage,
          rationale: entry['rationale']?.toString(),
          sourceUrl: sourceUrl,
          verdict: verdict,
          verifiedAt: verifiedAt,
        ),
      );
      accepted.add(value);
      if (catStr == 'industries') proposedIndustries.add(value);
    }

    final b = StringBuffer();
    if (accepted.isNotEmpty) b.write('Proposed: ${accepted.join(', ')}.');
    if (skipped.isNotEmpty) b.write(' Skipped: ${skipped.join('; ')}.');
    // When an industry is chosen, deterministically tell the host about the
    // sub-axis it introduces (e.g. Gaming → Genre) so it asks that next without
    // relying on it to remember to call scope_status.
    if (proposedIndustries.isNotEmpty) {
      final axes = await db.subAxesForIndustries(proposedIndustries);
      for (final a in axes) {
        b.write(
          '\nNEXT: "${a.name}" applies to '
          '${proposedIndustries.join(', ')} — ask which '
          '${a.name.toLowerCase()}(s) via ask_question using these options: '
          '${a.values.join(', ')}; then propose_tags(category `${a.key}`). '
          'After that, call scope_options for objectives and features to get '
          'vocabulary tailored to this selection.',
        );
      }
    }
    return b.isEmpty ? 'No valid tags to propose.' : b.toString();
  }

  /// Generate the `/PLANS` files from the project's confirmed tags WITHOUT
  /// touching setupStatus. Shared by [_finalize] (which then flips to refine)
  /// and the "continue to user stories" button path (which has already set
  /// setupStatus='complete' and must NOT have it reverted to 'refining').
  Future<List<String>> generatePlans() async {
    final tags = await db.getTagsForProject(projectPk);
    final uiTags = tags
        .map(
          (row) => ProjectTag(
            tagPk: row.tag_pk,
            category: row.category,
            value: row.value,
            source: TagSourceX.fromWire(row.source),
            origin: row.origin,
            status: TagStatusX.fromWire(row.status),
            layerKey: row.layerKey,
            forLanguage: row.forLanguage,
            rationale: row.rationale,
            sourceUrl: row.sourceUrl,
            verdict: row.verdict,
          ),
        )
        .where((t) => !t.isRejected)
        .toList();

    if (planStore == null) return const [];
    return PlanGenerator(planStore!).generate(uiTags);
  }

  /// Required stages (and unanswered industry sub-axes like Genre) that still
  /// have no tag, as human labels. Empty ⇒ the profile is complete enough to
  /// finalize. The single source of truth for the gate — used by both the AI's
  /// `finalize_setup` tool and the UI "Generate plan" button.
  Future<List<String>> missingRequiredLabels() async {
    if (requiredCategories.isEmpty) return const [];
    final tags = await db.getTagsForProject(projectPk);
    final present = <String>{
      for (final t in tags)
        if (t.status != 'rejected') t.category,
    };
    final missing = <String>[];
    requiredCategories.forEach((key, label) {
      if (!present.contains(key)) missing.add(label);
    });
    // Sub-axes the chosen industry introduces (e.g. Gaming → Genre) are part of
    // "all fields filled", so enforce any that are still unanswered.
    final scope = await _readScope();
    for (final a in scope.subAxes) {
      if (!a.answered) missing.add(a.name);
    }
    return missing;
  }

  Future<String> _finalize() async {
    // Gate: don't generate the plan until every required section has a tag. This
    // stops the host from ending the interview / the user from skipping ahead
    // with a half-filled profile (returns guidance so the AI keeps interviewing).
    final missing = await missingRequiredLabels();
    if (missing.isNotEmpty) {
      return 'Not ready to finalize — the profile still needs: '
          '${missing.join(', ')}. Ask the user about each of these, propose_tags '
          'for them, and only call finalize_setup once every required section '
          'has at least one tag.';
    }
    final generated = await generatePlans();
    // Enter the REFINE phase rather than completing outright: the plans now
    // exist, but the user keeps fleshing them out in Setup before tasks.
    await db.setProjectSetupStatus(projectPk, 'refining');

    return generated.isEmpty
        ? 'Setup finalized. (No workspace available to write plan files.)'
        : 'Setup finalized. Generated: ${generated.join(', ')}.';
  }

  Future<String> _listPlans() async {
    if (planStore == null) return 'No workspace available — no plans to list.';
    final nodes = await planStore!.list();
    final docs = nodes.where((n) => !n.isFolder).toList();
    if (docs.isEmpty) return 'No plan files exist yet.';
    return 'Plans:\n${docs.map((n) => '- ${n.path}').join('\n')}';
  }

  Future<String> _readPlan(Map<String, dynamic> args) async {
    if (planStore == null) return 'No workspace available.';
    final path = (args['path'] ?? '').toString().trim();
    if (!_isPlanPath(path)) return 'Path must be a file under /PLANS.';
    try {
      final content = await planStore!.read(path);
      return content.isEmpty ? '(empty file)' : content;
    } catch (e) {
      return 'Could not read $path: $e';
    }
  }

  Future<String> _updatePlan(Map<String, dynamic> args) async {
    if (planStore == null) return 'No workspace available — cannot edit plans.';
    final path = (args['path'] ?? '').toString().trim();
    final content = (args['content'] ?? '').toString();
    if (!_isPlanPath(path)) return 'Path must be a file under /PLANS.';
    if (content.trim().isEmpty) return 'Refusing to write empty content.';
    try {
      await planStore!.write(path, content);
      onPlansChanged?.call();
      final name = path.split('/').last;
      return 'Updated $name.';
    } catch (e) {
      return 'Could not update $path: $e';
    }
  }

  /// Guards plan tools to real documents under /PLANS (no traversal/escapes).
  static bool _isPlanPath(String path) =>
      path.startsWith('$plansRoot/') && !path.contains('..');

  static String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
