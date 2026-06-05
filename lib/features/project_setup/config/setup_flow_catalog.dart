// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import '../models/tag_category.dart';
import 'setup_flow.dart';

/// Built-in default setup flows keyed by project type + sub-category. These seed
/// the `SetupFlows` table (editable in the DB afterwards) and are the fallback
/// when no DB row exists. The software flow reproduces the legacy hardcoded
/// interview exactly (its stages map 1:1 to [TagCategory]); IVR / Call-Systems
/// sub-categories get phone-system-appropriate stages.

SetupStage _s(
  String key,
  String title,
  String guidance, {
  SetupStageInput input = SetupStageInput.mixed,
  SetupVocab vocab = SetupVocab.curated,
  List<String> suggestions = const [],
  bool required = true,
}) => SetupStage(
  key: key,
  title: title,
  guidance: guidance,
  input: input,
  vocab: vocab,
  suggestions: suggestions,
  required: required,
);

// ─────────────────────────────────────────── Software (legacy-compatible) ───

final SetupFlowDefinition applicationDevelopmentFlow = SetupFlowDefinition(
  projectType: 'application-development',
  name: 'Software project setup',
  intro:
      'Have a friendly, natural CONVERSATION that walks the user through describing '
      'their project — let THEM explain it in their own words, and build the profile '
      'from what they say. The sections below are topics to COVER (in any sensible '
      'order), not a rigid script. Use `ask_question` to offer bounded choices when '
      'it helps the user decide or to confirm — not for every turn. As the user '
      'describes their software, capture what you hear as tags: a delivery app that '
      'stores orders implies a `databases` tag (e.g. PostgreSQL); Stripe/Twilio/maps '
      'imply `services` tags. Derive the code stack (`languages`/`frameworks`) '
      'yourself rather than quizzing the user on it.',
  stages: [
    _s(
      'industries',
      TagCategoryX(TagCategory.industries).label,
      'What industry/industries is this for? Propose `industries` tags.',
      vocab: SetupVocab.curated,
      suggestions: kIndustries,
    ),
    _s(
      'platforms',
      TagCategoryX(TagCategory.platforms).label,
      'Which target surfaces? Propose `platforms` tags (closed vocab).',
      vocab: SetupVocab.closed,
      suggestions: kPlatforms,
    ),
    _s(
      'objectives',
      TagCategoryX(TagCategory.objectives).label,
      'System-level intent (UI, API, realtime, ML…). Propose `objectives` tags.',
      suggestions: kObjectives,
    ),
    _s(
      'features',
      TagCategoryX(TagCategory.features).label,
      'Concrete product features the app must ship. Propose `features` tags.',
      suggestions: kFeatures,
    ),
    _s(
      'languages',
      TagCategoryX(TagCategory.languages).label,
      'AI-DERIVED — do NOT ask the user. Derive the language stack and propose '
          '`languages` tags (closed vocab).',
      input: SetupStageInput.choices,
      vocab: SetupVocab.closed,
      suggestions: kLanguages,
    ),
    _s(
      'frameworks',
      TagCategoryX(TagCategory.frameworks).label,
      'AI-DERIVED — do NOT ask the user. Propose `frameworks` tags for the stack.',
      input: SetupStageInput.choices,
      suggestions: kFrameworks,
    ),
    // Optional: not every project needs its own datastore or external service,
    // so these don't block finalize (see SetupStage.required).
    _s(
      'databases',
      TagCategoryX(TagCategory.databases).label,
      'Data stores the project needs, inferred from what the user describes '
          '(e.g. orders/users → PostgreSQL; caching → Redis). Free entry — tag '
          'whatever fits. Propose `databases` tags.',
      suggestions: kDatabases,
      required: false,
    ),
    _s(
      'libraries',
      TagCategoryX(TagCategory.libraries).label,
      'Specific packages implementing the features — verify each via '
          '`lookup_package`, set `forLanguage`, propose as `libraries`.',
      vocab: SetupVocab.open,
    ),
    _s(
      'services',
      TagCategoryX(TagCategory.services).label,
      'External services/integrations the product depends on (payments, auth, '
          'SMS/email, maps, storage, push). Free entry. Propose `services` tags.',
      suggestions: kServices,
      required: false,
    ),
  ],
  finalizeGuidance:
      'When satisfied, call `finalize_setup` to generate /PLANS (Overview + one '
      'file per architectural layer: Client, Server, Database).',
);

