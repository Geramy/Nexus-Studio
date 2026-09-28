// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter/material.dart';

import 'package:nexus_projects_client/infrastructure/lemonade/models/discovered_server.dart';

import '../cards/discovered_server_card.dart';
import 'package:nexus_projects_client/shared/ui/widgets/empty_state.dart';

/// Tab showing servers discovered via beacon.
class DiscoveredServersTab extends StatelessWidget {
  final List<DiscoveredServer> discovered;

  const DiscoveredServersTab({super.key, required this.discovered});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Discovered Servers',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (discovered.isEmpty)
          const EmptyState(
            icon: Icons.wifi_off_outlined,
            title: 'No servers discovered',
            message: 'Make sure your Lemonade server is running.',
          )
        else
          ...discovered.map(
            (server) => DiscoveredServerCard(server: server, isSelected: false),
          ),
      ],
    );
  }
}
