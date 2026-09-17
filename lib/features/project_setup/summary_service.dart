// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../project_plans/plan_store.dart';
import 'setup_inference.dart';

/// Compiles every `/PLANS` file into a plain-language project summary the user
/// can read to verify the AI understood their intent. Persisted to
/// `Projects.projectSummaryMd`. Regenerated on demand ("Generate Project
/// Summary") and opportunistically by the coordinator during idle cycles.
class SummaryService {
  SummaryService(this.ref);

  final Ref ref;

  /// Reads all plan documents, asks the project's backend to compile a summary,
  /// saves it, and returns the markdown. Throws if no inference is configured.
  Future<String> generate({
    required int projectId,
    required int clientId,
  }) async {
    final store = await ref.read(planStoreProvider(projectId).future);
    final nodes = await store.list();
    final docs = nodes.where((n) => !n.isFolder).toList();

    final combined = StringBuffer();
    for (final doc in docs) {
      try {
        final content = await store.read(doc.path);
        if (content.trim().isEmpty) continue;
        combined.writeln('# FILE: ${doc.name}');
        combined.writeln(content);
        combined.writeln('\n---\n');
      } catch (_) {}
    }

    final db = ref.read(nexusDatabaseProvider);

    if (combined.isEmpty) {
      const empty =
          '_No plans yet. Run Project Setup or add files under /PLANS, then regenerate._';
      await db.setProjectSummary(projectId, empty);
      return empty;
    }

    final resolved = await ref.read(
      projectInferenceProvider((
        projectId: projectId,
        clientId: clientId,
      )).future,
    );
    if (resolved == null) {
      throw StateError(
        'No inference server configured — add one in Agents Hub to generate a summary.',
      );
    }

    final resp = await resolved.backend.createChatCompletion(
      model: resolved.model,
      messages: [
        {
          'role': 'system',
          'content':
              'You compile a project\'s planning documents into a clear, plain-'
              'language summary for a non-technical stakeholder. Use short '
              'sections and bullets. Cover: what the project is, who it serves, '
              'the architecture (client/server/db/etc.), the chosen stack, and '
              'the major work outlined. Do not invent details not in the plans. '
              'Output Markdown only.',
        },
        {
          'role': 'user',
          'content':
              'Here are the project plan files. Compile them into a project '
              'summary:\n\n${combined.toString()}',
        },
      ],
      temperature: 0.4,
      // Agent's thinking level, sent verbatim (no clamping).
      extra: resolved.reasoningEffort != null
          ? {'reasoning_effort': resolved.reasoningEffort}
          : null,
    );

    final summary = resp.choices.isNotEmpty
        ? (resp.choices.first.message.content ?? '').trim()
        : '';
    final out = summary.isEmpty ? '_Could not generate a summary._' : summary;
    await db.setProjectSummary(projectId, out);
    return out;
  }
}

final summaryServiceProvider = Provider<SummaryService>((ref) {
  return SummaryService(ref);
});