// ───────────────────────────────────────────────────── IVR / Call Systems ───

SetupStage _persona() => _s(
  'voicePersona',
  'Voice & Persona',
  'How should the system sound — tone (warm/professional), pace, and which '
      'kokoro voice? Propose `voicePersona` tags.',
  vocab: SetupVocab.curated,
  suggestions: [
    'Warm & friendly',
    'Professional',
    'Concise',
    'af_heart',
    'am_michael',
  ],
);

SetupStage _compliance() => _s(
  'compliance',
  'Compliance',
  'OUTBOUND: confirm consent basis (prior express/written), DNC handling, '
      'allowed calling hours (8am–9pm local), and call-recording consent for the '
      'states involved (one- vs all-party). Propose `compliance` tags and WARN on gaps.',
  suggestions: [
    'Has written consent',
    'DNC scrubbed',
    'Recording disclosed',
    'Calling 8am-9pm local',
  ],
);

final SetupFlowDefinition ivrInboundFlow = SetupFlowDefinition(
  projectType: 'ivr-call-systems',
  subCategory: 'inboundIvr',
  name: 'Inbound IVR / auto-attendant setup',
  intro:
      'Interview the user to design an inbound phone tree. Ask ONE short question at '
      'a time via `ask_question`; after each answer call `propose_tags` for that '
      'answer. Keep it concrete — these answers become the call flow.',
  stages: [
    _s(
      'businessContext',
      'Business Context',
      'What is the business and what do callers usually want? Propose `businessContext` tags.',
      suggestions: [
        'Medical office',
        'Home services',
        'Retail',
        'Professional services',
      ],
    ),
    _s(
      'callPurpose',
      'Call Purpose',
      'Top reasons people call (the menu options you will offer). Propose `callPurpose` tags.',
      suggestions: [
        'Make appointment',
        'Billing',
        'Support',
        'Hours & location',
        'Speak to a person',
      ],
    ),
    _s(
      'hoursGreeting',
      'Hours & Greeting',
      'Business hours, and the greeting text for open vs after-hours. Propose `hoursGreeting` tags.',
      input: SetupStageInput.freeform,
    ),
    _s(
      'menuOptions',
      'Menu Options',
      'For each call purpose, the DTMF key and a one-line script. Propose `menuOptions` tags.',
      input: SetupStageInput.freeform,
    ),
    _s(
      'routingTargets',
      'Routing',
      'Where each option goes — extension, ring group, queue, or voicemail. Propose `routingTargets` tags.',
      suggestions: [
        'Front desk extension',
        'Sales ring group',
        'Support queue',
        'Voicemail',
      ],
    ),
    _s(
      'voicemailFallback',
      'Voicemail & Fallback',
      'What happens on no-answer / invalid input / after hours. Propose `voicemailFallback` tags.',
      suggestions: ['Leave a voicemail', 'Repeat menu', 'Transfer to operator'],
    ),
    _persona(),
  ],
  finalizeGuidance:
      'When satisfied, call `finalize_setup` to generate the call-system plan '
      '(an inbound flow: greeting → menu → routing → voicemail). The Call Flow '
      'builder turns this into the editable graph.',
);

final SetupFlowDefinition ivrVoicebotFlow = SetupFlowDefinition(
  projectType: 'ivr-call-systems',
  subCategory: 'aiVoicebot',
  name: 'AI voicebot setup',
  intro:
      'Interview the user to design a conversational phone agent that answers and '
      'handles calls. Ask one short question at a time; `propose_tags` after each.',
  stages: [
    _s(
      'botPurpose',
      'Bot Purpose',
      'What should the voicebot accomplish on a call (book, answer FAQs, qualify…)? Propose `botPurpose` tags.',
      suggestions: [
        'Answer FAQs',
        'Book appointments',
        'Qualify leads',
        'Take orders',
      ],
    ),
    _s(
      'persona',
      'Persona & Tone',
      'Name, personality, and tone of the agent. Propose `persona` tags.',
      suggestions: ['Friendly', 'Professional', 'Empathetic'],
    ),
    _s(
      'knowledgeAnswers',
      'Knowledge & Answers',
      'Key facts/answers the bot must know (hours, services, prices, policies). Propose `knowledgeAnswers` tags.',
      input: SetupStageInput.freeform,
    ),
    _s(
      'escalationTransfer',
      'Escalation',
      'When/how to hand off to a human (keywords, failures, request). Propose `escalationTransfer` tags.',
      suggestions: [
        'On request',
        'After 2 failed turns',
        'Billing disputes',
        'Transfer to front desk',
      ],
    ),
    _persona(),
  ],
  finalizeGuidance:
      'Call `finalize_setup` to generate an AI-voicebot flow (an aiVoicebot node '
      'with the goal + a transfer fallback) plus a knowledge summary.',
);

