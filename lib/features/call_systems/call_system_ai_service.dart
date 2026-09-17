// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_shell_provider.dart';
import '../../infrastructure/workspace/workspace_provider.dart';
import '../project_setup/setup_inference.dart';
import 'call_system_editor.dart';
import 'model/call_flow.dart';
import 'model/call_node.dart';
import 'model/call_system_project.dart';

/// AI assistance for the call-system builder, over the SAME Omni inference the
/// rest of the app uses (resolved via [projectInferenceProvider]):
///   - [generateFlow]  — turn a plain-language description into a full call flow.
///   - [synthesizePrompts] — render each prompt's text to audio with kokoro TTS.
class CallSystemAiService {
  CallSystemAiService(this._ref, this.projectId);
  final Ref _ref;
  final int projectId;

  CallSystemEditor get _editor =>
      _ref.read(callSystemEditorProvider(projectId));

  Future<dynamic> _resolveInference() async {
    final clientId = _ref.read(currentClientIdProvider);
    return _ref.read(
      projectInferenceProvider((
        projectId: projectId,
        clientId: clientId,
      )).future,
    );
  }

  static const _schemaSpec = '''
Return ONLY a JSON object for a phone call flow (no prose, no code fences) shaped:
{
  "flows": [{
    "id": "flow_main", "name": "Main", "entryNodeId": "n_entry",
    "nodes": [
      {"id":"n_entry","type":"entry","label":"Call starts","x":80,"y":60,"outputs":{"next":"n_greet"}},
      {"id":"n_greet","type":"playPrompt","label":"Greeting","x":80,"y":200,"config":{"promptId":"p_greet"},"outputs":{"next":"n_menu"}},
      {"id":"n_menu","type":"menu","label":"Main menu","x":80,"y":340,"config":{"promptId":"p_menu"},"outputs":{"1":"n_sales","2":"n_support","timeout":"n_vm","invalid":"n_vm"}}
    ]
  }],
  "prompts": [{"id":"p_greet","text":"Thanks for calling Acme.","voice":"af_heart"}]
}
Node "type" is one of: entry, playPrompt, menu, gatherDigits, gatherSpeech,
aiVoicebot, dial, transferToExtension, ringGroup, queue, voicemail, schedule,
condition, setVariable, httpRequest, record, playDirectory, hangup, subFlow.
Rules: exactly one "entry" node; every spoken node references a prompt via
config.promptId and that prompt MUST exist in "prompts"; menu digit keys ("1".."9")
plus "timeout"/"invalid" are outputs; end branches with a "hangup" node or omit.
Keep it focused and valid.''';

  /// Generate a call flow from [description], replacing the project's flows +
  /// prompts (the project name / sub-category / experience mode are preserved).
  Future<void> generateFlow(String description) async {
    final resolved = await _resolveInference();
    if (resolved == null) {
      throw StateError(
        'No inference is configured. Sign in or add a local server first.',
      );
    }
    final current = _editor.current;
    final resp = await resolved.backend.createChatCompletion(
      model: resolved.model,
      messages: [
        {
          'role': 'system',
          'content':
              'You are an expert phone-system (IVR) designer. $_schemaSpec',
        },
        {
          'role': 'user',
          'content':
              'Design the call flow for: "$description". Sub-category: ${current.subCategory.name}.',
        },
      ],
      temperature: 0.4,
      enableThinking: resolved.enableThinking,
      // Agent's thinking level, sent verbatim (no clamping).
      extra: resolved.reasoningEffort != null
          ? {'reasoning_effort': resolved.reasoningEffort}
          : null,
    );
    final content = resp.choices.isNotEmpty
        ? (resp.choices.first.message.content ?? '')
        : '';
    final json = _extractJson(content);
    if (json == null) {
      throw StateError('The model did not return a usable call flow.');
    }
    final generated = CallSystemProject.fromJson(json);
    // Preserve project identity; take the generated flows/prompts/entities.
    final merged = CallSystemProject(
      name: current.name,
      subCategory: current.subCategory,
      experienceMode: current.experienceMode,
      dids: generated.dids.isNotEmpty ? generated.dids : current.dids,
      extensions: generated.extensions.isNotEmpty
          ? generated.extensions
          : current.extensions,
      ringGroups: generated.ringGroups,
      pickupGroups: generated.pickupGroups,
      parkGroups: generated.parkGroups,
      queues: generated.queues,
      voicemailBoxes: generated.voicemailBoxes,
      timeConditions: generated.timeConditions,
      // AI-generated nodes arrive as `proposed` so they appear ghosted on the
      // tree for the user to review/approve (the entry node stays structural).
      flows: generated.flows.isNotEmpty
          ? generated.flows.map(_markProposed).toList()
          : current.flows,
      prompts: generated.prompts,
      variables: {...current.variables, ...generated.variables},
    );
    await _editor.replaceProject(merged);
  }

