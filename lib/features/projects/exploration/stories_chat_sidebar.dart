// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// The right-hand sidebar that lives beside the User Story tree (both on the
/// persistent "User Stories" workspace screen and in the post-setup discovery
/// phase). Two tabs:
///   • **Chat** — the live Coordinator conversation ([ProjectCoordinatorChatScreen]).
///   • **History** — past coordinator chat sessions for this project
///     ([ChatSessionsSidebar]); picking one swaps the Chat tab's conversation
///     (both are wired through `currentChatSessionProvider`).
library;

import 'package:flutter/material.dart';

import 'package:nexus_projects_client/features/main/widgets/chat_sessions_sidebar.dart';
import 'package:nexus_projects_client/features/projects/coordinator_chat_screen.dart';

class StoriesChatSidebar extends StatelessWidget {
  const StoriesChatSidebar({
    super.key,
    required this.projectId,
    required this.projectName,
    this.discoveryMode = false,
    this.editorMode = false,
    this.systemPromptOverride,
    this.autoOpenPrompt,
  });

  final int projectId;
  final String projectName;

  /// Discovery-phase passthrough: limits the chat to user-story tools, swaps in
  /// the discovery system prompt, and makes the Coordinator speak first.
  final bool discoveryMode;

  /// Post-completion Editor passthrough: gives the chat the file/git/build edit
  /// tools + the editor system prompt (maintain the already-built app).
  final bool editorMode;
  final String? systemPromptOverride;
  final String? autoOpenPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Chat is the default tab so the conversation (and the composer the CI
    // screenshot test drives) is front-and-center.
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelStyle: theme.textTheme.labelLarge,
            tabs: const [
              Tab(
                height: 40,
                icon: Icon(Icons.forum_outlined, size: 16),
                iconMargin: EdgeInsets.zero,
                text: 'Chat',
              ),
              Tab(
                height: 40,
                icon: Icon(Icons.history, size: 16),
                iconMargin: EdgeInsets.zero,
                text: 'History',
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              // Don't let a horizontal drag in the chat composer flip tabs.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ProjectCoordinatorChatScreen(
                  key: ValueKey('stories-chat-$projectId'),
                  projectId: projectId,
                  projectName: projectName,
                  discoveryMode: discoveryMode,
                  editorMode: editorMode,
                  systemPromptOverride: systemPromptOverride,
                  autoOpenPrompt: autoOpenPrompt,
                ),
                const ChatSessionsSidebar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