final SetupFlowDefinition ivrOutboundFlow = SetupFlowDefinition(
  projectType: 'ivr-call-systems',
  subCategory: 'outboundCampaign',
  name: 'Outbound campaign setup',
  intro:
      'Interview the user to design an outbound calling campaign. Outbound is '
      'compliance-sensitive — be explicit about consent. One question at a time; '
      '`propose_tags` after each.',
  stages: [
    _s(
      'campaignGoal',
      'Campaign Goal',
      'What is the outbound call for (reminder, notification, follow-up)? Propose `campaignGoal` tags.',
      suggestions: [
        'Appointment reminder',
        'Payment reminder',
        'Notification',
        'Survey',
      ],
    ),
    _s(
      'audienceConsent',
      'Audience & Consent',
      'Who is being called and the consent basis to call them. Propose `audienceConsent` tags. WARN if no consent.',
      suggestions: [
        'Existing customers (written consent)',
        'Opt-in list',
        'Has prior express consent',
      ],
    ),
    _s(
      'scriptMessage',
      'Script / Message',
      'The spoken message/script, including the required identification + opt-out. Propose `scriptMessage` tags.',
      input: SetupStageInput.freeform,
    ),
    _s(
      'outcomesRouting',
      'Outcomes',
      'Handling for answer / voicemail / press-to-confirm / opt-out. Propose `outcomesRouting` tags.',
      suggestions: [
        'Press 1 to confirm',
        'Leave voicemail',
        'Press 9 to opt out',
        'Transfer to agent',
      ],
    ),
    _compliance(),
    _persona(),
  ],
  finalizeGuidance:
      'Call `finalize_setup` to generate an outbound flow (greeting → message → '
      'confirm/opt-out → outcome) with the compliance settings recorded.',
);

final SetupFlowDefinition ivrGenericFlow = SetupFlowDefinition(
  projectType: 'ivr-call-systems',
  name: 'Call system setup',
  intro:
      'Interview the user to design their phone system. One short question at a '
      'time via `ask_question`; `propose_tags` after each answer.',
  stages: [
    _s(
      'businessContext',
      'Business Context',
      'What is the business and what do callers need? Propose `businessContext` tags.',
    ),
    _s(
      'callPurpose',
      'Call Purpose',
      'The main things the system must handle. Propose `callPurpose` tags.',
    ),
    _s(
      'routingTargets',
      'Routing',
      'Where calls should go (people, groups, queues, voicemail). Propose `routingTargets` tags.',
    ),
    _persona(),
  ],
  finalizeGuidance:
      'Call `finalize_setup` to generate the call-system plan for the Call Flow builder.',
);

/// Every built-in flow, in resolution-preference order (specific sub-category
/// before the type-generic before the global default).
final List<SetupFlowDefinition> kBuiltinSetupFlows = [
  ivrInboundFlow,
  ivrVoicebotFlow,
  ivrOutboundFlow,
  ivrGenericFlow,
  applicationDevelopmentFlow,
];

/// The global fallback when a project type has no built-in flow.
SetupFlowDefinition get defaultSetupFlow => applicationDevelopmentFlow;

/// Resolve the built-in flow for a (projectType, subCategory): exact match →
/// type-generic (subCategory == null) → global default.
SetupFlowDefinition resolveBuiltinSetupFlow(
  String projectType,
  String? subCategory,
) {
  SetupFlowDefinition? typeGeneric;
  for (final f in kBuiltinSetupFlows) {
    if (f.projectType != projectType) continue;
    if (f.subCategory == subCategory) return f;
    if (f.subCategory == null) typeGeneric = f;
  }
  return typeGeneric ?? defaultSetupFlow;
}