  /// Synthesize audio for every prompt that has text but no audio yet, using the
  /// resolved kokoro TTS model/voice. Audio is written INTO the project workspace
  /// (our git-backed sandbox storage) under `call-system/audio/`, so it travels
  /// with the repo + the "Download .zip" export, and each prompt's
  /// audioAssetPath references the workspace-relative path. Returns the count.
  Future<int> synthesizePrompts({bool force = false}) async {
    final resolved = await _resolveInference();
    if (resolved == null) {
      throw StateError('No inference is configured for speech synthesis.');
    }
    final ws = await _ref.read(workspaceFsProvider(projectId).future);

    var count = 0;
    for (final prompt in _editor.current.prompts) {
      if (prompt.text.trim().isEmpty) continue;
      if (!force && (prompt.audioAssetPath?.isNotEmpty ?? false)) continue;
      final speech = await resolved.backend.generateSpeech(
        input: prompt.text,
        model: resolved.ttsModel,
        voice: prompt.voice ?? resolved.ttsVoice ?? 'af_heart',
      );
      final ext = speech.contentType.contains('wav') ? 'wav' : 'mp3';
      final rel = 'call-system/audio/${prompt.id}.$ext';
      await ws.writeBytes('/$rel', speech.audioBytes);
      await _editor.upsertPrompt(prompt.copyWith(audioAssetPath: rel));
      count++;
    }
    return count;
  }

  /// Delete synthesized audio files in the workspace that no prompt references
  /// anymore — e.g. after a prompt id changed or audio was regenerated under a
  /// new name. Keeps the git-backed repo (and the exported zip) free of orphaned
  /// clips. Returns the number of files removed.
  Future<int> pruneOrphanAudio() async {
    final ws = await _ref.read(workspaceFsProvider(projectId).future);
    const dir = '/call-system/audio';
    if (!await ws.exists(dir)) return 0;

    String norm(String s) => s.startsWith('/') ? s.substring(1) : s;
    final referenced = <String>{
      for (final pr in _editor.current.prompts)
        if (pr.audioAssetPath != null && pr.audioAssetPath!.isNotEmpty)
          norm(pr.audioAssetPath!),
    };

    var removed = 0;
    for (final e in await ws.list(dir)) {
      if (e.isDirectory) continue;
      if (!referenced.contains(norm(e.path))) {
        await ws.delete(e.path);
        removed++;
      }
    }
    return removed;
  }

  /// Pull the first JSON object out of a model reply (tolerating code fences /
  /// surrounding prose).
  Map<String, dynamic>? _extractJson(String raw) {
    var s = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

/// Mark every non-entry node of a flow `proposed` (awaiting approval).
CallFlow _markProposed(CallFlow f) => f.copyWith(
  nodes: f.nodes
      .map(
        (n) => n.type == CallNodeType.entry
            ? n
            : n.copyWith(status: NodeStatus.proposed),
      )
      .toList(),
);

final callSystemAiServiceProvider = Provider.family<CallSystemAiService, int>((
  ref,
  projectId,
) {
  return CallSystemAiService(ref, projectId);
});
