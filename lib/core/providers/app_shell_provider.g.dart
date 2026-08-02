// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_shell_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentMainView)
final currentMainViewProvider = CurrentMainViewProvider._();

final class CurrentMainViewProvider
    extends $NotifierProvider<CurrentMainView, MainView> {
  CurrentMainViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMainViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMainViewHash();

  @$internal
  @override
  CurrentMainView create() => CurrentMainView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MainView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MainView>(value),
    );
  }
}

String _$currentMainViewHash() => r'd8d197027b1d2b403652bea6613441e1063d875c';

abstract class _$CurrentMainView extends $Notifier<MainView> {
  MainView build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MainView, MainView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MainView, MainView>,
              MainView,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SelectedTaskIdNotifier)
final selectedTaskIdProvider = SelectedTaskIdNotifierProvider._();

final class SelectedTaskIdNotifierProvider
    extends $NotifierProvider<SelectedTaskIdNotifier, int?> {
  SelectedTaskIdNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedTaskIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedTaskIdNotifierHash();

  @$internal
  @override
  SelectedTaskIdNotifier create() => SelectedTaskIdNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$selectedTaskIdNotifierHash() =>
    r'cd8d00b7f5de6cdebbb18fbc7d789d7ee416113d';

abstract class _$SelectedTaskIdNotifier extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Current selected client (top level of the hierarchy)

@ProviderFor(CurrentClientId)
final currentClientIdProvider = CurrentClientIdProvider._();

/// Current selected client (top level of the hierarchy)
final class CurrentClientIdProvider
    extends $NotifierProvider<CurrentClientId, int> {
  /// Current selected client (top level of the hierarchy)
  CurrentClientIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentClientIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentClientIdHash();

  @$internal
  @override
  CurrentClientId create() => CurrentClientId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$currentClientIdHash() => r'd6e260afe729c1d0ef84da228525f9da7cdd2045';

/// Current selected client (top level of the hierarchy)

abstract class _$CurrentClientId extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Current selected project (part of Client → Projects → Tasks hierarchy)

@ProviderFor(CurrentProjectId)
final currentProjectIdProvider = CurrentProjectIdProvider._();

/// Current selected project (part of Client → Projects → Tasks hierarchy)
final class CurrentProjectIdProvider
    extends $NotifierProvider<CurrentProjectId, int> {
  /// Current selected project (part of Client → Projects → Tasks hierarchy)
  CurrentProjectIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentProjectIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentProjectIdHash();

  @$internal
  @override
  CurrentProjectId create() => CurrentProjectId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$currentProjectIdHash() => r'47203f032825bdf387bdee40c1bd2215003bc7b4';

/// Current selected project (part of Client → Projects → Tasks hierarchy)

abstract class _$CurrentProjectId extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ConnectionModeNotifier)
final connectionModeProvider = ConnectionModeNotifierProvider._();

final class ConnectionModeNotifierProvider
    extends $NotifierProvider<ConnectionModeNotifier, String> {
  ConnectionModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionModeNotifierHash();

  @$internal
  @override
  ConnectionModeNotifier create() => ConnectionModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$connectionModeNotifierHash() =>
    r'ec812b9d5e0ba75c816fd86cd1914a947b9e832e';

abstract class _$ConnectionModeNotifier extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SelectedPersonaNotifier)
final selectedPersonaProvider = SelectedPersonaNotifierProvider._();

final class SelectedPersonaNotifierProvider
    extends $NotifierProvider<SelectedPersonaNotifier, EditingPersona?> {
  SelectedPersonaNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedPersonaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedPersonaNotifierHash();

  @$internal
  @override
  SelectedPersonaNotifier create() => SelectedPersonaNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditingPersona? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditingPersona?>(value),
    );
  }
}

String _$selectedPersonaNotifierHash() =>
    r'e83cc09624e5cc0b3e96ff816f435412ab54ddfb';

