// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_riverpod/legacy.dart';

/// Bump counter used to request that the project workspace switch to its
/// Overview tab (where the orchestration Start/Pause/Stop controls live).
/// Incremented from places that can't reach the [TabController] directly —
/// e.g. the setup "Done" flow nudging the user to turn orchestration on.
final requestOverviewTabProvider = StateProvider<int>((ref) => 0);

/// Bump counter used to request that the project workspace switch to its
/// User Stories tab (which becomes the post-completion Editor workspace)
/// AND open the Editor in VISUAL mode. Incremented from the Overview
/// "Launch with Editor" button.
final requestVisualEditorProvider = StateProvider<int>((ref) => 0);
