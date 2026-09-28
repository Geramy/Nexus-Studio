// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';

import 'package:nexus_projects_client/infrastructure/lemonade/models/server_config.dart';
import 'package:nexus_projects_client/infrastructure/lemonade/models/discovered_server.dart';

import '../cards/configured_server_card.dart';
import '../widgets/server_count_chip.dart';
import 'package:nexus_projects_client/shared/ui/widgets/empty_state.dart';

/// Tab showing configured Lemonade servers with add/edit/remove actions.
class ConfiguredServersTab extends StatelessWidget {
  final List<DiscoveredServer> discovered;
  final List<ServerConfig> configured;
  final ServerConfig? selected;
  final VoidCallback onAddServer;

  const ConfiguredServersTab({
    super.key,
    required this.discovered,
    required this.configured,
    required this.selected,
    required this.onAddServer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Configured Servers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            ServerCountChip(count: configured.length, color: Colors.deepPurple),
            const Spacer(),
            FilledButton.icon(
              onPressed: onAddServer,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Server'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (configured.isEmpty)
          const EmptyState(
            icon: Icons.storage_outlined,
            title: 'No servers configured',
            message: 'Add one to get started.',
          )
        else
          ...configured.map(
            (server) => ConfiguredServerCard(
              server: server,
              isSelected: selected == server,
            ),
          ),
      ],
    );
  }
}