abstract class _$SelectedPersonaNotifier extends $Notifier<EditingPersona?> {
  EditingPersona? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EditingPersona?, EditingPersona?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EditingPersona?, EditingPersona?>,
              EditingPersona?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The active Coordinator chat session id for a given project (right-panel
/// selection). Family keyed by projectId so each project has its own active
/// session. The coordinator chat screen opens this session; the Chat Sessions
/// sidebar selects/creates it.

@ProviderFor(CurrentChatSession)
final currentChatSessionProvider = CurrentChatSessionFamily._();

/// The active Coordinator chat session id for a given project (right-panel
/// selection). Family keyed by projectId so each project has its own active
/// session. The coordinator chat screen opens this session; the Chat Sessions
/// sidebar selects/creates it.
final class CurrentChatSessionProvider
    extends $NotifierProvider<CurrentChatSession, int?> {
  /// The active Coordinator chat session id for a given project (right-panel
  /// selection). Family keyed by projectId so each project has its own active
  /// session. The coordinator chat screen opens this session; the Chat Sessions
  /// sidebar selects/creates it.
  CurrentChatSessionProvider._({
    required CurrentChatSessionFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'currentChatSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$currentChatSessionHash();

  @override
  String toString() {
    return r'currentChatSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CurrentChatSession create() => CurrentChatSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentChatSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$currentChatSessionHash() =>
    r'474108968b9d2a27768cda1173df5581f4a26bd3';

/// The active Coordinator chat session id for a given project (right-panel
/// selection). Family keyed by projectId so each project has its own active
/// session. The coordinator chat screen opens this session; the Chat Sessions
/// sidebar selects/creates it.

final class CurrentChatSessionFamily extends $Family
    with $ClassFamilyOverride<CurrentChatSession, int?, int?, int?, int> {
  CurrentChatSessionFamily._()
    : super(
        retry: null,
        name: r'currentChatSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The active Coordinator chat session id for a given project (right-panel
  /// selection). Family keyed by projectId so each project has its own active
  /// session. The coordinator chat screen opens this session; the Chat Sessions
  /// sidebar selects/creates it.

  CurrentChatSessionProvider call(int projectId) =>
      CurrentChatSessionProvider._(argument: projectId, from: this);

  @override
  String toString() => r'currentChatSessionProvider';
}

/// The active Coordinator chat session id for a given project (right-panel
/// selection). Family keyed by projectId so each project has its own active
/// session. The coordinator chat screen opens this session; the Chat Sessions
/// sidebar selects/creates it.

abstract class _$CurrentChatSession extends $Notifier<int?> {
  late final _$args = ref.$arg as int;
  int get projectId => _$args;

  int? build(int projectId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The plan currently opened in the Project Plans workspace (workspace path,
/// e.g. `/PLANS/Roadmap.md`), set by clicking a plan file in the explorer.
/// Null = nothing open.

@ProviderFor(OpenPlanNotifier)
final openPlanProvider = OpenPlanNotifierProvider._();

/// The plan currently opened in the Project Plans workspace (workspace path,
/// e.g. `/PLANS/Roadmap.md`), set by clicking a plan file in the explorer.
/// Null = nothing open.
final class OpenPlanNotifierProvider
    extends $NotifierProvider<OpenPlanNotifier, String?> {
  /// The plan currently opened in the Project Plans workspace (workspace path,
  /// e.g. `/PLANS/Roadmap.md`), set by clicking a plan file in the explorer.
  /// Null = nothing open.
  OpenPlanNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openPlanNotifierHash();

  @$internal
  @override
  OpenPlanNotifier create() => OpenPlanNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$openPlanNotifierHash() => r'14ed91b11239ac2e5da57bd58b3aa563f36db545';

/// The plan currently opened in the Project Plans workspace (workspace path,
/// e.g. `/PLANS/Roadmap.md`), set by clicking a plan file in the explorer.
/// Null = nothing open.

abstract class _$OpenPlanNotifier extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PlanModeNotifier)
final planModeProvider = PlanModeNotifierProvider._();

final class PlanModeNotifierProvider
    extends $NotifierProvider<PlanModeNotifier, PlanMode> {
  PlanModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planModeNotifierHash();

  @$internal
  @override
  PlanModeNotifier create() => PlanModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanMode>(value),
    );
  }
}

String _$planModeNotifierHash() => r'098ce815492356cc7aed11814e6e1f5f430cab69';

abstract class _$PlanModeNotifier extends $Notifier<PlanMode> {
  PlanMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlanMode, PlanMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlanMode, PlanMode>,
              PlanMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Persistent right-panel width per MainView.
/// Stored in SharedPreferences so layout survives app restarts.

@ProviderFor(PanelLayoutNotifier)
final panelLayoutProvider = PanelLayoutNotifierProvider._();

/// Persistent right-panel width per MainView.
/// Stored in SharedPreferences so layout survives app restarts.
final class PanelLayoutNotifierProvider
    extends $NotifierProvider<PanelLayoutNotifier, Map<MainView, double>> {
  /// Persistent right-panel width per MainView.
  /// Stored in SharedPreferences so layout survives app restarts.
  PanelLayoutNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'panelLayoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$panelLayoutNotifierHash();

  @$internal
  @override
  PanelLayoutNotifier create() => PanelLayoutNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<MainView, double> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<MainView, double>>(value),
    );
  }
}

String _$panelLayoutNotifierHash() =>
    r'c6c29e60a74ec135edf94c6cae907d10a6a6cdf6';

/// Persistent right-panel width per MainView.
/// Stored in SharedPreferences so layout survives app restarts.

abstract class _$PanelLayoutNotifier extends $Notifier<Map<MainView, double>> {
  Map<MainView, double> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<MainView, double>, Map<MainView, double>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<MainView, double>, Map<MainView, double>>,
              Map<MainView, double>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
