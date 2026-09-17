// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';

/// Tri-state "thinking mode" for an agent (and, in pass 2, a task).
///
/// `unset` inherits the next level down; `on`/`off` force the model's
/// `enable_thinking` request flag. Stored as a string in a persona's
/// `configJson` under the `thinkingMode` key (alongside `toolPermissions`).
enum ThinkingMode {
  unset,
  on,
  off;

  static ThinkingMode fromString(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'on':
      case 'true':
        return ThinkingMode.on;
      case 'off':
      case 'false':
        return ThinkingMode.off;
      default:
        return ThinkingMode.unset;
    }
  }

  String get wire => switch (this) {
    ThinkingMode.on => 'on',
    ThinkingMode.off => 'off',
    ThinkingMode.unset => 'unset',
  };

  String get label => switch (this) {
    ThinkingMode.on => 'On',
    ThinkingMode.off => 'Off',
    ThinkingMode.unset => 'Unset',
  };

  /// The `enable_thinking` value this mode forces, or null when it inherits
  /// (i.e. the request omits the parameter entirely).
  bool? get enableThinking => switch (this) {
    ThinkingMode.on => true,
    ThinkingMode.off => false,
    ThinkingMode.unset => null,
  };
}

/// Resolves the effective `enable_thinking` flag.
///
/// Precedence (per product decision): the AGENT wins; the task is only consulted
/// when the agent is Unset; if both are Unset the parameter is omitted (null).
bool? resolveEnableThinking({
  required ThinkingMode agent,
  ThinkingMode task = ThinkingMode.unset,
}) => agent.enableThinking ?? task.enableThinking;

/// Reads a persona's thinking mode from its `configJson`. When the persona
/// hasn't set one, the default is Off for the **Project Manager** and Unset for
/// every other agent.
ThinkingMode personaThinkingMode(String? configJson, {String? personaName}) {
  if (configJson != null && configJson.trim().isNotEmpty) {
    try {
      final cfg = jsonDecode(configJson);
      if (cfg is Map && cfg['thinkingMode'] != null) {
        return ThinkingMode.fromString('${cfg['thinkingMode']}');
      }
    } catch (_) {}
  }
  if ((personaName ?? '').trim().toLowerCase() == 'project manager') {
    return ThinkingMode.off;
  }
  return ThinkingMode.unset;
}

/// Merges [mode] into an existing `configJson`, preserving other keys. Unset
/// removes the key so the Project-Manager default can still apply.
String writeThinkingModeIntoConfigJson(String? configJson, ThinkingMode mode) {
  Map<String, dynamic> cfg = {};
  if (configJson != null && configJson.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(configJson);
      if (parsed is Map) cfg = Map<String, dynamic>.from(parsed);
    } catch (_) {}
  }
  if (mode == ThinkingMode.unset) {
    cfg.remove('thinkingMode');
  } else {
    cfg['thinkingMode'] = mode.wire;
  }
  return jsonEncode(cfg);
}

/// Graded reasoning effort for an agent, pi-style.
///
/// Sent to the model VERBATIM as `reasoning_effort` (identity mapping — the
/// level we pick is the level we send; no clamping to whatever the model
/// claims to support). Stored as a string in a persona's `configJson` under
/// the `thinkingLevel` key (alongside `thinkingMode`).
enum ThinkingLevel {
  off,
  minimal,
  low,
  medium,
  high,
  xhigh,
  max;

  /// Lenient parse. Unknown/missing values fall back to
  /// [kDefaultThinkingLevel] (Low for now).
  static ThinkingLevel fromString(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'off':
      case 'none':
        return ThinkingLevel.off;
      case 'minimal':
      case 'min':
        return ThinkingLevel.minimal;
      case 'low':
        return ThinkingLevel.low;
      case 'medium':
      case 'med':
        return ThinkingLevel.medium;
      case 'high':
        return ThinkingLevel.high;
      case 'xhigh':
      case 'x-high':
      case 'x_high':
        return ThinkingLevel.xhigh;
      case 'max':
        return ThinkingLevel.max;
      default:
        return kDefaultThinkingLevel;
    }
  }

  /// The value sent to the model in `reasoning_effort`. Identity: the level
  /// name itself, nothing else.
  String get wire => name;

  String get label => switch (this) {
    ThinkingLevel.off => 'Off',
    ThinkingLevel.minimal => 'Minimal',
    ThinkingLevel.low => 'Low',
    ThinkingLevel.medium => 'Medium',
    ThinkingLevel.high => 'High',
    ThinkingLevel.xhigh => 'X-High',
    ThinkingLevel.max => 'Max',
  };
}

/// The level any agent that hasn't set one explicitly runs at. For now:
/// everything is Low.
const ThinkingLevel kDefaultThinkingLevel = ThinkingLevel.low;

/// Reads a persona's thinking level from its `configJson` (`thinkingLevel`
/// key). Agents without an explicit level resolve to [kDefaultThinkingLevel]
/// (Low), so every agent starts at Low until the user adjusts one.
ThinkingLevel personaThinkingLevel(String? configJson) {
  if (configJson != null && configJson.trim().isNotEmpty) {
    try {
      final cfg = jsonDecode(configJson);
      if (cfg is Map && cfg['thinkingLevel'] != null) {
        return ThinkingLevel.fromString('${cfg['thinkingLevel']}');
      }
    } catch (_) {}
  }
  return kDefaultThinkingLevel;
}

/// The `reasoning_effort` value to send for this persona's config (null
/// omits the parameter entirely).
String? personaReasoningEffort(String? configJson) =>
    personaThinkingLevel(configJson).wire;

/// Merges [level] into an existing `configJson`, preserving other keys.
String writeThinkingLevelIntoConfigJson(String? configJson, ThinkingLevel level) {
  Map<String, dynamic> cfg = {};
  if (configJson != null && configJson.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(configJson);
      if (parsed is Map) cfg = Map<String, dynamic>.from(parsed);
    } catch (_) {}
  }
  cfg['thinkingLevel'] = level.wire;
  return jsonEncode(cfg);
}
