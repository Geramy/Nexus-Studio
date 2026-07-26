// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';

import '../../infrastructure/database/nexus_database.dart' hide ProjectTag;
import '../../infrastructure/inference/inference_backend.dart';
import '../../infrastructure/registry/registry_models.dart';
import '../../infrastructure/registry/verification_service.dart';
import '../project_plans/plan_store.dart';
import 'config/setup_flow.dart';
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
    bool includeLibraryTools = false,
  }) {
    final cats = (categories == null || categories.isEmpty)
        ? const [
            'industries',
            'platforms',
            'features',
            'languages',
            'frameworks',
            'databases',
            'libraries',
            'services',
          ]
        : categories;
    final tools = <Map<String, dynamic>>[
      {
        'type': 'function',
        'function': {
          'name': 'generate_image',
          'description':
              'Generate an image from a text description and show it to the user '
              '(e.g. a mock-up of a screen, a logo, a concept illustration). Call '
              'this whenever the user asks to see / make / draw / show a picture '
              'or design during setup. Write a detailed visual prompt — the image '
              'renders inline in the chat. Example: generate_image(prompt: '
              '"mobile app launch screen for a lemonade stand, bright and '
              'friendly, app-store style", size: "1024x1024").',
          'parameters': {
            'type': 'object',
            'properties': {
              'prompt': {
                'type': 'string',
                'description':
                    'Detailed visual description of the image to create.',
              },
              'size': {
                'type': 'string',
                'description':
                    'WxH — 1024x1024 (default), 1024x1792 (portrait), or '
                    '1792x1024 (landscape).',
              },
            },
            'required': ['prompt'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'edit_image',
          'description':
              'Modify the most recent image with a described change (e.g. "make '
              'the background blue", "add a logo", "brighter"). The latest image '
              'you generated is used as the source automatically. Call this when '
              'the user asks to change / edit / adjust the picture you just showed.',
          'parameters': {
            'type': 'object',
            'properties': {
              'prompt': {
                'type': 'string',
                'description': 'The change to apply to the current image.',
              },
              'size': {
                'type': 'string',
                'description': 'Optional output size, e.g. 1024x1024.',
              },
            },
            'required': ['prompt'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'ask_question',
          'description':
              'Ask the user ONE interview question and get their answer. This is '
              'how you ask every setup question: it shows the options as buttons '
              'the user taps and returns their selection to you, so the user can '
              'answer. Use it for each step (platforms, features, and '
              'so on). Give a clear question plus 2-8 short options, and keep '
              'multi=true so the user can pick several. Example: '
              'ask_question(question: "Question 2 of 7 — Which platforms should '
              'it run on?", options: ["iOS", "Android", "Web"], multi: true).',
          'parameters': {
            'type': 'object',
            'properties': {
              'question': {
                'type': 'string',
                'description':
                    'The question to show the user (a single, clear question).',
              },
              'options': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': '2-8 short, selectable choices for the user.',
              },
              'multi': {
                'type': 'boolean',
                'description':
                    'Whether the user may pick more than one option. DEFAULTS '
                    'TO TRUE — most setup questions (platforms, languages, '
                    'frameworks, libraries, industries, features) are '
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
              'features (use the returned values as the '
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
              'Use before proposing any library tag. After EVERY lookup you MUST '
              'either propose_tags it (add) or dismiss_item it (skip) — setup '
              'will not finalize while a lookup is left undecided.',
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
          'name': 'consider_items',
          'description':
              'Register options you are WEIGHING but have not committed to — '
              'whenever you would tell the user "let me think about this; here '
              'are the candidates…", list them here (ANY category: libraries, '
              'databases, services, features, frameworks, …). Each becomes a '
              'pending decision you MUST then resolve with propose_tags (add) or '
              'dismiss_item (skip); setup will not move on or finalize while any '
              'are undecided.',
          'parameters': {
            'type': 'object',
            'properties': {
              'category': {
                'type': 'string',
                'description':
                    'What kind of options these are (e.g. databases, services, '
                    'libraries, features).',
              },
              'items': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'The candidate names you are weighing.',
              },
              'note': {
                'type': 'string',
                'description': 'Optional: what you are deciding between.',
              },
            },
            'required': ['items'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'dismiss_item',
          'description':
              'Record a decision NOT to add something you looked up '
              '(lookup_package) or were weighing (consider_items) — it is '
              'stale/dead, a duplicate, or not needed. Every looked-up or '
              'considered item MUST end in either propose_tags (add) or '
              'dismiss_item (skip); setup will not finalize while a decision is '
              'pending.',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': 'The item to skip (as you named it).',
              },
              'reason': {
                'type': 'string',
                'description': 'Short reason for not adding it.',
              },
            },
            'required': ['name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'propose_tags',
          'description':
              'Save the user\'s answer(s) to the project profile as tags. Call '
              'this right after the user answers a question, recording EXACTLY '
              'their picks under that question\'s category — ONLY the options '
              'they selected, never the ones they left unpicked and never extra '
              'values you invent. Each tag value is a SHORT label (a few words, '
              '≤5) for ONE concept — give the user\'s several picks for the '
              'current topic as several tag objects. '
              'Saved as `proposed` for the user to accept. Languages and '
              'platforms use the allowed vocab; databases/services/frameworks '
              'accept free entry. Example: propose_tags(tags: ['
              '{"category": "features", "value": "Order tracking"}, '
              '{"category": "features", "value": "Push notifications"}]).',
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
                    'value': {
                      'type': 'string',
                      'description':
                          'A SHORT label — a few words (≤5), one concept per '
                          'tag. Give multiple items as SEPARATE tag objects '
                          '(e.g. two tags "Order tracking" and "Push '
                          'notifications").',
                    },
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
          'name': 'remove_tags',
          'description':
              'Remove tag(s) from the project profile that the user has '
              'explicitly said are WRONG. ONLY call this when the user corrects '
              'or rejects a tag (e.g. "this isn\'t a logistics app", "that\'s not '
              'ecommerce", "we\'re not B2B — take that off", "the Media tag is '
              'wrong, it\'s a game"). Never remove a tag the user has not '
              'disowned. Give each tag as its category + exact value (the mirror '
              'of propose_tags). Removing an `industries` tag AUTOMATICALLY '
              'clears the sub-axis selections it introduced (e.g. dropping '
              '"Media" also clears its genre pick) — you do not need to remove '
              'those yourself, but DO re-check features that only fit '
              'the old industry and remove any that no longer apply. After '
              'removing, propose_tags the correct value if the user named one.',
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
                          'The tag\'s category (${cats.join(', ')}, or a '
                          'sub-axis like `genre`).',
                    },
                    'value': {
                      'type': 'string',
                      'description':
                          'The EXACT label to remove, as it was previously '
                          'tagged.',
                    },
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
    // Library deliberation tools (lookup_package / consider_items / dismiss_item)
    // add tool-selection load and can trap small models in the unresolved-decision
    // guard, so they are OFF by default for the setup interview. Enable them only
    // for capable models that benefit from registry verification.
    if (!includeLibraryTools) {
      tools.removeWhere(
        (t) => const {
          'lookup_package',
          'consider_items',
          'dismiss_item',
        }.contains((t['function'] as Map)['name']),
      );
    }
    return tools;
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
    this.inference,
    this.imageModel,
    this.onImage,
  });

  final NexusDatabase db;
  final int projectPk;
  final VerificationService verification;

  /// Inference backend + image model id for the generate_image / edit_image
  /// tools (null in background executors that never call them).
  final InferenceBackend? inference;
  final String? imageModel;

  /// Side-channel that delivers a generated/edited image (base64 PNG) to the
  /// setup chat UI to render inline; the text returned to the model stays short.
  final void Function(String b64Png, String caption)? onImage;

  /// Most recent image generated/edited this session — the source for edits.
  String? _lastImageB64;

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

  /// Items the host has put up for decision — looked up via `lookup_package` or
  /// shortlisted via `consider_items` ("let me think about these…") — that have
  /// NOT yet been resolved: neither added (`propose_tags`) nor dismissed
  /// (`dismiss_item`). The session guard refuses to end a turn or finalize while
  /// any remain, so every deliberation ends in an explicit add/skip PER ITEM.
  /// Keyed by normalized name → display label. Session-scoped (persists across
  /// turns) so a dangling decision keeps blocking until it is made.
  final Map<String, String> _pendingDecisions = {};

  /// Display labels of items still awaiting an add/dismiss decision.
  List<String> get pendingDecisions => _pendingDecisions.values.toList();

  /// Normalize an item/package id for matching across consider/lookup/propose/
  /// dismiss: lowercase and, for `owner/repo` GitHub ids, keep the repo segment.
  static String _normPkg(String raw) {
    final s = raw.trim().toLowerCase();
    final slash = s.lastIndexOf('/');
    return slash >= 0 ? s.substring(slash + 1) : s;
  }

  Future<String> execute(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'generate_image':
        return _generateImage(args);
      case 'edit_image':
        return _editImage(args);
      case 'ask_question':
        return _ask(args);
      case 'scope_status':
        return _scopeStatus();
      case 'scope_options':
        return _scopeOptions(args);
      case 'lookup_package':
        return _lookup(args);
      case 'consider_items':
        return _consider(args);
      case 'propose_tags':
        return _propose(args);
      case 'remove_tags':
        return _remove(args);
      case 'dismiss_item':
        return _dismiss(args);
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

  Future<String> _generateImage(Map<String, dynamic> args) async {
    final prompt = (args['prompt'] as String? ?? '').trim();
    if (prompt.isEmpty) return 'generate_image needs a prompt.';
    final size = (args['size'] as String?) ?? '1024x1024';
    if (inference == null) {
      return 'Image generation is not available (no inference backend).';
    }
    try {
      final resp = await inference!.generateImage(
        prompt: prompt,
        size: size,
        model: imageModel,
        responseFormat: 'b64_json',
      );
      final b64 = resp.data.isNotEmpty ? resp.data.first.b64Json : null;
      if (b64 != null && b64.isNotEmpty) {
        _lastImageB64 = b64;
        onImage?.call(b64, prompt);
        return 'Generated the image and showed it to the user. You can refine it with edit_image.';
      }
      final url = resp.data.isNotEmpty ? resp.data.first.url : null;
      return (url != null && url.isNotEmpty)
          ? 'Generated the image: $url'
          : 'Image generation returned no data.';
    } catch (e) {
      return 'Image generation failed: $e';
    }
  }

  Future<String> _editImage(Map<String, dynamic> args) async {
    final prompt = (args['prompt'] as String? ?? '').trim();
    if (prompt.isEmpty) return 'edit_image needs a prompt describing the change.';
    final size = (args['size'] as String?) ?? '1024x1024';
    if (inference == null) {
      return 'Image editing is not available (no inference backend).';
    }
    if (_lastImageB64 == null) {
      return 'There is no image to edit yet — call generate_image first, then edit it.';
    }
    try {
      final resp = await inference!.generateImageEdit(
        imageBytes: base64Decode(_lastImageB64!),
        prompt: prompt,
        model: imageModel,
        size: size,
        responseFormat: 'b64_json',
      );
      final b64 = resp.data.isNotEmpty ? resp.data.first.b64Json : null;
      if (b64 != null && b64.isNotEmpty) {
        _lastImageB64 = b64;
        onImage?.call(b64, prompt);
        return 'Edited the image and showed the updated version to the user.';
      }
      return 'Image edit returned no data.';
    } catch (e) {
      return 'Image edit failed: $e';
    }
  }

  /// The user's most recent ask_question answer (picks or typed text) that has
  /// NOT yet been turned into tags via propose_tags. The session uses this to
  /// detect the common stall where the host asks (e.g. features), the user
  /// picks some, and the model then just acknowledges and stops WITHOUT recording
  /// them — leaving a required section empty and the "Generate plan" gate stuck.
  /// Cleared the moment propose_tags runs.
  String? lastSelection;

  /// The options shown by the most recent ask_question, and the subset the user
  /// actually picked (both normalized). Used by [_propose] to REFUSE re-adding an
  /// option the user was shown but did NOT select — the "asked 3 of 12, don't
  /// add the other 9 (or invent more)" guard. Reset on each new ask_question and
  /// on a skipped / free-text answer (where option-filtering doesn't apply).
  Set<String> _lastOfferedOptions = const {};
  Set<String> _lastPicks = const {};

  static String _normOpt(String s) => s.trim().toLowerCase();

  Future<String> _ask(Map<String, dynamic> args) async {
    final question = (args['question'] ?? '').toString();
    final options = ((args['options'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    // ALWAYS multi-select. Setup choices are additive — a project can span
    // several industries, platforms, objectives, features, etc. — and the few
    // genuinely-exclusive things (e.g. a primary language) aren't asked as
    // questions anyway. Forcing multi here keeps every picker consistent
    // (checkboxes) regardless of what the model puts in `multi`.
    const multi = true;
    if (askQuestion == null) {
      return 'Cannot ask the user here (no input channel). Proceed with sensible defaults.';
    }
    final answer = await askQuestion!(question, options, multi);
    // Conversation-first: a typed reply is returned verbatim so the host reacts
    // to what the user actually said (not a canned "User selected: …"); chip
    // picks come back as the chosen labels; either being empty is a skip.
    if (answer.freeText != null && answer.freeText!.trim().isNotEmpty) {
      final text = answer.freeText!.trim();
      lastSelection = text;
      // Free-text isn't a pick from the listed options → no option-filtering.
      _lastOfferedOptions = const {};
      _lastPicks = const {};
      return 'User answered: "$text"';
    }
    if (answer.picks.isEmpty) {
      lastSelection = null;
      _lastOfferedOptions = const {};
      _lastPicks = const {};
      return 'User skipped the question.';
    }
    lastSelection = answer.picks.join(', ');
    // Remember what was offered vs. picked so propose_tags can't re-add options
    // the user deliberately left unselected (or invent ones beyond their picks).
    _lastOfferedOptions = options.map(_normOpt).toSet();
    _lastPicks = answer.picks.map(_normOpt).toSet();
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

  /// Categories with at least one non-rejected tag on the board (what's done).
  Future<Set<String>> filledCategories() async {
    final tags = await db.getTagsForProject(projectPk);
    return {
      for (final t in tags)
        if (t.status != 'rejected') t.category,
    };
  }

  /// The single next topic to ask, walking [orderedStages] IN ORDER so the host
  /// covers them one at a time instead of jumping ahead or batching. Skips
  /// AI-derived stages (languages/frameworks — the host proposes those itself)
  /// and, right after `industries` is filled, enforces any unanswered industry
  /// sub-axis (e.g. Gaming → Genre) before later stages. Injected into the prompt
  /// each round; deterministic, so it advances as topics get tagged.
  Future<String> nextTopicInstruction(List<SetupStage> orderedStages) async {
    final filled = await filledCategories();
    for (final s in orderedStages) {
      if (!s.required) continue;
      if (s.guidance.toUpperCase().contains('AI-DERIVED')) continue;
      if (!filled.contains(s.key)) {
        return 'NEXT TOPIC — ask this and ONLY this now: "${s.title}" '
            '(category `${s.key}`). Use ask_question, then propose_tags ONLY the '
            'user\'s picks. Do NOT ask or tag any other topic this turn unless '
            'the user is correcting an earlier answer. One topic at a time, in order.';
      }
      // After industries, an industry-introduced sub-axis (e.g. Genre / business
      // model) must be answered before moving on to objectives/features.
      if (s.key == 'industries') {
        final scope = await _readScope();
        final pending = scope.subAxes.where((a) => !a.answered).toList();
        if (pending.isNotEmpty) {
          final a = pending.first;
          return 'NEXT TOPIC — ask this and ONLY this now: "${a.name}" '
              '(category `${a.key}`) using these options: ${a.values.join(', ')}. '
              'Then propose_tags ONLY the user\'s picks. Do NOT skip ahead to '
              'other topics this turn.';
        }
      }
    }
    return 'All required user topics have a tag. If `languages`/`frameworks` are '
        'not on the board yet, propose them yourself now (derive a minimal stack '
        'for the chosen platforms), then call finalize_setup.';
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
        ' No sub-axis pending. Proceed to features '
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
      // Mark this lookup UNRESOLVED until the host explicitly adds it
      // (propose_tags) or dismisses it (dismiss_item). The session guard and
      // the finalize gate both refuse to move on while it is pending.
      _pendingDecisions[_normPkg(name)] = name;
      return '$name ($ecosystem): ${parts.join(', ')}.'
          '${r.repoUrl != null ? ' repo=${r.repoUrl}' : ''}'
          ' — DECIDE NEXT: add it with propose_tags (category `libraries`) or '
          'drop it with dismiss_item.';
    } catch (e) {
      // A failed verification is NOT a pending decision — the host should retry
      // the lookup (or pick another package), so don't register it.
      return 'Could not verify $name: $e';
    }
  }

  /// Split a tag value on list delimiters into atomic values, so a crammed
  /// "a, b, c" — or a model that lists several items in one value — becomes
  /// separate tags. Trimmed; empties dropped.
  static List<String> _splitTagValues(String raw) => raw
      .split(RegExp(r'[,;\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// A tag value must be a short label. Reject run-on sentences/paragraphs —
  /// the model's failure mode of dumping ~100 words into one objective.
  static bool _tooLongForTag(String v) =>
      v.split(RegExp(r'\s+')).length > 6 || v.length > 64;

  Future<String> _propose(Map<String, dynamic> args) async {
    // The model is recording choices now → the user's last answer is no longer
    // "unrecorded", so the session's anti-stall nudge stands down.
    lastSelection = null;
    final raw = (args['tags'] as List?) ?? const [];
    final controller = TagController(db, projectPk);
    final accepted = <String>[];
    final skipped = <String>[];
    final tooLong = <String>[];
    final unpicked = <String>[];
    final proposedIndustries = <String>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      // Category is a setup-flow stage key (raw string). For known software
      // categories we keep the legacy enum semantics (closed-vocab, library
      // verification); non-software (IVR) categories pass through as-is.
      final catStr = (entry['category'] ?? '').toString().trim();
      final rawValue = (entry['value'] ?? '').toString().trim();
      if (catStr.isEmpty || rawValue.isEmpty) continue;
      final known = TagCategoryX.fromWire(catStr);

      // Per-entry attributes shared by every value split out of this entry.
      String? forLanguage;
      if (known == TagCategory.libraries) {
        final fl = entry['forLanguage']?.toString().trim();
        if (fl != null && fl.isNotEmpty) {
          for (final lang in kLanguages) {
            if (lang.toLowerCase() == fl.toLowerCase()) {
              forLanguage = lang;
              break;
            }
          }
        }
      }
      final sourceUrl = entry['sourceUrl']?.toString();
      final rationale = entry['rationale']?.toString();
      final layerKey = entry['layerKey']?.toString();

      // Tag values MUST be short atomic labels. Split a crammed list into
      // separate tags, then REJECT anything still too long, so the model can't
      // dump a sentence/paragraph into one value (the real failure mode).
      for (final value in _splitTagValues(rawValue)) {
        if (_tooLongForTag(value)) {
          tooLong.add(value);
          continue;
        }

        // STICK TO WHAT THE USER PICKED: if this value was one of the options
        // shown in the last question but the user did NOT select it, refuse to
        // add it — the host must not re-add unpicked options (or pad the answer
        // with extras). Values that were never offered (the initial-description
        // inferences, the AI-derived stack) are unaffected.
        if (_lastOfferedOptions.contains(_normOpt(value)) &&
            !_lastPicks.contains(_normOpt(value))) {
          unpicked.add(value);
          continue;
        }

        // Enforce closed vocab for known closed categories (languages/platforms).
        if (known != null &&
            known.vocab == VocabKind.closed &&
            !known.vocabulary
                .map((v) => v.toLowerCase())
                .contains(value.toLowerCase())) {
          skipped.add('$value (not an allowed ${known.label} value)');
          continue;
        }

        // Library tags must carry a verified verdict.
        String? verdict;
        DateTime? verifiedAt;
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

        // SOURCE: if this value is one the user PICKED from the options the last
        // ask_question offered, it's their explicit CHOICE (AI suggested → user
        // selected), not an AI invention — tag it `chosen`. Anything else the host
        // records (the AI-derived stack, description inferences) stays `ai`.
        final tagSource = _lastPicks.contains(_normOpt(value))
            ? TagSource.chosen
            : TagSource.ai;
        await controller.upsert(
          ProjectTag(
            category: catStr,
            value: value,
            source: tagSource,
            origin: 'setup',
            status: TagStatus.proposed,
            layerKey: layerKey,
            forLanguage: forLanguage,
            rationale: rationale,
            sourceUrl: sourceUrl,
            verdict: verdict,
            verifiedAt: verifiedAt,
          ),
        );
        accepted.add(value);
        // Adding a tag resolves any pending lookup for the same package.
        _pendingDecisions.remove(_normPkg(value));
        if (catStr == 'industries') proposedIndustries.add(value);
      }
    }

    final b = StringBuffer();
    if (accepted.isNotEmpty) b.write('Proposed: ${accepted.join(', ')}.');
    if (skipped.isNotEmpty) b.write(' Skipped: ${skipped.join('; ')}.');
    if (unpicked.isNotEmpty) {
      b.write(
        ' NOT added (the user was shown these but did NOT pick them — do not '
        'add options the user left unselected): ${unpicked.join(', ')}.',
      );
    }
    if (tooLong.isNotEmpty) {
      b.write(
        ' REJECTED (too long — each tag must be a SHORT label, ≤5 words, one '
        'idea each): "${tooLong.join('", "')}". Re-propose these as several '
        'short tags.',
      );
    }
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
          'After that, call scope_options for features to get '
          'vocabulary tailored to this selection.',
        );
      }
    }
    return b.isEmpty ? 'No valid tags to propose.' : b.toString();
  }

  /// Remove tags the user explicitly disowned. Matches each {category, value}
  /// against the board (case-insensitive, ignoring already-rejected rows) and
  /// deletes the matches; the correct value, if the user named one, is re-added
  /// by a following propose_tags. Only acts on what the model passed — never a
  /// blanket clear.
  ///
  /// CASCADE: removing an `industries` tag orphans the sub-axis it introduced
  /// (e.g. dropping "Media" leaves a stale "genre" pick that only Media's scope
  /// defined). After the explicit removals, any sub-axis category contributed
  /// ONLY by a now-removed industry — not by any industry still on the board —
  /// has its tags removed too, so a category correction takes its derived
  /// selections with it.
  Future<String> _remove(Map<String, dynamic> args) async {
    final raw = (args['tags'] as List?) ?? const [];
    if (raw.isEmpty) {
      return 'remove_tags needs a `tags` list of {category, value} to remove.';
    }
    final existing = await db.getTagsForProject(projectPk);
    final controller = TagController(db, projectPk);
    final removed = <String>[];
    final notFound = <String>[];
    var removedAnIndustry = false;

    for (final entry in raw) {
      if (entry is! Map) continue;
      final cat = (entry['category'] ?? '').toString().trim();
      final val = (entry['value'] ?? '').toString().trim();
      if (cat.isEmpty || val.isEmpty) continue;

      final matches = existing
          .where(
            (t) =>
                t.status != 'rejected' &&
                t.category.toLowerCase() == cat.toLowerCase() &&
                t.value.toLowerCase() == val.toLowerCase(),
          )
          .toList();
      if (matches.isEmpty) {
        notFound.add('$cat: $val');
        continue;
      }
      for (final m in matches) {
        await controller.remove(m.tag_pk);
        removed.add(m.value);
        _pendingDecisions.remove(_normPkg(m.value));
        if (m.category.toLowerCase() == 'industries') removedAnIndustry = true;
      }
    }

    final cascaded = removedAnIndustry ? await _cascadeOrphanedSubAxes() : const <String>[];

    final b = StringBuffer();
    if (removed.isNotEmpty) {
      b.write('Removed ${removed.length} tag(s): ${removed.join(', ')}.');
    }
    if (cascaded.isNotEmpty) {
      b.write(
        '${b.isEmpty ? '' : ' '}Also cleared sub-axis selection(s) left behind '
        'by the removed industry: ${cascaded.join(', ')}.',
      );
    }
    if (notFound.isNotEmpty) {
      b.write(
        '${b.isEmpty ? '' : ' '}Not on the board (nothing to remove): '
        '${notFound.join('; ')}.',
      );
    }
    return b.isEmpty ? 'No matching tags — nothing removed.' : b.toString();
  }

  /// After an industry is removed, delete tags under any sub-axis category that
  /// is no longer introduced by ANY industry still selected. Returns the values
  /// it cleared (for the tool report). Deterministic — only touches sub-axis
  /// categories the scope vocab defines, never user-picked objectives/features.
  Future<List<String>> _cascadeOrphanedSubAxes() async {
    final current = await db.getTagsForProject(projectPk);
    final remainingIndustries = current
        .where((t) => t.status != 'rejected' && t.category == 'industries')
        .map((t) => t.value)
        .toList();
    // Sub-axis categories still valid for the surviving industries.
    final keptAxes = await db.subAxesForIndustries(remainingIndustries);
    final keptKeys = keptAxes.map((a) => a.key).toSet();
    // Any sub-axis tag on the board whose category is NOT a kept axis is an
    // orphan from the removed industry — clear it.
    final allAxisKeys = <String>{};
    // Discover which board categories are sub-axes at all (vs. flow stages) by
    // asking the full set of industries that ever defined them; cheapest is to
    // treat any category not in the standard flow set and not kept as a sub-axis
    // orphan only if it WAS an axis. We detect axis categories via the kept set
    // plus the categories present that aren't standard flow stages.
    const flowCats = {
      'industries', 'platforms', 'objectives', 'features', 'languages',
      'frameworks', 'databases', 'libraries', 'services',
    };
    for (final t in current) {
      if (t.status == 'rejected') continue;
      if (flowCats.contains(t.category)) continue;
      allAxisKeys.add(t.category);
    }
    final orphanKeys = allAxisKeys.difference(keptKeys);
    if (orphanKeys.isEmpty) return const [];
    final controller = TagController(db, projectPk);
    final cleared = <String>[];
    for (final t in current) {
      if (t.status == 'rejected') continue;
      if (!orphanKeys.contains(t.category)) continue;
      await controller.remove(t.tag_pk);
      _pendingDecisions.remove(_normPkg(t.value));
      cleared.add(t.value);
    }
    return cleared;
  }

  /// Register a shortlist of options the host is weighing ("let me think about
  /// these…") as pending decisions, so each is forced into an explicit add/skip
  /// rather than mentioned in prose and forgotten.
  Future<String> _consider(Map<String, dynamic> args) async {
    final category = (args['category'] ?? '').toString().trim();
    final items = ((args['items'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (items.isEmpty) return 'consider_items needs a non-empty items list.';
    for (final it in items) {
      _pendingDecisions[_normPkg(it)] = category.isEmpty
          ? it
          : '$it ($category)';
    }
    return 'Noted ${items.length} option(s) under consideration: '
        '${items.join(', ')}. Decide on EACH before moving on — propose_tags to '
        'add it, or dismiss_item to skip it (with a reason). Ask the user with '
        'ask_question if you are unsure which to keep.';
  }

  /// Resolve a looked-up or considered item as the "don't add" decision — clears
  /// it from the pending set so setup can proceed without adding a tag for it.
  Future<String> _dismiss(Map<String, dynamic> args) async {
    final name = (args['name'] ?? '').toString().trim();
    if (name.isEmpty) return 'dismiss_item needs the item name.';
    final reason = (args['reason'] ?? '').toString().trim();
    final had = _pendingDecisions.remove(_normPkg(name)) != null;
    return had
        ? 'Dismissed $name${reason.isNotEmpty ? ' ($reason)' : ''} — it will not '
              'be added.'
        : 'Nothing pending for "$name" (already added or dismissed).';
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
    // A looked-up/considered item left undecided at finalize is simply NOT added
    // — clear it and proceed. The in-turn reconcile nudge already prompts a
    // decision; finalize must never HARD-BLOCK on it (that trapped the model).
    _pendingDecisions.clear();
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
