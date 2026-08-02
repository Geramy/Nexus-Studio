// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nexus_database.dart';

// ignore_for_file: type=lint
class $ClientsTable extends Clients with TableInfo<$ClientsTable, Client> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _client_pkMeta = const VerificationMeta(
    'client_pk',
  );
  @override
  late final GeneratedColumn<int> client_pk = GeneratedColumn<int>(
    'client_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    client_pk,
    name,
    isDefault,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Client> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_pk')) {
      context.handle(
        _client_pkMeta,
        client_pk.isAcceptableOrUnknown(data['client_pk']!, _client_pkMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {client_pk};
  @override
  Client map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Client(
      client_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_pk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }
}

class Client extends DataClass implements Insertable<Client> {
  final int client_pk;
  final String name;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Client({
    required this.client_pk,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_pk'] = Variable<int>(client_pk);
    map['name'] = Variable<String>(name);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      client_pk: Value(client_pk),
      name: Value(name),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Client.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Client(
      client_pk: serializer.fromJson<int>(json['client_pk']),
      name: serializer.fromJson<String>(json['name']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'client_pk': serializer.toJson<int>(client_pk),
      'name': serializer.toJson<String>(name),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Client copyWith({
    int? client_pk,
    String? name,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Client(
    client_pk: client_pk ?? this.client_pk,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Client copyWithCompanion(ClientsCompanion data) {
    return Client(
      client_pk: data.client_pk.present ? data.client_pk.value : this.client_pk,
      name: data.name.present ? data.name.value : this.name,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Client(')
          ..write('client_pk: $client_pk, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(client_pk, name, isDefault, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Client &&
          other.client_pk == this.client_pk &&
          other.name == this.name &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ClientsCompanion extends UpdateCompanion<Client> {
  final Value<int> client_pk;
  final Value<String> name;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ClientsCompanion({
    this.client_pk = const Value.absent(),
    this.name = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ClientsCompanion.insert({
    this.client_pk = const Value.absent(),
    required String name,
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Client> custom({
    Expression<int>? client_pk,
    Expression<String>? name,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (client_pk != null) 'client_pk': client_pk,
      if (name != null) 'name': name,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ClientsCompanion copyWith({
    Value<int>? client_pk,
    Value<String>? name,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ClientsCompanion(
      client_pk: client_pk ?? this.client_pk,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (client_pk.present) {
      map['client_pk'] = Variable<int>(client_pk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('client_pk: $client_pk, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $InferenceServersTable extends InferenceServers
    with TableInfo<$InferenceServersTable, InferenceServer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InferenceServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _server_pkMeta = const VerificationMeta(
    'server_pk',
  );
  @override
  late final GeneratedColumn<int> server_pk = GeneratedColumn<int>(
    'server_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiKeyMeta = const VerificationMeta('apiKey');
  @override
  late final GeneratedColumn<String> apiKey = GeneratedColumn<String>(
    'api_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _providerTypeMeta = const VerificationMeta(
    'providerType',
  );
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
    'provider_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('custom'),
  );
  static const VerificationMeta _maxConcurrencyMeta = const VerificationMeta(
    'maxConcurrency',
  );
  @override
  late final GeneratedColumn<int> maxConcurrency = GeneratedColumn<int>(
    'max_concurrency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _maxAgentsMeta = const VerificationMeta(
    'maxAgents',
  );
  @override
  late final GeneratedColumn<int> maxAgents = GeneratedColumn<int>(
    'max_agents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _selectedModelMeta = const VerificationMeta(
    'selectedModel',
  );
  @override
  late final GeneratedColumn<String> selectedModel = GeneratedColumn<String>(
    'selected_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _availableModelsJsonMeta =
      const VerificationMeta('availableModelsJson');
  @override
  late final GeneratedColumn<String> availableModelsJson =
      GeneratedColumn<String>(
        'available_models_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _extraConfigJsonMeta = const VerificationMeta(
    'extraConfigJson',
  );
  @override
  late final GeneratedColumn<String> extraConfigJson = GeneratedColumn<String>(
    'extra_config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    server_pk,
    client_fk,
    name,
    baseUrl,
    apiKey,
    providerType,
    maxConcurrency,
    maxAgents,
    isEnabled,
    selectedModel,
    availableModelsJson,
    extraConfigJson,
    capabilitiesJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inference_servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<InferenceServer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_pk')) {
      context.handle(
        _server_pkMeta,
        server_pk.isAcceptableOrUnknown(data['server_pk']!, _server_pkMeta),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('api_key')) {
      context.handle(
        _apiKeyMeta,
        apiKey.isAcceptableOrUnknown(data['api_key']!, _apiKeyMeta),
      );
    }
    if (data.containsKey('provider_type')) {
      context.handle(
        _providerTypeMeta,
        providerType.isAcceptableOrUnknown(
          data['provider_type']!,
          _providerTypeMeta,
        ),
      );
    }
    if (data.containsKey('max_concurrency')) {
      context.handle(
        _maxConcurrencyMeta,
        maxConcurrency.isAcceptableOrUnknown(
          data['max_concurrency']!,
          _maxConcurrencyMeta,
        ),
      );
    }
    if (data.containsKey('max_agents')) {
      context.handle(
        _maxAgentsMeta,
        maxAgents.isAcceptableOrUnknown(data['max_agents']!, _maxAgentsMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('selected_model')) {
      context.handle(
        _selectedModelMeta,
        selectedModel.isAcceptableOrUnknown(
          data['selected_model']!,
          _selectedModelMeta,
        ),
      );
    }
    if (data.containsKey('available_models_json')) {
      context.handle(
        _availableModelsJsonMeta,
        availableModelsJson.isAcceptableOrUnknown(
          data['available_models_json']!,
          _availableModelsJsonMeta,
        ),
      );
    }
    if (data.containsKey('extra_config_json')) {
      context.handle(
        _extraConfigJsonMeta,
        extraConfigJson.isAcceptableOrUnknown(
          data['extra_config_json']!,
          _extraConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {server_pk};
  @override
  InferenceServer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InferenceServer(
      server_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      apiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_key'],
      )!,
      providerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_type'],
      )!,
      maxConcurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_concurrency'],
      )!,
      maxAgents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_agents'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      selectedModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_model'],
      ),
      availableModelsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}available_models_json'],
      )!,
      extraConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_config_json'],
      )!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $InferenceServersTable createAlias(String alias) {
    return $InferenceServersTable(attachedDatabase, alias);
  }
}

class InferenceServer extends DataClass implements Insertable<InferenceServer> {
  final int server_pk;
  final int client_fk;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String providerType;
  final int maxConcurrency;
  final int maxAgents;
  final bool isEnabled;
  final String? selectedModel;
  final String availableModelsJson;
  final String extraConfigJson;
  final String capabilitiesJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const InferenceServer({
    required this.server_pk,
    required this.client_fk,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.providerType,
    required this.maxConcurrency,
    required this.maxAgents,
    required this.isEnabled,
    this.selectedModel,
    required this.availableModelsJson,
    required this.extraConfigJson,
    required this.capabilitiesJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_pk'] = Variable<int>(server_pk);
    map['client_fk'] = Variable<int>(client_fk);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['api_key'] = Variable<String>(apiKey);
    map['provider_type'] = Variable<String>(providerType);
    map['max_concurrency'] = Variable<int>(maxConcurrency);
    map['max_agents'] = Variable<int>(maxAgents);
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || selectedModel != null) {
      map['selected_model'] = Variable<String>(selectedModel);
    }
    map['available_models_json'] = Variable<String>(availableModelsJson);
    map['extra_config_json'] = Variable<String>(extraConfigJson);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InferenceServersCompanion toCompanion(bool nullToAbsent) {
    return InferenceServersCompanion(
      server_pk: Value(server_pk),
      client_fk: Value(client_fk),
      name: Value(name),
      baseUrl: Value(baseUrl),
      apiKey: Value(apiKey),
      providerType: Value(providerType),
      maxConcurrency: Value(maxConcurrency),
      maxAgents: Value(maxAgents),
      isEnabled: Value(isEnabled),
      selectedModel: selectedModel == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedModel),
      availableModelsJson: Value(availableModelsJson),
      extraConfigJson: Value(extraConfigJson),
      capabilitiesJson: Value(capabilitiesJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory InferenceServer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InferenceServer(
      server_pk: serializer.fromJson<int>(json['server_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      apiKey: serializer.fromJson<String>(json['apiKey']),
      providerType: serializer.fromJson<String>(json['providerType']),
      maxConcurrency: serializer.fromJson<int>(json['maxConcurrency']),
      maxAgents: serializer.fromJson<int>(json['maxAgents']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      selectedModel: serializer.fromJson<String?>(json['selectedModel']),
      availableModelsJson: serializer.fromJson<String>(
        json['availableModelsJson'],
      ),
      extraConfigJson: serializer.fromJson<String>(json['extraConfigJson']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'server_pk': serializer.toJson<int>(server_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'apiKey': serializer.toJson<String>(apiKey),
      'providerType': serializer.toJson<String>(providerType),
      'maxConcurrency': serializer.toJson<int>(maxConcurrency),
      'maxAgents': serializer.toJson<int>(maxAgents),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'selectedModel': serializer.toJson<String?>(selectedModel),
      'availableModelsJson': serializer.toJson<String>(availableModelsJson),
      'extraConfigJson': serializer.toJson<String>(extraConfigJson),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InferenceServer copyWith({
    int? server_pk,
    int? client_fk,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? providerType,
    int? maxConcurrency,
    int? maxAgents,
    bool? isEnabled,
    Value<String?> selectedModel = const Value.absent(),
    String? availableModelsJson,
    String? extraConfigJson,
    String? capabilitiesJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InferenceServer(
    server_pk: server_pk ?? this.server_pk,
    client_fk: client_fk ?? this.client_fk,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    providerType: providerType ?? this.providerType,
    maxConcurrency: maxConcurrency ?? this.maxConcurrency,
    maxAgents: maxAgents ?? this.maxAgents,
    isEnabled: isEnabled ?? this.isEnabled,
    selectedModel: selectedModel.present
        ? selectedModel.value
        : this.selectedModel,
    availableModelsJson: availableModelsJson ?? this.availableModelsJson,
    extraConfigJson: extraConfigJson ?? this.extraConfigJson,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InferenceServer copyWithCompanion(InferenceServersCompanion data) {
    return InferenceServer(
      server_pk: data.server_pk.present ? data.server_pk.value : this.server_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      apiKey: data.apiKey.present ? data.apiKey.value : this.apiKey,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      maxConcurrency: data.maxConcurrency.present
          ? data.maxConcurrency.value
          : this.maxConcurrency,
      maxAgents: data.maxAgents.present ? data.maxAgents.value : this.maxAgents,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      selectedModel: data.selectedModel.present
          ? data.selectedModel.value
          : this.selectedModel,
      availableModelsJson: data.availableModelsJson.present
          ? data.availableModelsJson.value
          : this.availableModelsJson,
      extraConfigJson: data.extraConfigJson.present
          ? data.extraConfigJson.value
          : this.extraConfigJson,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InferenceServer(')
          ..write('server_pk: $server_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('providerType: $providerType, ')
          ..write('maxConcurrency: $maxConcurrency, ')
          ..write('maxAgents: $maxAgents, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('selectedModel: $selectedModel, ')
          ..write('availableModelsJson: $availableModelsJson, ')
          ..write('extraConfigJson: $extraConfigJson, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    server_pk,
    client_fk,
    name,
    baseUrl,
    apiKey,
    providerType,
    maxConcurrency,
    maxAgents,
    isEnabled,
    selectedModel,
    availableModelsJson,
    extraConfigJson,
    capabilitiesJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InferenceServer &&
          other.server_pk == this.server_pk &&
          other.client_fk == this.client_fk &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.apiKey == this.apiKey &&
          other.providerType == this.providerType &&
          other.maxConcurrency == this.maxConcurrency &&
          other.maxAgents == this.maxAgents &&
          other.isEnabled == this.isEnabled &&
          other.selectedModel == this.selectedModel &&
          other.availableModelsJson == this.availableModelsJson &&
          other.extraConfigJson == this.extraConfigJson &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InferenceServersCompanion extends UpdateCompanion<InferenceServer> {
  final Value<int> server_pk;
  final Value<int> client_fk;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> apiKey;
  final Value<String> providerType;
  final Value<int> maxConcurrency;
  final Value<int> maxAgents;
  final Value<bool> isEnabled;
  final Value<String?> selectedModel;
  final Value<String> availableModelsJson;
  final Value<String> extraConfigJson;
  final Value<String> capabilitiesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const InferenceServersCompanion({
    this.server_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiKey = const Value.absent(),
    this.providerType = const Value.absent(),
    this.maxConcurrency = const Value.absent(),
    this.maxAgents = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.selectedModel = const Value.absent(),
    this.availableModelsJson = const Value.absent(),
    this.extraConfigJson = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  InferenceServersCompanion.insert({
    this.server_pk = const Value.absent(),
    required int client_fk,
    required String name,
    required String baseUrl,
    this.apiKey = const Value.absent(),
    this.providerType = const Value.absent(),
    this.maxConcurrency = const Value.absent(),
    this.maxAgents = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.selectedModel = const Value.absent(),
    this.availableModelsJson = const Value.absent(),
    this.extraConfigJson = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : client_fk = Value(client_fk),
       name = Value(name),
       baseUrl = Value(baseUrl);
  static Insertable<InferenceServer> custom({
    Expression<int>? server_pk,
    Expression<int>? client_fk,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? apiKey,
    Expression<String>? providerType,
    Expression<int>? maxConcurrency,
    Expression<int>? maxAgents,
    Expression<bool>? isEnabled,
    Expression<String>? selectedModel,
    Expression<String>? availableModelsJson,
    Expression<String>? extraConfigJson,
    Expression<String>? capabilitiesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (server_pk != null) 'server_pk': server_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiKey != null) 'api_key': apiKey,
      if (providerType != null) 'provider_type': providerType,
      if (maxConcurrency != null) 'max_concurrency': maxConcurrency,
      if (maxAgents != null) 'max_agents': maxAgents,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (selectedModel != null) 'selected_model': selectedModel,
      if (availableModelsJson != null)
        'available_models_json': availableModelsJson,
      if (extraConfigJson != null) 'extra_config_json': extraConfigJson,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  InferenceServersCompanion copyWith({
    Value<int>? server_pk,
    Value<int>? client_fk,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? apiKey,
    Value<String>? providerType,
    Value<int>? maxConcurrency,
    Value<int>? maxAgents,
    Value<bool>? isEnabled,
    Value<String?>? selectedModel,
    Value<String>? availableModelsJson,
    Value<String>? extraConfigJson,
    Value<String>? capabilitiesJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return InferenceServersCompanion(
      server_pk: server_pk ?? this.server_pk,
      client_fk: client_fk ?? this.client_fk,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      providerType: providerType ?? this.providerType,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      maxAgents: maxAgents ?? this.maxAgents,
      isEnabled: isEnabled ?? this.isEnabled,
      selectedModel: selectedModel ?? this.selectedModel,
      availableModelsJson: availableModelsJson ?? this.availableModelsJson,
      extraConfigJson: extraConfigJson ?? this.extraConfigJson,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (server_pk.present) {
      map['server_pk'] = Variable<int>(server_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (apiKey.present) {
      map['api_key'] = Variable<String>(apiKey.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (maxConcurrency.present) {
      map['max_concurrency'] = Variable<int>(maxConcurrency.value);
    }
    if (maxAgents.present) {
      map['max_agents'] = Variable<int>(maxAgents.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (selectedModel.present) {
      map['selected_model'] = Variable<String>(selectedModel.value);
    }
    if (availableModelsJson.present) {
      map['available_models_json'] = Variable<String>(
        availableModelsJson.value,
      );
    }
    if (extraConfigJson.present) {
      map['extra_config_json'] = Variable<String>(extraConfigJson.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InferenceServersCompanion(')
          ..write('server_pk: $server_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiKey: $apiKey, ')
          ..write('providerType: $providerType, ')
          ..write('maxConcurrency: $maxConcurrency, ')
          ..write('maxAgents: $maxAgents, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('selectedModel: $selectedModel, ')
          ..write('availableModelsJson: $availableModelsJson, ')
          ..write('extraConfigJson: $extraConfigJson, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AgentPersonasTable extends AgentPersonas
    with TableInfo<$AgentPersonasTable, AgentPersona> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentPersonasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agent_pkMeta = const VerificationMeta(
    'agent_pk',
  );
  @override
  late final GeneratedColumn<int> agent_pk = GeneratedColumn<int>(
    'agent_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryModelMeta = const VerificationMeta(
    'primaryModel',
  );
  @override
  late final GeneratedColumn<String> primaryModel = GeneratedColumn<String>(
    'primary_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costPerMillionTokensMeta =
      const VerificationMeta('costPerMillionTokens');
  @override
  late final GeneratedColumn<double> costPerMillionTokens =
      GeneratedColumn<double>(
        'cost_per_million_tokens',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _isPrefabMeta = const VerificationMeta(
    'isPrefab',
  );
  @override
  late final GeneratedColumn<bool> isPrefab = GeneratedColumn<bool>(
    'is_prefab',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_prefab" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _prefab_fkMeta = const VerificationMeta(
    'prefab_fk',
  );
  @override
  late final GeneratedColumn<int> prefab_fk = GeneratedColumn<int>(
    'prefab_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_personas (agent_pk)',
    ),
  );
  static const VerificationMeta _overridesJsonMeta = const VerificationMeta(
    'overridesJson',
  );
  @override
  late final GeneratedColumn<String> overridesJson = GeneratedColumn<String>(
    'overrides_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _provider_fkMeta = const VerificationMeta(
    'provider_fk',
  );
  @override
  late final GeneratedColumn<int> provider_fk = GeneratedColumn<int>(
    'provider_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES inference_servers (server_pk)',
    ),
  );
  static const VerificationMeta _omniCollectionModelMeta =
      const VerificationMeta('omniCollectionModel');
  @override
  late final GeneratedColumn<String> omniCollectionModel =
      GeneratedColumn<String>(
        'omni_collection_model',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ttsModelMeta = const VerificationMeta(
    'ttsModel',
  );
  @override
  late final GeneratedColumn<String> ttsModel = GeneratedColumn<String>(
    'tts_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sttModelMeta = const VerificationMeta(
    'sttModel',
  );
  @override
  late final GeneratedColumn<String> sttModel = GeneratedColumn<String>(
    'stt_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageGenModelMeta = const VerificationMeta(
    'imageGenModel',
  );
  @override
  late final GeneratedColumn<String> imageGenModel = GeneratedColumn<String>(
    'image_gen_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visionModelMeta = const VerificationMeta(
    'visionModel',
  );
  @override
  late final GeneratedColumn<String> visionModel = GeneratedColumn<String>(
    'vision_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _llmModelMeta = const VerificationMeta(
    'llmModel',
  );
  @override
  late final GeneratedColumn<String> llmModel = GeneratedColumn<String>(
    'llm_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttsVoiceMeta = const VerificationMeta(
    'ttsVoice',
  );
  @override
  late final GeneratedColumn<String> ttsVoice = GeneratedColumn<String>(
    'tts_voice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agent_pk,
    client_fk,
    name,
    title,
    description,
    primaryModel,
    costPerMillionTokens,
    capabilitiesJson,
    configJson,
    isPrefab,
    prefab_fk,
    overridesJson,
    provider_fk,
    omniCollectionModel,
    ttsModel,
    sttModel,
    imageGenModel,
    visionModel,
    llmModel,
    ttsVoice,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_personas';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentPersona> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_pk')) {
      context.handle(
        _agent_pkMeta,
        agent_pk.isAcceptableOrUnknown(data['agent_pk']!, _agent_pkMeta),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('primary_model')) {
      context.handle(
        _primaryModelMeta,
        primaryModel.isAcceptableOrUnknown(
          data['primary_model']!,
          _primaryModelMeta,
        ),
      );
    }
    if (data.containsKey('cost_per_million_tokens')) {
      context.handle(
        _costPerMillionTokensMeta,
        costPerMillionTokens.isAcceptableOrUnknown(
          data['cost_per_million_tokens']!,
          _costPerMillionTokensMeta,
        ),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('is_prefab')) {
      context.handle(
        _isPrefabMeta,
        isPrefab.isAcceptableOrUnknown(data['is_prefab']!, _isPrefabMeta),
      );
    }
    if (data.containsKey('prefab_fk')) {
      context.handle(
        _prefab_fkMeta,
        prefab_fk.isAcceptableOrUnknown(data['prefab_fk']!, _prefab_fkMeta),
      );
    }
    if (data.containsKey('overrides_json')) {
      context.handle(
        _overridesJsonMeta,
        overridesJson.isAcceptableOrUnknown(
          data['overrides_json']!,
          _overridesJsonMeta,
        ),
      );
    }
    if (data.containsKey('provider_fk')) {
      context.handle(
        _provider_fkMeta,
        provider_fk.isAcceptableOrUnknown(
          data['provider_fk']!,
          _provider_fkMeta,
        ),
      );
    }
    if (data.containsKey('omni_collection_model')) {
      context.handle(
        _omniCollectionModelMeta,
        omniCollectionModel.isAcceptableOrUnknown(
          data['omni_collection_model']!,
          _omniCollectionModelMeta,
        ),
      );
    }
    if (data.containsKey('tts_model')) {
      context.handle(
        _ttsModelMeta,
        ttsModel.isAcceptableOrUnknown(data['tts_model']!, _ttsModelMeta),
      );
    }
    if (data.containsKey('stt_model')) {
      context.handle(
        _sttModelMeta,
        sttModel.isAcceptableOrUnknown(data['stt_model']!, _sttModelMeta),
      );
    }
    if (data.containsKey('image_gen_model')) {
      context.handle(
        _imageGenModelMeta,
        imageGenModel.isAcceptableOrUnknown(
          data['image_gen_model']!,
          _imageGenModelMeta,
        ),
      );
    }
    if (data.containsKey('vision_model')) {
      context.handle(
        _visionModelMeta,
        visionModel.isAcceptableOrUnknown(
          data['vision_model']!,
          _visionModelMeta,
        ),
      );
    }
    if (data.containsKey('llm_model')) {
      context.handle(
        _llmModelMeta,
        llmModel.isAcceptableOrUnknown(data['llm_model']!, _llmModelMeta),
      );
    }
    if (data.containsKey('tts_voice')) {
      context.handle(
        _ttsVoiceMeta,
        ttsVoice.isAcceptableOrUnknown(data['tts_voice']!, _ttsVoiceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agent_pk};
  @override
  AgentPersona map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentPersona(
      agent_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}agent_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      primaryModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_model'],
      ),
      costPerMillionTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_per_million_tokens'],
      )!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      isPrefab: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_prefab'],
      )!,
      prefab_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prefab_fk'],
      ),
      overridesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overrides_json'],
      )!,
      provider_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}provider_fk'],
      ),
      omniCollectionModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}omni_collection_model'],
      ),
      ttsModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tts_model'],
      ),
      sttModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stt_model'],
      ),
      imageGenModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_gen_model'],
      ),
      visionModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vision_model'],
      ),
      llmModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}llm_model'],
      ),
      ttsVoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tts_voice'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AgentPersonasTable createAlias(String alias) {
    return $AgentPersonasTable(attachedDatabase, alias);
  }
}

class AgentPersona extends DataClass implements Insertable<AgentPersona> {
  final int agent_pk;
  final int client_fk;
  final String name;

  /// Human-readable job title / role (e.g. "Backend Engineer", "QA Lead").
  /// Surfaced to the orchestrator so it can pick the right agent for a task.
  final String? title;
  final String? description;
  final String? primaryModel;
  final double costPerMillionTokens;
  final String capabilitiesJson;
  final String configJson;

  /// Whether this Persona is a reusable Prefab (template).
  final bool isPrefab;

  /// If set, this Persona is an *instance* that derives from the referenced Prefab.
  final int? prefab_fk;

  /// JSON map of fields that have been customized locally on this instance.
  final String overridesJson;

  /// References a row in the InferenceServers table (the global "AI Providers" list).
  final int? provider_fk;
  final String? omniCollectionModel;
  final String? ttsModel;
  final String? sttModel;
  final String? imageGenModel;
  final String? visionModel;
  final String? llmModel;

  /// Kokoro TTS voice id (e.g. 'af_heart', 'am_michael'). Null = default voice.
  final String? ttsVoice;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AgentPersona({
    required this.agent_pk,
    required this.client_fk,
    required this.name,
    this.title,
    this.description,
    this.primaryModel,
    required this.costPerMillionTokens,
    required this.capabilitiesJson,
    required this.configJson,
    required this.isPrefab,
    this.prefab_fk,
    required this.overridesJson,
    this.provider_fk,
    this.omniCollectionModel,
    this.ttsModel,
    this.sttModel,
    this.imageGenModel,
    this.visionModel,
    this.llmModel,
    this.ttsVoice,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_pk'] = Variable<int>(agent_pk);
    map['client_fk'] = Variable<int>(client_fk);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || primaryModel != null) {
      map['primary_model'] = Variable<String>(primaryModel);
    }
    map['cost_per_million_tokens'] = Variable<double>(costPerMillionTokens);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['config_json'] = Variable<String>(configJson);
    map['is_prefab'] = Variable<bool>(isPrefab);
    if (!nullToAbsent || prefab_fk != null) {
      map['prefab_fk'] = Variable<int>(prefab_fk);
    }
    map['overrides_json'] = Variable<String>(overridesJson);
    if (!nullToAbsent || provider_fk != null) {
      map['provider_fk'] = Variable<int>(provider_fk);
    }
    if (!nullToAbsent || omniCollectionModel != null) {
      map['omni_collection_model'] = Variable<String>(omniCollectionModel);
    }
    if (!nullToAbsent || ttsModel != null) {
      map['tts_model'] = Variable<String>(ttsModel);
    }
    if (!nullToAbsent || sttModel != null) {
      map['stt_model'] = Variable<String>(sttModel);
    }
    if (!nullToAbsent || imageGenModel != null) {
      map['image_gen_model'] = Variable<String>(imageGenModel);
    }
    if (!nullToAbsent || visionModel != null) {
      map['vision_model'] = Variable<String>(visionModel);
    }
    if (!nullToAbsent || llmModel != null) {
      map['llm_model'] = Variable<String>(llmModel);
    }
    if (!nullToAbsent || ttsVoice != null) {
      map['tts_voice'] = Variable<String>(ttsVoice);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AgentPersonasCompanion toCompanion(bool nullToAbsent) {
    return AgentPersonasCompanion(
      agent_pk: Value(agent_pk),
      client_fk: Value(client_fk),
      name: Value(name),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      primaryModel: primaryModel == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryModel),
      costPerMillionTokens: Value(costPerMillionTokens),
      capabilitiesJson: Value(capabilitiesJson),
      configJson: Value(configJson),
      isPrefab: Value(isPrefab),
      prefab_fk: prefab_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(prefab_fk),
      overridesJson: Value(overridesJson),
      provider_fk: provider_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(provider_fk),
      omniCollectionModel: omniCollectionModel == null && nullToAbsent
          ? const Value.absent()
          : Value(omniCollectionModel),
      ttsModel: ttsModel == null && nullToAbsent
          ? const Value.absent()
          : Value(ttsModel),
      sttModel: sttModel == null && nullToAbsent
          ? const Value.absent()
          : Value(sttModel),
      imageGenModel: imageGenModel == null && nullToAbsent
          ? const Value.absent()
          : Value(imageGenModel),
      visionModel: visionModel == null && nullToAbsent
          ? const Value.absent()
          : Value(visionModel),
      llmModel: llmModel == null && nullToAbsent
          ? const Value.absent()
          : Value(llmModel),
      ttsVoice: ttsVoice == null && nullToAbsent
          ? const Value.absent()
          : Value(ttsVoice),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AgentPersona.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentPersona(
      agent_pk: serializer.fromJson<int>(json['agent_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      name: serializer.fromJson<String>(json['name']),
      title: serializer.fromJson<String?>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      primaryModel: serializer.fromJson<String?>(json['primaryModel']),
      costPerMillionTokens: serializer.fromJson<double>(
        json['costPerMillionTokens'],
      ),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      configJson: serializer.fromJson<String>(json['configJson']),
      isPrefab: serializer.fromJson<bool>(json['isPrefab']),
      prefab_fk: serializer.fromJson<int?>(json['prefab_fk']),
      overridesJson: serializer.fromJson<String>(json['overridesJson']),
      provider_fk: serializer.fromJson<int?>(json['provider_fk']),
      omniCollectionModel: serializer.fromJson<String?>(
        json['omniCollectionModel'],
      ),
      ttsModel: serializer.fromJson<String?>(json['ttsModel']),
      sttModel: serializer.fromJson<String?>(json['sttModel']),
      imageGenModel: serializer.fromJson<String?>(json['imageGenModel']),
      visionModel: serializer.fromJson<String?>(json['visionModel']),
      llmModel: serializer.fromJson<String?>(json['llmModel']),
      ttsVoice: serializer.fromJson<String?>(json['ttsVoice']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agent_pk': serializer.toJson<int>(agent_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'name': serializer.toJson<String>(name),
      'title': serializer.toJson<String?>(title),
      'description': serializer.toJson<String?>(description),
      'primaryModel': serializer.toJson<String?>(primaryModel),
      'costPerMillionTokens': serializer.toJson<double>(costPerMillionTokens),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'configJson': serializer.toJson<String>(configJson),
      'isPrefab': serializer.toJson<bool>(isPrefab),
      'prefab_fk': serializer.toJson<int?>(prefab_fk),
      'overridesJson': serializer.toJson<String>(overridesJson),
      'provider_fk': serializer.toJson<int?>(provider_fk),
      'omniCollectionModel': serializer.toJson<String?>(omniCollectionModel),
      'ttsModel': serializer.toJson<String?>(ttsModel),
      'sttModel': serializer.toJson<String?>(sttModel),
      'imageGenModel': serializer.toJson<String?>(imageGenModel),
      'visionModel': serializer.toJson<String?>(visionModel),
      'llmModel': serializer.toJson<String?>(llmModel),
      'ttsVoice': serializer.toJson<String?>(ttsVoice),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AgentPersona copyWith({
    int? agent_pk,
    int? client_fk,
    String? name,
    Value<String?> title = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> primaryModel = const Value.absent(),
    double? costPerMillionTokens,
    String? capabilitiesJson,
    String? configJson,
    bool? isPrefab,
    Value<int?> prefab_fk = const Value.absent(),
    String? overridesJson,
    Value<int?> provider_fk = const Value.absent(),
    Value<String?> omniCollectionModel = const Value.absent(),
    Value<String?> ttsModel = const Value.absent(),
    Value<String?> sttModel = const Value.absent(),
    Value<String?> imageGenModel = const Value.absent(),
    Value<String?> visionModel = const Value.absent(),
    Value<String?> llmModel = const Value.absent(),
    Value<String?> ttsVoice = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AgentPersona(
    agent_pk: agent_pk ?? this.agent_pk,
    client_fk: client_fk ?? this.client_fk,
    name: name ?? this.name,
    title: title.present ? title.value : this.title,
    description: description.present ? description.value : this.description,
    primaryModel: primaryModel.present ? primaryModel.value : this.primaryModel,
    costPerMillionTokens: costPerMillionTokens ?? this.costPerMillionTokens,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    configJson: configJson ?? this.configJson,
    isPrefab: isPrefab ?? this.isPrefab,
    prefab_fk: prefab_fk.present ? prefab_fk.value : this.prefab_fk,
    overridesJson: overridesJson ?? this.overridesJson,
    provider_fk: provider_fk.present ? provider_fk.value : this.provider_fk,
    omniCollectionModel: omniCollectionModel.present
        ? omniCollectionModel.value
        : this.omniCollectionModel,
    ttsModel: ttsModel.present ? ttsModel.value : this.ttsModel,
    sttModel: sttModel.present ? sttModel.value : this.sttModel,
    imageGenModel: imageGenModel.present
        ? imageGenModel.value
        : this.imageGenModel,
    visionModel: visionModel.present ? visionModel.value : this.visionModel,
    llmModel: llmModel.present ? llmModel.value : this.llmModel,
    ttsVoice: ttsVoice.present ? ttsVoice.value : this.ttsVoice,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AgentPersona copyWithCompanion(AgentPersonasCompanion data) {
    return AgentPersona(
      agent_pk: data.agent_pk.present ? data.agent_pk.value : this.agent_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      name: data.name.present ? data.name.value : this.name,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      primaryModel: data.primaryModel.present
          ? data.primaryModel.value
          : this.primaryModel,
      costPerMillionTokens: data.costPerMillionTokens.present
          ? data.costPerMillionTokens.value
          : this.costPerMillionTokens,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      isPrefab: data.isPrefab.present ? data.isPrefab.value : this.isPrefab,
      prefab_fk: data.prefab_fk.present ? data.prefab_fk.value : this.prefab_fk,
      overridesJson: data.overridesJson.present
          ? data.overridesJson.value
          : this.overridesJson,
      provider_fk: data.provider_fk.present
          ? data.provider_fk.value
          : this.provider_fk,
      omniCollectionModel: data.omniCollectionModel.present
          ? data.omniCollectionModel.value
          : this.omniCollectionModel,
      ttsModel: data.ttsModel.present ? data.ttsModel.value : this.ttsModel,
      sttModel: data.sttModel.present ? data.sttModel.value : this.sttModel,
      imageGenModel: data.imageGenModel.present
          ? data.imageGenModel.value
          : this.imageGenModel,
      visionModel: data.visionModel.present
          ? data.visionModel.value
          : this.visionModel,
      llmModel: data.llmModel.present ? data.llmModel.value : this.llmModel,
      ttsVoice: data.ttsVoice.present ? data.ttsVoice.value : this.ttsVoice,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentPersona(')
          ..write('agent_pk: $agent_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('primaryModel: $primaryModel, ')
          ..write('costPerMillionTokens: $costPerMillionTokens, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('configJson: $configJson, ')
          ..write('isPrefab: $isPrefab, ')
          ..write('prefab_fk: $prefab_fk, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('provider_fk: $provider_fk, ')
          ..write('omniCollectionModel: $omniCollectionModel, ')
          ..write('ttsModel: $ttsModel, ')
          ..write('sttModel: $sttModel, ')
          ..write('imageGenModel: $imageGenModel, ')
          ..write('visionModel: $visionModel, ')
          ..write('llmModel: $llmModel, ')
          ..write('ttsVoice: $ttsVoice, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    agent_pk,
    client_fk,
    name,
    title,
    description,
    primaryModel,
    costPerMillionTokens,
    capabilitiesJson,
    configJson,
    isPrefab,
    prefab_fk,
    overridesJson,
    provider_fk,
    omniCollectionModel,
    ttsModel,
    sttModel,
    imageGenModel,
    visionModel,
    llmModel,
    ttsVoice,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPersona &&
          other.agent_pk == this.agent_pk &&
          other.client_fk == this.client_fk &&
          other.name == this.name &&
          other.title == this.title &&
          other.description == this.description &&
          other.primaryModel == this.primaryModel &&
          other.costPerMillionTokens == this.costPerMillionTokens &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.configJson == this.configJson &&
          other.isPrefab == this.isPrefab &&
          other.prefab_fk == this.prefab_fk &&
          other.overridesJson == this.overridesJson &&
          other.provider_fk == this.provider_fk &&
          other.omniCollectionModel == this.omniCollectionModel &&
          other.ttsModel == this.ttsModel &&
          other.sttModel == this.sttModel &&
          other.imageGenModel == this.imageGenModel &&
          other.visionModel == this.visionModel &&
          other.llmModel == this.llmModel &&
          other.ttsVoice == this.ttsVoice &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AgentPersonasCompanion extends UpdateCompanion<AgentPersona> {
  final Value<int> agent_pk;
  final Value<int> client_fk;
  final Value<String> name;
  final Value<String?> title;
  final Value<String?> description;
  final Value<String?> primaryModel;
  final Value<double> costPerMillionTokens;
  final Value<String> capabilitiesJson;
  final Value<String> configJson;
  final Value<bool> isPrefab;
  final Value<int?> prefab_fk;
  final Value<String> overridesJson;
  final Value<int?> provider_fk;
  final Value<String?> omniCollectionModel;
  final Value<String?> ttsModel;
  final Value<String?> sttModel;
  final Value<String?> imageGenModel;
  final Value<String?> visionModel;
  final Value<String?> llmModel;
  final Value<String?> ttsVoice;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AgentPersonasCompanion({
    this.agent_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.primaryModel = const Value.absent(),
    this.costPerMillionTokens = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.configJson = const Value.absent(),
    this.isPrefab = const Value.absent(),
    this.prefab_fk = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.provider_fk = const Value.absent(),
    this.omniCollectionModel = const Value.absent(),
    this.ttsModel = const Value.absent(),
    this.sttModel = const Value.absent(),
    this.imageGenModel = const Value.absent(),
    this.visionModel = const Value.absent(),
    this.llmModel = const Value.absent(),
    this.ttsVoice = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AgentPersonasCompanion.insert({
    this.agent_pk = const Value.absent(),
    required int client_fk,
    required String name,
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.primaryModel = const Value.absent(),
    this.costPerMillionTokens = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.configJson = const Value.absent(),
    this.isPrefab = const Value.absent(),
    this.prefab_fk = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.provider_fk = const Value.absent(),
    this.omniCollectionModel = const Value.absent(),
    this.ttsModel = const Value.absent(),
    this.sttModel = const Value.absent(),
    this.imageGenModel = const Value.absent(),
    this.visionModel = const Value.absent(),
    this.llmModel = const Value.absent(),
    this.ttsVoice = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : client_fk = Value(client_fk),
       name = Value(name);
  static Insertable<AgentPersona> custom({
    Expression<int>? agent_pk,
    Expression<int>? client_fk,
    Expression<String>? name,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? primaryModel,
    Expression<double>? costPerMillionTokens,
    Expression<String>? capabilitiesJson,
    Expression<String>? configJson,
    Expression<bool>? isPrefab,
    Expression<int>? prefab_fk,
    Expression<String>? overridesJson,
    Expression<int>? provider_fk,
    Expression<String>? omniCollectionModel,
    Expression<String>? ttsModel,
    Expression<String>? sttModel,
    Expression<String>? imageGenModel,
    Expression<String>? visionModel,
    Expression<String>? llmModel,
    Expression<String>? ttsVoice,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (agent_pk != null) 'agent_pk': agent_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (name != null) 'name': name,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (primaryModel != null) 'primary_model': primaryModel,
      if (costPerMillionTokens != null)
        'cost_per_million_tokens': costPerMillionTokens,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (configJson != null) 'config_json': configJson,
      if (isPrefab != null) 'is_prefab': isPrefab,
      if (prefab_fk != null) 'prefab_fk': prefab_fk,
      if (overridesJson != null) 'overrides_json': overridesJson,
      if (provider_fk != null) 'provider_fk': provider_fk,
      if (omniCollectionModel != null)
        'omni_collection_model': omniCollectionModel,
      if (ttsModel != null) 'tts_model': ttsModel,
      if (sttModel != null) 'stt_model': sttModel,
      if (imageGenModel != null) 'image_gen_model': imageGenModel,
      if (visionModel != null) 'vision_model': visionModel,
      if (llmModel != null) 'llm_model': llmModel,
      if (ttsVoice != null) 'tts_voice': ttsVoice,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AgentPersonasCompanion copyWith({
    Value<int>? agent_pk,
    Value<int>? client_fk,
    Value<String>? name,
    Value<String?>? title,
    Value<String?>? description,
    Value<String?>? primaryModel,
    Value<double>? costPerMillionTokens,
    Value<String>? capabilitiesJson,
    Value<String>? configJson,
    Value<bool>? isPrefab,
    Value<int?>? prefab_fk,
    Value<String>? overridesJson,
    Value<int?>? provider_fk,
    Value<String?>? omniCollectionModel,
    Value<String?>? ttsModel,
    Value<String?>? sttModel,
    Value<String?>? imageGenModel,
    Value<String?>? visionModel,
    Value<String?>? llmModel,
    Value<String?>? ttsVoice,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AgentPersonasCompanion(
      agent_pk: agent_pk ?? this.agent_pk,
      client_fk: client_fk ?? this.client_fk,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      primaryModel: primaryModel ?? this.primaryModel,
      costPerMillionTokens: costPerMillionTokens ?? this.costPerMillionTokens,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      configJson: configJson ?? this.configJson,
      isPrefab: isPrefab ?? this.isPrefab,
      prefab_fk: prefab_fk ?? this.prefab_fk,
      overridesJson: overridesJson ?? this.overridesJson,
      provider_fk: provider_fk ?? this.provider_fk,
      omniCollectionModel: omniCollectionModel ?? this.omniCollectionModel,
      ttsModel: ttsModel ?? this.ttsModel,
      sttModel: sttModel ?? this.sttModel,
      imageGenModel: imageGenModel ?? this.imageGenModel,
      visionModel: visionModel ?? this.visionModel,
      llmModel: llmModel ?? this.llmModel,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agent_pk.present) {
      map['agent_pk'] = Variable<int>(agent_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (primaryModel.present) {
      map['primary_model'] = Variable<String>(primaryModel.value);
    }
    if (costPerMillionTokens.present) {
      map['cost_per_million_tokens'] = Variable<double>(
        costPerMillionTokens.value,
      );
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (isPrefab.present) {
      map['is_prefab'] = Variable<bool>(isPrefab.value);
    }
    if (prefab_fk.present) {
      map['prefab_fk'] = Variable<int>(prefab_fk.value);
    }
    if (overridesJson.present) {
      map['overrides_json'] = Variable<String>(overridesJson.value);
    }
    if (provider_fk.present) {
      map['provider_fk'] = Variable<int>(provider_fk.value);
    }
    if (omniCollectionModel.present) {
      map['omni_collection_model'] = Variable<String>(
        omniCollectionModel.value,
      );
    }
    if (ttsModel.present) {
      map['tts_model'] = Variable<String>(ttsModel.value);
    }
    if (sttModel.present) {
      map['stt_model'] = Variable<String>(sttModel.value);
    }
    if (imageGenModel.present) {
      map['image_gen_model'] = Variable<String>(imageGenModel.value);
    }
    if (visionModel.present) {
      map['vision_model'] = Variable<String>(visionModel.value);
    }
    if (llmModel.present) {
      map['llm_model'] = Variable<String>(llmModel.value);
    }
    if (ttsVoice.present) {
      map['tts_voice'] = Variable<String>(ttsVoice.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentPersonasCompanion(')
          ..write('agent_pk: $agent_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('primaryModel: $primaryModel, ')
          ..write('costPerMillionTokens: $costPerMillionTokens, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('configJson: $configJson, ')
          ..write('isPrefab: $isPrefab, ')
          ..write('prefab_fk: $prefab_fk, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('provider_fk: $provider_fk, ')
          ..write('omniCollectionModel: $omniCollectionModel, ')
          ..write('ttsModel: $ttsModel, ')
          ..write('sttModel: $sttModel, ')
          ..write('imageGenModel: $imageGenModel, ')
          ..write('visionModel: $visionModel, ')
          ..write('llmModel: $llmModel, ')
          ..write('ttsVoice: $ttsVoice, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _project_pkMeta = const VerificationMeta(
    'project_pk',
  );
  @override
  late final GeneratedColumn<int> project_pk = GeneratedColumn<int>(
    'project_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _agent_persona_fkMeta = const VerificationMeta(
    'agent_persona_fk',
  );
  @override
  late final GeneratedColumn<int> agent_persona_fk = GeneratedColumn<int>(
    'agent_persona_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_personas (agent_pk)',
    ),
  );
  static const VerificationMeta _orchestrationStateMeta =
      const VerificationMeta('orchestrationState');
  @override
  late final GeneratedColumn<String> orchestrationState =
      GeneratedColumn<String>(
        'orchestration_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('stopped'),
      );
  static const VerificationMeta _workHoursEnabledMeta = const VerificationMeta(
    'workHoursEnabled',
  );
  @override
  late final GeneratedColumn<bool> workHoursEnabled = GeneratedColumn<bool>(
    'work_hours_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("work_hours_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _workHoursStartMeta = const VerificationMeta(
    'workHoursStart',
  );
  @override
  late final GeneratedColumn<int> workHoursStart = GeneratedColumn<int>(
    'work_hours_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workHoursEndMeta = const VerificationMeta(
    'workHoursEnd',
  );
  @override
  late final GeneratedColumn<int> workHoursEnd = GeneratedColumn<int>(
    'work_hours_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workDaysMaskMeta = const VerificationMeta(
    'workDaysMask',
  );
  @override
  late final GeneratedColumn<int> workDaysMask = GeneratedColumn<int>(
    'work_days_mask',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orchestratorPromptsJsonMeta =
      const VerificationMeta('orchestratorPromptsJson');
  @override
  late final GeneratedColumn<String> orchestratorPromptsJson =
      GeneratedColumn<String>(
        'orchestrator_prompts_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _setupStatusMeta = const VerificationMeta(
    'setupStatus',
  );
  @override
  late final GeneratedColumn<String> setupStatus = GeneratedColumn<String>(
    'setup_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('notStarted'),
  );
  static const VerificationMeta _setupTranscriptJsonMeta =
      const VerificationMeta('setupTranscriptJson');
  @override
  late final GeneratedColumn<String> setupTranscriptJson =
      GeneratedColumn<String>(
        'setup_transcript_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _explorationStatusMeta = const VerificationMeta(
    'explorationStatus',
  );
  @override
  late final GeneratedColumn<String> explorationStatus =
      GeneratedColumn<String>(
        'exploration_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  static const VerificationMeta _templateStatusMeta = const VerificationMeta(
    'templateStatus',
  );
  @override
  late final GeneratedColumn<String> templateStatus = GeneratedColumn<String>(
    'template_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _currentMilestoneMeta = const VerificationMeta(
    'currentMilestone',
  );
  @override
  late final GeneratedColumn<int> currentMilestone = GeneratedColumn<int>(
    'current_milestone',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _milestoneCountMeta = const VerificationMeta(
    'milestoneCount',
  );
  @override
  late final GeneratedColumn<int> milestoneCount = GeneratedColumn<int>(
    'milestone_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _projectSummaryMdMeta = const VerificationMeta(
    'projectSummaryMd',
  );
  @override
  late final GeneratedColumn<String> projectSummaryMd = GeneratedColumn<String>(
    'project_summary_md',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryUpdatedAtMeta = const VerificationMeta(
    'summaryUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> summaryUpdatedAt =
      GeneratedColumn<DateTime>(
        'summary_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _projectTypeMeta = const VerificationMeta(
    'projectType',
  );
  @override
  late final GeneratedColumn<String> projectType = GeneratedColumn<String>(
    'project_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('application-development'),
  );
  static const VerificationMeta _subCategoryMeta = const VerificationMeta(
    'subCategory',
  );
  @override
  late final GeneratedColumn<String> subCategory = GeneratedColumn<String>(
    'sub_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _experienceModeMeta = const VerificationMeta(
    'experienceMode',
  );
  @override
  late final GeneratedColumn<String> experienceMode = GeneratedColumn<String>(
    'experience_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('regular'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    project_pk,
    client_fk,
    name,
    description,
    agent_persona_fk,
    orchestrationState,
    workHoursEnabled,
    workHoursStart,
    workHoursEnd,
    workDaysMask,
    orchestratorPromptsJson,
    setupStatus,
    setupTranscriptJson,
    explorationStatus,
    templateStatus,
    currentMilestone,
    milestoneCount,
    projectSummaryMd,
    summaryUpdatedAt,
    projectType,
    subCategory,
    experienceMode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_pk')) {
      context.handle(
        _project_pkMeta,
        project_pk.isAcceptableOrUnknown(data['project_pk']!, _project_pkMeta),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('agent_persona_fk')) {
      context.handle(
        _agent_persona_fkMeta,
        agent_persona_fk.isAcceptableOrUnknown(
          data['agent_persona_fk']!,
          _agent_persona_fkMeta,
        ),
      );
    }
    if (data.containsKey('orchestration_state')) {
      context.handle(
        _orchestrationStateMeta,
        orchestrationState.isAcceptableOrUnknown(
          data['orchestration_state']!,
          _orchestrationStateMeta,
        ),
      );
    }
    if (data.containsKey('work_hours_enabled')) {
      context.handle(
        _workHoursEnabledMeta,
        workHoursEnabled.isAcceptableOrUnknown(
          data['work_hours_enabled']!,
          _workHoursEnabledMeta,
        ),
      );
    }
    if (data.containsKey('work_hours_start')) {
      context.handle(
        _workHoursStartMeta,
        workHoursStart.isAcceptableOrUnknown(
          data['work_hours_start']!,
          _workHoursStartMeta,
        ),
      );
    }
    if (data.containsKey('work_hours_end')) {
      context.handle(
        _workHoursEndMeta,
        workHoursEnd.isAcceptableOrUnknown(
          data['work_hours_end']!,
          _workHoursEndMeta,
        ),
      );
    }
    if (data.containsKey('work_days_mask')) {
      context.handle(
        _workDaysMaskMeta,
        workDaysMask.isAcceptableOrUnknown(
          data['work_days_mask']!,
          _workDaysMaskMeta,
        ),
      );
    }
    if (data.containsKey('orchestrator_prompts_json')) {
      context.handle(
        _orchestratorPromptsJsonMeta,
        orchestratorPromptsJson.isAcceptableOrUnknown(
          data['orchestrator_prompts_json']!,
          _orchestratorPromptsJsonMeta,
        ),
      );
    }
    if (data.containsKey('setup_status')) {
      context.handle(
        _setupStatusMeta,
        setupStatus.isAcceptableOrUnknown(
          data['setup_status']!,
          _setupStatusMeta,
        ),
      );
    }
    if (data.containsKey('setup_transcript_json')) {
      context.handle(
        _setupTranscriptJsonMeta,
        setupTranscriptJson.isAcceptableOrUnknown(
          data['setup_transcript_json']!,
          _setupTranscriptJsonMeta,
        ),
      );
    }
    if (data.containsKey('exploration_status')) {
      context.handle(
        _explorationStatusMeta,
        explorationStatus.isAcceptableOrUnknown(
          data['exploration_status']!,
          _explorationStatusMeta,
        ),
      );
    }
    if (data.containsKey('template_status')) {
      context.handle(
        _templateStatusMeta,
        templateStatus.isAcceptableOrUnknown(
          data['template_status']!,
          _templateStatusMeta,
        ),
      );
    }
    if (data.containsKey('current_milestone')) {
      context.handle(
        _currentMilestoneMeta,
        currentMilestone.isAcceptableOrUnknown(
          data['current_milestone']!,
          _currentMilestoneMeta,
        ),
      );
    }
    if (data.containsKey('milestone_count')) {
      context.handle(
        _milestoneCountMeta,
        milestoneCount.isAcceptableOrUnknown(
          data['milestone_count']!,
          _milestoneCountMeta,
        ),
      );
    }
    if (data.containsKey('project_summary_md')) {
      context.handle(
        _projectSummaryMdMeta,
        projectSummaryMd.isAcceptableOrUnknown(
          data['project_summary_md']!,
          _projectSummaryMdMeta,
        ),
      );
    }
    if (data.containsKey('summary_updated_at')) {
      context.handle(
        _summaryUpdatedAtMeta,
        summaryUpdatedAt.isAcceptableOrUnknown(
          data['summary_updated_at']!,
          _summaryUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('project_type')) {
      context.handle(
        _projectTypeMeta,
        projectType.isAcceptableOrUnknown(
          data['project_type']!,
          _projectTypeMeta,
        ),
      );
    }
    if (data.containsKey('sub_category')) {
      context.handle(
        _subCategoryMeta,
        subCategory.isAcceptableOrUnknown(
          data['sub_category']!,
          _subCategoryMeta,
        ),
      );
    }
    if (data.containsKey('experience_mode')) {
      context.handle(
        _experienceModeMeta,
        experienceMode.isAcceptableOrUnknown(
          data['experience_mode']!,
          _experienceModeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {project_pk};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      project_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      agent_persona_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}agent_persona_fk'],
      ),
      orchestrationState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}orchestration_state'],
      )!,
      workHoursEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}work_hours_enabled'],
      )!,
      workHoursStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}work_hours_start'],
      ),
      workHoursEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}work_hours_end'],
      ),
      workDaysMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}work_days_mask'],
      ),
      orchestratorPromptsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}orchestrator_prompts_json'],
      ),
      setupStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setup_status'],
      )!,
      setupTranscriptJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setup_transcript_json'],
      ),
      explorationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exploration_status'],
      )!,
      templateStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_status'],
      )!,
      currentMilestone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_milestone'],
      )!,
      milestoneCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}milestone_count'],
      )!,
      projectSummaryMd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_summary_md'],
      ),
      summaryUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}summary_updated_at'],
      ),
      projectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_type'],
      )!,
      subCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_category'],
      ),
      experienceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}experience_mode'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final int project_pk;
  final int client_fk;
  final String name;
  final String? description;

  /// Optional reference to an Agent Persona used for this project's Coordinator.
  final int? agent_persona_fk;

  /// Whether the autonomous worker-spawn loop is running for this project:
  /// `stopped` (idle, no agents spawned), `running` (actively picking up
  /// assigned tasks), or `paused` (loop suspended, resumable). The Start/Pause
  /// controls on the project drive this.
  final String orchestrationState;

  /// When true, the loop only spawns workers inside the configured working
  /// hours window; outside it the loop idles even while `running`.
  final bool workHoursEnabled;

  /// Working-hours window as minutes from midnight (local time), e.g. 540 = 09:00.
  /// Null when unset. If start > end the window wraps past midnight.
  final int? workHoursStart;
  final int? workHoursEnd;

  /// Bitmask of allowed weekdays (bit 0 = Monday … bit 6 = Sunday). 0/null = every day.
  final int? workDaysMask;

  /// Per-project overrides for the orchestrator's prompt templates (the framing
  /// + kickoff text wrapped around each role's [defaultSystemPrompt]). JSON map
  /// of template-key → string; absent keys fall back to the built-in defaults.
  /// Null/empty = use defaults for everything.
  final String? orchestratorPromptsJson;

  /// Setup workflow state: notStarted | inProgress | skipped | complete. A new
  /// project starts at notStarted and is gated to the Setup tab until the user
  /// finishes or skips.
  final String setupStatus;

  /// The setup interview Q/A transcript (JSON) so decisions can be re-explained.
  final String? setupTranscriptJson;

  /// Post-setup **Exploration** phase state: none | active | complete. After
  /// setup finishes the project enters `active` — a discovery chat that builds
  /// the user-story tree — and stays there (NO tasks generated) until the user
  /// presses "Generate tasks from stories", which flips it to `complete`.
  final String explorationStatus;

  /// The Templater (pre-task) phase state: `none` (not applicable / legacy),
  /// `pending` (tasks generated, base not yet scaffolded), `scaffolding` (the
  /// Coordinator is building the base project + task stubs), `ready` (base
  /// committed & CI-green — workers may start), or `failed`. Workers are gated
  /// until this is `ready`, which is what stops every agent from racing to
  /// scaffold an empty `main` at once.
  final String templateStatus;

  /// The milestone batch currently open for work (0-based). Workers only pick up
  /// tasks whose `milestoneOrder` equals this; when that batch finishes and its
  /// CI is green, the orchestrator advances it until it reaches [milestoneCount].
  final int currentMilestone;

  /// Total number of milestone batches the Templater split the backlog into
  /// (1 = no intermediate milestones: base → all tasks → final CI). 0 until the
  /// Templater runs.
  final int milestoneCount;

  /// AI-compiled, human-readable summary of the project (markdown), built from
  /// all /PLANS files. Regenerated on plan changes and by the coordinator's
  /// idle cycles. Null until first generated.
  final String? projectSummaryMd;
  final DateTime? summaryUpdatedAt;

  /// The project type key from the ProjectType catalog (e.g.
  /// 'application-development', 'project-coordination', 'ivr-call-systems').
  /// Drives which capabilities/UI are shown. Defaults to application-development
  /// so existing projects are unchanged.
  final String projectType;

  /// Optional sub-category within the type (e.g. IVR: 'inboundIvr',
  /// 'outboundCampaign', 'aiVoicebot'). Null = the type's default.
  final String? subCategory;

  /// Experience mode: 'regular' | 'advanced'. Presentation only — same model.
  final String experienceMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Project({
    required this.project_pk,
    required this.client_fk,
    required this.name,
    this.description,
    this.agent_persona_fk,
    required this.orchestrationState,
    required this.workHoursEnabled,
    this.workHoursStart,
    this.workHoursEnd,
    this.workDaysMask,
    this.orchestratorPromptsJson,
    required this.setupStatus,
    this.setupTranscriptJson,
    required this.explorationStatus,
    required this.templateStatus,
    required this.currentMilestone,
    required this.milestoneCount,
    this.projectSummaryMd,
    this.summaryUpdatedAt,
    required this.projectType,
    this.subCategory,
    required this.experienceMode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_pk'] = Variable<int>(project_pk);
    map['client_fk'] = Variable<int>(client_fk);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || agent_persona_fk != null) {
      map['agent_persona_fk'] = Variable<int>(agent_persona_fk);
    }
    map['orchestration_state'] = Variable<String>(orchestrationState);
    map['work_hours_enabled'] = Variable<bool>(workHoursEnabled);
    if (!nullToAbsent || workHoursStart != null) {
      map['work_hours_start'] = Variable<int>(workHoursStart);
    }
    if (!nullToAbsent || workHoursEnd != null) {
      map['work_hours_end'] = Variable<int>(workHoursEnd);
    }
    if (!nullToAbsent || workDaysMask != null) {
      map['work_days_mask'] = Variable<int>(workDaysMask);
    }
    if (!nullToAbsent || orchestratorPromptsJson != null) {
      map['orchestrator_prompts_json'] = Variable<String>(
        orchestratorPromptsJson,
      );
    }
    map['setup_status'] = Variable<String>(setupStatus);
    if (!nullToAbsent || setupTranscriptJson != null) {
      map['setup_transcript_json'] = Variable<String>(setupTranscriptJson);
    }
    map['exploration_status'] = Variable<String>(explorationStatus);
    map['template_status'] = Variable<String>(templateStatus);
    map['current_milestone'] = Variable<int>(currentMilestone);
    map['milestone_count'] = Variable<int>(milestoneCount);
    if (!nullToAbsent || projectSummaryMd != null) {
      map['project_summary_md'] = Variable<String>(projectSummaryMd);
    }
    if (!nullToAbsent || summaryUpdatedAt != null) {
      map['summary_updated_at'] = Variable<DateTime>(summaryUpdatedAt);
    }
    map['project_type'] = Variable<String>(projectType);
    if (!nullToAbsent || subCategory != null) {
      map['sub_category'] = Variable<String>(subCategory);
    }
    map['experience_mode'] = Variable<String>(experienceMode);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      project_pk: Value(project_pk),
      client_fk: Value(client_fk),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      agent_persona_fk: agent_persona_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(agent_persona_fk),
      orchestrationState: Value(orchestrationState),
      workHoursEnabled: Value(workHoursEnabled),
      workHoursStart: workHoursStart == null && nullToAbsent
          ? const Value.absent()
          : Value(workHoursStart),
      workHoursEnd: workHoursEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(workHoursEnd),
      workDaysMask: workDaysMask == null && nullToAbsent
          ? const Value.absent()
          : Value(workDaysMask),
      orchestratorPromptsJson: orchestratorPromptsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(orchestratorPromptsJson),
      setupStatus: Value(setupStatus),
      setupTranscriptJson: setupTranscriptJson == null && nullToAbsent
          ? const Value.absent()
          : Value(setupTranscriptJson),
      explorationStatus: Value(explorationStatus),
      templateStatus: Value(templateStatus),
      currentMilestone: Value(currentMilestone),
      milestoneCount: Value(milestoneCount),
      projectSummaryMd: projectSummaryMd == null && nullToAbsent
          ? const Value.absent()
          : Value(projectSummaryMd),
      summaryUpdatedAt: summaryUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryUpdatedAt),
      projectType: Value(projectType),
      subCategory: subCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(subCategory),
      experienceMode: Value(experienceMode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      project_pk: serializer.fromJson<int>(json['project_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      agent_persona_fk: serializer.fromJson<int?>(json['agent_persona_fk']),
      orchestrationState: serializer.fromJson<String>(
        json['orchestrationState'],
      ),
      workHoursEnabled: serializer.fromJson<bool>(json['workHoursEnabled']),
      workHoursStart: serializer.fromJson<int?>(json['workHoursStart']),
      workHoursEnd: serializer.fromJson<int?>(json['workHoursEnd']),
      workDaysMask: serializer.fromJson<int?>(json['workDaysMask']),
      orchestratorPromptsJson: serializer.fromJson<String?>(
        json['orchestratorPromptsJson'],
      ),
      setupStatus: serializer.fromJson<String>(json['setupStatus']),
      setupTranscriptJson: serializer.fromJson<String?>(
        json['setupTranscriptJson'],
      ),
      explorationStatus: serializer.fromJson<String>(json['explorationStatus']),
      templateStatus: serializer.fromJson<String>(json['templateStatus']),
      currentMilestone: serializer.fromJson<int>(json['currentMilestone']),
      milestoneCount: serializer.fromJson<int>(json['milestoneCount']),
      projectSummaryMd: serializer.fromJson<String?>(json['projectSummaryMd']),
      summaryUpdatedAt: serializer.fromJson<DateTime?>(
        json['summaryUpdatedAt'],
      ),
      projectType: serializer.fromJson<String>(json['projectType']),
      subCategory: serializer.fromJson<String?>(json['subCategory']),
      experienceMode: serializer.fromJson<String>(json['experienceMode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'project_pk': serializer.toJson<int>(project_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'agent_persona_fk': serializer.toJson<int?>(agent_persona_fk),
      'orchestrationState': serializer.toJson<String>(orchestrationState),
      'workHoursEnabled': serializer.toJson<bool>(workHoursEnabled),
      'workHoursStart': serializer.toJson<int?>(workHoursStart),
      'workHoursEnd': serializer.toJson<int?>(workHoursEnd),
      'workDaysMask': serializer.toJson<int?>(workDaysMask),
      'orchestratorPromptsJson': serializer.toJson<String?>(
        orchestratorPromptsJson,
      ),
      'setupStatus': serializer.toJson<String>(setupStatus),
      'setupTranscriptJson': serializer.toJson<String?>(setupTranscriptJson),
      'explorationStatus': serializer.toJson<String>(explorationStatus),
      'templateStatus': serializer.toJson<String>(templateStatus),
      'currentMilestone': serializer.toJson<int>(currentMilestone),
      'milestoneCount': serializer.toJson<int>(milestoneCount),
      'projectSummaryMd': serializer.toJson<String?>(projectSummaryMd),
      'summaryUpdatedAt': serializer.toJson<DateTime?>(summaryUpdatedAt),
      'projectType': serializer.toJson<String>(projectType),
      'subCategory': serializer.toJson<String?>(subCategory),
      'experienceMode': serializer.toJson<String>(experienceMode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Project copyWith({
    int? project_pk,
    int? client_fk,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<int?> agent_persona_fk = const Value.absent(),
    String? orchestrationState,
    bool? workHoursEnabled,
    Value<int?> workHoursStart = const Value.absent(),
    Value<int?> workHoursEnd = const Value.absent(),
    Value<int?> workDaysMask = const Value.absent(),
    Value<String?> orchestratorPromptsJson = const Value.absent(),
    String? setupStatus,
    Value<String?> setupTranscriptJson = const Value.absent(),
    String? explorationStatus,
    String? templateStatus,
    int? currentMilestone,
    int? milestoneCount,
    Value<String?> projectSummaryMd = const Value.absent(),
    Value<DateTime?> summaryUpdatedAt = const Value.absent(),
    String? projectType,
    Value<String?> subCategory = const Value.absent(),
    String? experienceMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Project(
    project_pk: project_pk ?? this.project_pk,
    client_fk: client_fk ?? this.client_fk,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    agent_persona_fk: agent_persona_fk.present
        ? agent_persona_fk.value
        : this.agent_persona_fk,
    orchestrationState: orchestrationState ?? this.orchestrationState,
    workHoursEnabled: workHoursEnabled ?? this.workHoursEnabled,
    workHoursStart: workHoursStart.present
        ? workHoursStart.value
        : this.workHoursStart,
    workHoursEnd: workHoursEnd.present ? workHoursEnd.value : this.workHoursEnd,
    workDaysMask: workDaysMask.present ? workDaysMask.value : this.workDaysMask,
    orchestratorPromptsJson: orchestratorPromptsJson.present
        ? orchestratorPromptsJson.value
        : this.orchestratorPromptsJson,
    setupStatus: setupStatus ?? this.setupStatus,
    setupTranscriptJson: setupTranscriptJson.present
        ? setupTranscriptJson.value
        : this.setupTranscriptJson,
    explorationStatus: explorationStatus ?? this.explorationStatus,
    templateStatus: templateStatus ?? this.templateStatus,
    currentMilestone: currentMilestone ?? this.currentMilestone,
    milestoneCount: milestoneCount ?? this.milestoneCount,
    projectSummaryMd: projectSummaryMd.present
        ? projectSummaryMd.value
        : this.projectSummaryMd,
    summaryUpdatedAt: summaryUpdatedAt.present
        ? summaryUpdatedAt.value
        : this.summaryUpdatedAt,
    projectType: projectType ?? this.projectType,
    subCategory: subCategory.present ? subCategory.value : this.subCategory,
    experienceMode: experienceMode ?? this.experienceMode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      project_pk: data.project_pk.present
          ? data.project_pk.value
          : this.project_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      agent_persona_fk: data.agent_persona_fk.present
          ? data.agent_persona_fk.value
          : this.agent_persona_fk,
      orchestrationState: data.orchestrationState.present
          ? data.orchestrationState.value
          : this.orchestrationState,
      workHoursEnabled: data.workHoursEnabled.present
          ? data.workHoursEnabled.value
          : this.workHoursEnabled,
      workHoursStart: data.workHoursStart.present
          ? data.workHoursStart.value
          : this.workHoursStart,
      workHoursEnd: data.workHoursEnd.present
          ? data.workHoursEnd.value
          : this.workHoursEnd,
      workDaysMask: data.workDaysMask.present
          ? data.workDaysMask.value
          : this.workDaysMask,
      orchestratorPromptsJson: data.orchestratorPromptsJson.present
          ? data.orchestratorPromptsJson.value
          : this.orchestratorPromptsJson,
      setupStatus: data.setupStatus.present
          ? data.setupStatus.value
          : this.setupStatus,
      setupTranscriptJson: data.setupTranscriptJson.present
          ? data.setupTranscriptJson.value
          : this.setupTranscriptJson,
      explorationStatus: data.explorationStatus.present
          ? data.explorationStatus.value
          : this.explorationStatus,
      templateStatus: data.templateStatus.present
          ? data.templateStatus.value
          : this.templateStatus,
      currentMilestone: data.currentMilestone.present
          ? data.currentMilestone.value
          : this.currentMilestone,
      milestoneCount: data.milestoneCount.present
          ? data.milestoneCount.value
          : this.milestoneCount,
      projectSummaryMd: data.projectSummaryMd.present
          ? data.projectSummaryMd.value
          : this.projectSummaryMd,
      summaryUpdatedAt: data.summaryUpdatedAt.present
          ? data.summaryUpdatedAt.value
          : this.summaryUpdatedAt,
      projectType: data.projectType.present
          ? data.projectType.value
          : this.projectType,
      subCategory: data.subCategory.present
          ? data.subCategory.value
          : this.subCategory,
      experienceMode: data.experienceMode.present
          ? data.experienceMode.value
          : this.experienceMode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('project_pk: $project_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('agent_persona_fk: $agent_persona_fk, ')
          ..write('orchestrationState: $orchestrationState, ')
          ..write('workHoursEnabled: $workHoursEnabled, ')
          ..write('workHoursStart: $workHoursStart, ')
          ..write('workHoursEnd: $workHoursEnd, ')
          ..write('workDaysMask: $workDaysMask, ')
          ..write('orchestratorPromptsJson: $orchestratorPromptsJson, ')
          ..write('setupStatus: $setupStatus, ')
          ..write('setupTranscriptJson: $setupTranscriptJson, ')
          ..write('explorationStatus: $explorationStatus, ')
          ..write('templateStatus: $templateStatus, ')
          ..write('currentMilestone: $currentMilestone, ')
          ..write('milestoneCount: $milestoneCount, ')
          ..write('projectSummaryMd: $projectSummaryMd, ')
          ..write('summaryUpdatedAt: $summaryUpdatedAt, ')
          ..write('projectType: $projectType, ')
          ..write('subCategory: $subCategory, ')
          ..write('experienceMode: $experienceMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    project_pk,
    client_fk,
    name,
    description,
    agent_persona_fk,
    orchestrationState,
    workHoursEnabled,
    workHoursStart,
    workHoursEnd,
    workDaysMask,
    orchestratorPromptsJson,
    setupStatus,
    setupTranscriptJson,
    explorationStatus,
    templateStatus,
    currentMilestone,
    milestoneCount,
    projectSummaryMd,
    summaryUpdatedAt,
    projectType,
    subCategory,
    experienceMode,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.project_pk == this.project_pk &&
          other.client_fk == this.client_fk &&
          other.name == this.name &&
          other.description == this.description &&
          other.agent_persona_fk == this.agent_persona_fk &&
          other.orchestrationState == this.orchestrationState &&
          other.workHoursEnabled == this.workHoursEnabled &&
          other.workHoursStart == this.workHoursStart &&
          other.workHoursEnd == this.workHoursEnd &&
          other.workDaysMask == this.workDaysMask &&
          other.orchestratorPromptsJson == this.orchestratorPromptsJson &&
          other.setupStatus == this.setupStatus &&
          other.setupTranscriptJson == this.setupTranscriptJson &&
          other.explorationStatus == this.explorationStatus &&
          other.templateStatus == this.templateStatus &&
          other.currentMilestone == this.currentMilestone &&
          other.milestoneCount == this.milestoneCount &&
          other.projectSummaryMd == this.projectSummaryMd &&
          other.summaryUpdatedAt == this.summaryUpdatedAt &&
          other.projectType == this.projectType &&
          other.subCategory == this.subCategory &&
          other.experienceMode == this.experienceMode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<int> project_pk;
  final Value<int> client_fk;
  final Value<String> name;
  final Value<String?> description;
  final Value<int?> agent_persona_fk;
  final Value<String> orchestrationState;
  final Value<bool> workHoursEnabled;
  final Value<int?> workHoursStart;
  final Value<int?> workHoursEnd;
  final Value<int?> workDaysMask;
  final Value<String?> orchestratorPromptsJson;
  final Value<String> setupStatus;
  final Value<String?> setupTranscriptJson;
  final Value<String> explorationStatus;
  final Value<String> templateStatus;
  final Value<int> currentMilestone;
  final Value<int> milestoneCount;
  final Value<String?> projectSummaryMd;
  final Value<DateTime?> summaryUpdatedAt;
  final Value<String> projectType;
  final Value<String?> subCategory;
  final Value<String> experienceMode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ProjectsCompanion({
    this.project_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.agent_persona_fk = const Value.absent(),
    this.orchestrationState = const Value.absent(),
    this.workHoursEnabled = const Value.absent(),
    this.workHoursStart = const Value.absent(),
    this.workHoursEnd = const Value.absent(),
    this.workDaysMask = const Value.absent(),
    this.orchestratorPromptsJson = const Value.absent(),
    this.setupStatus = const Value.absent(),
    this.setupTranscriptJson = const Value.absent(),
    this.explorationStatus = const Value.absent(),
    this.templateStatus = const Value.absent(),
    this.currentMilestone = const Value.absent(),
    this.milestoneCount = const Value.absent(),
    this.projectSummaryMd = const Value.absent(),
    this.summaryUpdatedAt = const Value.absent(),
    this.projectType = const Value.absent(),
    this.subCategory = const Value.absent(),
    this.experienceMode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProjectsCompanion.insert({
    this.project_pk = const Value.absent(),
    required int client_fk,
    required String name,
    this.description = const Value.absent(),
    this.agent_persona_fk = const Value.absent(),
    this.orchestrationState = const Value.absent(),
    this.workHoursEnabled = const Value.absent(),
    this.workHoursStart = const Value.absent(),
    this.workHoursEnd = const Value.absent(),
    this.workDaysMask = const Value.absent(),
    this.orchestratorPromptsJson = const Value.absent(),
    this.setupStatus = const Value.absent(),
    this.setupTranscriptJson = const Value.absent(),
    this.explorationStatus = const Value.absent(),
    this.templateStatus = const Value.absent(),
    this.currentMilestone = const Value.absent(),
    this.milestoneCount = const Value.absent(),
    this.projectSummaryMd = const Value.absent(),
    this.summaryUpdatedAt = const Value.absent(),
    this.projectType = const Value.absent(),
    this.subCategory = const Value.absent(),
    this.experienceMode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : client_fk = Value(client_fk),
       name = Value(name);
  static Insertable<Project> custom({
    Expression<int>? project_pk,
    Expression<int>? client_fk,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? agent_persona_fk,
    Expression<String>? orchestrationState,
    Expression<bool>? workHoursEnabled,
    Expression<int>? workHoursStart,
    Expression<int>? workHoursEnd,
    Expression<int>? workDaysMask,
    Expression<String>? orchestratorPromptsJson,
    Expression<String>? setupStatus,
    Expression<String>? setupTranscriptJson,
    Expression<String>? explorationStatus,
    Expression<String>? templateStatus,
    Expression<int>? currentMilestone,
    Expression<int>? milestoneCount,
    Expression<String>? projectSummaryMd,
    Expression<DateTime>? summaryUpdatedAt,
    Expression<String>? projectType,
    Expression<String>? subCategory,
    Expression<String>? experienceMode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (project_pk != null) 'project_pk': project_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (agent_persona_fk != null) 'agent_persona_fk': agent_persona_fk,
      if (orchestrationState != null) 'orchestration_state': orchestrationState,
      if (workHoursEnabled != null) 'work_hours_enabled': workHoursEnabled,
      if (workHoursStart != null) 'work_hours_start': workHoursStart,
      if (workHoursEnd != null) 'work_hours_end': workHoursEnd,
      if (workDaysMask != null) 'work_days_mask': workDaysMask,
      if (orchestratorPromptsJson != null)
        'orchestrator_prompts_json': orchestratorPromptsJson,
      if (setupStatus != null) 'setup_status': setupStatus,
      if (setupTranscriptJson != null)
        'setup_transcript_json': setupTranscriptJson,
      if (explorationStatus != null) 'exploration_status': explorationStatus,
      if (templateStatus != null) 'template_status': templateStatus,
      if (currentMilestone != null) 'current_milestone': currentMilestone,
      if (milestoneCount != null) 'milestone_count': milestoneCount,
      if (projectSummaryMd != null) 'project_summary_md': projectSummaryMd,
      if (summaryUpdatedAt != null) 'summary_updated_at': summaryUpdatedAt,
      if (projectType != null) 'project_type': projectType,
      if (subCategory != null) 'sub_category': subCategory,
      if (experienceMode != null) 'experience_mode': experienceMode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProjectsCompanion copyWith({
    Value<int>? project_pk,
    Value<int>? client_fk,
    Value<String>? name,
    Value<String?>? description,
    Value<int?>? agent_persona_fk,
    Value<String>? orchestrationState,
    Value<bool>? workHoursEnabled,
    Value<int?>? workHoursStart,
    Value<int?>? workHoursEnd,
    Value<int?>? workDaysMask,
    Value<String?>? orchestratorPromptsJson,
    Value<String>? setupStatus,
    Value<String?>? setupTranscriptJson,
    Value<String>? explorationStatus,
    Value<String>? templateStatus,
    Value<int>? currentMilestone,
    Value<int>? milestoneCount,
    Value<String?>? projectSummaryMd,
    Value<DateTime?>? summaryUpdatedAt,
    Value<String>? projectType,
    Value<String?>? subCategory,
    Value<String>? experienceMode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ProjectsCompanion(
      project_pk: project_pk ?? this.project_pk,
      client_fk: client_fk ?? this.client_fk,
      name: name ?? this.name,
      description: description ?? this.description,
      agent_persona_fk: agent_persona_fk ?? this.agent_persona_fk,
      orchestrationState: orchestrationState ?? this.orchestrationState,
      workHoursEnabled: workHoursEnabled ?? this.workHoursEnabled,
      workHoursStart: workHoursStart ?? this.workHoursStart,
      workHoursEnd: workHoursEnd ?? this.workHoursEnd,
      workDaysMask: workDaysMask ?? this.workDaysMask,
      orchestratorPromptsJson:
          orchestratorPromptsJson ?? this.orchestratorPromptsJson,
      setupStatus: setupStatus ?? this.setupStatus,
      setupTranscriptJson: setupTranscriptJson ?? this.setupTranscriptJson,
      explorationStatus: explorationStatus ?? this.explorationStatus,
      templateStatus: templateStatus ?? this.templateStatus,
      currentMilestone: currentMilestone ?? this.currentMilestone,
      milestoneCount: milestoneCount ?? this.milestoneCount,
      projectSummaryMd: projectSummaryMd ?? this.projectSummaryMd,
      summaryUpdatedAt: summaryUpdatedAt ?? this.summaryUpdatedAt,
      projectType: projectType ?? this.projectType,
      subCategory: subCategory ?? this.subCategory,
      experienceMode: experienceMode ?? this.experienceMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (project_pk.present) {
      map['project_pk'] = Variable<int>(project_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (agent_persona_fk.present) {
      map['agent_persona_fk'] = Variable<int>(agent_persona_fk.value);
    }
    if (orchestrationState.present) {
      map['orchestration_state'] = Variable<String>(orchestrationState.value);
    }
    if (workHoursEnabled.present) {
      map['work_hours_enabled'] = Variable<bool>(workHoursEnabled.value);
    }
    if (workHoursStart.present) {
      map['work_hours_start'] = Variable<int>(workHoursStart.value);
    }
    if (workHoursEnd.present) {
      map['work_hours_end'] = Variable<int>(workHoursEnd.value);
    }
    if (workDaysMask.present) {
      map['work_days_mask'] = Variable<int>(workDaysMask.value);
    }
    if (orchestratorPromptsJson.present) {
      map['orchestrator_prompts_json'] = Variable<String>(
        orchestratorPromptsJson.value,
      );
    }
    if (setupStatus.present) {
      map['setup_status'] = Variable<String>(setupStatus.value);
    }
    if (setupTranscriptJson.present) {
      map['setup_transcript_json'] = Variable<String>(
        setupTranscriptJson.value,
      );
    }
    if (explorationStatus.present) {
      map['exploration_status'] = Variable<String>(explorationStatus.value);
    }
    if (templateStatus.present) {
      map['template_status'] = Variable<String>(templateStatus.value);
    }
    if (currentMilestone.present) {
      map['current_milestone'] = Variable<int>(currentMilestone.value);
    }
    if (milestoneCount.present) {
      map['milestone_count'] = Variable<int>(milestoneCount.value);
    }
    if (projectSummaryMd.present) {
      map['project_summary_md'] = Variable<String>(projectSummaryMd.value);
    }
    if (summaryUpdatedAt.present) {
      map['summary_updated_at'] = Variable<DateTime>(summaryUpdatedAt.value);
    }
    if (projectType.present) {
      map['project_type'] = Variable<String>(projectType.value);
    }
    if (subCategory.present) {
      map['sub_category'] = Variable<String>(subCategory.value);
    }
    if (experienceMode.present) {
      map['experience_mode'] = Variable<String>(experienceMode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('project_pk: $project_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('agent_persona_fk: $agent_persona_fk, ')
          ..write('orchestrationState: $orchestrationState, ')
          ..write('workHoursEnabled: $workHoursEnabled, ')
          ..write('workHoursStart: $workHoursStart, ')
          ..write('workHoursEnd: $workHoursEnd, ')
          ..write('workDaysMask: $workDaysMask, ')
          ..write('orchestratorPromptsJson: $orchestratorPromptsJson, ')
          ..write('setupStatus: $setupStatus, ')
          ..write('setupTranscriptJson: $setupTranscriptJson, ')
          ..write('explorationStatus: $explorationStatus, ')
          ..write('templateStatus: $templateStatus, ')
          ..write('currentMilestone: $currentMilestone, ')
          ..write('milestoneCount: $milestoneCount, ')
          ..write('projectSummaryMd: $projectSummaryMd, ')
          ..write('summaryUpdatedAt: $summaryUpdatedAt, ')
          ..write('projectType: $projectType, ')
          ..write('subCategory: $subCategory, ')
          ..write('experienceMode: $experienceMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ChatSessionsTable extends ChatSessions
    with TableInfo<$ChatSessionsTable, ChatSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _session_pkMeta = const VerificationMeta(
    'session_pk',
  );
  @override
  late final GeneratedColumn<int> session_pk = GeneratedColumn<int>(
    'session_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _plan_pathMeta = const VerificationMeta(
    'plan_path',
  );
  @override
  late final GeneratedColumn<String> plan_path = GeneratedColumn<String>(
    'plan_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('New conversation'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    session_pk,
    project_fk,
    plan_path,
    title,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_pk')) {
      context.handle(
        _session_pkMeta,
        session_pk.isAcceptableOrUnknown(data['session_pk']!, _session_pkMeta),
      );
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_project_fkMeta);
    }
    if (data.containsKey('plan_path')) {
      context.handle(
        _plan_pathMeta,
        plan_path.isAcceptableOrUnknown(data['plan_path']!, _plan_pathMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {session_pk};
  @override
  ChatSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSession(
      session_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_pk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      )!,
      plan_path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_path'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChatSessionsTable createAlias(String alias) {
    return $ChatSessionsTable(attachedDatabase, alias);
  }
}

class ChatSession extends DataClass implements Insertable<ChatSession> {
  final int session_pk;
  final int project_fk;
  final String? plan_path;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChatSession({
    required this.session_pk,
    required this.project_fk,
    this.plan_path,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_pk'] = Variable<int>(session_pk);
    map['project_fk'] = Variable<int>(project_fk);
    if (!nullToAbsent || plan_path != null) {
      map['plan_path'] = Variable<String>(plan_path);
    }
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChatSessionsCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsCompanion(
      session_pk: Value(session_pk),
      project_fk: Value(project_fk),
      plan_path: plan_path == null && nullToAbsent
          ? const Value.absent()
          : Value(plan_path),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChatSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSession(
      session_pk: serializer.fromJson<int>(json['session_pk']),
      project_fk: serializer.fromJson<int>(json['project_fk']),
      plan_path: serializer.fromJson<String?>(json['plan_path']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'session_pk': serializer.toJson<int>(session_pk),
      'project_fk': serializer.toJson<int>(project_fk),
      'plan_path': serializer.toJson<String?>(plan_path),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChatSession copyWith({
    int? session_pk,
    int? project_fk,
    Value<String?> plan_path = const Value.absent(),
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChatSession(
    session_pk: session_pk ?? this.session_pk,
    project_fk: project_fk ?? this.project_fk,
    plan_path: plan_path.present ? plan_path.value : this.plan_path,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChatSession copyWithCompanion(ChatSessionsCompanion data) {
    return ChatSession(
      session_pk: data.session_pk.present
          ? data.session_pk.value
          : this.session_pk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      plan_path: data.plan_path.present ? data.plan_path.value : this.plan_path,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSession(')
          ..write('session_pk: $session_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('plan_path: $plan_path, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    session_pk,
    project_fk,
    plan_path,
    title,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSession &&
          other.session_pk == this.session_pk &&
          other.project_fk == this.project_fk &&
          other.plan_path == this.plan_path &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChatSessionsCompanion extends UpdateCompanion<ChatSession> {
  final Value<int> session_pk;
  final Value<int> project_fk;
  final Value<String?> plan_path;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ChatSessionsCompanion({
    this.session_pk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.plan_path = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChatSessionsCompanion.insert({
    this.session_pk = const Value.absent(),
    required int project_fk,
    this.plan_path = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : project_fk = Value(project_fk);
  static Insertable<ChatSession> custom({
    Expression<int>? session_pk,
    Expression<int>? project_fk,
    Expression<String>? plan_path,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (session_pk != null) 'session_pk': session_pk,
      if (project_fk != null) 'project_fk': project_fk,
      if (plan_path != null) 'plan_path': plan_path,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChatSessionsCompanion copyWith({
    Value<int>? session_pk,
    Value<int>? project_fk,
    Value<String?>? plan_path,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ChatSessionsCompanion(
      session_pk: session_pk ?? this.session_pk,
      project_fk: project_fk ?? this.project_fk,
      plan_path: plan_path ?? this.plan_path,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (session_pk.present) {
      map['session_pk'] = Variable<int>(session_pk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (plan_path.present) {
      map['plan_path'] = Variable<String>(plan_path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsCompanion(')
          ..write('session_pk: $session_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('plan_path: $plan_path, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $UserStoriesTable extends UserStories
    with TableInfo<$UserStoriesTable, UserStory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _story_pkMeta = const VerificationMeta(
    'story_pk',
  );
  @override
  late final GeneratedColumn<int> story_pk = GeneratedColumn<int>(
    'story_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _parent_story_fkMeta = const VerificationMeta(
    'parent_story_fk',
  );
  @override
  late final GeneratedColumn<int> parent_story_fk = GeneratedColumn<int>(
    'parent_story_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_stories (story_pk)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _narrativeMeta = const VerificationMeta(
    'narrative',
  );
  @override
  late final GeneratedColumn<String> narrative = GeneratedColumn<String>(
    'narrative',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _acceptanceCriteriaMeta =
      const VerificationMeta('acceptanceCriteria');
  @override
  late final GeneratedColumn<String> acceptanceCriteria =
      GeneratedColumn<String>(
        'acceptance_criteria',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('story'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _posXMeta = const VerificationMeta('posX');
  @override
  late final GeneratedColumn<double> posX = GeneratedColumn<double>(
    'pos_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posYMeta = const VerificationMeta('posY');
  @override
  late final GeneratedColumn<double> posY = GeneratedColumn<double>(
    'pos_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    story_pk,
    project_fk,
    parent_story_fk,
    title,
    narrative,
    acceptanceCriteria,
    kind,
    status,
    posX,
    posY,
    orderIndex,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_stories';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserStory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('story_pk')) {
      context.handle(
        _story_pkMeta,
        story_pk.isAcceptableOrUnknown(data['story_pk']!, _story_pkMeta),
      );
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_project_fkMeta);
    }
    if (data.containsKey('parent_story_fk')) {
      context.handle(
        _parent_story_fkMeta,
        parent_story_fk.isAcceptableOrUnknown(
          data['parent_story_fk']!,
          _parent_story_fkMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('narrative')) {
      context.handle(
        _narrativeMeta,
        narrative.isAcceptableOrUnknown(data['narrative']!, _narrativeMeta),
      );
    }
    if (data.containsKey('acceptance_criteria')) {
      context.handle(
        _acceptanceCriteriaMeta,
        acceptanceCriteria.isAcceptableOrUnknown(
          data['acceptance_criteria']!,
          _acceptanceCriteriaMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('pos_x')) {
      context.handle(
        _posXMeta,
        posX.isAcceptableOrUnknown(data['pos_x']!, _posXMeta),
      );
    }
    if (data.containsKey('pos_y')) {
      context.handle(
        _posYMeta,
        posY.isAcceptableOrUnknown(data['pos_y']!, _posYMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {story_pk};
  @override
  UserStory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStory(
      story_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_pk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      )!,
      parent_story_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_story_fk'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      narrative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrative'],
      )!,
      acceptanceCriteria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acceptance_criteria'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      posX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_x'],
      ),
      posY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_y'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserStoriesTable createAlias(String alias) {
    return $UserStoriesTable(attachedDatabase, alias);
  }
}

class UserStory extends DataClass implements Insertable<UserStory> {
  final int story_pk;
  final int project_fk;

  /// Tree edge: the parent story (epic → story → sub-story). Null = root/epic.
  final int? parent_story_fk;

  /// Short node title shown on the canvas.
  final String title;

  /// The story narrative — `As a <role>, I want <goal>, so that <benefit>`.
  final String narrative;

  /// Acceptance criteria (markdown bullet list), if captured.
  final String? acceptanceCriteria;

  /// Node kind: epic | story | substory. Drives the canvas styling.
  final String kind;

  /// Confirm state: draft | confirmed | done.
  final String status;

  /// Persisted canvas position (null until first auto-layout / drag).
  final double? posX;
  final double? posY;

  /// Sibling order under the same parent.
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserStory({
    required this.story_pk,
    required this.project_fk,
    this.parent_story_fk,
    required this.title,
    required this.narrative,
    this.acceptanceCriteria,
    required this.kind,
    required this.status,
    this.posX,
    this.posY,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['story_pk'] = Variable<int>(story_pk);
    map['project_fk'] = Variable<int>(project_fk);
    if (!nullToAbsent || parent_story_fk != null) {
      map['parent_story_fk'] = Variable<int>(parent_story_fk);
    }
    map['title'] = Variable<String>(title);
    map['narrative'] = Variable<String>(narrative);
    if (!nullToAbsent || acceptanceCriteria != null) {
      map['acceptance_criteria'] = Variable<String>(acceptanceCriteria);
    }
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || posX != null) {
      map['pos_x'] = Variable<double>(posX);
    }
    if (!nullToAbsent || posY != null) {
      map['pos_y'] = Variable<double>(posY);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserStoriesCompanion toCompanion(bool nullToAbsent) {
    return UserStoriesCompanion(
      story_pk: Value(story_pk),
      project_fk: Value(project_fk),
      parent_story_fk: parent_story_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(parent_story_fk),
      title: Value(title),
      narrative: Value(narrative),
      acceptanceCriteria: acceptanceCriteria == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptanceCriteria),
      kind: Value(kind),
      status: Value(status),
      posX: posX == null && nullToAbsent ? const Value.absent() : Value(posX),
      posY: posY == null && nullToAbsent ? const Value.absent() : Value(posY),
      orderIndex: Value(orderIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserStory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStory(
      story_pk: serializer.fromJson<int>(json['story_pk']),
      project_fk: serializer.fromJson<int>(json['project_fk']),
      parent_story_fk: serializer.fromJson<int?>(json['parent_story_fk']),
      title: serializer.fromJson<String>(json['title']),
      narrative: serializer.fromJson<String>(json['narrative']),
      acceptanceCriteria: serializer.fromJson<String?>(
        json['acceptanceCriteria'],
      ),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      posX: serializer.fromJson<double?>(json['posX']),
      posY: serializer.fromJson<double?>(json['posY']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'story_pk': serializer.toJson<int>(story_pk),
      'project_fk': serializer.toJson<int>(project_fk),
      'parent_story_fk': serializer.toJson<int?>(parent_story_fk),
      'title': serializer.toJson<String>(title),
      'narrative': serializer.toJson<String>(narrative),
      'acceptanceCriteria': serializer.toJson<String?>(acceptanceCriteria),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'posX': serializer.toJson<double?>(posX),
      'posY': serializer.toJson<double?>(posY),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserStory copyWith({
    int? story_pk,
    int? project_fk,
    Value<int?> parent_story_fk = const Value.absent(),
    String? title,
    String? narrative,
    Value<String?> acceptanceCriteria = const Value.absent(),
    String? kind,
    String? status,
    Value<double?> posX = const Value.absent(),
    Value<double?> posY = const Value.absent(),
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserStory(
    story_pk: story_pk ?? this.story_pk,
    project_fk: project_fk ?? this.project_fk,
    parent_story_fk: parent_story_fk.present
        ? parent_story_fk.value
        : this.parent_story_fk,
    title: title ?? this.title,
    narrative: narrative ?? this.narrative,
    acceptanceCriteria: acceptanceCriteria.present
        ? acceptanceCriteria.value
        : this.acceptanceCriteria,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    posX: posX.present ? posX.value : this.posX,
    posY: posY.present ? posY.value : this.posY,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserStory copyWithCompanion(UserStoriesCompanion data) {
    return UserStory(
      story_pk: data.story_pk.present ? data.story_pk.value : this.story_pk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      parent_story_fk: data.parent_story_fk.present
          ? data.parent_story_fk.value
          : this.parent_story_fk,
      title: data.title.present ? data.title.value : this.title,
      narrative: data.narrative.present ? data.narrative.value : this.narrative,
      acceptanceCriteria: data.acceptanceCriteria.present
          ? data.acceptanceCriteria.value
          : this.acceptanceCriteria,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      posX: data.posX.present ? data.posX.value : this.posX,
      posY: data.posY.present ? data.posY.value : this.posY,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStory(')
          ..write('story_pk: $story_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('parent_story_fk: $parent_story_fk, ')
          ..write('title: $title, ')
          ..write('narrative: $narrative, ')
          ..write('acceptanceCriteria: $acceptanceCriteria, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    story_pk,
    project_fk,
    parent_story_fk,
    title,
    narrative,
    acceptanceCriteria,
    kind,
    status,
    posX,
    posY,
    orderIndex,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStory &&
          other.story_pk == this.story_pk &&
          other.project_fk == this.project_fk &&
          other.parent_story_fk == this.parent_story_fk &&
          other.title == this.title &&
          other.narrative == this.narrative &&
          other.acceptanceCriteria == this.acceptanceCriteria &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.posX == this.posX &&
          other.posY == this.posY &&
          other.orderIndex == this.orderIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserStoriesCompanion extends UpdateCompanion<UserStory> {
  final Value<int> story_pk;
  final Value<int> project_fk;
  final Value<int?> parent_story_fk;
  final Value<String> title;
  final Value<String> narrative;
  final Value<String?> acceptanceCriteria;
  final Value<String> kind;
  final Value<String> status;
  final Value<double?> posX;
  final Value<double?> posY;
  final Value<int> orderIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserStoriesCompanion({
    this.story_pk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.parent_story_fk = const Value.absent(),
    this.title = const Value.absent(),
    this.narrative = const Value.absent(),
    this.acceptanceCriteria = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserStoriesCompanion.insert({
    this.story_pk = const Value.absent(),
    required int project_fk,
    this.parent_story_fk = const Value.absent(),
    required String title,
    this.narrative = const Value.absent(),
    this.acceptanceCriteria = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : project_fk = Value(project_fk),
       title = Value(title);
  static Insertable<UserStory> custom({
    Expression<int>? story_pk,
    Expression<int>? project_fk,
    Expression<int>? parent_story_fk,
    Expression<String>? title,
    Expression<String>? narrative,
    Expression<String>? acceptanceCriteria,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<double>? posX,
    Expression<double>? posY,
    Expression<int>? orderIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (story_pk != null) 'story_pk': story_pk,
      if (project_fk != null) 'project_fk': project_fk,
      if (parent_story_fk != null) 'parent_story_fk': parent_story_fk,
      if (title != null) 'title': title,
      if (narrative != null) 'narrative': narrative,
      if (acceptanceCriteria != null) 'acceptance_criteria': acceptanceCriteria,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (posX != null) 'pos_x': posX,
      if (posY != null) 'pos_y': posY,
      if (orderIndex != null) 'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserStoriesCompanion copyWith({
    Value<int>? story_pk,
    Value<int>? project_fk,
    Value<int?>? parent_story_fk,
    Value<String>? title,
    Value<String>? narrative,
    Value<String?>? acceptanceCriteria,
    Value<String>? kind,
    Value<String>? status,
    Value<double?>? posX,
    Value<double?>? posY,
    Value<int>? orderIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserStoriesCompanion(
      story_pk: story_pk ?? this.story_pk,
      project_fk: project_fk ?? this.project_fk,
      parent_story_fk: parent_story_fk ?? this.parent_story_fk,
      title: title ?? this.title,
      narrative: narrative ?? this.narrative,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (story_pk.present) {
      map['story_pk'] = Variable<int>(story_pk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (parent_story_fk.present) {
      map['parent_story_fk'] = Variable<int>(parent_story_fk.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (narrative.present) {
      map['narrative'] = Variable<String>(narrative.value);
    }
    if (acceptanceCriteria.present) {
      map['acceptance_criteria'] = Variable<String>(acceptanceCriteria.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (posX.present) {
      map['pos_x'] = Variable<double>(posX.value);
    }
    if (posY.present) {
      map['pos_y'] = Variable<double>(posY.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStoriesCompanion(')
          ..write('story_pk: $story_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('parent_story_fk: $parent_story_fk, ')
          ..write('title: $title, ')
          ..write('narrative: $narrative, ')
          ..write('acceptanceCriteria: $acceptanceCriteria, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _task_pkMeta = const VerificationMeta(
    'task_pk',
  );
  @override
  late final GeneratedColumn<int> task_pk = GeneratedColumn<int>(
    'task_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _task_client_fkMeta = const VerificationMeta(
    'task_client_fk',
  );
  @override
  late final GeneratedColumn<int> task_client_fk = GeneratedColumn<int>(
    'task_client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _task_project_fkMeta = const VerificationMeta(
    'task_project_fk',
  );
  @override
  late final GeneratedColumn<int> task_project_fk = GeneratedColumn<int>(
    'task_project_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _task_parent_fkMeta = const VerificationMeta(
    'task_parent_fk',
  );
  @override
  late final GeneratedColumn<int> task_parent_fk = GeneratedColumn<int>(
    'task_parent_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (task_pk)',
    ),
  );
  static const VerificationMeta _task_plan_pathMeta = const VerificationMeta(
    'task_plan_path',
  );
  @override
  late final GeneratedColumn<String> task_plan_path = GeneratedColumn<String>(
    'task_plan_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _task_chat_session_fkMeta =
      const VerificationMeta('task_chat_session_fk');
  @override
  late final GeneratedColumn<int> task_chat_session_fk = GeneratedColumn<int>(
    'task_chat_session_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (session_pk)',
    ),
  );
  static const VerificationMeta _task_agent_fkMeta = const VerificationMeta(
    'task_agent_fk',
  );
  @override
  late final GeneratedColumn<int> task_agent_fk = GeneratedColumn<int>(
    'task_agent_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_personas (agent_pk)',
    ),
  );
  static const VerificationMeta _task_story_fkMeta = const VerificationMeta(
    'task_story_fk',
  );
  @override
  late final GeneratedColumn<int> task_story_fk = GeneratedColumn<int>(
    'task_story_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_stories (story_pk)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Todo'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('MED'),
  );
  static const VerificationMeta _thinkingModeMeta = const VerificationMeta(
    'thinkingMode',
  );
  @override
  late final GeneratedColumn<String> thinkingMode = GeneratedColumn<String>(
    'thinking_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokenCostMeta = const VerificationMeta(
    'tokenCost',
  );
  @override
  late final GeneratedColumn<int> tokenCost = GeneratedColumn<int>(
    'token_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _usdCostMeta = const VerificationMeta(
    'usdCost',
  );
  @override
  late final GeneratedColumn<double> usdCost = GeneratedColumn<double>(
    'usd_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _acceptanceCriteriaMeta =
      const VerificationMeta('acceptanceCriteria');
  @override
  late final GeneratedColumn<String> acceptanceCriteria =
      GeneratedColumn<String>(
        'acceptance_criteria',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _verificationMeta = const VerificationMeta(
    'verification',
  );
  @override
  late final GeneratedColumn<String> verification = GeneratedColumn<String>(
    'verification',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _executionStatusMeta = const VerificationMeta(
    'executionStatus',
  );
  @override
  late final GeneratedColumn<String> executionStatus = GeneratedColumn<String>(
    'execution_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('idle'),
  );
  static const VerificationMeta _submissionJsonMeta = const VerificationMeta(
    'submissionJson',
  );
  @override
  late final GeneratedColumn<String> submissionJson = GeneratedColumn<String>(
    'submission_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _worker_session_fkMeta = const VerificationMeta(
    'worker_session_fk',
  );
  @override
  late final GeneratedColumn<int> worker_session_fk = GeneratedColumn<int>(
    'worker_session_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (session_pk)',
    ),
  );
  static const VerificationMeta _workBranchMeta = const VerificationMeta(
    'workBranch',
  );
  @override
  late final GeneratedColumn<String> workBranch = GeneratedColumn<String>(
    'work_branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _milestoneOrderMeta = const VerificationMeta(
    'milestoneOrder',
  );
  @override
  late final GeneratedColumn<int> milestoneOrder = GeneratedColumn<int>(
    'milestone_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEditMeta = const VerificationMeta('isEdit');
  @override
  late final GeneratedColumn<bool> isEdit = GeneratedColumn<bool>(
    'is_edit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edit" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _requiresBuildMeta = const VerificationMeta(
    'requiresBuild',
  );
  @override
  late final GeneratedColumn<bool> requiresBuild = GeneratedColumn<bool>(
    'requires_build',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_build" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dockerfilePathMeta = const VerificationMeta(
    'dockerfilePath',
  );
  @override
  late final GeneratedColumn<String> dockerfilePath = GeneratedColumn<String>(
    'dockerfile_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workflowPathMeta = const VerificationMeta(
    'workflowPath',
  );
  @override
  late final GeneratedColumn<String> workflowPath = GeneratedColumn<String>(
    'workflow_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    task_pk,
    task_client_fk,
    task_project_fk,
    task_parent_fk,
    task_plan_path,
    task_chat_session_fk,
    task_agent_fk,
    task_story_fk,
    title,
    description,
    status,
    priority,
    thinkingMode,
    tokenCost,
    usdCost,
    acceptanceCriteria,
    verification,
    executionStatus,
    submissionJson,
    worker_session_fk,
    workBranch,
    milestoneOrder,
    isEdit,
    requiresBuild,
    dockerfilePath,
    workflowPath,
    imageTag,
    startDate,
    dueDate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_pk')) {
      context.handle(
        _task_pkMeta,
        task_pk.isAcceptableOrUnknown(data['task_pk']!, _task_pkMeta),
      );
    }
    if (data.containsKey('task_client_fk')) {
      context.handle(
        _task_client_fkMeta,
        task_client_fk.isAcceptableOrUnknown(
          data['task_client_fk']!,
          _task_client_fkMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_task_client_fkMeta);
    }
    if (data.containsKey('task_project_fk')) {
      context.handle(
        _task_project_fkMeta,
        task_project_fk.isAcceptableOrUnknown(
          data['task_project_fk']!,
          _task_project_fkMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_task_project_fkMeta);
    }
    if (data.containsKey('task_parent_fk')) {
      context.handle(
        _task_parent_fkMeta,
        task_parent_fk.isAcceptableOrUnknown(
          data['task_parent_fk']!,
          _task_parent_fkMeta,
        ),
      );
    }
    if (data.containsKey('task_plan_path')) {
      context.handle(
        _task_plan_pathMeta,
        task_plan_path.isAcceptableOrUnknown(
          data['task_plan_path']!,
          _task_plan_pathMeta,
        ),
      );
    }
    if (data.containsKey('task_chat_session_fk')) {
      context.handle(
        _task_chat_session_fkMeta,
        task_chat_session_fk.isAcceptableOrUnknown(
          data['task_chat_session_fk']!,
          _task_chat_session_fkMeta,
        ),
      );
    }
    if (data.containsKey('task_agent_fk')) {
      context.handle(
        _task_agent_fkMeta,
        task_agent_fk.isAcceptableOrUnknown(
          data['task_agent_fk']!,
          _task_agent_fkMeta,
        ),
      );
    }
    if (data.containsKey('task_story_fk')) {
      context.handle(
        _task_story_fkMeta,
        task_story_fk.isAcceptableOrUnknown(
          data['task_story_fk']!,
          _task_story_fkMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('thinking_mode')) {
      context.handle(
        _thinkingModeMeta,
        thinkingMode.isAcceptableOrUnknown(
          data['thinking_mode']!,
          _thinkingModeMeta,
        ),
      );
    }
    if (data.containsKey('token_cost')) {
      context.handle(
        _tokenCostMeta,
        tokenCost.isAcceptableOrUnknown(data['token_cost']!, _tokenCostMeta),
      );
    }
    if (data.containsKey('usd_cost')) {
      context.handle(
        _usdCostMeta,
        usdCost.isAcceptableOrUnknown(data['usd_cost']!, _usdCostMeta),
      );
    }
    if (data.containsKey('acceptance_criteria')) {
      context.handle(
        _acceptanceCriteriaMeta,
        acceptanceCriteria.isAcceptableOrUnknown(
          data['acceptance_criteria']!,
          _acceptanceCriteriaMeta,
        ),
      );
    }
    if (data.containsKey('verification')) {
      context.handle(
        _verificationMeta,
        verification.isAcceptableOrUnknown(
          data['verification']!,
          _verificationMeta,
        ),
      );
    }
    if (data.containsKey('execution_status')) {
      context.handle(
        _executionStatusMeta,
        executionStatus.isAcceptableOrUnknown(
          data['execution_status']!,
          _executionStatusMeta,
        ),
      );
    }
    if (data.containsKey('submission_json')) {
      context.handle(
        _submissionJsonMeta,
        submissionJson.isAcceptableOrUnknown(
          data['submission_json']!,
          _submissionJsonMeta,
        ),
      );
    }
    if (data.containsKey('worker_session_fk')) {
      context.handle(
        _worker_session_fkMeta,
        worker_session_fk.isAcceptableOrUnknown(
          data['worker_session_fk']!,
          _worker_session_fkMeta,
        ),
      );
    }
    if (data.containsKey('work_branch')) {
      context.handle(
        _workBranchMeta,
        workBranch.isAcceptableOrUnknown(data['work_branch']!, _workBranchMeta),
      );
    }
    if (data.containsKey('milestone_order')) {
      context.handle(
        _milestoneOrderMeta,
        milestoneOrder.isAcceptableOrUnknown(
          data['milestone_order']!,
          _milestoneOrderMeta,
        ),
      );
    }
    if (data.containsKey('is_edit')) {
      context.handle(
        _isEditMeta,
        isEdit.isAcceptableOrUnknown(data['is_edit']!, _isEditMeta),
      );
    }
    if (data.containsKey('requires_build')) {
      context.handle(
        _requiresBuildMeta,
        requiresBuild.isAcceptableOrUnknown(
          data['requires_build']!,
          _requiresBuildMeta,
        ),
      );
    }
    if (data.containsKey('dockerfile_path')) {
      context.handle(
        _dockerfilePathMeta,
        dockerfilePath.isAcceptableOrUnknown(
          data['dockerfile_path']!,
          _dockerfilePathMeta,
        ),
      );
    }
    if (data.containsKey('workflow_path')) {
      context.handle(
        _workflowPathMeta,
        workflowPath.isAcceptableOrUnknown(
          data['workflow_path']!,
          _workflowPathMeta,
        ),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {task_pk};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      task_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_pk'],
      )!,
      task_client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_client_fk'],
      )!,
      task_project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_project_fk'],
      )!,
      task_parent_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_parent_fk'],
      ),
      task_plan_path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_plan_path'],
      ),
      task_chat_session_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_chat_session_fk'],
      ),
      task_agent_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_agent_fk'],
      ),
      task_story_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_story_fk'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      thinkingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thinking_mode'],
      ),
      tokenCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}token_cost'],
      )!,
      usdCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}usd_cost'],
      )!,
      acceptanceCriteria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acceptance_criteria'],
      ),
      verification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification'],
      ),
      executionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_status'],
      )!,
      submissionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submission_json'],
      ),
      worker_session_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worker_session_fk'],
      ),
      workBranch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_branch'],
      ),
      milestoneOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}milestone_order'],
      ),
      isEdit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edit'],
      )!,
      requiresBuild: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_build'],
      )!,
      dockerfilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dockerfile_path'],
      ),
      workflowPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_path'],
      ),
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final int task_pk;
  final int task_client_fk;
  final int task_project_fk;

  /// Subtask tree (points at the parent task).
  final int? task_parent_fk;

  /// Provenance: the workspace path of the plan this task was generated from
  /// (e.g. `/PLANS/Roadmap.md`). Plans are files, not DB rows.
  final String? task_plan_path;

  /// Provenance: the coordinator chat session that created this task.
  final int? task_chat_session_fk;

  /// The agent persona responsible for this task.
  final int? task_agent_fk;

  /// Provenance: the user-story item this task implements (set when tasks are
  /// generated from the exploration story tree). Lets the system trace any task
  /// back to its story, and a story to its task(s). Null for ad-hoc tasks.
  final int? task_story_fk;
  final String title;
  final String? description;
  final String status;
  final String priority;

  /// Per-task model thinking mode: 'on' | 'off' | null (inherit). Set by the
  /// Coordinator via the create_task/update_task `thinking_enabled` param.
  final String? thinkingMode;
  final int tokenCost;
  final double usdCost;

  /// Plain-language definition of done, authored by the Project Manager.
  final String? acceptanceCriteria;

  /// The runnable proof: a command and its expected result (e.g.
  /// "flutter analyze -> no issues"). The Verification Agent runs this.
  final String? verification;

  /// Execution phase distinct from the kanban [status]:
  /// idle | queued | running | submitted | verifying | passed | failed.
  final String executionStatus;

  /// The worker's submission for review (JSON: summary, evidence, branch, etc.).
  final String? submissionJson;

  /// The chat session of the worker currently assigned to execute this task.
  final int? worker_session_fk;

  /// The git branch this task is being worked on (e.g. `task/42`).
  final String? workBranch;

  /// Which milestone batch this task belongs to (0-based), assigned by the
  /// Templater stage when it splits the backlog into sequential, topic-grouped
  /// milestones. Workers only pick up tasks whose milestone is the project's
  /// current one. Null = unassigned (short projects / legacy tasks → batch 0).
  final int? milestoneOrder;

  /// True for tasks created by the EDITOR (the post-build fast lane) rather than
  /// the original autonomous build. Purely a provenance/UI flag: edit tasks are
  /// filed under the workspace's "Edits" tab instead of bloating the main build
  /// task board. Does not affect scheduling.
  final bool isEdit;

  /// When true, the orchestration pipeline runs a Docker build / CI gate on this
  /// task after verification passes and before it is handed off for merge.
  final bool requiresBuild;

  /// Workspace path of the Dockerfile to build for the build gate (e.g.
  /// `/Dockerfile`). Used when [workflowPath] is null.
  final String? dockerfilePath;

  /// Workspace path of a GitHub-Actions workflow to run for the build gate
  /// (e.g. `/.github/workflows/ci.yml`). Takes precedence over [dockerfilePath].
  final String? workflowPath;

  /// Image tag to produce when building from [dockerfilePath] (e.g.
  /// `myapp:task-42`). Defaults to a task-derived tag when null.
  final String? imageTag;

  /// Optional scheduling (owner- or AI-set).
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Task({
    required this.task_pk,
    required this.task_client_fk,
    required this.task_project_fk,
    this.task_parent_fk,
    this.task_plan_path,
    this.task_chat_session_fk,
    this.task_agent_fk,
    this.task_story_fk,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.thinkingMode,
    required this.tokenCost,
    required this.usdCost,
    this.acceptanceCriteria,
    this.verification,
    required this.executionStatus,
    this.submissionJson,
    this.worker_session_fk,
    this.workBranch,
    this.milestoneOrder,
    required this.isEdit,
    required this.requiresBuild,
    this.dockerfilePath,
    this.workflowPath,
    this.imageTag,
    this.startDate,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_pk'] = Variable<int>(task_pk);
    map['task_client_fk'] = Variable<int>(task_client_fk);
    map['task_project_fk'] = Variable<int>(task_project_fk);
    if (!nullToAbsent || task_parent_fk != null) {
      map['task_parent_fk'] = Variable<int>(task_parent_fk);
    }
    if (!nullToAbsent || task_plan_path != null) {
      map['task_plan_path'] = Variable<String>(task_plan_path);
    }
    if (!nullToAbsent || task_chat_session_fk != null) {
      map['task_chat_session_fk'] = Variable<int>(task_chat_session_fk);
    }
    if (!nullToAbsent || task_agent_fk != null) {
      map['task_agent_fk'] = Variable<int>(task_agent_fk);
    }
    if (!nullToAbsent || task_story_fk != null) {
      map['task_story_fk'] = Variable<int>(task_story_fk);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || thinkingMode != null) {
      map['thinking_mode'] = Variable<String>(thinkingMode);
    }
    map['token_cost'] = Variable<int>(tokenCost);
    map['usd_cost'] = Variable<double>(usdCost);
    if (!nullToAbsent || acceptanceCriteria != null) {
      map['acceptance_criteria'] = Variable<String>(acceptanceCriteria);
    }
    if (!nullToAbsent || verification != null) {
      map['verification'] = Variable<String>(verification);
    }
    map['execution_status'] = Variable<String>(executionStatus);
    if (!nullToAbsent || submissionJson != null) {
      map['submission_json'] = Variable<String>(submissionJson);
    }
    if (!nullToAbsent || worker_session_fk != null) {
      map['worker_session_fk'] = Variable<int>(worker_session_fk);
    }
    if (!nullToAbsent || workBranch != null) {
      map['work_branch'] = Variable<String>(workBranch);
    }
    if (!nullToAbsent || milestoneOrder != null) {
      map['milestone_order'] = Variable<int>(milestoneOrder);
    }
    map['is_edit'] = Variable<bool>(isEdit);
    map['requires_build'] = Variable<bool>(requiresBuild);
    if (!nullToAbsent || dockerfilePath != null) {
      map['dockerfile_path'] = Variable<String>(dockerfilePath);
    }
    if (!nullToAbsent || workflowPath != null) {
      map['workflow_path'] = Variable<String>(workflowPath);
    }
    if (!nullToAbsent || imageTag != null) {
      map['image_tag'] = Variable<String>(imageTag);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      task_pk: Value(task_pk),
      task_client_fk: Value(task_client_fk),
      task_project_fk: Value(task_project_fk),
      task_parent_fk: task_parent_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(task_parent_fk),
      task_plan_path: task_plan_path == null && nullToAbsent
          ? const Value.absent()
          : Value(task_plan_path),
      task_chat_session_fk: task_chat_session_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(task_chat_session_fk),
      task_agent_fk: task_agent_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(task_agent_fk),
      task_story_fk: task_story_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(task_story_fk),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      priority: Value(priority),
      thinkingMode: thinkingMode == null && nullToAbsent
          ? const Value.absent()
          : Value(thinkingMode),
      tokenCost: Value(tokenCost),
      usdCost: Value(usdCost),
      acceptanceCriteria: acceptanceCriteria == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptanceCriteria),
      verification: verification == null && nullToAbsent
          ? const Value.absent()
          : Value(verification),
      executionStatus: Value(executionStatus),
      submissionJson: submissionJson == null && nullToAbsent
          ? const Value.absent()
          : Value(submissionJson),
      worker_session_fk: worker_session_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(worker_session_fk),
      workBranch: workBranch == null && nullToAbsent
          ? const Value.absent()
          : Value(workBranch),
      milestoneOrder: milestoneOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(milestoneOrder),
      isEdit: Value(isEdit),
      requiresBuild: Value(requiresBuild),
      dockerfilePath: dockerfilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(dockerfilePath),
      workflowPath: workflowPath == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowPath),
      imageTag: imageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTag),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      task_pk: serializer.fromJson<int>(json['task_pk']),
      task_client_fk: serializer.fromJson<int>(json['task_client_fk']),
      task_project_fk: serializer.fromJson<int>(json['task_project_fk']),
      task_parent_fk: serializer.fromJson<int?>(json['task_parent_fk']),
      task_plan_path: serializer.fromJson<String?>(json['task_plan_path']),
      task_chat_session_fk: serializer.fromJson<int?>(
        json['task_chat_session_fk'],
      ),
      task_agent_fk: serializer.fromJson<int?>(json['task_agent_fk']),
      task_story_fk: serializer.fromJson<int?>(json['task_story_fk']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<String>(json['priority']),
      thinkingMode: serializer.fromJson<String?>(json['thinkingMode']),
      tokenCost: serializer.fromJson<int>(json['tokenCost']),
      usdCost: serializer.fromJson<double>(json['usdCost']),
      acceptanceCriteria: serializer.fromJson<String?>(
        json['acceptanceCriteria'],
      ),
      verification: serializer.fromJson<String?>(json['verification']),
      executionStatus: serializer.fromJson<String>(json['executionStatus']),
      submissionJson: serializer.fromJson<String?>(json['submissionJson']),
      worker_session_fk: serializer.fromJson<int?>(json['worker_session_fk']),
      workBranch: serializer.fromJson<String?>(json['workBranch']),
      milestoneOrder: serializer.fromJson<int?>(json['milestoneOrder']),
      isEdit: serializer.fromJson<bool>(json['isEdit']),
      requiresBuild: serializer.fromJson<bool>(json['requiresBuild']),
      dockerfilePath: serializer.fromJson<String?>(json['dockerfilePath']),
      workflowPath: serializer.fromJson<String?>(json['workflowPath']),
      imageTag: serializer.fromJson<String?>(json['imageTag']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'task_pk': serializer.toJson<int>(task_pk),
      'task_client_fk': serializer.toJson<int>(task_client_fk),
      'task_project_fk': serializer.toJson<int>(task_project_fk),
      'task_parent_fk': serializer.toJson<int?>(task_parent_fk),
      'task_plan_path': serializer.toJson<String?>(task_plan_path),
      'task_chat_session_fk': serializer.toJson<int?>(task_chat_session_fk),
      'task_agent_fk': serializer.toJson<int?>(task_agent_fk),
      'task_story_fk': serializer.toJson<int?>(task_story_fk),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<String>(priority),
      'thinkingMode': serializer.toJson<String?>(thinkingMode),
      'tokenCost': serializer.toJson<int>(tokenCost),
      'usdCost': serializer.toJson<double>(usdCost),
      'acceptanceCriteria': serializer.toJson<String?>(acceptanceCriteria),
      'verification': serializer.toJson<String?>(verification),
      'executionStatus': serializer.toJson<String>(executionStatus),
      'submissionJson': serializer.toJson<String?>(submissionJson),
      'worker_session_fk': serializer.toJson<int?>(worker_session_fk),
      'workBranch': serializer.toJson<String?>(workBranch),
      'milestoneOrder': serializer.toJson<int?>(milestoneOrder),
      'isEdit': serializer.toJson<bool>(isEdit),
      'requiresBuild': serializer.toJson<bool>(requiresBuild),
      'dockerfilePath': serializer.toJson<String?>(dockerfilePath),
      'workflowPath': serializer.toJson<String?>(workflowPath),
      'imageTag': serializer.toJson<String?>(imageTag),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Task copyWith({
    int? task_pk,
    int? task_client_fk,
    int? task_project_fk,
    Value<int?> task_parent_fk = const Value.absent(),
    Value<String?> task_plan_path = const Value.absent(),
    Value<int?> task_chat_session_fk = const Value.absent(),
    Value<int?> task_agent_fk = const Value.absent(),
    Value<int?> task_story_fk = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    String? status,
    String? priority,
    Value<String?> thinkingMode = const Value.absent(),
    int? tokenCost,
    double? usdCost,
    Value<String?> acceptanceCriteria = const Value.absent(),
    Value<String?> verification = const Value.absent(),
    String? executionStatus,
    Value<String?> submissionJson = const Value.absent(),
    Value<int?> worker_session_fk = const Value.absent(),
    Value<String?> workBranch = const Value.absent(),
    Value<int?> milestoneOrder = const Value.absent(),
    bool? isEdit,
    bool? requiresBuild,
    Value<String?> dockerfilePath = const Value.absent(),
    Value<String?> workflowPath = const Value.absent(),
    Value<String?> imageTag = const Value.absent(),
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Task(
    task_pk: task_pk ?? this.task_pk,
    task_client_fk: task_client_fk ?? this.task_client_fk,
    task_project_fk: task_project_fk ?? this.task_project_fk,
    task_parent_fk: task_parent_fk.present
        ? task_parent_fk.value
        : this.task_parent_fk,
    task_plan_path: task_plan_path.present
        ? task_plan_path.value
        : this.task_plan_path,
    task_chat_session_fk: task_chat_session_fk.present
        ? task_chat_session_fk.value
        : this.task_chat_session_fk,
    task_agent_fk: task_agent_fk.present
        ? task_agent_fk.value
        : this.task_agent_fk,
    task_story_fk: task_story_fk.present
        ? task_story_fk.value
        : this.task_story_fk,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    thinkingMode: thinkingMode.present ? thinkingMode.value : this.thinkingMode,
    tokenCost: tokenCost ?? this.tokenCost,
    usdCost: usdCost ?? this.usdCost,
    acceptanceCriteria: acceptanceCriteria.present
        ? acceptanceCriteria.value
        : this.acceptanceCriteria,
    verification: verification.present ? verification.value : this.verification,
    executionStatus: executionStatus ?? this.executionStatus,
    submissionJson: submissionJson.present
        ? submissionJson.value
        : this.submissionJson,
    worker_session_fk: worker_session_fk.present
        ? worker_session_fk.value
        : this.worker_session_fk,
    workBranch: workBranch.present ? workBranch.value : this.workBranch,
    milestoneOrder: milestoneOrder.present
        ? milestoneOrder.value
        : this.milestoneOrder,
    isEdit: isEdit ?? this.isEdit,
    requiresBuild: requiresBuild ?? this.requiresBuild,
    dockerfilePath: dockerfilePath.present
        ? dockerfilePath.value
        : this.dockerfilePath,
    workflowPath: workflowPath.present ? workflowPath.value : this.workflowPath,
    imageTag: imageTag.present ? imageTag.value : this.imageTag,
    startDate: startDate.present ? startDate.value : this.startDate,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      task_pk: data.task_pk.present ? data.task_pk.value : this.task_pk,
      task_client_fk: data.task_client_fk.present
          ? data.task_client_fk.value
          : this.task_client_fk,
      task_project_fk: data.task_project_fk.present
          ? data.task_project_fk.value
          : this.task_project_fk,
      task_parent_fk: data.task_parent_fk.present
          ? data.task_parent_fk.value
          : this.task_parent_fk,
      task_plan_path: data.task_plan_path.present
          ? data.task_plan_path.value
          : this.task_plan_path,
      task_chat_session_fk: data.task_chat_session_fk.present
          ? data.task_chat_session_fk.value
          : this.task_chat_session_fk,
      task_agent_fk: data.task_agent_fk.present
          ? data.task_agent_fk.value
          : this.task_agent_fk,
      task_story_fk: data.task_story_fk.present
          ? data.task_story_fk.value
          : this.task_story_fk,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      thinkingMode: data.thinkingMode.present
          ? data.thinkingMode.value
          : this.thinkingMode,
      tokenCost: data.tokenCost.present ? data.tokenCost.value : this.tokenCost,
      usdCost: data.usdCost.present ? data.usdCost.value : this.usdCost,
      acceptanceCriteria: data.acceptanceCriteria.present
          ? data.acceptanceCriteria.value
          : this.acceptanceCriteria,
      verification: data.verification.present
          ? data.verification.value
          : this.verification,
      executionStatus: data.executionStatus.present
          ? data.executionStatus.value
          : this.executionStatus,
      submissionJson: data.submissionJson.present
          ? data.submissionJson.value
          : this.submissionJson,
      worker_session_fk: data.worker_session_fk.present
          ? data.worker_session_fk.value
          : this.worker_session_fk,
      workBranch: data.workBranch.present
          ? data.workBranch.value
          : this.workBranch,
      milestoneOrder: data.milestoneOrder.present
          ? data.milestoneOrder.value
          : this.milestoneOrder,
      isEdit: data.isEdit.present ? data.isEdit.value : this.isEdit,
      requiresBuild: data.requiresBuild.present
          ? data.requiresBuild.value
          : this.requiresBuild,
      dockerfilePath: data.dockerfilePath.present
          ? data.dockerfilePath.value
          : this.dockerfilePath,
      workflowPath: data.workflowPath.present
          ? data.workflowPath.value
          : this.workflowPath,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('task_pk: $task_pk, ')
          ..write('task_client_fk: $task_client_fk, ')
          ..write('task_project_fk: $task_project_fk, ')
          ..write('task_parent_fk: $task_parent_fk, ')
          ..write('task_plan_path: $task_plan_path, ')
          ..write('task_chat_session_fk: $task_chat_session_fk, ')
          ..write('task_agent_fk: $task_agent_fk, ')
          ..write('task_story_fk: $task_story_fk, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('thinkingMode: $thinkingMode, ')
          ..write('tokenCost: $tokenCost, ')
          ..write('usdCost: $usdCost, ')
          ..write('acceptanceCriteria: $acceptanceCriteria, ')
          ..write('verification: $verification, ')
          ..write('executionStatus: $executionStatus, ')
          ..write('submissionJson: $submissionJson, ')
          ..write('worker_session_fk: $worker_session_fk, ')
          ..write('workBranch: $workBranch, ')
          ..write('milestoneOrder: $milestoneOrder, ')
          ..write('isEdit: $isEdit, ')
          ..write('requiresBuild: $requiresBuild, ')
          ..write('dockerfilePath: $dockerfilePath, ')
          ..write('workflowPath: $workflowPath, ')
          ..write('imageTag: $imageTag, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    task_pk,
    task_client_fk,
    task_project_fk,
    task_parent_fk,
    task_plan_path,
    task_chat_session_fk,
    task_agent_fk,
    task_story_fk,
    title,
    description,
    status,
    priority,
    thinkingMode,
    tokenCost,
    usdCost,
    acceptanceCriteria,
    verification,
    executionStatus,
    submissionJson,
    worker_session_fk,
    workBranch,
    milestoneOrder,
    isEdit,
    requiresBuild,
    dockerfilePath,
    workflowPath,
    imageTag,
    startDate,
    dueDate,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.task_pk == this.task_pk &&
          other.task_client_fk == this.task_client_fk &&
          other.task_project_fk == this.task_project_fk &&
          other.task_parent_fk == this.task_parent_fk &&
          other.task_plan_path == this.task_plan_path &&
          other.task_chat_session_fk == this.task_chat_session_fk &&
          other.task_agent_fk == this.task_agent_fk &&
          other.task_story_fk == this.task_story_fk &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.thinkingMode == this.thinkingMode &&
          other.tokenCost == this.tokenCost &&
          other.usdCost == this.usdCost &&
          other.acceptanceCriteria == this.acceptanceCriteria &&
          other.verification == this.verification &&
          other.executionStatus == this.executionStatus &&
          other.submissionJson == this.submissionJson &&
          other.worker_session_fk == this.worker_session_fk &&
          other.workBranch == this.workBranch &&
          other.milestoneOrder == this.milestoneOrder &&
          other.isEdit == this.isEdit &&
          other.requiresBuild == this.requiresBuild &&
          other.dockerfilePath == this.dockerfilePath &&
          other.workflowPath == this.workflowPath &&
          other.imageTag == this.imageTag &&
          other.startDate == this.startDate &&
          other.dueDate == this.dueDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<int> task_pk;
  final Value<int> task_client_fk;
  final Value<int> task_project_fk;
  final Value<int?> task_parent_fk;
  final Value<String?> task_plan_path;
  final Value<int?> task_chat_session_fk;
  final Value<int?> task_agent_fk;
  final Value<int?> task_story_fk;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> status;
  final Value<String> priority;
  final Value<String?> thinkingMode;
  final Value<int> tokenCost;
  final Value<double> usdCost;
  final Value<String?> acceptanceCriteria;
  final Value<String?> verification;
  final Value<String> executionStatus;
  final Value<String?> submissionJson;
  final Value<int?> worker_session_fk;
  final Value<String?> workBranch;
  final Value<int?> milestoneOrder;
  final Value<bool> isEdit;
  final Value<bool> requiresBuild;
  final Value<String?> dockerfilePath;
  final Value<String?> workflowPath;
  final Value<String?> imageTag;
  final Value<DateTime?> startDate;
  final Value<DateTime?> dueDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TasksCompanion({
    this.task_pk = const Value.absent(),
    this.task_client_fk = const Value.absent(),
    this.task_project_fk = const Value.absent(),
    this.task_parent_fk = const Value.absent(),
    this.task_plan_path = const Value.absent(),
    this.task_chat_session_fk = const Value.absent(),
    this.task_agent_fk = const Value.absent(),
    this.task_story_fk = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.thinkingMode = const Value.absent(),
    this.tokenCost = const Value.absent(),
    this.usdCost = const Value.absent(),
    this.acceptanceCriteria = const Value.absent(),
    this.verification = const Value.absent(),
    this.executionStatus = const Value.absent(),
    this.submissionJson = const Value.absent(),
    this.worker_session_fk = const Value.absent(),
    this.workBranch = const Value.absent(),
    this.milestoneOrder = const Value.absent(),
    this.isEdit = const Value.absent(),
    this.requiresBuild = const Value.absent(),
    this.dockerfilePath = const Value.absent(),
    this.workflowPath = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TasksCompanion.insert({
    this.task_pk = const Value.absent(),
    required int task_client_fk,
    required int task_project_fk,
    this.task_parent_fk = const Value.absent(),
    this.task_plan_path = const Value.absent(),
    this.task_chat_session_fk = const Value.absent(),
    this.task_agent_fk = const Value.absent(),
    this.task_story_fk = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.thinkingMode = const Value.absent(),
    this.tokenCost = const Value.absent(),
    this.usdCost = const Value.absent(),
    this.acceptanceCriteria = const Value.absent(),
    this.verification = const Value.absent(),
    this.executionStatus = const Value.absent(),
    this.submissionJson = const Value.absent(),
    this.worker_session_fk = const Value.absent(),
    this.workBranch = const Value.absent(),
    this.milestoneOrder = const Value.absent(),
    this.isEdit = const Value.absent(),
    this.requiresBuild = const Value.absent(),
    this.dockerfilePath = const Value.absent(),
    this.workflowPath = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : task_client_fk = Value(task_client_fk),
       task_project_fk = Value(task_project_fk),
       title = Value(title);
  static Insertable<Task> custom({
    Expression<int>? task_pk,
    Expression<int>? task_client_fk,
    Expression<int>? task_project_fk,
    Expression<int>? task_parent_fk,
    Expression<String>? task_plan_path,
    Expression<int>? task_chat_session_fk,
    Expression<int>? task_agent_fk,
    Expression<int>? task_story_fk,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? status,
    Expression<String>? priority,
    Expression<String>? thinkingMode,
    Expression<int>? tokenCost,
    Expression<double>? usdCost,
    Expression<String>? acceptanceCriteria,
    Expression<String>? verification,
    Expression<String>? executionStatus,
    Expression<String>? submissionJson,
    Expression<int>? worker_session_fk,
    Expression<String>? workBranch,
    Expression<int>? milestoneOrder,
    Expression<bool>? isEdit,
    Expression<bool>? requiresBuild,
    Expression<String>? dockerfilePath,
    Expression<String>? workflowPath,
    Expression<String>? imageTag,
    Expression<DateTime>? startDate,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (task_pk != null) 'task_pk': task_pk,
      if (task_client_fk != null) 'task_client_fk': task_client_fk,
      if (task_project_fk != null) 'task_project_fk': task_project_fk,
      if (task_parent_fk != null) 'task_parent_fk': task_parent_fk,
      if (task_plan_path != null) 'task_plan_path': task_plan_path,
      if (task_chat_session_fk != null)
        'task_chat_session_fk': task_chat_session_fk,
      if (task_agent_fk != null) 'task_agent_fk': task_agent_fk,
      if (task_story_fk != null) 'task_story_fk': task_story_fk,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (thinkingMode != null) 'thinking_mode': thinkingMode,
      if (tokenCost != null) 'token_cost': tokenCost,
      if (usdCost != null) 'usd_cost': usdCost,
      if (acceptanceCriteria != null) 'acceptance_criteria': acceptanceCriteria,
      if (verification != null) 'verification': verification,
      if (executionStatus != null) 'execution_status': executionStatus,
      if (submissionJson != null) 'submission_json': submissionJson,
      if (worker_session_fk != null) 'worker_session_fk': worker_session_fk,
      if (workBranch != null) 'work_branch': workBranch,
      if (milestoneOrder != null) 'milestone_order': milestoneOrder,
      if (isEdit != null) 'is_edit': isEdit,
      if (requiresBuild != null) 'requires_build': requiresBuild,
      if (dockerfilePath != null) 'dockerfile_path': dockerfilePath,
      if (workflowPath != null) 'workflow_path': workflowPath,
      if (imageTag != null) 'image_tag': imageTag,
      if (startDate != null) 'start_date': startDate,
      if (dueDate != null) 'due_date': dueDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TasksCompanion copyWith({
    Value<int>? task_pk,
    Value<int>? task_client_fk,
    Value<int>? task_project_fk,
    Value<int?>? task_parent_fk,
    Value<String?>? task_plan_path,
    Value<int?>? task_chat_session_fk,
    Value<int?>? task_agent_fk,
    Value<int?>? task_story_fk,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? status,
    Value<String>? priority,
    Value<String?>? thinkingMode,
    Value<int>? tokenCost,
    Value<double>? usdCost,
    Value<String?>? acceptanceCriteria,
    Value<String?>? verification,
    Value<String>? executionStatus,
    Value<String?>? submissionJson,
    Value<int?>? worker_session_fk,
    Value<String?>? workBranch,
    Value<int?>? milestoneOrder,
    Value<bool>? isEdit,
    Value<bool>? requiresBuild,
    Value<String?>? dockerfilePath,
    Value<String?>? workflowPath,
    Value<String?>? imageTag,
    Value<DateTime?>? startDate,
    Value<DateTime?>? dueDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TasksCompanion(
      task_pk: task_pk ?? this.task_pk,
      task_client_fk: task_client_fk ?? this.task_client_fk,
      task_project_fk: task_project_fk ?? this.task_project_fk,
      task_parent_fk: task_parent_fk ?? this.task_parent_fk,
      task_plan_path: task_plan_path ?? this.task_plan_path,
      task_chat_session_fk: task_chat_session_fk ?? this.task_chat_session_fk,
      task_agent_fk: task_agent_fk ?? this.task_agent_fk,
      task_story_fk: task_story_fk ?? this.task_story_fk,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      thinkingMode: thinkingMode ?? this.thinkingMode,
      tokenCost: tokenCost ?? this.tokenCost,
      usdCost: usdCost ?? this.usdCost,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      verification: verification ?? this.verification,
      executionStatus: executionStatus ?? this.executionStatus,
      submissionJson: submissionJson ?? this.submissionJson,
      worker_session_fk: worker_session_fk ?? this.worker_session_fk,
      workBranch: workBranch ?? this.workBranch,
      milestoneOrder: milestoneOrder ?? this.milestoneOrder,
      isEdit: isEdit ?? this.isEdit,
      requiresBuild: requiresBuild ?? this.requiresBuild,
      dockerfilePath: dockerfilePath ?? this.dockerfilePath,
      workflowPath: workflowPath ?? this.workflowPath,
      imageTag: imageTag ?? this.imageTag,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (task_pk.present) {
      map['task_pk'] = Variable<int>(task_pk.value);
    }
    if (task_client_fk.present) {
      map['task_client_fk'] = Variable<int>(task_client_fk.value);
    }
    if (task_project_fk.present) {
      map['task_project_fk'] = Variable<int>(task_project_fk.value);
    }
    if (task_parent_fk.present) {
      map['task_parent_fk'] = Variable<int>(task_parent_fk.value);
    }
    if (task_plan_path.present) {
      map['task_plan_path'] = Variable<String>(task_plan_path.value);
    }
    if (task_chat_session_fk.present) {
      map['task_chat_session_fk'] = Variable<int>(task_chat_session_fk.value);
    }
    if (task_agent_fk.present) {
      map['task_agent_fk'] = Variable<int>(task_agent_fk.value);
    }
    if (task_story_fk.present) {
      map['task_story_fk'] = Variable<int>(task_story_fk.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (thinkingMode.present) {
      map['thinking_mode'] = Variable<String>(thinkingMode.value);
    }
    if (tokenCost.present) {
      map['token_cost'] = Variable<int>(tokenCost.value);
    }
    if (usdCost.present) {
      map['usd_cost'] = Variable<double>(usdCost.value);
    }
    if (acceptanceCriteria.present) {
      map['acceptance_criteria'] = Variable<String>(acceptanceCriteria.value);
    }
    if (verification.present) {
      map['verification'] = Variable<String>(verification.value);
    }
    if (executionStatus.present) {
      map['execution_status'] = Variable<String>(executionStatus.value);
    }
    if (submissionJson.present) {
      map['submission_json'] = Variable<String>(submissionJson.value);
    }
    if (worker_session_fk.present) {
      map['worker_session_fk'] = Variable<int>(worker_session_fk.value);
    }
    if (workBranch.present) {
      map['work_branch'] = Variable<String>(workBranch.value);
    }
    if (milestoneOrder.present) {
      map['milestone_order'] = Variable<int>(milestoneOrder.value);
    }
    if (isEdit.present) {
      map['is_edit'] = Variable<bool>(isEdit.value);
    }
    if (requiresBuild.present) {
      map['requires_build'] = Variable<bool>(requiresBuild.value);
    }
    if (dockerfilePath.present) {
      map['dockerfile_path'] = Variable<String>(dockerfilePath.value);
    }
    if (workflowPath.present) {
      map['workflow_path'] = Variable<String>(workflowPath.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('task_pk: $task_pk, ')
          ..write('task_client_fk: $task_client_fk, ')
          ..write('task_project_fk: $task_project_fk, ')
          ..write('task_parent_fk: $task_parent_fk, ')
          ..write('task_plan_path: $task_plan_path, ')
          ..write('task_chat_session_fk: $task_chat_session_fk, ')
          ..write('task_agent_fk: $task_agent_fk, ')
          ..write('task_story_fk: $task_story_fk, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('thinkingMode: $thinkingMode, ')
          ..write('tokenCost: $tokenCost, ')
          ..write('usdCost: $usdCost, ')
          ..write('acceptanceCriteria: $acceptanceCriteria, ')
          ..write('verification: $verification, ')
          ..write('executionStatus: $executionStatus, ')
          ..write('submissionJson: $submissionJson, ')
          ..write('worker_session_fk: $worker_session_fk, ')
          ..write('workBranch: $workBranch, ')
          ..write('milestoneOrder: $milestoneOrder, ')
          ..write('isEdit: $isEdit, ')
          ..write('requiresBuild: $requiresBuild, ')
          ..write('dockerfilePath: $dockerfilePath, ')
          ..write('workflowPath: $workflowPath, ')
          ..write('imageTag: $imageTag, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SkillsTable extends Skills with TableInfo<$SkillsTable, Skill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _skill_pkMeta = const VerificationMeta(
    'skill_pk',
  );
  @override
  late final GeneratedColumn<int> skill_pk = GeneratedColumn<int>(
    'skill_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('general'),
  );
  static const VerificationMeta _riskLevelMeta = const VerificationMeta(
    'riskLevel',
  );
  @override
  late final GeneratedColumn<String> riskLevel = GeneratedColumn<String>(
    'risk_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('medium'),
  );
  static const VerificationMeta _defaultPermissionMeta = const VerificationMeta(
    'defaultPermission',
  );
  @override
  late final GeneratedColumn<String> defaultPermission =
      GeneratedColumn<String>(
        'default_permission',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('ask'),
      );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _isPrefabMeta = const VerificationMeta(
    'isPrefab',
  );
  @override
  late final GeneratedColumn<bool> isPrefab = GeneratedColumn<bool>(
    'is_prefab',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_prefab" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _prefab_fkMeta = const VerificationMeta(
    'prefab_fk',
  );
  @override
  late final GeneratedColumn<int> prefab_fk = GeneratedColumn<int>(
    'prefab_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES skills (skill_pk)',
    ),
  );
  static const VerificationMeta _overridesJsonMeta = const VerificationMeta(
    'overridesJson',
  );
  @override
  late final GeneratedColumn<String> overridesJson = GeneratedColumn<String>(
    'overrides_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    skill_pk,
    client_fk,
    name,
    description,
    category,
    riskLevel,
    defaultPermission,
    configJson,
    isPrefab,
    prefab_fk,
    overridesJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skills';
  @override
  VerificationContext validateIntegrity(
    Insertable<Skill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('skill_pk')) {
      context.handle(
        _skill_pkMeta,
        skill_pk.isAcceptableOrUnknown(data['skill_pk']!, _skill_pkMeta),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('risk_level')) {
      context.handle(
        _riskLevelMeta,
        riskLevel.isAcceptableOrUnknown(data['risk_level']!, _riskLevelMeta),
      );
    }
    if (data.containsKey('default_permission')) {
      context.handle(
        _defaultPermissionMeta,
        defaultPermission.isAcceptableOrUnknown(
          data['default_permission']!,
          _defaultPermissionMeta,
        ),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('is_prefab')) {
      context.handle(
        _isPrefabMeta,
        isPrefab.isAcceptableOrUnknown(data['is_prefab']!, _isPrefabMeta),
      );
    }
    if (data.containsKey('prefab_fk')) {
      context.handle(
        _prefab_fkMeta,
        prefab_fk.isAcceptableOrUnknown(data['prefab_fk']!, _prefab_fkMeta),
      );
    }
    if (data.containsKey('overrides_json')) {
      context.handle(
        _overridesJsonMeta,
        overridesJson.isAcceptableOrUnknown(
          data['overrides_json']!,
          _overridesJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {skill_pk};
  @override
  Skill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Skill(
      skill_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skill_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      riskLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk_level'],
      )!,
      defaultPermission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_permission'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      isPrefab: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_prefab'],
      )!,
      prefab_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prefab_fk'],
      ),
      overridesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overrides_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SkillsTable createAlias(String alias) {
    return $SkillsTable(attachedDatabase, alias);
  }
}

class Skill extends DataClass implements Insertable<Skill> {
  final int skill_pk;
  final int client_fk;
  final String name;
  final String? description;

  /// The category this skill belongs to (e.g. "git", "build", "deploy", "filesystem", "web").
  final String category;

  /// Risk / blast radius level. Used for policy enforcement.
  final String riskLevel;

  /// Default permission when this skill is granted via a Persona.
  final String defaultPermission;
  final String configJson;
  final bool isPrefab;
  final int? prefab_fk;
  final String overridesJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Skill({
    required this.skill_pk,
    required this.client_fk,
    required this.name,
    this.description,
    required this.category,
    required this.riskLevel,
    required this.defaultPermission,
    required this.configJson,
    required this.isPrefab,
    this.prefab_fk,
    required this.overridesJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['skill_pk'] = Variable<int>(skill_pk);
    map['client_fk'] = Variable<int>(client_fk);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['category'] = Variable<String>(category);
    map['risk_level'] = Variable<String>(riskLevel);
    map['default_permission'] = Variable<String>(defaultPermission);
    map['config_json'] = Variable<String>(configJson);
    map['is_prefab'] = Variable<bool>(isPrefab);
    if (!nullToAbsent || prefab_fk != null) {
      map['prefab_fk'] = Variable<int>(prefab_fk);
    }
    map['overrides_json'] = Variable<String>(overridesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SkillsCompanion toCompanion(bool nullToAbsent) {
    return SkillsCompanion(
      skill_pk: Value(skill_pk),
      client_fk: Value(client_fk),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: Value(category),
      riskLevel: Value(riskLevel),
      defaultPermission: Value(defaultPermission),
      configJson: Value(configJson),
      isPrefab: Value(isPrefab),
      prefab_fk: prefab_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(prefab_fk),
      overridesJson: Value(overridesJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Skill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Skill(
      skill_pk: serializer.fromJson<int>(json['skill_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String>(json['category']),
      riskLevel: serializer.fromJson<String>(json['riskLevel']),
      defaultPermission: serializer.fromJson<String>(json['defaultPermission']),
      configJson: serializer.fromJson<String>(json['configJson']),
      isPrefab: serializer.fromJson<bool>(json['isPrefab']),
      prefab_fk: serializer.fromJson<int?>(json['prefab_fk']),
      overridesJson: serializer.fromJson<String>(json['overridesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'skill_pk': serializer.toJson<int>(skill_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String>(category),
      'riskLevel': serializer.toJson<String>(riskLevel),
      'defaultPermission': serializer.toJson<String>(defaultPermission),
      'configJson': serializer.toJson<String>(configJson),
      'isPrefab': serializer.toJson<bool>(isPrefab),
      'prefab_fk': serializer.toJson<int?>(prefab_fk),
      'overridesJson': serializer.toJson<String>(overridesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Skill copyWith({
    int? skill_pk,
    int? client_fk,
    String? name,
    Value<String?> description = const Value.absent(),
    String? category,
    String? riskLevel,
    String? defaultPermission,
    String? configJson,
    bool? isPrefab,
    Value<int?> prefab_fk = const Value.absent(),
    String? overridesJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Skill(
    skill_pk: skill_pk ?? this.skill_pk,
    client_fk: client_fk ?? this.client_fk,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    category: category ?? this.category,
    riskLevel: riskLevel ?? this.riskLevel,
    defaultPermission: defaultPermission ?? this.defaultPermission,
    configJson: configJson ?? this.configJson,
    isPrefab: isPrefab ?? this.isPrefab,
    prefab_fk: prefab_fk.present ? prefab_fk.value : this.prefab_fk,
    overridesJson: overridesJson ?? this.overridesJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Skill copyWithCompanion(SkillsCompanion data) {
    return Skill(
      skill_pk: data.skill_pk.present ? data.skill_pk.value : this.skill_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      category: data.category.present ? data.category.value : this.category,
      riskLevel: data.riskLevel.present ? data.riskLevel.value : this.riskLevel,
      defaultPermission: data.defaultPermission.present
          ? data.defaultPermission.value
          : this.defaultPermission,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      isPrefab: data.isPrefab.present ? data.isPrefab.value : this.isPrefab,
      prefab_fk: data.prefab_fk.present ? data.prefab_fk.value : this.prefab_fk,
      overridesJson: data.overridesJson.present
          ? data.overridesJson.value
          : this.overridesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Skill(')
          ..write('skill_pk: $skill_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('defaultPermission: $defaultPermission, ')
          ..write('configJson: $configJson, ')
          ..write('isPrefab: $isPrefab, ')
          ..write('prefab_fk: $prefab_fk, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    skill_pk,
    client_fk,
    name,
    description,
    category,
    riskLevel,
    defaultPermission,
    configJson,
    isPrefab,
    prefab_fk,
    overridesJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Skill &&
          other.skill_pk == this.skill_pk &&
          other.client_fk == this.client_fk &&
          other.name == this.name &&
          other.description == this.description &&
          other.category == this.category &&
          other.riskLevel == this.riskLevel &&
          other.defaultPermission == this.defaultPermission &&
          other.configJson == this.configJson &&
          other.isPrefab == this.isPrefab &&
          other.prefab_fk == this.prefab_fk &&
          other.overridesJson == this.overridesJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SkillsCompanion extends UpdateCompanion<Skill> {
  final Value<int> skill_pk;
  final Value<int> client_fk;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> category;
  final Value<String> riskLevel;
  final Value<String> defaultPermission;
  final Value<String> configJson;
  final Value<bool> isPrefab;
  final Value<int?> prefab_fk;
  final Value<String> overridesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SkillsCompanion({
    this.skill_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.riskLevel = const Value.absent(),
    this.defaultPermission = const Value.absent(),
    this.configJson = const Value.absent(),
    this.isPrefab = const Value.absent(),
    this.prefab_fk = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SkillsCompanion.insert({
    this.skill_pk = const Value.absent(),
    required int client_fk,
    required String name,
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.riskLevel = const Value.absent(),
    this.defaultPermission = const Value.absent(),
    this.configJson = const Value.absent(),
    this.isPrefab = const Value.absent(),
    this.prefab_fk = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : client_fk = Value(client_fk),
       name = Value(name);
  static Insertable<Skill> custom({
    Expression<int>? skill_pk,
    Expression<int>? client_fk,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? riskLevel,
    Expression<String>? defaultPermission,
    Expression<String>? configJson,
    Expression<bool>? isPrefab,
    Expression<int>? prefab_fk,
    Expression<String>? overridesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (skill_pk != null) 'skill_pk': skill_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (defaultPermission != null) 'default_permission': defaultPermission,
      if (configJson != null) 'config_json': configJson,
      if (isPrefab != null) 'is_prefab': isPrefab,
      if (prefab_fk != null) 'prefab_fk': prefab_fk,
      if (overridesJson != null) 'overrides_json': overridesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SkillsCompanion copyWith({
    Value<int>? skill_pk,
    Value<int>? client_fk,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? category,
    Value<String>? riskLevel,
    Value<String>? defaultPermission,
    Value<String>? configJson,
    Value<bool>? isPrefab,
    Value<int?>? prefab_fk,
    Value<String>? overridesJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SkillsCompanion(
      skill_pk: skill_pk ?? this.skill_pk,
      client_fk: client_fk ?? this.client_fk,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      riskLevel: riskLevel ?? this.riskLevel,
      defaultPermission: defaultPermission ?? this.defaultPermission,
      configJson: configJson ?? this.configJson,
      isPrefab: isPrefab ?? this.isPrefab,
      prefab_fk: prefab_fk ?? this.prefab_fk,
      overridesJson: overridesJson ?? this.overridesJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (skill_pk.present) {
      map['skill_pk'] = Variable<int>(skill_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (riskLevel.present) {
      map['risk_level'] = Variable<String>(riskLevel.value);
    }
    if (defaultPermission.present) {
      map['default_permission'] = Variable<String>(defaultPermission.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (isPrefab.present) {
      map['is_prefab'] = Variable<bool>(isPrefab.value);
    }
    if (prefab_fk.present) {
      map['prefab_fk'] = Variable<int>(prefab_fk.value);
    }
    if (overridesJson.present) {
      map['overrides_json'] = Variable<String>(overridesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillsCompanion(')
          ..write('skill_pk: $skill_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('defaultPermission: $defaultPermission, ')
          ..write('configJson: $configJson, ')
          ..write('isPrefab: $isPrefab, ')
          ..write('prefab_fk: $prefab_fk, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DeploymentsTable extends Deployments
    with TableInfo<$DeploymentsTable, Deployment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeploymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deployment_pkMeta = const VerificationMeta(
    'deployment_pk',
  );
  @override
  late final GeneratedColumn<int> deployment_pk = GeneratedColumn<int>(
    'deployment_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _environmentMeta = const VerificationMeta(
    'environment',
  );
  @override
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
    'environment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('staging'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _triggeredByMeta = const VerificationMeta(
    'triggeredBy',
  );
  @override
  late final GeneratedColumn<String> triggeredBy = GeneratedColumn<String>(
    'triggered_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deployment_pk,
    client_fk,
    project_fk,
    name,
    environment,
    status,
    triggeredBy,
    createdAt,
    completedAt,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deployments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Deployment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deployment_pk')) {
      context.handle(
        _deployment_pkMeta,
        deployment_pk.isAcceptableOrUnknown(
          data['deployment_pk']!,
          _deployment_pkMeta,
        ),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('environment')) {
      context.handle(
        _environmentMeta,
        environment.isAcceptableOrUnknown(
          data['environment']!,
          _environmentMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('triggered_by')) {
      context.handle(
        _triggeredByMeta,
        triggeredBy.isAcceptableOrUnknown(
          data['triggered_by']!,
          _triggeredByMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deployment_pk};
  @override
  Deployment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deployment(
      deployment_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deployment_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      environment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      triggeredBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triggered_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
    );
  }

  @override
  $DeploymentsTable createAlias(String alias) {
    return $DeploymentsTable(attachedDatabase, alias);
  }
}

class Deployment extends DataClass implements Insertable<Deployment> {
  final int deployment_pk;
  final int client_fk;
  final int? project_fk;
  final String name;
  final String environment;
  final String status;
  final String? triggeredBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String metadataJson;
  const Deployment({
    required this.deployment_pk,
    required this.client_fk,
    this.project_fk,
    required this.name,
    required this.environment,
    required this.status,
    this.triggeredBy,
    required this.createdAt,
    this.completedAt,
    required this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deployment_pk'] = Variable<int>(deployment_pk);
    map['client_fk'] = Variable<int>(client_fk);
    if (!nullToAbsent || project_fk != null) {
      map['project_fk'] = Variable<int>(project_fk);
    }
    map['name'] = Variable<String>(name);
    map['environment'] = Variable<String>(environment);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || triggeredBy != null) {
      map['triggered_by'] = Variable<String>(triggeredBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['metadata_json'] = Variable<String>(metadataJson);
    return map;
  }

  DeploymentsCompanion toCompanion(bool nullToAbsent) {
    return DeploymentsCompanion(
      deployment_pk: Value(deployment_pk),
      client_fk: Value(client_fk),
      project_fk: project_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(project_fk),
      name: Value(name),
      environment: Value(environment),
      status: Value(status),
      triggeredBy: triggeredBy == null && nullToAbsent
          ? const Value.absent()
          : Value(triggeredBy),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      metadataJson: Value(metadataJson),
    );
  }

  factory Deployment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deployment(
      deployment_pk: serializer.fromJson<int>(json['deployment_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      project_fk: serializer.fromJson<int?>(json['project_fk']),
      name: serializer.fromJson<String>(json['name']),
      environment: serializer.fromJson<String>(json['environment']),
      status: serializer.fromJson<String>(json['status']),
      triggeredBy: serializer.fromJson<String?>(json['triggeredBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deployment_pk': serializer.toJson<int>(deployment_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'project_fk': serializer.toJson<int?>(project_fk),
      'name': serializer.toJson<String>(name),
      'environment': serializer.toJson<String>(environment),
      'status': serializer.toJson<String>(status),
      'triggeredBy': serializer.toJson<String?>(triggeredBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'metadataJson': serializer.toJson<String>(metadataJson),
    };
  }

  Deployment copyWith({
    int? deployment_pk,
    int? client_fk,
    Value<int?> project_fk = const Value.absent(),
    String? name,
    String? environment,
    String? status,
    Value<String?> triggeredBy = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
    String? metadataJson,
  }) => Deployment(
    deployment_pk: deployment_pk ?? this.deployment_pk,
    client_fk: client_fk ?? this.client_fk,
    project_fk: project_fk.present ? project_fk.value : this.project_fk,
    name: name ?? this.name,
    environment: environment ?? this.environment,
    status: status ?? this.status,
    triggeredBy: triggeredBy.present ? triggeredBy.value : this.triggeredBy,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    metadataJson: metadataJson ?? this.metadataJson,
  );
  Deployment copyWithCompanion(DeploymentsCompanion data) {
    return Deployment(
      deployment_pk: data.deployment_pk.present
          ? data.deployment_pk.value
          : this.deployment_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      name: data.name.present ? data.name.value : this.name,
      environment: data.environment.present
          ? data.environment.value
          : this.environment,
      status: data.status.present ? data.status.value : this.status,
      triggeredBy: data.triggeredBy.present
          ? data.triggeredBy.value
          : this.triggeredBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deployment(')
          ..write('deployment_pk: $deployment_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('project_fk: $project_fk, ')
          ..write('name: $name, ')
          ..write('environment: $environment, ')
          ..write('status: $status, ')
          ..write('triggeredBy: $triggeredBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deployment_pk,
    client_fk,
    project_fk,
    name,
    environment,
    status,
    triggeredBy,
    createdAt,
    completedAt,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deployment &&
          other.deployment_pk == this.deployment_pk &&
          other.client_fk == this.client_fk &&
          other.project_fk == this.project_fk &&
          other.name == this.name &&
          other.environment == this.environment &&
          other.status == this.status &&
          other.triggeredBy == this.triggeredBy &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.metadataJson == this.metadataJson);
}

class DeploymentsCompanion extends UpdateCompanion<Deployment> {
  final Value<int> deployment_pk;
  final Value<int> client_fk;
  final Value<int?> project_fk;
  final Value<String> name;
  final Value<String> environment;
  final Value<String> status;
  final Value<String?> triggeredBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<String> metadataJson;
  const DeploymentsCompanion({
    this.deployment_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.environment = const Value.absent(),
    this.status = const Value.absent(),
    this.triggeredBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.metadataJson = const Value.absent(),
  });
  DeploymentsCompanion.insert({
    this.deployment_pk = const Value.absent(),
    required int client_fk,
    this.project_fk = const Value.absent(),
    required String name,
    this.environment = const Value.absent(),
    this.status = const Value.absent(),
    this.triggeredBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.metadataJson = const Value.absent(),
  }) : client_fk = Value(client_fk),
       name = Value(name);
  static Insertable<Deployment> custom({
    Expression<int>? deployment_pk,
    Expression<int>? client_fk,
    Expression<int>? project_fk,
    Expression<String>? name,
    Expression<String>? environment,
    Expression<String>? status,
    Expression<String>? triggeredBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<String>? metadataJson,
  }) {
    return RawValuesInsertable({
      if (deployment_pk != null) 'deployment_pk': deployment_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (project_fk != null) 'project_fk': project_fk,
      if (name != null) 'name': name,
      if (environment != null) 'environment': environment,
      if (status != null) 'status': status,
      if (triggeredBy != null) 'triggered_by': triggeredBy,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (metadataJson != null) 'metadata_json': metadataJson,
    });
  }

  DeploymentsCompanion copyWith({
    Value<int>? deployment_pk,
    Value<int>? client_fk,
    Value<int?>? project_fk,
    Value<String>? name,
    Value<String>? environment,
    Value<String>? status,
    Value<String?>? triggeredBy,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<String>? metadataJson,
  }) {
    return DeploymentsCompanion(
      deployment_pk: deployment_pk ?? this.deployment_pk,
      client_fk: client_fk ?? this.client_fk,
      project_fk: project_fk ?? this.project_fk,
      name: name ?? this.name,
      environment: environment ?? this.environment,
      status: status ?? this.status,
      triggeredBy: triggeredBy ?? this.triggeredBy,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deployment_pk.present) {
      map['deployment_pk'] = Variable<int>(deployment_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (triggeredBy.present) {
      map['triggered_by'] = Variable<String>(triggeredBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeploymentsCompanion(')
          ..write('deployment_pk: $deployment_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('project_fk: $project_fk, ')
          ..write('name: $name, ')
          ..write('environment: $environment, ')
          ..write('status: $status, ')
          ..write('triggeredBy: $triggeredBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }
}

class $ActivityLogsTable extends ActivityLogs
    with TableInfo<$ActivityLogsTable, ActivityLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _activity_pkMeta = const VerificationMeta(
    'activity_pk',
  );
  @override
  late final GeneratedColumn<int> activity_pk = GeneratedColumn<int>(
    'activity_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _actorTypeMeta = const VerificationMeta(
    'actorType',
  );
  @override
  late final GeneratedColumn<String> actorType = GeneratedColumn<String>(
    'actor_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('user'),
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta(
    'targetType',
  );
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    activity_pk,
    client_fk,
    project_fk,
    actorType,
    actorId,
    action,
    targetType,
    targetId,
    summary,
    metadataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('activity_pk')) {
      context.handle(
        _activity_pkMeta,
        activity_pk.isAcceptableOrUnknown(
          data['activity_pk']!,
          _activity_pkMeta,
        ),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    }
    if (data.containsKey('actor_type')) {
      context.handle(
        _actorTypeMeta,
        actorType.isAcceptableOrUnknown(data['actor_type']!, _actorTypeMeta),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {activity_pk};
  @override
  ActivityLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityLog(
      activity_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}activity_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      ),
      actorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_type'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ActivityLogsTable createAlias(String alias) {
    return $ActivityLogsTable(attachedDatabase, alias);
  }
}

class ActivityLog extends DataClass implements Insertable<ActivityLog> {
  final int activity_pk;
  final int client_fk;
  final int? project_fk;
  final String actorType;
  final String? actorId;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? summary;
  final String metadataJson;
  final DateTime createdAt;
  const ActivityLog({
    required this.activity_pk,
    required this.client_fk,
    this.project_fk,
    required this.actorType,
    this.actorId,
    required this.action,
    this.targetType,
    this.targetId,
    this.summary,
    required this.metadataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['activity_pk'] = Variable<int>(activity_pk);
    map['client_fk'] = Variable<int>(client_fk);
    if (!nullToAbsent || project_fk != null) {
      map['project_fk'] = Variable<int>(project_fk);
    }
    map['actor_type'] = Variable<String>(actorType);
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || targetType != null) {
      map['target_type'] = Variable<String>(targetType);
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ActivityLogsCompanion toCompanion(bool nullToAbsent) {
    return ActivityLogsCompanion(
      activity_pk: Value(activity_pk),
      client_fk: Value(client_fk),
      project_fk: project_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(project_fk),
      actorType: Value(actorType),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      action: Value(action),
      targetType: targetType == null && nullToAbsent
          ? const Value.absent()
          : Value(targetType),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      metadataJson: Value(metadataJson),
      createdAt: Value(createdAt),
    );
  }

  factory ActivityLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityLog(
      activity_pk: serializer.fromJson<int>(json['activity_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      project_fk: serializer.fromJson<int?>(json['project_fk']),
      actorType: serializer.fromJson<String>(json['actorType']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      action: serializer.fromJson<String>(json['action']),
      targetType: serializer.fromJson<String?>(json['targetType']),
      targetId: serializer.fromJson<String?>(json['targetId']),
      summary: serializer.fromJson<String?>(json['summary']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'activity_pk': serializer.toJson<int>(activity_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'project_fk': serializer.toJson<int?>(project_fk),
      'actorType': serializer.toJson<String>(actorType),
      'actorId': serializer.toJson<String?>(actorId),
      'action': serializer.toJson<String>(action),
      'targetType': serializer.toJson<String?>(targetType),
      'targetId': serializer.toJson<String?>(targetId),
      'summary': serializer.toJson<String?>(summary),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ActivityLog copyWith({
    int? activity_pk,
    int? client_fk,
    Value<int?> project_fk = const Value.absent(),
    String? actorType,
    Value<String?> actorId = const Value.absent(),
    String? action,
    Value<String?> targetType = const Value.absent(),
    Value<String?> targetId = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    String? metadataJson,
    DateTime? createdAt,
  }) => ActivityLog(
    activity_pk: activity_pk ?? this.activity_pk,
    client_fk: client_fk ?? this.client_fk,
    project_fk: project_fk.present ? project_fk.value : this.project_fk,
    actorType: actorType ?? this.actorType,
    actorId: actorId.present ? actorId.value : this.actorId,
    action: action ?? this.action,
    targetType: targetType.present ? targetType.value : this.targetType,
    targetId: targetId.present ? targetId.value : this.targetId,
    summary: summary.present ? summary.value : this.summary,
    metadataJson: metadataJson ?? this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ActivityLog copyWithCompanion(ActivityLogsCompanion data) {
    return ActivityLog(
      activity_pk: data.activity_pk.present
          ? data.activity_pk.value
          : this.activity_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      actorType: data.actorType.present ? data.actorType.value : this.actorType,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      action: data.action.present ? data.action.value : this.action,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      summary: data.summary.present ? data.summary.value : this.summary,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLog(')
          ..write('activity_pk: $activity_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('project_fk: $project_fk, ')
          ..write('actorType: $actorType, ')
          ..write('actorId: $actorId, ')
          ..write('action: $action, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('summary: $summary, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    activity_pk,
    client_fk,
    project_fk,
    actorType,
    actorId,
    action,
    targetType,
    targetId,
    summary,
    metadataJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityLog &&
          other.activity_pk == this.activity_pk &&
          other.client_fk == this.client_fk &&
          other.project_fk == this.project_fk &&
          other.actorType == this.actorType &&
          other.actorId == this.actorId &&
          other.action == this.action &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.summary == this.summary &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt);
}

class ActivityLogsCompanion extends UpdateCompanion<ActivityLog> {
  final Value<int> activity_pk;
  final Value<int> client_fk;
  final Value<int?> project_fk;
  final Value<String> actorType;
  final Value<String?> actorId;
  final Value<String> action;
  final Value<String?> targetType;
  final Value<String?> targetId;
  final Value<String?> summary;
  final Value<String> metadataJson;
  final Value<DateTime> createdAt;
  const ActivityLogsCompanion({
    this.activity_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.actorType = const Value.absent(),
    this.actorId = const Value.absent(),
    this.action = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.summary = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ActivityLogsCompanion.insert({
    this.activity_pk = const Value.absent(),
    required int client_fk,
    this.project_fk = const Value.absent(),
    this.actorType = const Value.absent(),
    this.actorId = const Value.absent(),
    required String action,
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.summary = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : client_fk = Value(client_fk),
       action = Value(action);
  static Insertable<ActivityLog> custom({
    Expression<int>? activity_pk,
    Expression<int>? client_fk,
    Expression<int>? project_fk,
    Expression<String>? actorType,
    Expression<String>? actorId,
    Expression<String>? action,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? summary,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (activity_pk != null) 'activity_pk': activity_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (project_fk != null) 'project_fk': project_fk,
      if (actorType != null) 'actor_type': actorType,
      if (actorId != null) 'actor_id': actorId,
      if (action != null) 'action': action,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (summary != null) 'summary': summary,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ActivityLogsCompanion copyWith({
    Value<int>? activity_pk,
    Value<int>? client_fk,
    Value<int?>? project_fk,
    Value<String>? actorType,
    Value<String?>? actorId,
    Value<String>? action,
    Value<String?>? targetType,
    Value<String?>? targetId,
    Value<String?>? summary,
    Value<String>? metadataJson,
    Value<DateTime>? createdAt,
  }) {
    return ActivityLogsCompanion(
      activity_pk: activity_pk ?? this.activity_pk,
      client_fk: client_fk ?? this.client_fk,
      project_fk: project_fk ?? this.project_fk,
      actorType: actorType ?? this.actorType,
      actorId: actorId ?? this.actorId,
      action: action ?? this.action,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      summary: summary ?? this.summary,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (activity_pk.present) {
      map['activity_pk'] = Variable<int>(activity_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (actorType.present) {
      map['actor_type'] = Variable<String>(actorType.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogsCompanion(')
          ..write('activity_pk: $activity_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('project_fk: $project_fk, ')
          ..write('actorType: $actorType, ')
          ..write('actorId: $actorId, ')
          ..write('action: $action, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('summary: $summary, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CiRunsTable extends CiRuns with TableInfo<$CiRunsTable, CiRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CiRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ci_run_pkMeta = const VerificationMeta(
    'ci_run_pk',
  );
  @override
  late final GeneratedColumn<int> ci_run_pk = GeneratedColumn<int>(
    'ci_run_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _client_fkMeta = const VerificationMeta(
    'client_fk',
  );
  @override
  late final GeneratedColumn<int> client_fk = GeneratedColumn<int>(
    'client_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clients (client_pk)',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _task_fkMeta = const VerificationMeta(
    'task_fk',
  );
  @override
  late final GeneratedColumn<int> task_fk = GeneratedColumn<int>(
    'task_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (task_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('dockerBuild'),
  );
  static const VerificationMeta _backendMeta = const VerificationMeta(
    'backend',
  );
  @override
  late final GeneratedColumn<String> backend = GeneratedColumn<String>(
    'backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localDocker'),
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commitOidMeta = const VerificationMeta(
    'commitOid',
  );
  @override
  late final GeneratedColumn<String> commitOid = GeneratedColumn<String>(
    'commit_oid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dockerfilePathMeta = const VerificationMeta(
    'dockerfilePath',
  );
  @override
  late final GeneratedColumn<String> dockerfilePath = GeneratedColumn<String>(
    'dockerfile_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workflowPathMeta = const VerificationMeta(
    'workflowPath',
  );
  @override
  late final GeneratedColumn<String> workflowPath = GeneratedColumn<String>(
    'workflow_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggeredByMeta = const VerificationMeta(
    'triggeredBy',
  );
  @override
  late final GeneratedColumn<String> triggeredBy = GeneratedColumn<String>(
    'triggered_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorTextMeta = const VerificationMeta(
    'errorText',
  );
  @override
  late final GeneratedColumn<String> errorText = GeneratedColumn<String>(
    'error_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ci_run_pk,
    client_fk,
    project_fk,
    task_fk,
    name,
    status,
    kind,
    backend,
    branch,
    commitOid,
    dockerfilePath,
    imageTag,
    workflowPath,
    triggeredBy,
    errorText,
    createdAt,
    startedAt,
    completedAt,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ci_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CiRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ci_run_pk')) {
      context.handle(
        _ci_run_pkMeta,
        ci_run_pk.isAcceptableOrUnknown(data['ci_run_pk']!, _ci_run_pkMeta),
      );
    }
    if (data.containsKey('client_fk')) {
      context.handle(
        _client_fkMeta,
        client_fk.isAcceptableOrUnknown(data['client_fk']!, _client_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_client_fkMeta);
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    }
    if (data.containsKey('task_fk')) {
      context.handle(
        _task_fkMeta,
        task_fk.isAcceptableOrUnknown(data['task_fk']!, _task_fkMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('backend')) {
      context.handle(
        _backendMeta,
        backend.isAcceptableOrUnknown(data['backend']!, _backendMeta),
      );
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('commit_oid')) {
      context.handle(
        _commitOidMeta,
        commitOid.isAcceptableOrUnknown(data['commit_oid']!, _commitOidMeta),
      );
    }
    if (data.containsKey('dockerfile_path')) {
      context.handle(
        _dockerfilePathMeta,
        dockerfilePath.isAcceptableOrUnknown(
          data['dockerfile_path']!,
          _dockerfilePathMeta,
        ),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    }
    if (data.containsKey('workflow_path')) {
      context.handle(
        _workflowPathMeta,
        workflowPath.isAcceptableOrUnknown(
          data['workflow_path']!,
          _workflowPathMeta,
        ),
      );
    }
    if (data.containsKey('triggered_by')) {
      context.handle(
        _triggeredByMeta,
        triggeredBy.isAcceptableOrUnknown(
          data['triggered_by']!,
          _triggeredByMeta,
        ),
      );
    }
    if (data.containsKey('error_text')) {
      context.handle(
        _errorTextMeta,
        errorText.isAcceptableOrUnknown(data['error_text']!, _errorTextMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ci_run_pk};
  @override
  CiRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CiRun(
      ci_run_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ci_run_pk'],
      )!,
      client_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_fk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      ),
      task_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_fk'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      backend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend'],
      )!,
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      ),
      commitOid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commit_oid'],
      ),
      dockerfilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dockerfile_path'],
      ),
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      ),
      workflowPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_path'],
      ),
      triggeredBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triggered_by'],
      ),
      errorText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
    );
  }

  @override
  $CiRunsTable createAlias(String alias) {
    return $CiRunsTable(attachedDatabase, alias);
  }
}

class CiRun extends DataClass implements Insertable<CiRun> {
  final int ci_run_pk;
  final int client_fk;
  final int? project_fk;

  /// The task this run gates, if any. When set and the run succeeds the task is
  /// auto-approved (→ Done); when it fails the task returns to the board.
  final int? task_fk;
  final String name;

  /// pending | running | success | failed | cancelled | skipped
  final String status;

  /// dockerBuild | workflow
  final String kind;

  /// localDocker | remote
  final String backend;
  final String? branch;
  final String? commitOid;

  /// Docker build: the Dockerfile workspace path + produced image tag.
  final String? dockerfilePath;
  final String? imageTag;

  /// Workflow run: the workflow YAML workspace path.
  final String? workflowPath;
  final String? triggeredBy;

  /// Set when the run failed to start (e.g. docker not installed).
  final String? errorText;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String metadataJson;
  const CiRun({
    required this.ci_run_pk,
    required this.client_fk,
    this.project_fk,
    this.task_fk,
    required this.name,
    required this.status,
    required this.kind,
    required this.backend,
    this.branch,
    this.commitOid,
    this.dockerfilePath,
    this.imageTag,
    this.workflowPath,
    this.triggeredBy,
    this.errorText,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ci_run_pk'] = Variable<int>(ci_run_pk);
    map['client_fk'] = Variable<int>(client_fk);
    if (!nullToAbsent || project_fk != null) {
      map['project_fk'] = Variable<int>(project_fk);
    }
    if (!nullToAbsent || task_fk != null) {
      map['task_fk'] = Variable<int>(task_fk);
    }
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['kind'] = Variable<String>(kind);
    map['backend'] = Variable<String>(backend);
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || commitOid != null) {
      map['commit_oid'] = Variable<String>(commitOid);
    }
    if (!nullToAbsent || dockerfilePath != null) {
      map['dockerfile_path'] = Variable<String>(dockerfilePath);
    }
    if (!nullToAbsent || imageTag != null) {
      map['image_tag'] = Variable<String>(imageTag);
    }
    if (!nullToAbsent || workflowPath != null) {
      map['workflow_path'] = Variable<String>(workflowPath);
    }
    if (!nullToAbsent || triggeredBy != null) {
      map['triggered_by'] = Variable<String>(triggeredBy);
    }
    if (!nullToAbsent || errorText != null) {
      map['error_text'] = Variable<String>(errorText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['metadata_json'] = Variable<String>(metadataJson);
    return map;
  }

  CiRunsCompanion toCompanion(bool nullToAbsent) {
    return CiRunsCompanion(
      ci_run_pk: Value(ci_run_pk),
      client_fk: Value(client_fk),
      project_fk: project_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(project_fk),
      task_fk: task_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(task_fk),
      name: Value(name),
      status: Value(status),
      kind: Value(kind),
      backend: Value(backend),
      branch: branch == null && nullToAbsent
          ? const Value.absent()
          : Value(branch),
      commitOid: commitOid == null && nullToAbsent
          ? const Value.absent()
          : Value(commitOid),
      dockerfilePath: dockerfilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(dockerfilePath),
      imageTag: imageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTag),
      workflowPath: workflowPath == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowPath),
      triggeredBy: triggeredBy == null && nullToAbsent
          ? const Value.absent()
          : Value(triggeredBy),
      errorText: errorText == null && nullToAbsent
          ? const Value.absent()
          : Value(errorText),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      metadataJson: Value(metadataJson),
    );
  }

  factory CiRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CiRun(
      ci_run_pk: serializer.fromJson<int>(json['ci_run_pk']),
      client_fk: serializer.fromJson<int>(json['client_fk']),
      project_fk: serializer.fromJson<int?>(json['project_fk']),
      task_fk: serializer.fromJson<int?>(json['task_fk']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      kind: serializer.fromJson<String>(json['kind']),
      backend: serializer.fromJson<String>(json['backend']),
      branch: serializer.fromJson<String?>(json['branch']),
      commitOid: serializer.fromJson<String?>(json['commitOid']),
      dockerfilePath: serializer.fromJson<String?>(json['dockerfilePath']),
      imageTag: serializer.fromJson<String?>(json['imageTag']),
      workflowPath: serializer.fromJson<String?>(json['workflowPath']),
      triggeredBy: serializer.fromJson<String?>(json['triggeredBy']),
      errorText: serializer.fromJson<String?>(json['errorText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ci_run_pk': serializer.toJson<int>(ci_run_pk),
      'client_fk': serializer.toJson<int>(client_fk),
      'project_fk': serializer.toJson<int?>(project_fk),
      'task_fk': serializer.toJson<int?>(task_fk),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'kind': serializer.toJson<String>(kind),
      'backend': serializer.toJson<String>(backend),
      'branch': serializer.toJson<String?>(branch),
      'commitOid': serializer.toJson<String?>(commitOid),
      'dockerfilePath': serializer.toJson<String?>(dockerfilePath),
      'imageTag': serializer.toJson<String?>(imageTag),
      'workflowPath': serializer.toJson<String?>(workflowPath),
      'triggeredBy': serializer.toJson<String?>(triggeredBy),
      'errorText': serializer.toJson<String?>(errorText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'metadataJson': serializer.toJson<String>(metadataJson),
    };
  }

  CiRun copyWith({
    int? ci_run_pk,
    int? client_fk,
    Value<int?> project_fk = const Value.absent(),
    Value<int?> task_fk = const Value.absent(),
    String? name,
    String? status,
    String? kind,
    String? backend,
    Value<String?> branch = const Value.absent(),
    Value<String?> commitOid = const Value.absent(),
    Value<String?> dockerfilePath = const Value.absent(),
    Value<String?> imageTag = const Value.absent(),
    Value<String?> workflowPath = const Value.absent(),
    Value<String?> triggeredBy = const Value.absent(),
    Value<String?> errorText = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    String? metadataJson,
  }) => CiRun(
    ci_run_pk: ci_run_pk ?? this.ci_run_pk,
    client_fk: client_fk ?? this.client_fk,
    project_fk: project_fk.present ? project_fk.value : this.project_fk,
    task_fk: task_fk.present ? task_fk.value : this.task_fk,
    name: name ?? this.name,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    backend: backend ?? this.backend,
    branch: branch.present ? branch.value : this.branch,
    commitOid: commitOid.present ? commitOid.value : this.commitOid,
    dockerfilePath: dockerfilePath.present
        ? dockerfilePath.value
        : this.dockerfilePath,
    imageTag: imageTag.present ? imageTag.value : this.imageTag,
    workflowPath: workflowPath.present ? workflowPath.value : this.workflowPath,
    triggeredBy: triggeredBy.present ? triggeredBy.value : this.triggeredBy,
    errorText: errorText.present ? errorText.value : this.errorText,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    metadataJson: metadataJson ?? this.metadataJson,
  );
  CiRun copyWithCompanion(CiRunsCompanion data) {
    return CiRun(
      ci_run_pk: data.ci_run_pk.present ? data.ci_run_pk.value : this.ci_run_pk,
      client_fk: data.client_fk.present ? data.client_fk.value : this.client_fk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      task_fk: data.task_fk.present ? data.task_fk.value : this.task_fk,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      kind: data.kind.present ? data.kind.value : this.kind,
      backend: data.backend.present ? data.backend.value : this.backend,
      branch: data.branch.present ? data.branch.value : this.branch,
      commitOid: data.commitOid.present ? data.commitOid.value : this.commitOid,
      dockerfilePath: data.dockerfilePath.present
          ? data.dockerfilePath.value
          : this.dockerfilePath,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      workflowPath: data.workflowPath.present
          ? data.workflowPath.value
          : this.workflowPath,
      triggeredBy: data.triggeredBy.present
          ? data.triggeredBy.value
          : this.triggeredBy,
      errorText: data.errorText.present ? data.errorText.value : this.errorText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CiRun(')
          ..write('ci_run_pk: $ci_run_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('project_fk: $project_fk, ')
          ..write('task_fk: $task_fk, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('kind: $kind, ')
          ..write('backend: $backend, ')
          ..write('branch: $branch, ')
          ..write('commitOid: $commitOid, ')
          ..write('dockerfilePath: $dockerfilePath, ')
          ..write('imageTag: $imageTag, ')
          ..write('workflowPath: $workflowPath, ')
          ..write('triggeredBy: $triggeredBy, ')
          ..write('errorText: $errorText, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ci_run_pk,
    client_fk,
    project_fk,
    task_fk,
    name,
    status,
    kind,
    backend,
    branch,
    commitOid,
    dockerfilePath,
    imageTag,
    workflowPath,
    triggeredBy,
    errorText,
    createdAt,
    startedAt,
    completedAt,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CiRun &&
          other.ci_run_pk == this.ci_run_pk &&
          other.client_fk == this.client_fk &&
          other.project_fk == this.project_fk &&
          other.task_fk == this.task_fk &&
          other.name == this.name &&
          other.status == this.status &&
          other.kind == this.kind &&
          other.backend == this.backend &&
          other.branch == this.branch &&
          other.commitOid == this.commitOid &&
          other.dockerfilePath == this.dockerfilePath &&
          other.imageTag == this.imageTag &&
          other.workflowPath == this.workflowPath &&
          other.triggeredBy == this.triggeredBy &&
          other.errorText == this.errorText &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.metadataJson == this.metadataJson);
}

class CiRunsCompanion extends UpdateCompanion<CiRun> {
  final Value<int> ci_run_pk;
  final Value<int> client_fk;
  final Value<int?> project_fk;
  final Value<int?> task_fk;
  final Value<String> name;
  final Value<String> status;
  final Value<String> kind;
  final Value<String> backend;
  final Value<String?> branch;
  final Value<String?> commitOid;
  final Value<String?> dockerfilePath;
  final Value<String?> imageTag;
  final Value<String?> workflowPath;
  final Value<String?> triggeredBy;
  final Value<String?> errorText;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<String> metadataJson;
  const CiRunsCompanion({
    this.ci_run_pk = const Value.absent(),
    this.client_fk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.task_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.kind = const Value.absent(),
    this.backend = const Value.absent(),
    this.branch = const Value.absent(),
    this.commitOid = const Value.absent(),
    this.dockerfilePath = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.workflowPath = const Value.absent(),
    this.triggeredBy = const Value.absent(),
    this.errorText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.metadataJson = const Value.absent(),
  });
  CiRunsCompanion.insert({
    this.ci_run_pk = const Value.absent(),
    required int client_fk,
    this.project_fk = const Value.absent(),
    this.task_fk = const Value.absent(),
    required String name,
    this.status = const Value.absent(),
    this.kind = const Value.absent(),
    this.backend = const Value.absent(),
    this.branch = const Value.absent(),
    this.commitOid = const Value.absent(),
    this.dockerfilePath = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.workflowPath = const Value.absent(),
    this.triggeredBy = const Value.absent(),
    this.errorText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.metadataJson = const Value.absent(),
  }) : client_fk = Value(client_fk),
       name = Value(name);
  static Insertable<CiRun> custom({
    Expression<int>? ci_run_pk,
    Expression<int>? client_fk,
    Expression<int>? project_fk,
    Expression<int>? task_fk,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? kind,
    Expression<String>? backend,
    Expression<String>? branch,
    Expression<String>? commitOid,
    Expression<String>? dockerfilePath,
    Expression<String>? imageTag,
    Expression<String>? workflowPath,
    Expression<String>? triggeredBy,
    Expression<String>? errorText,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? metadataJson,
  }) {
    return RawValuesInsertable({
      if (ci_run_pk != null) 'ci_run_pk': ci_run_pk,
      if (client_fk != null) 'client_fk': client_fk,
      if (project_fk != null) 'project_fk': project_fk,
      if (task_fk != null) 'task_fk': task_fk,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (kind != null) 'kind': kind,
      if (backend != null) 'backend': backend,
      if (branch != null) 'branch': branch,
      if (commitOid != null) 'commit_oid': commitOid,
      if (dockerfilePath != null) 'dockerfile_path': dockerfilePath,
      if (imageTag != null) 'image_tag': imageTag,
      if (workflowPath != null) 'workflow_path': workflowPath,
      if (triggeredBy != null) 'triggered_by': triggeredBy,
      if (errorText != null) 'error_text': errorText,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (metadataJson != null) 'metadata_json': metadataJson,
    });
  }

  CiRunsCompanion copyWith({
    Value<int>? ci_run_pk,
    Value<int>? client_fk,
    Value<int?>? project_fk,
    Value<int?>? task_fk,
    Value<String>? name,
    Value<String>? status,
    Value<String>? kind,
    Value<String>? backend,
    Value<String?>? branch,
    Value<String?>? commitOid,
    Value<String?>? dockerfilePath,
    Value<String?>? imageTag,
    Value<String?>? workflowPath,
    Value<String?>? triggeredBy,
    Value<String?>? errorText,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<String>? metadataJson,
  }) {
    return CiRunsCompanion(
      ci_run_pk: ci_run_pk ?? this.ci_run_pk,
      client_fk: client_fk ?? this.client_fk,
      project_fk: project_fk ?? this.project_fk,
      task_fk: task_fk ?? this.task_fk,
      name: name ?? this.name,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      backend: backend ?? this.backend,
      branch: branch ?? this.branch,
      commitOid: commitOid ?? this.commitOid,
      dockerfilePath: dockerfilePath ?? this.dockerfilePath,
      imageTag: imageTag ?? this.imageTag,
      workflowPath: workflowPath ?? this.workflowPath,
      triggeredBy: triggeredBy ?? this.triggeredBy,
      errorText: errorText ?? this.errorText,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ci_run_pk.present) {
      map['ci_run_pk'] = Variable<int>(ci_run_pk.value);
    }
    if (client_fk.present) {
      map['client_fk'] = Variable<int>(client_fk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (task_fk.present) {
      map['task_fk'] = Variable<int>(task_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (backend.present) {
      map['backend'] = Variable<String>(backend.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (commitOid.present) {
      map['commit_oid'] = Variable<String>(commitOid.value);
    }
    if (dockerfilePath.present) {
      map['dockerfile_path'] = Variable<String>(dockerfilePath.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (workflowPath.present) {
      map['workflow_path'] = Variable<String>(workflowPath.value);
    }
    if (triggeredBy.present) {
      map['triggered_by'] = Variable<String>(triggeredBy.value);
    }
    if (errorText.present) {
      map['error_text'] = Variable<String>(errorText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CiRunsCompanion(')
          ..write('ci_run_pk: $ci_run_pk, ')
          ..write('client_fk: $client_fk, ')
          ..write('project_fk: $project_fk, ')
          ..write('task_fk: $task_fk, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('kind: $kind, ')
          ..write('backend: $backend, ')
          ..write('branch: $branch, ')
          ..write('commitOid: $commitOid, ')
          ..write('dockerfilePath: $dockerfilePath, ')
          ..write('imageTag: $imageTag, ')
          ..write('workflowPath: $workflowPath, ')
          ..write('triggeredBy: $triggeredBy, ')
          ..write('errorText: $errorText, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }
}

class $CiJobsTable extends CiJobs with TableInfo<$CiJobsTable, CiJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CiJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ci_job_pkMeta = const VerificationMeta(
    'ci_job_pk',
  );
  @override
  late final GeneratedColumn<int> ci_job_pk = GeneratedColumn<int>(
    'ci_job_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ci_run_fkMeta = const VerificationMeta(
    'ci_run_fk',
  );
  @override
  late final GeneratedColumn<int> ci_run_fk = GeneratedColumn<int>(
    'ci_run_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ci_runs (ci_run_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 150,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _runsOnMeta = const VerificationMeta('runsOn');
  @override
  late final GeneratedColumn<String> runsOn = GeneratedColumn<String>(
    'runs_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ci_job_pk,
    ci_run_fk,
    name,
    status,
    runsOn,
    orderIndex,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ci_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CiJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ci_job_pk')) {
      context.handle(
        _ci_job_pkMeta,
        ci_job_pk.isAcceptableOrUnknown(data['ci_job_pk']!, _ci_job_pkMeta),
      );
    }
    if (data.containsKey('ci_run_fk')) {
      context.handle(
        _ci_run_fkMeta,
        ci_run_fk.isAcceptableOrUnknown(data['ci_run_fk']!, _ci_run_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_ci_run_fkMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('runs_on')) {
      context.handle(
        _runsOnMeta,
        runsOn.isAcceptableOrUnknown(data['runs_on']!, _runsOnMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ci_job_pk};
  @override
  CiJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CiJob(
      ci_job_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ci_job_pk'],
      )!,
      ci_run_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ci_run_fk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      runsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runs_on'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $CiJobsTable createAlias(String alias) {
    return $CiJobsTable(attachedDatabase, alias);
  }
}

class CiJob extends DataClass implements Insertable<CiJob> {
  final int ci_job_pk;
  final int ci_run_fk;
  final String name;

  /// pending | running | success | failed | cancelled | skipped
  final String status;

  /// The workflow's `runs-on` value (e.g. `ubuntu-latest`) → the container image
  /// the local runner uses. Null for a plain Docker build job.
  final String? runsOn;
  final int orderIndex;
  final DateTime? startedAt;
  final DateTime? completedAt;
  const CiJob({
    required this.ci_job_pk,
    required this.ci_run_fk,
    required this.name,
    required this.status,
    this.runsOn,
    required this.orderIndex,
    this.startedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ci_job_pk'] = Variable<int>(ci_job_pk);
    map['ci_run_fk'] = Variable<int>(ci_run_fk);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || runsOn != null) {
      map['runs_on'] = Variable<String>(runsOn);
    }
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  CiJobsCompanion toCompanion(bool nullToAbsent) {
    return CiJobsCompanion(
      ci_job_pk: Value(ci_job_pk),
      ci_run_fk: Value(ci_run_fk),
      name: Value(name),
      status: Value(status),
      runsOn: runsOn == null && nullToAbsent
          ? const Value.absent()
          : Value(runsOn),
      orderIndex: Value(orderIndex),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory CiJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CiJob(
      ci_job_pk: serializer.fromJson<int>(json['ci_job_pk']),
      ci_run_fk: serializer.fromJson<int>(json['ci_run_fk']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      runsOn: serializer.fromJson<String?>(json['runsOn']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ci_job_pk': serializer.toJson<int>(ci_job_pk),
      'ci_run_fk': serializer.toJson<int>(ci_run_fk),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'runsOn': serializer.toJson<String?>(runsOn),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  CiJob copyWith({
    int? ci_job_pk,
    int? ci_run_fk,
    String? name,
    String? status,
    Value<String?> runsOn = const Value.absent(),
    int? orderIndex,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => CiJob(
    ci_job_pk: ci_job_pk ?? this.ci_job_pk,
    ci_run_fk: ci_run_fk ?? this.ci_run_fk,
    name: name ?? this.name,
    status: status ?? this.status,
    runsOn: runsOn.present ? runsOn.value : this.runsOn,
    orderIndex: orderIndex ?? this.orderIndex,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  CiJob copyWithCompanion(CiJobsCompanion data) {
    return CiJob(
      ci_job_pk: data.ci_job_pk.present ? data.ci_job_pk.value : this.ci_job_pk,
      ci_run_fk: data.ci_run_fk.present ? data.ci_run_fk.value : this.ci_run_fk,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      runsOn: data.runsOn.present ? data.runsOn.value : this.runsOn,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CiJob(')
          ..write('ci_job_pk: $ci_job_pk, ')
          ..write('ci_run_fk: $ci_run_fk, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('runsOn: $runsOn, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ci_job_pk,
    ci_run_fk,
    name,
    status,
    runsOn,
    orderIndex,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CiJob &&
          other.ci_job_pk == this.ci_job_pk &&
          other.ci_run_fk == this.ci_run_fk &&
          other.name == this.name &&
          other.status == this.status &&
          other.runsOn == this.runsOn &&
          other.orderIndex == this.orderIndex &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class CiJobsCompanion extends UpdateCompanion<CiJob> {
  final Value<int> ci_job_pk;
  final Value<int> ci_run_fk;
  final Value<String> name;
  final Value<String> status;
  final Value<String?> runsOn;
  final Value<int> orderIndex;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  const CiJobsCompanion({
    this.ci_job_pk = const Value.absent(),
    this.ci_run_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.runsOn = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  CiJobsCompanion.insert({
    this.ci_job_pk = const Value.absent(),
    required int ci_run_fk,
    required String name,
    this.status = const Value.absent(),
    this.runsOn = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : ci_run_fk = Value(ci_run_fk),
       name = Value(name);
  static Insertable<CiJob> custom({
    Expression<int>? ci_job_pk,
    Expression<int>? ci_run_fk,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? runsOn,
    Expression<int>? orderIndex,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (ci_job_pk != null) 'ci_job_pk': ci_job_pk,
      if (ci_run_fk != null) 'ci_run_fk': ci_run_fk,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (runsOn != null) 'runs_on': runsOn,
      if (orderIndex != null) 'order_index': orderIndex,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  CiJobsCompanion copyWith({
    Value<int>? ci_job_pk,
    Value<int>? ci_run_fk,
    Value<String>? name,
    Value<String>? status,
    Value<String?>? runsOn,
    Value<int>? orderIndex,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
  }) {
    return CiJobsCompanion(
      ci_job_pk: ci_job_pk ?? this.ci_job_pk,
      ci_run_fk: ci_run_fk ?? this.ci_run_fk,
      name: name ?? this.name,
      status: status ?? this.status,
      runsOn: runsOn ?? this.runsOn,
      orderIndex: orderIndex ?? this.orderIndex,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ci_job_pk.present) {
      map['ci_job_pk'] = Variable<int>(ci_job_pk.value);
    }
    if (ci_run_fk.present) {
      map['ci_run_fk'] = Variable<int>(ci_run_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (runsOn.present) {
      map['runs_on'] = Variable<String>(runsOn.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CiJobsCompanion(')
          ..write('ci_job_pk: $ci_job_pk, ')
          ..write('ci_run_fk: $ci_run_fk, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('runsOn: $runsOn, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $CiStepsTable extends CiSteps with TableInfo<$CiStepsTable, CiStep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CiStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ci_step_pkMeta = const VerificationMeta(
    'ci_step_pk',
  );
  @override
  late final GeneratedColumn<int> ci_step_pk = GeneratedColumn<int>(
    'ci_step_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ci_job_fkMeta = const VerificationMeta(
    'ci_job_fk',
  );
  @override
  late final GeneratedColumn<int> ci_job_fk = GeneratedColumn<int>(
    'ci_job_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ci_jobs (ci_job_pk)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 250,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exitCodeMeta = const VerificationMeta(
    'exitCode',
  );
  @override
  late final GeneratedColumn<int> exitCode = GeneratedColumn<int>(
    'exit_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logTextMeta = const VerificationMeta(
    'logText',
  );
  @override
  late final GeneratedColumn<String> logText = GeneratedColumn<String>(
    'log_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ci_step_pk,
    ci_job_fk,
    name,
    status,
    orderIndex,
    command,
    exitCode,
    logText,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ci_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<CiStep> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ci_step_pk')) {
      context.handle(
        _ci_step_pkMeta,
        ci_step_pk.isAcceptableOrUnknown(data['ci_step_pk']!, _ci_step_pkMeta),
      );
    }
    if (data.containsKey('ci_job_fk')) {
      context.handle(
        _ci_job_fkMeta,
        ci_job_fk.isAcceptableOrUnknown(data['ci_job_fk']!, _ci_job_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_ci_job_fkMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    }
    if (data.containsKey('exit_code')) {
      context.handle(
        _exitCodeMeta,
        exitCode.isAcceptableOrUnknown(data['exit_code']!, _exitCodeMeta),
      );
    }
    if (data.containsKey('log_text')) {
      context.handle(
        _logTextMeta,
        logText.isAcceptableOrUnknown(data['log_text']!, _logTextMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ci_step_pk};
  @override
  CiStep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CiStep(
      ci_step_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ci_step_pk'],
      )!,
      ci_job_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ci_job_fk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      ),
      exitCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exit_code'],
      ),
      logText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}log_text'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $CiStepsTable createAlias(String alias) {
    return $CiStepsTable(attachedDatabase, alias);
  }
}

class CiStep extends DataClass implements Insertable<CiStep> {
  final int ci_step_pk;
  final int ci_job_fk;
  final String name;

  /// pending | running | success | failed | cancelled | skipped
  final String status;
  final int orderIndex;

  /// The shell script (`run:`) or action reference (`uses:`) this step executes.
  final String? command;
  final int? exitCode;

  /// Captured stdout+stderr, appended line-by-line as the step runs.
  final String logText;
  final DateTime? startedAt;
  final DateTime? completedAt;
  const CiStep({
    required this.ci_step_pk,
    required this.ci_job_fk,
    required this.name,
    required this.status,
    required this.orderIndex,
    this.command,
    this.exitCode,
    required this.logText,
    this.startedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ci_step_pk'] = Variable<int>(ci_step_pk);
    map['ci_job_fk'] = Variable<int>(ci_job_fk);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || command != null) {
      map['command'] = Variable<String>(command);
    }
    if (!nullToAbsent || exitCode != null) {
      map['exit_code'] = Variable<int>(exitCode);
    }
    map['log_text'] = Variable<String>(logText);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  CiStepsCompanion toCompanion(bool nullToAbsent) {
    return CiStepsCompanion(
      ci_step_pk: Value(ci_step_pk),
      ci_job_fk: Value(ci_job_fk),
      name: Value(name),
      status: Value(status),
      orderIndex: Value(orderIndex),
      command: command == null && nullToAbsent
          ? const Value.absent()
          : Value(command),
      exitCode: exitCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exitCode),
      logText: Value(logText),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory CiStep.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CiStep(
      ci_step_pk: serializer.fromJson<int>(json['ci_step_pk']),
      ci_job_fk: serializer.fromJson<int>(json['ci_job_fk']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      command: serializer.fromJson<String?>(json['command']),
      exitCode: serializer.fromJson<int?>(json['exitCode']),
      logText: serializer.fromJson<String>(json['logText']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ci_step_pk': serializer.toJson<int>(ci_step_pk),
      'ci_job_fk': serializer.toJson<int>(ci_job_fk),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'command': serializer.toJson<String?>(command),
      'exitCode': serializer.toJson<int?>(exitCode),
      'logText': serializer.toJson<String>(logText),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  CiStep copyWith({
    int? ci_step_pk,
    int? ci_job_fk,
    String? name,
    String? status,
    int? orderIndex,
    Value<String?> command = const Value.absent(),
    Value<int?> exitCode = const Value.absent(),
    String? logText,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => CiStep(
    ci_step_pk: ci_step_pk ?? this.ci_step_pk,
    ci_job_fk: ci_job_fk ?? this.ci_job_fk,
    name: name ?? this.name,
    status: status ?? this.status,
    orderIndex: orderIndex ?? this.orderIndex,
    command: command.present ? command.value : this.command,
    exitCode: exitCode.present ? exitCode.value : this.exitCode,
    logText: logText ?? this.logText,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  CiStep copyWithCompanion(CiStepsCompanion data) {
    return CiStep(
      ci_step_pk: data.ci_step_pk.present
          ? data.ci_step_pk.value
          : this.ci_step_pk,
      ci_job_fk: data.ci_job_fk.present ? data.ci_job_fk.value : this.ci_job_fk,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      command: data.command.present ? data.command.value : this.command,
      exitCode: data.exitCode.present ? data.exitCode.value : this.exitCode,
      logText: data.logText.present ? data.logText.value : this.logText,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CiStep(')
          ..write('ci_step_pk: $ci_step_pk, ')
          ..write('ci_job_fk: $ci_job_fk, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('command: $command, ')
          ..write('exitCode: $exitCode, ')
          ..write('logText: $logText, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ci_step_pk,
    ci_job_fk,
    name,
    status,
    orderIndex,
    command,
    exitCode,
    logText,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CiStep &&
          other.ci_step_pk == this.ci_step_pk &&
          other.ci_job_fk == this.ci_job_fk &&
          other.name == this.name &&
          other.status == this.status &&
          other.orderIndex == this.orderIndex &&
          other.command == this.command &&
          other.exitCode == this.exitCode &&
          other.logText == this.logText &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class CiStepsCompanion extends UpdateCompanion<CiStep> {
  final Value<int> ci_step_pk;
  final Value<int> ci_job_fk;
  final Value<String> name;
  final Value<String> status;
  final Value<int> orderIndex;
  final Value<String?> command;
  final Value<int?> exitCode;
  final Value<String> logText;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  const CiStepsCompanion({
    this.ci_step_pk = const Value.absent(),
    this.ci_job_fk = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.command = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.logText = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  CiStepsCompanion.insert({
    this.ci_step_pk = const Value.absent(),
    required int ci_job_fk,
    required String name,
    this.status = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.command = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.logText = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : ci_job_fk = Value(ci_job_fk),
       name = Value(name);
  static Insertable<CiStep> custom({
    Expression<int>? ci_step_pk,
    Expression<int>? ci_job_fk,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? orderIndex,
    Expression<String>? command,
    Expression<int>? exitCode,
    Expression<String>? logText,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (ci_step_pk != null) 'ci_step_pk': ci_step_pk,
      if (ci_job_fk != null) 'ci_job_fk': ci_job_fk,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (orderIndex != null) 'order_index': orderIndex,
      if (command != null) 'command': command,
      if (exitCode != null) 'exit_code': exitCode,
      if (logText != null) 'log_text': logText,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  CiStepsCompanion copyWith({
    Value<int>? ci_step_pk,
    Value<int>? ci_job_fk,
    Value<String>? name,
    Value<String>? status,
    Value<int>? orderIndex,
    Value<String?>? command,
    Value<int?>? exitCode,
    Value<String>? logText,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
  }) {
    return CiStepsCompanion(
      ci_step_pk: ci_step_pk ?? this.ci_step_pk,
      ci_job_fk: ci_job_fk ?? this.ci_job_fk,
      name: name ?? this.name,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
      command: command ?? this.command,
      exitCode: exitCode ?? this.exitCode,
      logText: logText ?? this.logText,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ci_step_pk.present) {
      map['ci_step_pk'] = Variable<int>(ci_step_pk.value);
    }
    if (ci_job_fk.present) {
      map['ci_job_fk'] = Variable<int>(ci_job_fk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (exitCode.present) {
      map['exit_code'] = Variable<int>(exitCode.value);
    }
    if (logText.present) {
      map['log_text'] = Variable<String>(logText.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CiStepsCompanion(')
          ..write('ci_step_pk: $ci_step_pk, ')
          ..write('ci_job_fk: $ci_job_fk, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('command: $command, ')
          ..write('exitCode: $exitCode, ')
          ..write('logText: $logText, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _message_pkMeta = const VerificationMeta(
    'message_pk',
  );
  @override
  late final GeneratedColumn<int> message_pk = GeneratedColumn<int>(
    'message_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _session_fkMeta = const VerificationMeta(
    'session_fk',
  );
  @override
  late final GeneratedColumn<int> session_fk = GeneratedColumn<int>(
    'session_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (session_pk)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    message_pk,
    session_fk,
    role,
    content,
    audioPath,
    seq,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_pk')) {
      context.handle(
        _message_pkMeta,
        message_pk.isAcceptableOrUnknown(data['message_pk']!, _message_pkMeta),
      );
    }
    if (data.containsKey('session_fk')) {
      context.handle(
        _session_fkMeta,
        session_fk.isAcceptableOrUnknown(data['session_fk']!, _session_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_session_fkMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {message_pk};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      message_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_pk'],
      )!,
      session_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_fk'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final int message_pk;
  final int session_fk;

  /// 'user' | 'assistant' | 'system'
  final String role;
  final String content;

  /// Retained path to synthesized TTS audio for assistant voice replies.
  final String? audioPath;

  /// Monotonic ordering key within the session (millisecondsSinceEpoch at insert).
  final int seq;
  final DateTime createdAt;
  const ChatMessage({
    required this.message_pk,
    required this.session_fk,
    required this.role,
    required this.content,
    this.audioPath,
    required this.seq,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_pk'] = Variable<int>(message_pk);
    map['session_fk'] = Variable<int>(session_fk);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    map['seq'] = Variable<int>(seq);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      message_pk: Value(message_pk),
      session_fk: Value(session_fk),
      role: Value(role),
      content: Value(content),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      seq: Value(seq),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      message_pk: serializer.fromJson<int>(json['message_pk']),
      session_fk: serializer.fromJson<int>(json['session_fk']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      seq: serializer.fromJson<int>(json['seq']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'message_pk': serializer.toJson<int>(message_pk),
      'session_fk': serializer.toJson<int>(session_fk),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'audioPath': serializer.toJson<String?>(audioPath),
      'seq': serializer.toJson<int>(seq),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    int? message_pk,
    int? session_fk,
    String? role,
    String? content,
    Value<String?> audioPath = const Value.absent(),
    int? seq,
    DateTime? createdAt,
  }) => ChatMessage(
    message_pk: message_pk ?? this.message_pk,
    session_fk: session_fk ?? this.session_fk,
    role: role ?? this.role,
    content: content ?? this.content,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    seq: seq ?? this.seq,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      message_pk: data.message_pk.present
          ? data.message_pk.value
          : this.message_pk,
      session_fk: data.session_fk.present
          ? data.session_fk.value
          : this.session_fk,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      seq: data.seq.present ? data.seq.value : this.seq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('message_pk: $message_pk, ')
          ..write('session_fk: $session_fk, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('audioPath: $audioPath, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    message_pk,
    session_fk,
    role,
    content,
    audioPath,
    seq,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.message_pk == this.message_pk &&
          other.session_fk == this.session_fk &&
          other.role == this.role &&
          other.content == this.content &&
          other.audioPath == this.audioPath &&
          other.seq == this.seq &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<int> message_pk;
  final Value<int> session_fk;
  final Value<String> role;
  final Value<String> content;
  final Value<String?> audioPath;
  final Value<int> seq;
  final Value<DateTime> createdAt;
  const ChatMessagesCompanion({
    this.message_pk = const Value.absent(),
    this.session_fk = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    this.message_pk = const Value.absent(),
    required int session_fk,
    required String role,
    this.content = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : session_fk = Value(session_fk),
       role = Value(role);
  static Insertable<ChatMessage> custom({
    Expression<int>? message_pk,
    Expression<int>? session_fk,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? audioPath,
    Expression<int>? seq,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (message_pk != null) 'message_pk': message_pk,
      if (session_fk != null) 'session_fk': session_fk,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (audioPath != null) 'audio_path': audioPath,
      if (seq != null) 'seq': seq,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<int>? message_pk,
    Value<int>? session_fk,
    Value<String>? role,
    Value<String>? content,
    Value<String?>? audioPath,
    Value<int>? seq,
    Value<DateTime>? createdAt,
  }) {
    return ChatMessagesCompanion(
      message_pk: message_pk ?? this.message_pk,
      session_fk: session_fk ?? this.session_fk,
      role: role ?? this.role,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (message_pk.present) {
      map['message_pk'] = Variable<int>(message_pk.value);
    }
    if (session_fk.present) {
      map['session_fk'] = Variable<int>(session_fk.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('message_pk: $message_pk, ')
          ..write('session_fk: $session_fk, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('audioPath: $audioPath, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ProjectTagsTable extends ProjectTags
    with TableInfo<$ProjectTagsTable, ProjectTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tag_pkMeta = const VerificationMeta('tag_pk');
  @override
  late final GeneratedColumn<int> tag_pk = GeneratedColumn<int>(
    'tag_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ai'),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('setup'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('proposed'),
  );
  static const VerificationMeta _layerKeyMeta = const VerificationMeta(
    'layerKey',
  );
  @override
  late final GeneratedColumn<String> layerKey = GeneratedColumn<String>(
    'layer_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forLanguageMeta = const VerificationMeta(
    'forLanguage',
  );
  @override
  late final GeneratedColumn<String> forLanguage = GeneratedColumn<String>(
    'for_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rationaleMeta = const VerificationMeta(
    'rationale',
  );
  @override
  late final GeneratedColumn<String> rationale = GeneratedColumn<String>(
    'rationale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verdictMeta = const VerificationMeta(
    'verdict',
  );
  @override
  late final GeneratedColumn<String> verdict = GeneratedColumn<String>(
    'verdict',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verifiedAtMeta = const VerificationMeta(
    'verifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
    'verified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag_pk,
    project_fk,
    category,
    value,
    source,
    origin,
    status,
    layerKey,
    forLanguage,
    rationale,
    sourceUrl,
    verdict,
    verifiedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag_pk')) {
      context.handle(
        _tag_pkMeta,
        tag_pk.isAcceptableOrUnknown(data['tag_pk']!, _tag_pkMeta),
      );
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_project_fkMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('layer_key')) {
      context.handle(
        _layerKeyMeta,
        layerKey.isAcceptableOrUnknown(data['layer_key']!, _layerKeyMeta),
      );
    }
    if (data.containsKey('for_language')) {
      context.handle(
        _forLanguageMeta,
        forLanguage.isAcceptableOrUnknown(
          data['for_language']!,
          _forLanguageMeta,
        ),
      );
    }
    if (data.containsKey('rationale')) {
      context.handle(
        _rationaleMeta,
        rationale.isAcceptableOrUnknown(data['rationale']!, _rationaleMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('verdict')) {
      context.handle(
        _verdictMeta,
        verdict.isAcceptableOrUnknown(data['verdict']!, _verdictMeta),
      );
    }
    if (data.containsKey('verified_at')) {
      context.handle(
        _verifiedAtMeta,
        verifiedAt.isAcceptableOrUnknown(data['verified_at']!, _verifiedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag_pk};
  @override
  ProjectTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectTag(
      tag_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_pk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      layerKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_key'],
      ),
      forLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}for_language'],
      ),
      rationale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rationale'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      verdict: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verdict'],
      ),
      verifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProjectTagsTable createAlias(String alias) {
    return $ProjectTagsTable(attachedDatabase, alias);
  }
}

class ProjectTag extends DataClass implements Insertable<ProjectTag> {
  final int tag_pk;
  final int project_fk;

  /// One of: industries | platforms | objectives | languages | frameworks | libraries.
  final String category;
  final String value;

  /// Who introduced the tag: user | ai | workspace (observed from real files).
  final String source;

  /// Where it came from: setup | plan | agent | workspace.
  final String origin;

  /// Confirm state: proposed | accepted | rejected.
  final String status;

  /// Which architecture layer this tag belongs to: client | server | db |
  /// worker | module. Null = project-wide (industries, cross-cutting objectives).
  final String? layerKey;

  /// For library tags: the language this library is used with (e.g. a Dart
  /// package vs. a C# NuGet). Must be one of the closed Languages vocab.
  /// Null for non-library tags (or libraries not yet attached to a language).
  final String? forLanguage;

  /// Short explanation of why the AI proposed this tag.
  final String? rationale;

  /// For library/framework tags: the canonical source (GitHub repo / pub.dev).
  final String? sourceUrl;

  /// Freshness verdict snapshot for library/framework tags: fresh|aging|stale|dead.
  final String? verdict;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  const ProjectTag({
    required this.tag_pk,
    required this.project_fk,
    required this.category,
    required this.value,
    required this.source,
    required this.origin,
    required this.status,
    this.layerKey,
    this.forLanguage,
    this.rationale,
    this.sourceUrl,
    this.verdict,
    this.verifiedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag_pk'] = Variable<int>(tag_pk);
    map['project_fk'] = Variable<int>(project_fk);
    map['category'] = Variable<String>(category);
    map['value'] = Variable<String>(value);
    map['source'] = Variable<String>(source);
    map['origin'] = Variable<String>(origin);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || layerKey != null) {
      map['layer_key'] = Variable<String>(layerKey);
    }
    if (!nullToAbsent || forLanguage != null) {
      map['for_language'] = Variable<String>(forLanguage);
    }
    if (!nullToAbsent || rationale != null) {
      map['rationale'] = Variable<String>(rationale);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || verdict != null) {
      map['verdict'] = Variable<String>(verdict);
    }
    if (!nullToAbsent || verifiedAt != null) {
      map['verified_at'] = Variable<DateTime>(verifiedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProjectTagsCompanion toCompanion(bool nullToAbsent) {
    return ProjectTagsCompanion(
      tag_pk: Value(tag_pk),
      project_fk: Value(project_fk),
      category: Value(category),
      value: Value(value),
      source: Value(source),
      origin: Value(origin),
      status: Value(status),
      layerKey: layerKey == null && nullToAbsent
          ? const Value.absent()
          : Value(layerKey),
      forLanguage: forLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(forLanguage),
      rationale: rationale == null && nullToAbsent
          ? const Value.absent()
          : Value(rationale),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      verdict: verdict == null && nullToAbsent
          ? const Value.absent()
          : Value(verdict),
      verifiedAt: verifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ProjectTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectTag(
      tag_pk: serializer.fromJson<int>(json['tag_pk']),
      project_fk: serializer.fromJson<int>(json['project_fk']),
      category: serializer.fromJson<String>(json['category']),
      value: serializer.fromJson<String>(json['value']),
      source: serializer.fromJson<String>(json['source']),
      origin: serializer.fromJson<String>(json['origin']),
      status: serializer.fromJson<String>(json['status']),
      layerKey: serializer.fromJson<String?>(json['layerKey']),
      forLanguage: serializer.fromJson<String?>(json['forLanguage']),
      rationale: serializer.fromJson<String?>(json['rationale']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      verdict: serializer.fromJson<String?>(json['verdict']),
      verifiedAt: serializer.fromJson<DateTime?>(json['verifiedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag_pk': serializer.toJson<int>(tag_pk),
      'project_fk': serializer.toJson<int>(project_fk),
      'category': serializer.toJson<String>(category),
      'value': serializer.toJson<String>(value),
      'source': serializer.toJson<String>(source),
      'origin': serializer.toJson<String>(origin),
      'status': serializer.toJson<String>(status),
      'layerKey': serializer.toJson<String?>(layerKey),
      'forLanguage': serializer.toJson<String?>(forLanguage),
      'rationale': serializer.toJson<String?>(rationale),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'verdict': serializer.toJson<String?>(verdict),
      'verifiedAt': serializer.toJson<DateTime?>(verifiedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProjectTag copyWith({
    int? tag_pk,
    int? project_fk,
    String? category,
    String? value,
    String? source,
    String? origin,
    String? status,
    Value<String?> layerKey = const Value.absent(),
    Value<String?> forLanguage = const Value.absent(),
    Value<String?> rationale = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> verdict = const Value.absent(),
    Value<DateTime?> verifiedAt = const Value.absent(),
    DateTime? createdAt,
  }) => ProjectTag(
    tag_pk: tag_pk ?? this.tag_pk,
    project_fk: project_fk ?? this.project_fk,
    category: category ?? this.category,
    value: value ?? this.value,
    source: source ?? this.source,
    origin: origin ?? this.origin,
    status: status ?? this.status,
    layerKey: layerKey.present ? layerKey.value : this.layerKey,
    forLanguage: forLanguage.present ? forLanguage.value : this.forLanguage,
    rationale: rationale.present ? rationale.value : this.rationale,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    verdict: verdict.present ? verdict.value : this.verdict,
    verifiedAt: verifiedAt.present ? verifiedAt.value : this.verifiedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ProjectTag copyWithCompanion(ProjectTagsCompanion data) {
    return ProjectTag(
      tag_pk: data.tag_pk.present ? data.tag_pk.value : this.tag_pk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      category: data.category.present ? data.category.value : this.category,
      value: data.value.present ? data.value.value : this.value,
      source: data.source.present ? data.source.value : this.source,
      origin: data.origin.present ? data.origin.value : this.origin,
      status: data.status.present ? data.status.value : this.status,
      layerKey: data.layerKey.present ? data.layerKey.value : this.layerKey,
      forLanguage: data.forLanguage.present
          ? data.forLanguage.value
          : this.forLanguage,
      rationale: data.rationale.present ? data.rationale.value : this.rationale,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      verdict: data.verdict.present ? data.verdict.value : this.verdict,
      verifiedAt: data.verifiedAt.present
          ? data.verifiedAt.value
          : this.verifiedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectTag(')
          ..write('tag_pk: $tag_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('category: $category, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('origin: $origin, ')
          ..write('status: $status, ')
          ..write('layerKey: $layerKey, ')
          ..write('forLanguage: $forLanguage, ')
          ..write('rationale: $rationale, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('verdict: $verdict, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tag_pk,
    project_fk,
    category,
    value,
    source,
    origin,
    status,
    layerKey,
    forLanguage,
    rationale,
    sourceUrl,
    verdict,
    verifiedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectTag &&
          other.tag_pk == this.tag_pk &&
          other.project_fk == this.project_fk &&
          other.category == this.category &&
          other.value == this.value &&
          other.source == this.source &&
          other.origin == this.origin &&
          other.status == this.status &&
          other.layerKey == this.layerKey &&
          other.forLanguage == this.forLanguage &&
          other.rationale == this.rationale &&
          other.sourceUrl == this.sourceUrl &&
          other.verdict == this.verdict &&
          other.verifiedAt == this.verifiedAt &&
          other.createdAt == this.createdAt);
}

class ProjectTagsCompanion extends UpdateCompanion<ProjectTag> {
  final Value<int> tag_pk;
  final Value<int> project_fk;
  final Value<String> category;
  final Value<String> value;
  final Value<String> source;
  final Value<String> origin;
  final Value<String> status;
  final Value<String?> layerKey;
  final Value<String?> forLanguage;
  final Value<String?> rationale;
  final Value<String?> sourceUrl;
  final Value<String?> verdict;
  final Value<DateTime?> verifiedAt;
  final Value<DateTime> createdAt;
  const ProjectTagsCompanion({
    this.tag_pk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.category = const Value.absent(),
    this.value = const Value.absent(),
    this.source = const Value.absent(),
    this.origin = const Value.absent(),
    this.status = const Value.absent(),
    this.layerKey = const Value.absent(),
    this.forLanguage = const Value.absent(),
    this.rationale = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.verdict = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ProjectTagsCompanion.insert({
    this.tag_pk = const Value.absent(),
    required int project_fk,
    required String category,
    required String value,
    this.source = const Value.absent(),
    this.origin = const Value.absent(),
    this.status = const Value.absent(),
    this.layerKey = const Value.absent(),
    this.forLanguage = const Value.absent(),
    this.rationale = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.verdict = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : project_fk = Value(project_fk),
       category = Value(category),
       value = Value(value);
  static Insertable<ProjectTag> custom({
    Expression<int>? tag_pk,
    Expression<int>? project_fk,
    Expression<String>? category,
    Expression<String>? value,
    Expression<String>? source,
    Expression<String>? origin,
    Expression<String>? status,
    Expression<String>? layerKey,
    Expression<String>? forLanguage,
    Expression<String>? rationale,
    Expression<String>? sourceUrl,
    Expression<String>? verdict,
    Expression<DateTime>? verifiedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (tag_pk != null) 'tag_pk': tag_pk,
      if (project_fk != null) 'project_fk': project_fk,
      if (category != null) 'category': category,
      if (value != null) 'value': value,
      if (source != null) 'source': source,
      if (origin != null) 'origin': origin,
      if (status != null) 'status': status,
      if (layerKey != null) 'layer_key': layerKey,
      if (forLanguage != null) 'for_language': forLanguage,
      if (rationale != null) 'rationale': rationale,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (verdict != null) 'verdict': verdict,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ProjectTagsCompanion copyWith({
    Value<int>? tag_pk,
    Value<int>? project_fk,
    Value<String>? category,
    Value<String>? value,
    Value<String>? source,
    Value<String>? origin,
    Value<String>? status,
    Value<String?>? layerKey,
    Value<String?>? forLanguage,
    Value<String?>? rationale,
    Value<String?>? sourceUrl,
    Value<String?>? verdict,
    Value<DateTime?>? verifiedAt,
    Value<DateTime>? createdAt,
  }) {
    return ProjectTagsCompanion(
      tag_pk: tag_pk ?? this.tag_pk,
      project_fk: project_fk ?? this.project_fk,
      category: category ?? this.category,
      value: value ?? this.value,
      source: source ?? this.source,
      origin: origin ?? this.origin,
      status: status ?? this.status,
      layerKey: layerKey ?? this.layerKey,
      forLanguage: forLanguage ?? this.forLanguage,
      rationale: rationale ?? this.rationale,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      verdict: verdict ?? this.verdict,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag_pk.present) {
      map['tag_pk'] = Variable<int>(tag_pk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (layerKey.present) {
      map['layer_key'] = Variable<String>(layerKey.value);
    }
    if (forLanguage.present) {
      map['for_language'] = Variable<String>(forLanguage.value);
    }
    if (rationale.present) {
      map['rationale'] = Variable<String>(rationale.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (verdict.present) {
      map['verdict'] = Variable<String>(verdict.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectTagsCompanion(')
          ..write('tag_pk: $tag_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('category: $category, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('origin: $origin, ')
          ..write('status: $status, ')
          ..write('layerKey: $layerKey, ')
          ..write('forLanguage: $forLanguage, ')
          ..write('rationale: $rationale, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('verdict: $verdict, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LibraryVerificationsTable extends LibraryVerifications
    with TableInfo<$LibraryVerificationsTable, LibraryVerification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryVerificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _verification_pkMeta = const VerificationMeta(
    'verification_pk',
  );
  @override
  late final GeneratedColumn<int> verification_pk = GeneratedColumn<int>(
    'verification_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ecosystemMeta = const VerificationMeta(
    'ecosystem',
  );
  @override
  late final GeneratedColumn<String> ecosystem = GeneratedColumn<String>(
    'ecosystem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoUrlMeta = const VerificationMeta(
    'repoUrl',
  );
  @override
  late final GeneratedColumn<String> repoUrl = GeneratedColumn<String>(
    'repo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCommitMeta = const VerificationMeta(
    'lastCommit',
  );
  @override
  late final GeneratedColumn<DateTime> lastCommit = GeneratedColumn<DateTime>(
    'last_commit',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReleaseMeta = const VerificationMeta(
    'lastRelease',
  );
  @override
  late final GeneratedColumn<DateTime> lastRelease = GeneratedColumn<DateTime>(
    'last_release',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _popularityMeta = const VerificationMeta(
    'popularity',
  );
  @override
  late final GeneratedColumn<int> popularity = GeneratedColumn<int>(
    'popularity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verdictMeta = const VerificationMeta(
    'verdict',
  );
  @override
  late final GeneratedColumn<String> verdict = GeneratedColumn<String>(
    'verdict',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    verification_pk,
    ecosystem,
    name,
    repoUrl,
    lastCommit,
    lastRelease,
    archived,
    popularity,
    owner,
    verdict,
    checkedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_verifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryVerification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('verification_pk')) {
      context.handle(
        _verification_pkMeta,
        verification_pk.isAcceptableOrUnknown(
          data['verification_pk']!,
          _verification_pkMeta,
        ),
      );
    }
    if (data.containsKey('ecosystem')) {
      context.handle(
        _ecosystemMeta,
        ecosystem.isAcceptableOrUnknown(data['ecosystem']!, _ecosystemMeta),
      );
    } else if (isInserting) {
      context.missing(_ecosystemMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('repo_url')) {
      context.handle(
        _repoUrlMeta,
        repoUrl.isAcceptableOrUnknown(data['repo_url']!, _repoUrlMeta),
      );
    }
    if (data.containsKey('last_commit')) {
      context.handle(
        _lastCommitMeta,
        lastCommit.isAcceptableOrUnknown(data['last_commit']!, _lastCommitMeta),
      );
    }
    if (data.containsKey('last_release')) {
      context.handle(
        _lastReleaseMeta,
        lastRelease.isAcceptableOrUnknown(
          data['last_release']!,
          _lastReleaseMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('popularity')) {
      context.handle(
        _popularityMeta,
        popularity.isAcceptableOrUnknown(data['popularity']!, _popularityMeta),
      );
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    }
    if (data.containsKey('verdict')) {
      context.handle(
        _verdictMeta,
        verdict.isAcceptableOrUnknown(data['verdict']!, _verdictMeta),
      );
    } else if (isInserting) {
      context.missing(_verdictMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {verification_pk};
  @override
  LibraryVerification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryVerification(
      verification_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verification_pk'],
      )!,
      ecosystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ecosystem'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      repoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_url'],
      ),
      lastCommit: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_commit'],
      ),
      lastRelease: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_release'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      popularity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}popularity'],
      ),
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      ),
      verdict: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verdict'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $LibraryVerificationsTable createAlias(String alias) {
    return $LibraryVerificationsTable(attachedDatabase, alias);
  }
}

class LibraryVerification extends DataClass
    implements Insertable<LibraryVerification> {
  final int verification_pk;

  /// pubdev | github | crates | nuget | maven | npm.
  final String ecosystem;
  final String name;
  final String? repoUrl;
  final DateTime? lastCommit;
  final DateTime? lastRelease;
  final bool archived;

  /// Stars (GitHub) or likes (pub.dev).
  final int? popularity;

  /// GitHub owner/org, for trust-by-org (e.g. flutter, google, facebook/meta).
  final String? owner;

  /// fresh | aging | stale | dead.
  final String verdict;
  final DateTime checkedAt;
  const LibraryVerification({
    required this.verification_pk,
    required this.ecosystem,
    required this.name,
    this.repoUrl,
    this.lastCommit,
    this.lastRelease,
    required this.archived,
    this.popularity,
    this.owner,
    required this.verdict,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['verification_pk'] = Variable<int>(verification_pk);
    map['ecosystem'] = Variable<String>(ecosystem);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || repoUrl != null) {
      map['repo_url'] = Variable<String>(repoUrl);
    }
    if (!nullToAbsent || lastCommit != null) {
      map['last_commit'] = Variable<DateTime>(lastCommit);
    }
    if (!nullToAbsent || lastRelease != null) {
      map['last_release'] = Variable<DateTime>(lastRelease);
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || popularity != null) {
      map['popularity'] = Variable<int>(popularity);
    }
    if (!nullToAbsent || owner != null) {
      map['owner'] = Variable<String>(owner);
    }
    map['verdict'] = Variable<String>(verdict);
    map['checked_at'] = Variable<DateTime>(checkedAt);
    return map;
  }

  LibraryVerificationsCompanion toCompanion(bool nullToAbsent) {
    return LibraryVerificationsCompanion(
      verification_pk: Value(verification_pk),
      ecosystem: Value(ecosystem),
      name: Value(name),
      repoUrl: repoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(repoUrl),
      lastCommit: lastCommit == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCommit),
      lastRelease: lastRelease == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRelease),
      archived: Value(archived),
      popularity: popularity == null && nullToAbsent
          ? const Value.absent()
          : Value(popularity),
      owner: owner == null && nullToAbsent
          ? const Value.absent()
          : Value(owner),
      verdict: Value(verdict),
      checkedAt: Value(checkedAt),
    );
  }

  factory LibraryVerification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryVerification(
      verification_pk: serializer.fromJson<int>(json['verification_pk']),
      ecosystem: serializer.fromJson<String>(json['ecosystem']),
      name: serializer.fromJson<String>(json['name']),
      repoUrl: serializer.fromJson<String?>(json['repoUrl']),
      lastCommit: serializer.fromJson<DateTime?>(json['lastCommit']),
      lastRelease: serializer.fromJson<DateTime?>(json['lastRelease']),
      archived: serializer.fromJson<bool>(json['archived']),
      popularity: serializer.fromJson<int?>(json['popularity']),
      owner: serializer.fromJson<String?>(json['owner']),
      verdict: serializer.fromJson<String>(json['verdict']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'verification_pk': serializer.toJson<int>(verification_pk),
      'ecosystem': serializer.toJson<String>(ecosystem),
      'name': serializer.toJson<String>(name),
      'repoUrl': serializer.toJson<String?>(repoUrl),
      'lastCommit': serializer.toJson<DateTime?>(lastCommit),
      'lastRelease': serializer.toJson<DateTime?>(lastRelease),
      'archived': serializer.toJson<bool>(archived),
      'popularity': serializer.toJson<int?>(popularity),
      'owner': serializer.toJson<String?>(owner),
      'verdict': serializer.toJson<String>(verdict),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
    };
  }

  LibraryVerification copyWith({
    int? verification_pk,
    String? ecosystem,
    String? name,
    Value<String?> repoUrl = const Value.absent(),
    Value<DateTime?> lastCommit = const Value.absent(),
    Value<DateTime?> lastRelease = const Value.absent(),
    bool? archived,
    Value<int?> popularity = const Value.absent(),
    Value<String?> owner = const Value.absent(),
    String? verdict,
    DateTime? checkedAt,
  }) => LibraryVerification(
    verification_pk: verification_pk ?? this.verification_pk,
    ecosystem: ecosystem ?? this.ecosystem,
    name: name ?? this.name,
    repoUrl: repoUrl.present ? repoUrl.value : this.repoUrl,
    lastCommit: lastCommit.present ? lastCommit.value : this.lastCommit,
    lastRelease: lastRelease.present ? lastRelease.value : this.lastRelease,
    archived: archived ?? this.archived,
    popularity: popularity.present ? popularity.value : this.popularity,
    owner: owner.present ? owner.value : this.owner,
    verdict: verdict ?? this.verdict,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  LibraryVerification copyWithCompanion(LibraryVerificationsCompanion data) {
    return LibraryVerification(
      verification_pk: data.verification_pk.present
          ? data.verification_pk.value
          : this.verification_pk,
      ecosystem: data.ecosystem.present ? data.ecosystem.value : this.ecosystem,
      name: data.name.present ? data.name.value : this.name,
      repoUrl: data.repoUrl.present ? data.repoUrl.value : this.repoUrl,
      lastCommit: data.lastCommit.present
          ? data.lastCommit.value
          : this.lastCommit,
      lastRelease: data.lastRelease.present
          ? data.lastRelease.value
          : this.lastRelease,
      archived: data.archived.present ? data.archived.value : this.archived,
      popularity: data.popularity.present
          ? data.popularity.value
          : this.popularity,
      owner: data.owner.present ? data.owner.value : this.owner,
      verdict: data.verdict.present ? data.verdict.value : this.verdict,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryVerification(')
          ..write('verification_pk: $verification_pk, ')
          ..write('ecosystem: $ecosystem, ')
          ..write('name: $name, ')
          ..write('repoUrl: $repoUrl, ')
          ..write('lastCommit: $lastCommit, ')
          ..write('lastRelease: $lastRelease, ')
          ..write('archived: $archived, ')
          ..write('popularity: $popularity, ')
          ..write('owner: $owner, ')
          ..write('verdict: $verdict, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    verification_pk,
    ecosystem,
    name,
    repoUrl,
    lastCommit,
    lastRelease,
    archived,
    popularity,
    owner,
    verdict,
    checkedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryVerification &&
          other.verification_pk == this.verification_pk &&
          other.ecosystem == this.ecosystem &&
          other.name == this.name &&
          other.repoUrl == this.repoUrl &&
          other.lastCommit == this.lastCommit &&
          other.lastRelease == this.lastRelease &&
          other.archived == this.archived &&
          other.popularity == this.popularity &&
          other.owner == this.owner &&
          other.verdict == this.verdict &&
          other.checkedAt == this.checkedAt);
}

class LibraryVerificationsCompanion
    extends UpdateCompanion<LibraryVerification> {
  final Value<int> verification_pk;
  final Value<String> ecosystem;
  final Value<String> name;
  final Value<String?> repoUrl;
  final Value<DateTime?> lastCommit;
  final Value<DateTime?> lastRelease;
  final Value<bool> archived;
  final Value<int?> popularity;
  final Value<String?> owner;
  final Value<String> verdict;
  final Value<DateTime> checkedAt;
  const LibraryVerificationsCompanion({
    this.verification_pk = const Value.absent(),
    this.ecosystem = const Value.absent(),
    this.name = const Value.absent(),
    this.repoUrl = const Value.absent(),
    this.lastCommit = const Value.absent(),
    this.lastRelease = const Value.absent(),
    this.archived = const Value.absent(),
    this.popularity = const Value.absent(),
    this.owner = const Value.absent(),
    this.verdict = const Value.absent(),
    this.checkedAt = const Value.absent(),
  });
  LibraryVerificationsCompanion.insert({
    this.verification_pk = const Value.absent(),
    required String ecosystem,
    required String name,
    this.repoUrl = const Value.absent(),
    this.lastCommit = const Value.absent(),
    this.lastRelease = const Value.absent(),
    this.archived = const Value.absent(),
    this.popularity = const Value.absent(),
    this.owner = const Value.absent(),
    required String verdict,
    this.checkedAt = const Value.absent(),
  }) : ecosystem = Value(ecosystem),
       name = Value(name),
       verdict = Value(verdict);
  static Insertable<LibraryVerification> custom({
    Expression<int>? verification_pk,
    Expression<String>? ecosystem,
    Expression<String>? name,
    Expression<String>? repoUrl,
    Expression<DateTime>? lastCommit,
    Expression<DateTime>? lastRelease,
    Expression<bool>? archived,
    Expression<int>? popularity,
    Expression<String>? owner,
    Expression<String>? verdict,
    Expression<DateTime>? checkedAt,
  }) {
    return RawValuesInsertable({
      if (verification_pk != null) 'verification_pk': verification_pk,
      if (ecosystem != null) 'ecosystem': ecosystem,
      if (name != null) 'name': name,
      if (repoUrl != null) 'repo_url': repoUrl,
      if (lastCommit != null) 'last_commit': lastCommit,
      if (lastRelease != null) 'last_release': lastRelease,
      if (archived != null) 'archived': archived,
      if (popularity != null) 'popularity': popularity,
      if (owner != null) 'owner': owner,
      if (verdict != null) 'verdict': verdict,
      if (checkedAt != null) 'checked_at': checkedAt,
    });
  }

  LibraryVerificationsCompanion copyWith({
    Value<int>? verification_pk,
    Value<String>? ecosystem,
    Value<String>? name,
    Value<String?>? repoUrl,
    Value<DateTime?>? lastCommit,
    Value<DateTime?>? lastRelease,
    Value<bool>? archived,
    Value<int?>? popularity,
    Value<String?>? owner,
    Value<String>? verdict,
    Value<DateTime>? checkedAt,
  }) {
    return LibraryVerificationsCompanion(
      verification_pk: verification_pk ?? this.verification_pk,
      ecosystem: ecosystem ?? this.ecosystem,
      name: name ?? this.name,
      repoUrl: repoUrl ?? this.repoUrl,
      lastCommit: lastCommit ?? this.lastCommit,
      lastRelease: lastRelease ?? this.lastRelease,
      archived: archived ?? this.archived,
      popularity: popularity ?? this.popularity,
      owner: owner ?? this.owner,
      verdict: verdict ?? this.verdict,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (verification_pk.present) {
      map['verification_pk'] = Variable<int>(verification_pk.value);
    }
    if (ecosystem.present) {
      map['ecosystem'] = Variable<String>(ecosystem.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (repoUrl.present) {
      map['repo_url'] = Variable<String>(repoUrl.value);
    }
    if (lastCommit.present) {
      map['last_commit'] = Variable<DateTime>(lastCommit.value);
    }
    if (lastRelease.present) {
      map['last_release'] = Variable<DateTime>(lastRelease.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (popularity.present) {
      map['popularity'] = Variable<int>(popularity.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (verdict.present) {
      map['verdict'] = Variable<String>(verdict.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryVerificationsCompanion(')
          ..write('verification_pk: $verification_pk, ')
          ..write('ecosystem: $ecosystem, ')
          ..write('name: $name, ')
          ..write('repoUrl: $repoUrl, ')
          ..write('lastCommit: $lastCommit, ')
          ..write('lastRelease: $lastRelease, ')
          ..write('archived: $archived, ')
          ..write('popularity: $popularity, ')
          ..write('owner: $owner, ')
          ..write('verdict: $verdict, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }
}

class $CallSystemsTable extends CallSystems
    with TableInfo<$CallSystemsTable, CallSystem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CallSystemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _call_system_pkMeta = const VerificationMeta(
    'call_system_pk',
  );
  @override
  late final GeneratedColumn<int> call_system_pk = GeneratedColumn<int>(
    'call_system_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _project_fkMeta = const VerificationMeta(
    'project_fk',
  );
  @override
  late final GeneratedColumn<int> project_fk = GeneratedColumn<int>(
    'project_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (project_pk)',
    ),
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    call_system_pk,
    project_fk,
    json,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'call_systems';
  @override
  VerificationContext validateIntegrity(
    Insertable<CallSystem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('call_system_pk')) {
      context.handle(
        _call_system_pkMeta,
        call_system_pk.isAcceptableOrUnknown(
          data['call_system_pk']!,
          _call_system_pkMeta,
        ),
      );
    }
    if (data.containsKey('project_fk')) {
      context.handle(
        _project_fkMeta,
        project_fk.isAcceptableOrUnknown(data['project_fk']!, _project_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_project_fkMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {call_system_pk};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {project_fk},
  ];
  @override
  CallSystem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CallSystem(
      call_system_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}call_system_pk'],
      )!,
      project_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_fk'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CallSystemsTable createAlias(String alias) {
    return $CallSystemsTable(attachedDatabase, alias);
  }
}

class CallSystem extends DataClass implements Insertable<CallSystem> {
  final int call_system_pk;
  final int project_fk;

  /// Serialized CallSystemProject.toJson().
  final String json;
  final DateTime updatedAt;
  const CallSystem({
    required this.call_system_pk,
    required this.project_fk,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['call_system_pk'] = Variable<int>(call_system_pk);
    map['project_fk'] = Variable<int>(project_fk);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CallSystemsCompanion toCompanion(bool nullToAbsent) {
    return CallSystemsCompanion(
      call_system_pk: Value(call_system_pk),
      project_fk: Value(project_fk),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory CallSystem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CallSystem(
      call_system_pk: serializer.fromJson<int>(json['call_system_pk']),
      project_fk: serializer.fromJson<int>(json['project_fk']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'call_system_pk': serializer.toJson<int>(call_system_pk),
      'project_fk': serializer.toJson<int>(project_fk),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CallSystem copyWith({
    int? call_system_pk,
    int? project_fk,
    String? json,
    DateTime? updatedAt,
  }) => CallSystem(
    call_system_pk: call_system_pk ?? this.call_system_pk,
    project_fk: project_fk ?? this.project_fk,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CallSystem copyWithCompanion(CallSystemsCompanion data) {
    return CallSystem(
      call_system_pk: data.call_system_pk.present
          ? data.call_system_pk.value
          : this.call_system_pk,
      project_fk: data.project_fk.present
          ? data.project_fk.value
          : this.project_fk,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CallSystem(')
          ..write('call_system_pk: $call_system_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(call_system_pk, project_fk, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CallSystem &&
          other.call_system_pk == this.call_system_pk &&
          other.project_fk == this.project_fk &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class CallSystemsCompanion extends UpdateCompanion<CallSystem> {
  final Value<int> call_system_pk;
  final Value<int> project_fk;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  const CallSystemsCompanion({
    this.call_system_pk = const Value.absent(),
    this.project_fk = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CallSystemsCompanion.insert({
    this.call_system_pk = const Value.absent(),
    required int project_fk,
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : project_fk = Value(project_fk);
  static Insertable<CallSystem> custom({
    Expression<int>? call_system_pk,
    Expression<int>? project_fk,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (call_system_pk != null) 'call_system_pk': call_system_pk,
      if (project_fk != null) 'project_fk': project_fk,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CallSystemsCompanion copyWith({
    Value<int>? call_system_pk,
    Value<int>? project_fk,
    Value<String>? json,
    Value<DateTime>? updatedAt,
  }) {
    return CallSystemsCompanion(
      call_system_pk: call_system_pk ?? this.call_system_pk,
      project_fk: project_fk ?? this.project_fk,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (call_system_pk.present) {
      map['call_system_pk'] = Variable<int>(call_system_pk.value);
    }
    if (project_fk.present) {
      map['project_fk'] = Variable<int>(project_fk.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CallSystemsCompanion(')
          ..write('call_system_pk: $call_system_pk, ')
          ..write('project_fk: $project_fk, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SetupFlowsTable extends SetupFlows
    with TableInfo<$SetupFlowsTable, SetupFlow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetupFlowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setup_flow_pkMeta = const VerificationMeta(
    'setup_flow_pk',
  );
  @override
  late final GeneratedColumn<int> setup_flow_pk = GeneratedColumn<int>(
    'setup_flow_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectTypeMeta = const VerificationMeta(
    'projectType',
  );
  @override
  late final GeneratedColumn<String> projectType = GeneratedColumn<String>(
    'project_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subCategoryMeta = const VerificationMeta(
    'subCategory',
  );
  @override
  late final GeneratedColumn<String> subCategory = GeneratedColumn<String>(
    'sub_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    setup_flow_pk,
    projectType,
    subCategory,
    json,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setup_flows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetupFlow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setup_flow_pk')) {
      context.handle(
        _setup_flow_pkMeta,
        setup_flow_pk.isAcceptableOrUnknown(
          data['setup_flow_pk']!,
          _setup_flow_pkMeta,
        ),
      );
    }
    if (data.containsKey('project_type')) {
      context.handle(
        _projectTypeMeta,
        projectType.isAcceptableOrUnknown(
          data['project_type']!,
          _projectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectTypeMeta);
    }
    if (data.containsKey('sub_category')) {
      context.handle(
        _subCategoryMeta,
        subCategory.isAcceptableOrUnknown(
          data['sub_category']!,
          _subCategoryMeta,
        ),
      );
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setup_flow_pk};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {projectType, subCategory},
  ];
  @override
  SetupFlow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetupFlow(
      setup_flow_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}setup_flow_pk'],
      )!,
      projectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_type'],
      )!,
      subCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_category'],
      ),
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SetupFlowsTable createAlias(String alias) {
    return $SetupFlowsTable(attachedDatabase, alias);
  }
}

class SetupFlow extends DataClass implements Insertable<SetupFlow> {
  final int setup_flow_pk;
  final String projectType;
  final String? subCategory;

  /// Serialized SetupFlowDefinition.toJson().
  final String json;
  final DateTime updatedAt;
  const SetupFlow({
    required this.setup_flow_pk,
    required this.projectType,
    this.subCategory,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setup_flow_pk'] = Variable<int>(setup_flow_pk);
    map['project_type'] = Variable<String>(projectType);
    if (!nullToAbsent || subCategory != null) {
      map['sub_category'] = Variable<String>(subCategory);
    }
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SetupFlowsCompanion toCompanion(bool nullToAbsent) {
    return SetupFlowsCompanion(
      setup_flow_pk: Value(setup_flow_pk),
      projectType: Value(projectType),
      subCategory: subCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(subCategory),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory SetupFlow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetupFlow(
      setup_flow_pk: serializer.fromJson<int>(json['setup_flow_pk']),
      projectType: serializer.fromJson<String>(json['projectType']),
      subCategory: serializer.fromJson<String?>(json['subCategory']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setup_flow_pk': serializer.toJson<int>(setup_flow_pk),
      'projectType': serializer.toJson<String>(projectType),
      'subCategory': serializer.toJson<String?>(subCategory),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SetupFlow copyWith({
    int? setup_flow_pk,
    String? projectType,
    Value<String?> subCategory = const Value.absent(),
    String? json,
    DateTime? updatedAt,
  }) => SetupFlow(
    setup_flow_pk: setup_flow_pk ?? this.setup_flow_pk,
    projectType: projectType ?? this.projectType,
    subCategory: subCategory.present ? subCategory.value : this.subCategory,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SetupFlow copyWithCompanion(SetupFlowsCompanion data) {
    return SetupFlow(
      setup_flow_pk: data.setup_flow_pk.present
          ? data.setup_flow_pk.value
          : this.setup_flow_pk,
      projectType: data.projectType.present
          ? data.projectType.value
          : this.projectType,
      subCategory: data.subCategory.present
          ? data.subCategory.value
          : this.subCategory,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetupFlow(')
          ..write('setup_flow_pk: $setup_flow_pk, ')
          ..write('projectType: $projectType, ')
          ..write('subCategory: $subCategory, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(setup_flow_pk, projectType, subCategory, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetupFlow &&
          other.setup_flow_pk == this.setup_flow_pk &&
          other.projectType == this.projectType &&
          other.subCategory == this.subCategory &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class SetupFlowsCompanion extends UpdateCompanion<SetupFlow> {
  final Value<int> setup_flow_pk;
  final Value<String> projectType;
  final Value<String?> subCategory;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  const SetupFlowsCompanion({
    this.setup_flow_pk = const Value.absent(),
    this.projectType = const Value.absent(),
    this.subCategory = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SetupFlowsCompanion.insert({
    this.setup_flow_pk = const Value.absent(),
    required String projectType,
    this.subCategory = const Value.absent(),
    required String json,
    this.updatedAt = const Value.absent(),
  }) : projectType = Value(projectType),
       json = Value(json);
  static Insertable<SetupFlow> custom({
    Expression<int>? setup_flow_pk,
    Expression<String>? projectType,
    Expression<String>? subCategory,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (setup_flow_pk != null) 'setup_flow_pk': setup_flow_pk,
      if (projectType != null) 'project_type': projectType,
      if (subCategory != null) 'sub_category': subCategory,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SetupFlowsCompanion copyWith({
    Value<int>? setup_flow_pk,
    Value<String>? projectType,
    Value<String?>? subCategory,
    Value<String>? json,
    Value<DateTime>? updatedAt,
  }) {
    return SetupFlowsCompanion(
      setup_flow_pk: setup_flow_pk ?? this.setup_flow_pk,
      projectType: projectType ?? this.projectType,
      subCategory: subCategory ?? this.subCategory,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setup_flow_pk.present) {
      map['setup_flow_pk'] = Variable<int>(setup_flow_pk.value);
    }
    if (projectType.present) {
      map['project_type'] = Variable<String>(projectType.value);
    }
    if (subCategory.present) {
      map['sub_category'] = Variable<String>(subCategory.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetupFlowsCompanion(')
          ..write('setup_flow_pk: $setup_flow_pk, ')
          ..write('projectType: $projectType, ')
          ..write('subCategory: $subCategory, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SetupScopesTable extends SetupScopes
    with TableInfo<$SetupScopesTable, SetupScope> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetupScopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setup_scope_pkMeta = const VerificationMeta(
    'setup_scope_pk',
  );
  @override
  late final GeneratedColumn<int> setup_scope_pk = GeneratedColumn<int>(
    'setup_scope_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _axisMeta = const VerificationMeta('axis');
  @override
  late final GeneratedColumn<String> axis = GeneratedColumn<String>(
    'axis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parent_scope_fkMeta = const VerificationMeta(
    'parent_scope_fk',
  );
  @override
  late final GeneratedColumn<int> parent_scope_fk = GeneratedColumn<int>(
    'parent_scope_fk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES setup_scopes (setup_scope_pk)',
    ),
  );
  static const VerificationMeta _subAxisNameMeta = const VerificationMeta(
    'subAxisName',
  );
  @override
  late final GeneratedColumn<String> subAxisName = GeneratedColumn<String>(
    'sub_axis_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subAxisKeyMeta = const VerificationMeta(
    'subAxisKey',
  );
  @override
  late final GeneratedColumn<String> subAxisKey = GeneratedColumn<String>(
    'sub_axis_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    setup_scope_pk,
    axis,
    value,
    parent_scope_fk,
    subAxisName,
    subAxisKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setup_scopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetupScope> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setup_scope_pk')) {
      context.handle(
        _setup_scope_pkMeta,
        setup_scope_pk.isAcceptableOrUnknown(
          data['setup_scope_pk']!,
          _setup_scope_pkMeta,
        ),
      );
    }
    if (data.containsKey('axis')) {
      context.handle(
        _axisMeta,
        axis.isAcceptableOrUnknown(data['axis']!, _axisMeta),
      );
    } else if (isInserting) {
      context.missing(_axisMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('parent_scope_fk')) {
      context.handle(
        _parent_scope_fkMeta,
        parent_scope_fk.isAcceptableOrUnknown(
          data['parent_scope_fk']!,
          _parent_scope_fkMeta,
        ),
      );
    }
    if (data.containsKey('sub_axis_name')) {
      context.handle(
        _subAxisNameMeta,
        subAxisName.isAcceptableOrUnknown(
          data['sub_axis_name']!,
          _subAxisNameMeta,
        ),
      );
    }
    if (data.containsKey('sub_axis_key')) {
      context.handle(
        _subAxisKeyMeta,
        subAxisKey.isAcceptableOrUnknown(
          data['sub_axis_key']!,
          _subAxisKeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setup_scope_pk};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {axis, value, parent_scope_fk},
  ];
  @override
  SetupScope map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetupScope(
      setup_scope_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}setup_scope_pk'],
      )!,
      axis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}axis'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      parent_scope_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_scope_fk'],
      ),
      subAxisName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_axis_name'],
      ),
      subAxisKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_axis_key'],
      ),
    );
  }

  @override
  $SetupScopesTable createAlias(String alias) {
    return $SetupScopesTable(attachedDatabase, alias);
  }
}

class SetupScope extends DataClass implements Insertable<SetupScope> {
  final int setup_scope_pk;

  /// The dimension this scope value lives on: `industry`, or a sub-axis key
  /// such as `genre`, `segment`, `business-model`, …
  final String axis;

  /// The scope value, e.g. "Gaming", "RPG".
  final String value;

  /// Parent scope (e.g. genre "RPG"'s parent is industry "Gaming"). Null for
  /// top-level (industry) scopes.
  final int? parent_scope_fk;

  /// If this scope introduces a further sub-axis, its display name (e.g.
  /// "Genre"); null when the scope has no sub-axis.
  final String? subAxisName;

  /// The lowercase slug/category key for the introduced sub-axis (e.g. "genre").
  final String? subAxisKey;
  const SetupScope({
    required this.setup_scope_pk,
    required this.axis,
    required this.value,
    this.parent_scope_fk,
    this.subAxisName,
    this.subAxisKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setup_scope_pk'] = Variable<int>(setup_scope_pk);
    map['axis'] = Variable<String>(axis);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || parent_scope_fk != null) {
      map['parent_scope_fk'] = Variable<int>(parent_scope_fk);
    }
    if (!nullToAbsent || subAxisName != null) {
      map['sub_axis_name'] = Variable<String>(subAxisName);
    }
    if (!nullToAbsent || subAxisKey != null) {
      map['sub_axis_key'] = Variable<String>(subAxisKey);
    }
    return map;
  }

  SetupScopesCompanion toCompanion(bool nullToAbsent) {
    return SetupScopesCompanion(
      setup_scope_pk: Value(setup_scope_pk),
      axis: Value(axis),
      value: Value(value),
      parent_scope_fk: parent_scope_fk == null && nullToAbsent
          ? const Value.absent()
          : Value(parent_scope_fk),
      subAxisName: subAxisName == null && nullToAbsent
          ? const Value.absent()
          : Value(subAxisName),
      subAxisKey: subAxisKey == null && nullToAbsent
          ? const Value.absent()
          : Value(subAxisKey),
    );
  }

  factory SetupScope.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetupScope(
      setup_scope_pk: serializer.fromJson<int>(json['setup_scope_pk']),
      axis: serializer.fromJson<String>(json['axis']),
      value: serializer.fromJson<String>(json['value']),
      parent_scope_fk: serializer.fromJson<int?>(json['parent_scope_fk']),
      subAxisName: serializer.fromJson<String?>(json['subAxisName']),
      subAxisKey: serializer.fromJson<String?>(json['subAxisKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setup_scope_pk': serializer.toJson<int>(setup_scope_pk),
      'axis': serializer.toJson<String>(axis),
      'value': serializer.toJson<String>(value),
      'parent_scope_fk': serializer.toJson<int?>(parent_scope_fk),
      'subAxisName': serializer.toJson<String?>(subAxisName),
      'subAxisKey': serializer.toJson<String?>(subAxisKey),
    };
  }

  SetupScope copyWith({
    int? setup_scope_pk,
    String? axis,
    String? value,
    Value<int?> parent_scope_fk = const Value.absent(),
    Value<String?> subAxisName = const Value.absent(),
    Value<String?> subAxisKey = const Value.absent(),
  }) => SetupScope(
    setup_scope_pk: setup_scope_pk ?? this.setup_scope_pk,
    axis: axis ?? this.axis,
    value: value ?? this.value,
    parent_scope_fk: parent_scope_fk.present
        ? parent_scope_fk.value
        : this.parent_scope_fk,
    subAxisName: subAxisName.present ? subAxisName.value : this.subAxisName,
    subAxisKey: subAxisKey.present ? subAxisKey.value : this.subAxisKey,
  );
  SetupScope copyWithCompanion(SetupScopesCompanion data) {
    return SetupScope(
      setup_scope_pk: data.setup_scope_pk.present
          ? data.setup_scope_pk.value
          : this.setup_scope_pk,
      axis: data.axis.present ? data.axis.value : this.axis,
      value: data.value.present ? data.value.value : this.value,
      parent_scope_fk: data.parent_scope_fk.present
          ? data.parent_scope_fk.value
          : this.parent_scope_fk,
      subAxisName: data.subAxisName.present
          ? data.subAxisName.value
          : this.subAxisName,
      subAxisKey: data.subAxisKey.present
          ? data.subAxisKey.value
          : this.subAxisKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetupScope(')
          ..write('setup_scope_pk: $setup_scope_pk, ')
          ..write('axis: $axis, ')
          ..write('value: $value, ')
          ..write('parent_scope_fk: $parent_scope_fk, ')
          ..write('subAxisName: $subAxisName, ')
          ..write('subAxisKey: $subAxisKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    setup_scope_pk,
    axis,
    value,
    parent_scope_fk,
    subAxisName,
    subAxisKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetupScope &&
          other.setup_scope_pk == this.setup_scope_pk &&
          other.axis == this.axis &&
          other.value == this.value &&
          other.parent_scope_fk == this.parent_scope_fk &&
          other.subAxisName == this.subAxisName &&
          other.subAxisKey == this.subAxisKey);
}

class SetupScopesCompanion extends UpdateCompanion<SetupScope> {
  final Value<int> setup_scope_pk;
  final Value<String> axis;
  final Value<String> value;
  final Value<int?> parent_scope_fk;
  final Value<String?> subAxisName;
  final Value<String?> subAxisKey;
  const SetupScopesCompanion({
    this.setup_scope_pk = const Value.absent(),
    this.axis = const Value.absent(),
    this.value = const Value.absent(),
    this.parent_scope_fk = const Value.absent(),
    this.subAxisName = const Value.absent(),
    this.subAxisKey = const Value.absent(),
  });
  SetupScopesCompanion.insert({
    this.setup_scope_pk = const Value.absent(),
    required String axis,
    required String value,
    this.parent_scope_fk = const Value.absent(),
    this.subAxisName = const Value.absent(),
    this.subAxisKey = const Value.absent(),
  }) : axis = Value(axis),
       value = Value(value);
  static Insertable<SetupScope> custom({
    Expression<int>? setup_scope_pk,
    Expression<String>? axis,
    Expression<String>? value,
    Expression<int>? parent_scope_fk,
    Expression<String>? subAxisName,
    Expression<String>? subAxisKey,
  }) {
    return RawValuesInsertable({
      if (setup_scope_pk != null) 'setup_scope_pk': setup_scope_pk,
      if (axis != null) 'axis': axis,
      if (value != null) 'value': value,
      if (parent_scope_fk != null) 'parent_scope_fk': parent_scope_fk,
      if (subAxisName != null) 'sub_axis_name': subAxisName,
      if (subAxisKey != null) 'sub_axis_key': subAxisKey,
    });
  }

  SetupScopesCompanion copyWith({
    Value<int>? setup_scope_pk,
    Value<String>? axis,
    Value<String>? value,
    Value<int?>? parent_scope_fk,
    Value<String?>? subAxisName,
    Value<String?>? subAxisKey,
  }) {
    return SetupScopesCompanion(
      setup_scope_pk: setup_scope_pk ?? this.setup_scope_pk,
      axis: axis ?? this.axis,
      value: value ?? this.value,
      parent_scope_fk: parent_scope_fk ?? this.parent_scope_fk,
      subAxisName: subAxisName ?? this.subAxisName,
      subAxisKey: subAxisKey ?? this.subAxisKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setup_scope_pk.present) {
      map['setup_scope_pk'] = Variable<int>(setup_scope_pk.value);
    }
    if (axis.present) {
      map['axis'] = Variable<String>(axis.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (parent_scope_fk.present) {
      map['parent_scope_fk'] = Variable<int>(parent_scope_fk.value);
    }
    if (subAxisName.present) {
      map['sub_axis_name'] = Variable<String>(subAxisName.value);
    }
    if (subAxisKey.present) {
      map['sub_axis_key'] = Variable<String>(subAxisKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetupScopesCompanion(')
          ..write('setup_scope_pk: $setup_scope_pk, ')
          ..write('axis: $axis, ')
          ..write('value: $value, ')
          ..write('parent_scope_fk: $parent_scope_fk, ')
          ..write('subAxisName: $subAxisName, ')
          ..write('subAxisKey: $subAxisKey')
          ..write(')'))
        .toString();
  }
}

class $SetupScopeOptionsTable extends SetupScopeOptions
    with TableInfo<$SetupScopeOptionsTable, SetupScopeOption> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetupScopeOptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _setup_scope_option_pkMeta =
      const VerificationMeta('setup_scope_option_pk');
  @override
  late final GeneratedColumn<int> setup_scope_option_pk = GeneratedColumn<int>(
    'setup_scope_option_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _setup_scope_fkMeta = const VerificationMeta(
    'setup_scope_fk',
  );
  @override
  late final GeneratedColumn<int> setup_scope_fk = GeneratedColumn<int>(
    'setup_scope_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES setup_scopes (setup_scope_pk)',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forLanguageMeta = const VerificationMeta(
    'forLanguage',
  );
  @override
  late final GeneratedColumn<String> forLanguage = GeneratedColumn<String>(
    'for_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
    'sort',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    setup_scope_option_pk,
    setup_scope_fk,
    category,
    value,
    platform,
    forLanguage,
    sort,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setup_scope_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetupScopeOption> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setup_scope_option_pk')) {
      context.handle(
        _setup_scope_option_pkMeta,
        setup_scope_option_pk.isAcceptableOrUnknown(
          data['setup_scope_option_pk']!,
          _setup_scope_option_pkMeta,
        ),
      );
    }
    if (data.containsKey('setup_scope_fk')) {
      context.handle(
        _setup_scope_fkMeta,
        setup_scope_fk.isAcceptableOrUnknown(
          data['setup_scope_fk']!,
          _setup_scope_fkMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_setup_scope_fkMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('for_language')) {
      context.handle(
        _forLanguageMeta,
        forLanguage.isAcceptableOrUnknown(
          data['for_language']!,
          _forLanguageMeta,
        ),
      );
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {setup_scope_option_pk};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {setup_scope_fk, category, platform, value},
  ];
  @override
  SetupScopeOption map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetupScopeOption(
      setup_scope_option_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}setup_scope_option_pk'],
      )!,
      setup_scope_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}setup_scope_fk'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      ),
      forLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}for_language'],
      ),
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort'],
      )!,
    );
  }

  @override
  $SetupScopeOptionsTable createAlias(String alias) {
    return $SetupScopeOptionsTable(attachedDatabase, alias);
  }
}

class SetupScopeOption extends DataClass
    implements Insertable<SetupScopeOption> {
  final int setup_scope_option_pk;
  final int setup_scope_fk;

  /// Which setup category this option feeds: `objectives`, `features`,
  /// `platforms`, `languages`, `frameworks`, `libraries`.
  final String category;
  final String value;

  /// For platform-conditional stack entries (languages/frameworks/libraries):
  /// the platform this entry applies to (`Mobile`, `Desktop`, `Web`, `Console`,
  /// `Embedded`, `Cloud/Server`). Null for platform-agnostic suggestions.
  final String? platform;

  /// Libraries only: the language/ecosystem the package belongs to (e.g. "Dart",
  /// "C#", "C++"). Null for non-library entries.
  final String? forLanguage;
  final int sort;
  const SetupScopeOption({
    required this.setup_scope_option_pk,
    required this.setup_scope_fk,
    required this.category,
    required this.value,
    this.platform,
    this.forLanguage,
    required this.sort,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setup_scope_option_pk'] = Variable<int>(setup_scope_option_pk);
    map['setup_scope_fk'] = Variable<int>(setup_scope_fk);
    map['category'] = Variable<String>(category);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    if (!nullToAbsent || forLanguage != null) {
      map['for_language'] = Variable<String>(forLanguage);
    }
    map['sort'] = Variable<int>(sort);
    return map;
  }

  SetupScopeOptionsCompanion toCompanion(bool nullToAbsent) {
    return SetupScopeOptionsCompanion(
      setup_scope_option_pk: Value(setup_scope_option_pk),
      setup_scope_fk: Value(setup_scope_fk),
      category: Value(category),
      value: Value(value),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      forLanguage: forLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(forLanguage),
      sort: Value(sort),
    );
  }

  factory SetupScopeOption.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetupScopeOption(
      setup_scope_option_pk: serializer.fromJson<int>(
        json['setup_scope_option_pk'],
      ),
      setup_scope_fk: serializer.fromJson<int>(json['setup_scope_fk']),
      category: serializer.fromJson<String>(json['category']),
      value: serializer.fromJson<String>(json['value']),
      platform: serializer.fromJson<String?>(json['platform']),
      forLanguage: serializer.fromJson<String?>(json['forLanguage']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'setup_scope_option_pk': serializer.toJson<int>(setup_scope_option_pk),
      'setup_scope_fk': serializer.toJson<int>(setup_scope_fk),
      'category': serializer.toJson<String>(category),
      'value': serializer.toJson<String>(value),
      'platform': serializer.toJson<String?>(platform),
      'forLanguage': serializer.toJson<String?>(forLanguage),
      'sort': serializer.toJson<int>(sort),
    };
  }

  SetupScopeOption copyWith({
    int? setup_scope_option_pk,
    int? setup_scope_fk,
    String? category,
    String? value,
    Value<String?> platform = const Value.absent(),
    Value<String?> forLanguage = const Value.absent(),
    int? sort,
  }) => SetupScopeOption(
    setup_scope_option_pk: setup_scope_option_pk ?? this.setup_scope_option_pk,
    setup_scope_fk: setup_scope_fk ?? this.setup_scope_fk,
    category: category ?? this.category,
    value: value ?? this.value,
    platform: platform.present ? platform.value : this.platform,
    forLanguage: forLanguage.present ? forLanguage.value : this.forLanguage,
    sort: sort ?? this.sort,
  );
  SetupScopeOption copyWithCompanion(SetupScopeOptionsCompanion data) {
    return SetupScopeOption(
      setup_scope_option_pk: data.setup_scope_option_pk.present
          ? data.setup_scope_option_pk.value
          : this.setup_scope_option_pk,
      setup_scope_fk: data.setup_scope_fk.present
          ? data.setup_scope_fk.value
          : this.setup_scope_fk,
      category: data.category.present ? data.category.value : this.category,
      value: data.value.present ? data.value.value : this.value,
      platform: data.platform.present ? data.platform.value : this.platform,
      forLanguage: data.forLanguage.present
          ? data.forLanguage.value
          : this.forLanguage,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetupScopeOption(')
          ..write('setup_scope_option_pk: $setup_scope_option_pk, ')
          ..write('setup_scope_fk: $setup_scope_fk, ')
          ..write('category: $category, ')
          ..write('value: $value, ')
          ..write('platform: $platform, ')
          ..write('forLanguage: $forLanguage, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    setup_scope_option_pk,
    setup_scope_fk,
    category,
    value,
    platform,
    forLanguage,
    sort,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetupScopeOption &&
          other.setup_scope_option_pk == this.setup_scope_option_pk &&
          other.setup_scope_fk == this.setup_scope_fk &&
          other.category == this.category &&
          other.value == this.value &&
          other.platform == this.platform &&
          other.forLanguage == this.forLanguage &&
          other.sort == this.sort);
}

class SetupScopeOptionsCompanion extends UpdateCompanion<SetupScopeOption> {
  final Value<int> setup_scope_option_pk;
  final Value<int> setup_scope_fk;
  final Value<String> category;
  final Value<String> value;
  final Value<String?> platform;
  final Value<String?> forLanguage;
  final Value<int> sort;
  const SetupScopeOptionsCompanion({
    this.setup_scope_option_pk = const Value.absent(),
    this.setup_scope_fk = const Value.absent(),
    this.category = const Value.absent(),
    this.value = const Value.absent(),
    this.platform = const Value.absent(),
    this.forLanguage = const Value.absent(),
    this.sort = const Value.absent(),
  });
  SetupScopeOptionsCompanion.insert({
    this.setup_scope_option_pk = const Value.absent(),
    required int setup_scope_fk,
    required String category,
    required String value,
    this.platform = const Value.absent(),
    this.forLanguage = const Value.absent(),
    this.sort = const Value.absent(),
  }) : setup_scope_fk = Value(setup_scope_fk),
       category = Value(category),
       value = Value(value);
  static Insertable<SetupScopeOption> custom({
    Expression<int>? setup_scope_option_pk,
    Expression<int>? setup_scope_fk,
    Expression<String>? category,
    Expression<String>? value,
    Expression<String>? platform,
    Expression<String>? forLanguage,
    Expression<int>? sort,
  }) {
    return RawValuesInsertable({
      if (setup_scope_option_pk != null)
        'setup_scope_option_pk': setup_scope_option_pk,
      if (setup_scope_fk != null) 'setup_scope_fk': setup_scope_fk,
      if (category != null) 'category': category,
      if (value != null) 'value': value,
      if (platform != null) 'platform': platform,
      if (forLanguage != null) 'for_language': forLanguage,
      if (sort != null) 'sort': sort,
    });
  }

  SetupScopeOptionsCompanion copyWith({
    Value<int>? setup_scope_option_pk,
    Value<int>? setup_scope_fk,
    Value<String>? category,
    Value<String>? value,
    Value<String?>? platform,
    Value<String?>? forLanguage,
    Value<int>? sort,
  }) {
    return SetupScopeOptionsCompanion(
      setup_scope_option_pk:
          setup_scope_option_pk ?? this.setup_scope_option_pk,
      setup_scope_fk: setup_scope_fk ?? this.setup_scope_fk,
      category: category ?? this.category,
      value: value ?? this.value,
      platform: platform ?? this.platform,
      forLanguage: forLanguage ?? this.forLanguage,
      sort: sort ?? this.sort,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (setup_scope_option_pk.present) {
      map['setup_scope_option_pk'] = Variable<int>(setup_scope_option_pk.value);
    }
    if (setup_scope_fk.present) {
      map['setup_scope_fk'] = Variable<int>(setup_scope_fk.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (forLanguage.present) {
      map['for_language'] = Variable<String>(forLanguage.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetupScopeOptionsCompanion(')
          ..write('setup_scope_option_pk: $setup_scope_option_pk, ')
          ..write('setup_scope_fk: $setup_scope_fk, ')
          ..write('category: $category, ')
          ..write('value: $value, ')
          ..write('platform: $platform, ')
          ..write('forLanguage: $forLanguage, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }
}

class $StoryNotesTable extends StoryNotes
    with TableInfo<$StoryNotesTable, StoryNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _note_pkMeta = const VerificationMeta(
    'note_pk',
  );
  @override
  late final GeneratedColumn<int> note_pk = GeneratedColumn<int>(
    'note_pk',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _story_fkMeta = const VerificationMeta(
    'story_fk',
  );
  @override
  late final GeneratedColumn<int> story_fk = GeneratedColumn<int>(
    'story_fk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_stories (story_pk)',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    note_pk,
    story_fk,
    body,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'story_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoryNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_pk')) {
      context.handle(
        _note_pkMeta,
        note_pk.isAcceptableOrUnknown(data['note_pk']!, _note_pkMeta),
      );
    }
    if (data.containsKey('story_fk')) {
      context.handle(
        _story_fkMeta,
        story_fk.isAcceptableOrUnknown(data['story_fk']!, _story_fkMeta),
      );
    } else if (isInserting) {
      context.missing(_story_fkMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {note_pk};
  @override
  StoryNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoryNote(
      note_pk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_pk'],
      )!,
      story_fk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_fk'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StoryNotesTable createAlias(String alias) {
    return $StoryNotesTable(attachedDatabase, alias);
  }
}

class StoryNote extends DataClass implements Insertable<StoryNote> {
  final int note_pk;
  final int story_fk;

  /// The note text.
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoryNote({
    required this.note_pk,
    required this.story_fk,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_pk'] = Variable<int>(note_pk);
    map['story_fk'] = Variable<int>(story_fk);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoryNotesCompanion toCompanion(bool nullToAbsent) {
    return StoryNotesCompanion(
      note_pk: Value(note_pk),
      story_fk: Value(story_fk),
      body: Value(body),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoryNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoryNote(
      note_pk: serializer.fromJson<int>(json['note_pk']),
      story_fk: serializer.fromJson<int>(json['story_fk']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'note_pk': serializer.toJson<int>(note_pk),
      'story_fk': serializer.toJson<int>(story_fk),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoryNote copyWith({
    int? note_pk,
    int? story_fk,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoryNote(
    note_pk: note_pk ?? this.note_pk,
    story_fk: story_fk ?? this.story_fk,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoryNote copyWithCompanion(StoryNotesCompanion data) {
    return StoryNote(
      note_pk: data.note_pk.present ? data.note_pk.value : this.note_pk,
      story_fk: data.story_fk.present ? data.story_fk.value : this.story_fk,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoryNote(')
          ..write('note_pk: $note_pk, ')
          ..write('story_fk: $story_fk, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(note_pk, story_fk, body, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryNote &&
          other.note_pk == this.note_pk &&
          other.story_fk == this.story_fk &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoryNotesCompanion extends UpdateCompanion<StoryNote> {
  final Value<int> note_pk;
  final Value<int> story_fk;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const StoryNotesCompanion({
    this.note_pk = const Value.absent(),
    this.story_fk = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StoryNotesCompanion.insert({
    this.note_pk = const Value.absent(),
    required int story_fk,
    required String body,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : story_fk = Value(story_fk),
       body = Value(body);
  static Insertable<StoryNote> custom({
    Expression<int>? note_pk,
    Expression<int>? story_fk,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (note_pk != null) 'note_pk': note_pk,
      if (story_fk != null) 'story_fk': story_fk,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StoryNotesCompanion copyWith({
    Value<int>? note_pk,
    Value<int>? story_fk,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return StoryNotesCompanion(
      note_pk: note_pk ?? this.note_pk,
      story_fk: story_fk ?? this.story_fk,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (note_pk.present) {
      map['note_pk'] = Variable<int>(note_pk.value);
    }
    if (story_fk.present) {
      map['story_fk'] = Variable<int>(story_fk.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryNotesCompanion(')
          ..write('note_pk: $note_pk, ')
          ..write('story_fk: $story_fk, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$NexusDatabase extends GeneratedDatabase {
  _$NexusDatabase(QueryExecutor e) : super(e);
  $NexusDatabaseManager get managers => $NexusDatabaseManager(this);
  late final $ClientsTable clients = $ClientsTable(this);
  late final $InferenceServersTable inferenceServers = $InferenceServersTable(
    this,
  );
  late final $AgentPersonasTable agentPersonas = $AgentPersonasTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ChatSessionsTable chatSessions = $ChatSessionsTable(this);
  late final $UserStoriesTable userStories = $UserStoriesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $SkillsTable skills = $SkillsTable(this);
  late final $DeploymentsTable deployments = $DeploymentsTable(this);
  late final $ActivityLogsTable activityLogs = $ActivityLogsTable(this);
  late final $CiRunsTable ciRuns = $CiRunsTable(this);
  late final $CiJobsTable ciJobs = $CiJobsTable(this);
  late final $CiStepsTable ciSteps = $CiStepsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $ProjectTagsTable projectTags = $ProjectTagsTable(this);
  late final $LibraryVerificationsTable libraryVerifications =
      $LibraryVerificationsTable(this);
  late final $CallSystemsTable callSystems = $CallSystemsTable(this);
  late final $SetupFlowsTable setupFlows = $SetupFlowsTable(this);
  late final $SetupScopesTable setupScopes = $SetupScopesTable(this);
  late final $SetupScopeOptionsTable setupScopeOptions =
      $SetupScopeOptionsTable(this);
  late final $StoryNotesTable storyNotes = $StoryNotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    clients,
    inferenceServers,
    agentPersonas,
    projects,
    chatSessions,
    userStories,
    tasks,
    skills,
    deployments,
    activityLogs,
    ciRuns,
    ciJobs,
    ciSteps,
    chatMessages,
    projectTags,
    libraryVerifications,
    callSystems,
    setupFlows,
    setupScopes,
    setupScopeOptions,
    storyNotes,
  ];
}

typedef $$ClientsTableCreateCompanionBuilder =
    ClientsCompanion Function({
      Value<int> client_pk,
      required String name,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ClientsTableUpdateCompanionBuilder =
    ClientsCompanion Function({
      Value<int> client_pk,
      Value<String> name,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ClientsTableReferences
    extends BaseReferences<_$NexusDatabase, $ClientsTable, Client> {
  $$ClientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$InferenceServersTable, List<InferenceServer>>
  _inferenceServersRefsTable(_$NexusDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.inferenceServers,
        aliasName: 'clients__client_pk__inference_servers__client_fk',
      );

  $$InferenceServersTableProcessedTableManager get inferenceServersRefs {
    final manager =
        $$InferenceServersTableTableManager($_db, $_db.inferenceServers).filter(
          (f) =>
              f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _inferenceServersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AgentPersonasTable, List<AgentPersona>>
  _agentPersonasRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.agentPersonas,
    aliasName: 'clients__client_pk__agent_personas__client_fk',
  );

  $$AgentPersonasTableProcessedTableManager get agentPersonasRefs {
    final manager = $$AgentPersonasTableTableManager($_db, $_db.agentPersonas)
        .filter(
          (f) =>
              f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(_agentPersonasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'clients__client_pk__projects__client_fk',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager($_db, $_db.projects).filter(
      (f) => f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'clients__client_pk__tasks__task_client_fk',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) =>
          f.task_client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SkillsTable, List<Skill>> _skillsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.skills,
    aliasName: 'clients__client_pk__skills__client_fk',
  );

  $$SkillsTableProcessedTableManager get skillsRefs {
    final manager = $$SkillsTableTableManager($_db, $_db.skills).filter(
      (f) => f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_skillsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeploymentsTable, List<Deployment>>
  _deploymentsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.deployments,
    aliasName: 'clients__client_pk__deployments__client_fk',
  );

  $$DeploymentsTableProcessedTableManager get deploymentsRefs {
    final manager = $$DeploymentsTableTableManager($_db, $_db.deployments)
        .filter(
          (f) =>
              f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(_deploymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActivityLogsTable, List<ActivityLog>>
  _activityLogsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.activityLogs,
    aliasName: 'clients__client_pk__activity_logs__client_fk',
  );

  $$ActivityLogsTableProcessedTableManager get activityLogsRefs {
    final manager = $$ActivityLogsTableTableManager($_db, $_db.activityLogs)
        .filter(
          (f) =>
              f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(_activityLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CiRunsTable, List<CiRun>> _ciRunsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ciRuns,
    aliasName: 'clients__client_pk__ci_runs__client_fk',
  );

  $$CiRunsTableProcessedTableManager get ciRunsRefs {
    final manager = $$CiRunsTableTableManager($_db, $_db.ciRuns).filter(
      (f) => f.client_fk.client_pk.sqlEquals($_itemColumn<int>('client_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_ciRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ClientsTableFilterComposer
    extends Composer<_$NexusDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get client_pk => $composableBuilder(
    column: $table.client_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> inferenceServersRefs(
    Expression<bool> Function($$InferenceServersTableFilterComposer f) f,
  ) {
    final $$InferenceServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.inferenceServers,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferenceServersTableFilterComposer(
            $db: $db,
            $table: $db.inferenceServers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> agentPersonasRefs(
    Expression<bool> Function($$AgentPersonasTableFilterComposer f) f,
  ) {
    final $$AgentPersonasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableFilterComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> skillsRefs(
    Expression<bool> Function($$SkillsTableFilterComposer f) f,
  ) {
    final $$SkillsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.skills,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillsTableFilterComposer(
            $db: $db,
            $table: $db.skills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deploymentsRefs(
    Expression<bool> Function($$DeploymentsTableFilterComposer f) f,
  ) {
    final $$DeploymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.deployments,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeploymentsTableFilterComposer(
            $db: $db,
            $table: $db.deployments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activityLogsRefs(
    Expression<bool> Function($$ActivityLogsTableFilterComposer f) f,
  ) {
    final $$ActivityLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.activityLogs,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogsTableFilterComposer(
            $db: $db,
            $table: $db.activityLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ciRunsRefs(
    Expression<bool> Function($$CiRunsTableFilterComposer f) f,
  ) {
    final $$CiRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableFilterComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClientsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get client_pk => $composableBuilder(
    column: $table.client_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get client_pk =>
      $composableBuilder(column: $table.client_pk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> inferenceServersRefs<T extends Object>(
    Expression<T> Function($$InferenceServersTableAnnotationComposer a) f,
  ) {
    final $$InferenceServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.inferenceServers,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferenceServersTableAnnotationComposer(
            $db: $db,
            $table: $db.inferenceServers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> agentPersonasRefs<T extends Object>(
    Expression<T> Function($$AgentPersonasTableAnnotationComposer a) f,
  ) {
    final $$AgentPersonasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableAnnotationComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> skillsRefs<T extends Object>(
    Expression<T> Function($$SkillsTableAnnotationComposer a) f,
  ) {
    final $$SkillsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.skills,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillsTableAnnotationComposer(
            $db: $db,
            $table: $db.skills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deploymentsRefs<T extends Object>(
    Expression<T> Function($$DeploymentsTableAnnotationComposer a) f,
  ) {
    final $$DeploymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.deployments,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeploymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.deployments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activityLogsRefs<T extends Object>(
    Expression<T> Function($$ActivityLogsTableAnnotationComposer a) f,
  ) {
    final $$ActivityLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.activityLogs,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.activityLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ciRunsRefs<T extends Object>(
    Expression<T> Function($$CiRunsTableAnnotationComposer a) f,
  ) {
    final $$CiRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_pk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.client_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClientsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ClientsTable,
          Client,
          $$ClientsTableFilterComposer,
          $$ClientsTableOrderingComposer,
          $$ClientsTableAnnotationComposer,
          $$ClientsTableCreateCompanionBuilder,
          $$ClientsTableUpdateCompanionBuilder,
          (Client, $$ClientsTableReferences),
          Client,
          PrefetchHooks Function({
            bool inferenceServersRefs,
            bool agentPersonasRefs,
            bool projectsRefs,
            bool tasksRefs,
            bool skillsRefs,
            bool deploymentsRefs,
            bool activityLogsRefs,
            bool ciRunsRefs,
          })
        > {
  $$ClientsTableTableManager(_$NexusDatabase db, $ClientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> client_pk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ClientsCompanion(
                client_pk: client_pk,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> client_pk = const Value.absent(),
                required String name,
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ClientsCompanion.insert(
                client_pk: client_pk,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ClientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                inferenceServersRefs = false,
                agentPersonasRefs = false,
                projectsRefs = false,
                tasksRefs = false,
                skillsRefs = false,
                deploymentsRefs = false,
                activityLogsRefs = false,
                ciRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (inferenceServersRefs) db.inferenceServers,
                    if (agentPersonasRefs) db.agentPersonas,
                    if (projectsRefs) db.projects,
                    if (tasksRefs) db.tasks,
                    if (skillsRefs) db.skills,
                    if (deploymentsRefs) db.deployments,
                    if (activityLogsRefs) db.activityLogs,
                    if (ciRunsRefs) db.ciRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (inferenceServersRefs)
                        await $_getPrefetchedData<
                          Client,
                          $ClientsTable,
                          InferenceServer
                        >(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._inferenceServersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).inferenceServersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (agentPersonasRefs)
                        await $_getPrefetchedData<
                          Client,
                          $ClientsTable,
                          AgentPersona
                        >(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._agentPersonasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentPersonasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (projectsRefs)
                        await $_getPrefetchedData<
                          Client,
                          $ClientsTable,
                          Project
                        >(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedData<Client, $ClientsTable, Task>(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(db, table, p0).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.task_client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (skillsRefs)
                        await $_getPrefetchedData<Client, $ClientsTable, Skill>(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._skillsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).skillsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (deploymentsRefs)
                        await $_getPrefetchedData<
                          Client,
                          $ClientsTable,
                          Deployment
                        >(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._deploymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).deploymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (activityLogsRefs)
                        await $_getPrefetchedData<
                          Client,
                          $ClientsTable,
                          ActivityLog
                        >(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._activityLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).activityLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                      if (ciRunsRefs)
                        await $_getPrefetchedData<Client, $ClientsTable, CiRun>(
                          currentTable: table,
                          referencedTable: $$ClientsTableReferences
                              ._ciRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientsTableReferences(
                                db,
                                table,
                                p0,
                              ).ciRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.client_fk == item.client_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ClientsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ClientsTable,
      Client,
      $$ClientsTableFilterComposer,
      $$ClientsTableOrderingComposer,
      $$ClientsTableAnnotationComposer,
      $$ClientsTableCreateCompanionBuilder,
      $$ClientsTableUpdateCompanionBuilder,
      (Client, $$ClientsTableReferences),
      Client,
      PrefetchHooks Function({
        bool inferenceServersRefs,
        bool agentPersonasRefs,
        bool projectsRefs,
        bool tasksRefs,
        bool skillsRefs,
        bool deploymentsRefs,
        bool activityLogsRefs,
        bool ciRunsRefs,
      })
    >;
typedef $$InferenceServersTableCreateCompanionBuilder =
    InferenceServersCompanion Function({
      Value<int> server_pk,
      required int client_fk,
      required String name,
      required String baseUrl,
      Value<String> apiKey,
      Value<String> providerType,
      Value<int> maxConcurrency,
      Value<int> maxAgents,
      Value<bool> isEnabled,
      Value<String?> selectedModel,
      Value<String> availableModelsJson,
      Value<String> extraConfigJson,
      Value<String> capabilitiesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$InferenceServersTableUpdateCompanionBuilder =
    InferenceServersCompanion Function({
      Value<int> server_pk,
      Value<int> client_fk,
      Value<String> name,
      Value<String> baseUrl,
      Value<String> apiKey,
      Value<String> providerType,
      Value<int> maxConcurrency,
      Value<int> maxAgents,
      Value<bool> isEnabled,
      Value<String?> selectedModel,
      Value<String> availableModelsJson,
      Value<String> extraConfigJson,
      Value<String> capabilitiesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$InferenceServersTableReferences
    extends
        BaseReferences<
          _$NexusDatabase,
          $InferenceServersTable,
          InferenceServer
        > {
  $$InferenceServersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ClientsTable _client_fkTable(_$NexusDatabase db) => db.clients
      .createAlias('inference_servers__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AgentPersonasTable, List<AgentPersona>>
  _agentPersonasRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.agentPersonas,
    aliasName: 'inference_servers__server_pk__agent_personas__provider_fk',
  );

  $$AgentPersonasTableProcessedTableManager get agentPersonasRefs {
    final manager = $$AgentPersonasTableTableManager($_db, $_db.agentPersonas)
        .filter(
          (f) => f.provider_fk.server_pk.sqlEquals(
            $_itemColumn<int>('server_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_agentPersonasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$InferenceServersTableFilterComposer
    extends Composer<_$NexusDatabase, $InferenceServersTable> {
  $$InferenceServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get server_pk => $composableBuilder(
    column: $table.server_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxConcurrency => $composableBuilder(
    column: $table.maxConcurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxAgents => $composableBuilder(
    column: $table.maxAgents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedModel => $composableBuilder(
    column: $table.selectedModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availableModelsJson => $composableBuilder(
    column: $table.availableModelsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraConfigJson => $composableBuilder(
    column: $table.extraConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> agentPersonasRefs(
    Expression<bool> Function($$AgentPersonasTableFilterComposer f) f,
  ) {
    final $$AgentPersonasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.server_pk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.provider_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableFilterComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InferenceServersTableOrderingComposer
    extends Composer<_$NexusDatabase, $InferenceServersTable> {
  $$InferenceServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get server_pk => $composableBuilder(
    column: $table.server_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiKey => $composableBuilder(
    column: $table.apiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxConcurrency => $composableBuilder(
    column: $table.maxConcurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxAgents => $composableBuilder(
    column: $table.maxAgents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedModel => $composableBuilder(
    column: $table.selectedModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availableModelsJson => $composableBuilder(
    column: $table.availableModelsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraConfigJson => $composableBuilder(
    column: $table.extraConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InferenceServersTableAnnotationComposer
    extends Composer<_$NexusDatabase, $InferenceServersTable> {
  $$InferenceServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get server_pk =>
      $composableBuilder(column: $table.server_pk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get apiKey =>
      $composableBuilder(column: $table.apiKey, builder: (column) => column);

  GeneratedColumn<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxConcurrency => $composableBuilder(
    column: $table.maxConcurrency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxAgents =>
      $composableBuilder(column: $table.maxAgents, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get selectedModel => $composableBuilder(
    column: $table.selectedModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availableModelsJson => $composableBuilder(
    column: $table.availableModelsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extraConfigJson => $composableBuilder(
    column: $table.extraConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> agentPersonasRefs<T extends Object>(
    Expression<T> Function($$AgentPersonasTableAnnotationComposer a) f,
  ) {
    final $$AgentPersonasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.server_pk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.provider_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableAnnotationComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InferenceServersTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $InferenceServersTable,
          InferenceServer,
          $$InferenceServersTableFilterComposer,
          $$InferenceServersTableOrderingComposer,
          $$InferenceServersTableAnnotationComposer,
          $$InferenceServersTableCreateCompanionBuilder,
          $$InferenceServersTableUpdateCompanionBuilder,
          (InferenceServer, $$InferenceServersTableReferences),
          InferenceServer,
          PrefetchHooks Function({bool client_fk, bool agentPersonasRefs})
        > {
  $$InferenceServersTableTableManager(
    _$NexusDatabase db,
    $InferenceServersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InferenceServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InferenceServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InferenceServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> server_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> apiKey = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<int> maxConcurrency = const Value.absent(),
                Value<int> maxAgents = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> selectedModel = const Value.absent(),
                Value<String> availableModelsJson = const Value.absent(),
                Value<String> extraConfigJson = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => InferenceServersCompanion(
                server_pk: server_pk,
                client_fk: client_fk,
                name: name,
                baseUrl: baseUrl,
                apiKey: apiKey,
                providerType: providerType,
                maxConcurrency: maxConcurrency,
                maxAgents: maxAgents,
                isEnabled: isEnabled,
                selectedModel: selectedModel,
                availableModelsJson: availableModelsJson,
                extraConfigJson: extraConfigJson,
                capabilitiesJson: capabilitiesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> server_pk = const Value.absent(),
                required int client_fk,
                required String name,
                required String baseUrl,
                Value<String> apiKey = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<int> maxConcurrency = const Value.absent(),
                Value<int> maxAgents = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> selectedModel = const Value.absent(),
                Value<String> availableModelsJson = const Value.absent(),
                Value<String> extraConfigJson = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => InferenceServersCompanion.insert(
                server_pk: server_pk,
                client_fk: client_fk,
                name: name,
                baseUrl: baseUrl,
                apiKey: apiKey,
                providerType: providerType,
                maxConcurrency: maxConcurrency,
                maxAgents: maxAgents,
                isEnabled: isEnabled,
                selectedModel: selectedModel,
                availableModelsJson: availableModelsJson,
                extraConfigJson: extraConfigJson,
                capabilitiesJson: capabilitiesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$InferenceServersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({client_fk = false, agentPersonasRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (agentPersonasRefs) db.agentPersonas,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (client_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.client_fk,
                                    referencedTable:
                                        $$InferenceServersTableReferences
                                            ._client_fkTable(db),
                                    referencedColumn:
                                        $$InferenceServersTableReferences
                                            ._client_fkTable(db)
                                            .client_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (agentPersonasRefs)
                        await $_getPrefetchedData<
                          InferenceServer,
                          $InferenceServersTable,
                          AgentPersona
                        >(
                          currentTable: table,
                          referencedTable: $$InferenceServersTableReferences
                              ._agentPersonasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InferenceServersTableReferences(
                                db,
                                table,
                                p0,
                              ).agentPersonasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.provider_fk == item.server_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$InferenceServersTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $InferenceServersTable,
      InferenceServer,
      $$InferenceServersTableFilterComposer,
      $$InferenceServersTableOrderingComposer,
      $$InferenceServersTableAnnotationComposer,
      $$InferenceServersTableCreateCompanionBuilder,
      $$InferenceServersTableUpdateCompanionBuilder,
      (InferenceServer, $$InferenceServersTableReferences),
      InferenceServer,
      PrefetchHooks Function({bool client_fk, bool agentPersonasRefs})
    >;
typedef $$AgentPersonasTableCreateCompanionBuilder =
    AgentPersonasCompanion Function({
      Value<int> agent_pk,
      required int client_fk,
      required String name,
      Value<String?> title,
      Value<String?> description,
      Value<String?> primaryModel,
      Value<double> costPerMillionTokens,
      Value<String> capabilitiesJson,
      Value<String> configJson,
      Value<bool> isPrefab,
      Value<int?> prefab_fk,
      Value<String> overridesJson,
      Value<int?> provider_fk,
      Value<String?> omniCollectionModel,
      Value<String?> ttsModel,
      Value<String?> sttModel,
      Value<String?> imageGenModel,
      Value<String?> visionModel,
      Value<String?> llmModel,
      Value<String?> ttsVoice,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$AgentPersonasTableUpdateCompanionBuilder =
    AgentPersonasCompanion Function({
      Value<int> agent_pk,
      Value<int> client_fk,
      Value<String> name,
      Value<String?> title,
      Value<String?> description,
      Value<String?> primaryModel,
      Value<double> costPerMillionTokens,
      Value<String> capabilitiesJson,
      Value<String> configJson,
      Value<bool> isPrefab,
      Value<int?> prefab_fk,
      Value<String> overridesJson,
      Value<int?> provider_fk,
      Value<String?> omniCollectionModel,
      Value<String?> ttsModel,
      Value<String?> sttModel,
      Value<String?> imageGenModel,
      Value<String?> visionModel,
      Value<String?> llmModel,
      Value<String?> ttsVoice,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$AgentPersonasTableReferences
    extends BaseReferences<_$NexusDatabase, $AgentPersonasTable, AgentPersona> {
  $$AgentPersonasTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ClientsTable _client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('agent_personas__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AgentPersonasTable _prefab_fkTable(_$NexusDatabase db) => db
      .agentPersonas
      .createAlias('agent_personas__prefab_fk__agent_personas__agent_pk');

  $$AgentPersonasTableProcessedTableManager? get prefab_fk {
    final $_column = $_itemColumn<int>('prefab_fk');
    if ($_column == null) return null;
    final manager = $$AgentPersonasTableTableManager(
      $_db,
      $_db.agentPersonas,
    ).filter((f) => f.agent_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prefab_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $InferenceServersTable _provider_fkTable(_$NexusDatabase db) => db
      .inferenceServers
      .createAlias('agent_personas__provider_fk__inference_servers__server_pk');

  $$InferenceServersTableProcessedTableManager? get provider_fk {
    final $_column = $_itemColumn<int>('provider_fk');
    if ($_column == null) return null;
    final manager = $$InferenceServersTableTableManager(
      $_db,
      $_db.inferenceServers,
    ).filter((f) => f.server_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_provider_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'agent_personas__agent_pk__projects__agent_persona_fk',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager($_db, $_db.projects).filter(
      (f) =>
          f.agent_persona_fk.agent_pk.sqlEquals($_itemColumn<int>('agent_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'agent_personas__agent_pk__tasks__task_agent_fk',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.task_agent_fk.agent_pk.sqlEquals($_itemColumn<int>('agent_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AgentPersonasTableFilterComposer
    extends Composer<_$NexusDatabase, $AgentPersonasTable> {
  $$AgentPersonasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get agent_pk => $composableBuilder(
    column: $table.agent_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryModel => $composableBuilder(
    column: $table.primaryModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPerMillionTokens => $composableBuilder(
    column: $table.costPerMillionTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrefab => $composableBuilder(
    column: $table.isPrefab,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get omniCollectionModel => $composableBuilder(
    column: $table.omniCollectionModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ttsModel => $composableBuilder(
    column: $table.ttsModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sttModel => $composableBuilder(
    column: $table.sttModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageGenModel => $composableBuilder(
    column: $table.imageGenModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visionModel => $composableBuilder(
    column: $table.visionModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get llmModel => $composableBuilder(
    column: $table.llmModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ttsVoice => $composableBuilder(
    column: $table.ttsVoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableFilterComposer get prefab_fk {
    final $$AgentPersonasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prefab_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableFilterComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InferenceServersTableFilterComposer get provider_fk {
    final $$InferenceServersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.provider_fk,
      referencedTable: $db.inferenceServers,
      getReferencedColumn: (t) => t.server_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferenceServersTableFilterComposer(
            $db: $db,
            $table: $db.inferenceServers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_pk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.agent_persona_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_agent_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AgentPersonasTableOrderingComposer
    extends Composer<_$NexusDatabase, $AgentPersonasTable> {
  $$AgentPersonasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get agent_pk => $composableBuilder(
    column: $table.agent_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryModel => $composableBuilder(
    column: $table.primaryModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPerMillionTokens => $composableBuilder(
    column: $table.costPerMillionTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrefab => $composableBuilder(
    column: $table.isPrefab,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get omniCollectionModel => $composableBuilder(
    column: $table.omniCollectionModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttsModel => $composableBuilder(
    column: $table.ttsModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sttModel => $composableBuilder(
    column: $table.sttModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageGenModel => $composableBuilder(
    column: $table.imageGenModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visionModel => $composableBuilder(
    column: $table.visionModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get llmModel => $composableBuilder(
    column: $table.llmModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttsVoice => $composableBuilder(
    column: $table.ttsVoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableOrderingComposer get prefab_fk {
    final $$AgentPersonasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prefab_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableOrderingComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InferenceServersTableOrderingComposer get provider_fk {
    final $$InferenceServersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.provider_fk,
      referencedTable: $db.inferenceServers,
      getReferencedColumn: (t) => t.server_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferenceServersTableOrderingComposer(
            $db: $db,
            $table: $db.inferenceServers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentPersonasTableAnnotationComposer
    extends Composer<_$NexusDatabase, $AgentPersonasTable> {
  $$AgentPersonasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get agent_pk =>
      $composableBuilder(column: $table.agent_pk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryModel => $composableBuilder(
    column: $table.primaryModel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get costPerMillionTokens => $composableBuilder(
    column: $table.costPerMillionTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrefab =>
      $composableBuilder(column: $table.isPrefab, builder: (column) => column);

  GeneratedColumn<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get omniCollectionModel => $composableBuilder(
    column: $table.omniCollectionModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ttsModel =>
      $composableBuilder(column: $table.ttsModel, builder: (column) => column);

  GeneratedColumn<String> get sttModel =>
      $composableBuilder(column: $table.sttModel, builder: (column) => column);

  GeneratedColumn<String> get imageGenModel => $composableBuilder(
    column: $table.imageGenModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visionModel => $composableBuilder(
    column: $table.visionModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get llmModel =>
      $composableBuilder(column: $table.llmModel, builder: (column) => column);

  GeneratedColumn<String> get ttsVoice =>
      $composableBuilder(column: $table.ttsVoice, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableAnnotationComposer get prefab_fk {
    final $$AgentPersonasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prefab_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableAnnotationComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InferenceServersTableAnnotationComposer get provider_fk {
    final $$InferenceServersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.provider_fk,
      referencedTable: $db.inferenceServers,
      getReferencedColumn: (t) => t.server_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferenceServersTableAnnotationComposer(
            $db: $db,
            $table: $db.inferenceServers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_pk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.agent_persona_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_agent_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AgentPersonasTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $AgentPersonasTable,
          AgentPersona,
          $$AgentPersonasTableFilterComposer,
          $$AgentPersonasTableOrderingComposer,
          $$AgentPersonasTableAnnotationComposer,
          $$AgentPersonasTableCreateCompanionBuilder,
          $$AgentPersonasTableUpdateCompanionBuilder,
          (AgentPersona, $$AgentPersonasTableReferences),
          AgentPersona,
          PrefetchHooks Function({
            bool client_fk,
            bool prefab_fk,
            bool provider_fk,
            bool projectsRefs,
            bool tasksRefs,
          })
        > {
  $$AgentPersonasTableTableManager(
    _$NexusDatabase db,
    $AgentPersonasTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentPersonasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentPersonasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentPersonasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> agent_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> primaryModel = const Value.absent(),
                Value<double> costPerMillionTokens = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<bool> isPrefab = const Value.absent(),
                Value<int?> prefab_fk = const Value.absent(),
                Value<String> overridesJson = const Value.absent(),
                Value<int?> provider_fk = const Value.absent(),
                Value<String?> omniCollectionModel = const Value.absent(),
                Value<String?> ttsModel = const Value.absent(),
                Value<String?> sttModel = const Value.absent(),
                Value<String?> imageGenModel = const Value.absent(),
                Value<String?> visionModel = const Value.absent(),
                Value<String?> llmModel = const Value.absent(),
                Value<String?> ttsVoice = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AgentPersonasCompanion(
                agent_pk: agent_pk,
                client_fk: client_fk,
                name: name,
                title: title,
                description: description,
                primaryModel: primaryModel,
                costPerMillionTokens: costPerMillionTokens,
                capabilitiesJson: capabilitiesJson,
                configJson: configJson,
                isPrefab: isPrefab,
                prefab_fk: prefab_fk,
                overridesJson: overridesJson,
                provider_fk: provider_fk,
                omniCollectionModel: omniCollectionModel,
                ttsModel: ttsModel,
                sttModel: sttModel,
                imageGenModel: imageGenModel,
                visionModel: visionModel,
                llmModel: llmModel,
                ttsVoice: ttsVoice,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> agent_pk = const Value.absent(),
                required int client_fk,
                required String name,
                Value<String?> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> primaryModel = const Value.absent(),
                Value<double> costPerMillionTokens = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<bool> isPrefab = const Value.absent(),
                Value<int?> prefab_fk = const Value.absent(),
                Value<String> overridesJson = const Value.absent(),
                Value<int?> provider_fk = const Value.absent(),
                Value<String?> omniCollectionModel = const Value.absent(),
                Value<String?> ttsModel = const Value.absent(),
                Value<String?> sttModel = const Value.absent(),
                Value<String?> imageGenModel = const Value.absent(),
                Value<String?> visionModel = const Value.absent(),
                Value<String?> llmModel = const Value.absent(),
                Value<String?> ttsVoice = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AgentPersonasCompanion.insert(
                agent_pk: agent_pk,
                client_fk: client_fk,
                name: name,
                title: title,
                description: description,
                primaryModel: primaryModel,
                costPerMillionTokens: costPerMillionTokens,
                capabilitiesJson: capabilitiesJson,
                configJson: configJson,
                isPrefab: isPrefab,
                prefab_fk: prefab_fk,
                overridesJson: overridesJson,
                provider_fk: provider_fk,
                omniCollectionModel: omniCollectionModel,
                ttsModel: ttsModel,
                sttModel: sttModel,
                imageGenModel: imageGenModel,
                visionModel: visionModel,
                llmModel: llmModel,
                ttsVoice: ttsVoice,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentPersonasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                client_fk = false,
                prefab_fk = false,
                provider_fk = false,
                projectsRefs = false,
                tasksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectsRefs) db.projects,
                    if (tasksRefs) db.tasks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (client_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.client_fk,
                                    referencedTable:
                                        $$AgentPersonasTableReferences
                                            ._client_fkTable(db),
                                    referencedColumn:
                                        $$AgentPersonasTableReferences
                                            ._client_fkTable(db)
                                            .client_pk,
                                  )
                                  as T;
                        }
                        if (prefab_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.prefab_fk,
                                    referencedTable:
                                        $$AgentPersonasTableReferences
                                            ._prefab_fkTable(db),
                                    referencedColumn:
                                        $$AgentPersonasTableReferences
                                            ._prefab_fkTable(db)
                                            .agent_pk,
                                  )
                                  as T;
                        }
                        if (provider_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.provider_fk,
                                    referencedTable:
                                        $$AgentPersonasTableReferences
                                            ._provider_fkTable(db),
                                    referencedColumn:
                                        $$AgentPersonasTableReferences
                                            ._provider_fkTable(db)
                                            .server_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectsRefs)
                        await $_getPrefetchedData<
                          AgentPersona,
                          $AgentPersonasTable,
                          Project
                        >(
                          currentTable: table,
                          referencedTable: $$AgentPersonasTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AgentPersonasTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.agent_persona_fk == item.agent_pk,
                              ),
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedData<
                          AgentPersona,
                          $AgentPersonasTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$AgentPersonasTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AgentPersonasTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.task_agent_fk == item.agent_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AgentPersonasTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $AgentPersonasTable,
      AgentPersona,
      $$AgentPersonasTableFilterComposer,
      $$AgentPersonasTableOrderingComposer,
      $$AgentPersonasTableAnnotationComposer,
      $$AgentPersonasTableCreateCompanionBuilder,
      $$AgentPersonasTableUpdateCompanionBuilder,
      (AgentPersona, $$AgentPersonasTableReferences),
      AgentPersona,
      PrefetchHooks Function({
        bool client_fk,
        bool prefab_fk,
        bool provider_fk,
        bool projectsRefs,
        bool tasksRefs,
      })
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> project_pk,
      required int client_fk,
      required String name,
      Value<String?> description,
      Value<int?> agent_persona_fk,
      Value<String> orchestrationState,
      Value<bool> workHoursEnabled,
      Value<int?> workHoursStart,
      Value<int?> workHoursEnd,
      Value<int?> workDaysMask,
      Value<String?> orchestratorPromptsJson,
      Value<String> setupStatus,
      Value<String?> setupTranscriptJson,
      Value<String> explorationStatus,
      Value<String> templateStatus,
      Value<int> currentMilestone,
      Value<int> milestoneCount,
      Value<String?> projectSummaryMd,
      Value<DateTime?> summaryUpdatedAt,
      Value<String> projectType,
      Value<String?> subCategory,
      Value<String> experienceMode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<int> project_pk,
      Value<int> client_fk,
      Value<String> name,
      Value<String?> description,
      Value<int?> agent_persona_fk,
      Value<String> orchestrationState,
      Value<bool> workHoursEnabled,
      Value<int?> workHoursStart,
      Value<int?> workHoursEnd,
      Value<int?> workDaysMask,
      Value<String?> orchestratorPromptsJson,
      Value<String> setupStatus,
      Value<String?> setupTranscriptJson,
      Value<String> explorationStatus,
      Value<String> templateStatus,
      Value<int> currentMilestone,
      Value<int> milestoneCount,
      Value<String?> projectSummaryMd,
      Value<DateTime?> summaryUpdatedAt,
      Value<String> projectType,
      Value<String?> subCategory,
      Value<String> experienceMode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$NexusDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('projects__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AgentPersonasTable _agent_persona_fkTable(_$NexusDatabase db) => db
      .agentPersonas
      .createAlias('projects__agent_persona_fk__agent_personas__agent_pk');

  $$AgentPersonasTableProcessedTableManager? get agent_persona_fk {
    final $_column = $_itemColumn<int>('agent_persona_fk');
    if ($_column == null) return null;
    final manager = $$AgentPersonasTableTableManager(
      $_db,
      $_db.agentPersonas,
    ).filter((f) => f.agent_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_agent_persona_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChatSessionsTable, List<ChatSession>>
  _chatSessionsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.chatSessions,
    aliasName: 'projects__project_pk__chat_sessions__project_fk',
  );

  $$ChatSessionsTableProcessedTableManager get chatSessionsRefs {
    final manager = $$ChatSessionsTableTableManager($_db, $_db.chatSessions)
        .filter(
          (f) => f.project_fk.project_pk.sqlEquals(
            $_itemColumn<int>('project_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_chatSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UserStoriesTable, List<UserStory>>
  _userStoriesRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.userStories,
    aliasName: 'projects__project_pk__user_stories__project_fk',
  );

  $$UserStoriesTableProcessedTableManager get userStoriesRefs {
    final manager = $$UserStoriesTableTableManager($_db, $_db.userStories)
        .filter(
          (f) => f.project_fk.project_pk.sqlEquals(
            $_itemColumn<int>('project_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_userStoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'projects__project_pk__tasks__task_project_fk',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.task_project_fk.project_pk.sqlEquals(
        $_itemColumn<int>('project_pk')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeploymentsTable, List<Deployment>>
  _deploymentsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.deployments,
    aliasName: 'projects__project_pk__deployments__project_fk',
  );

  $$DeploymentsTableProcessedTableManager get deploymentsRefs {
    final manager = $$DeploymentsTableTableManager($_db, $_db.deployments)
        .filter(
          (f) => f.project_fk.project_pk.sqlEquals(
            $_itemColumn<int>('project_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_deploymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActivityLogsTable, List<ActivityLog>>
  _activityLogsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.activityLogs,
    aliasName: 'projects__project_pk__activity_logs__project_fk',
  );

  $$ActivityLogsTableProcessedTableManager get activityLogsRefs {
    final manager = $$ActivityLogsTableTableManager($_db, $_db.activityLogs)
        .filter(
          (f) => f.project_fk.project_pk.sqlEquals(
            $_itemColumn<int>('project_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_activityLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CiRunsTable, List<CiRun>> _ciRunsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ciRuns,
    aliasName: 'projects__project_pk__ci_runs__project_fk',
  );

  $$CiRunsTableProcessedTableManager get ciRunsRefs {
    final manager = $$CiRunsTableTableManager($_db, $_db.ciRuns).filter(
      (f) =>
          f.project_fk.project_pk.sqlEquals($_itemColumn<int>('project_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_ciRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectTagsTable, List<ProjectTag>>
  _projectTagsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.projectTags,
    aliasName: 'projects__project_pk__project_tags__project_fk',
  );

  $$ProjectTagsTableProcessedTableManager get projectTagsRefs {
    final manager = $$ProjectTagsTableTableManager($_db, $_db.projectTags)
        .filter(
          (f) => f.project_fk.project_pk.sqlEquals(
            $_itemColumn<int>('project_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_projectTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CallSystemsTable, List<CallSystem>>
  _callSystemsRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.callSystems,
    aliasName: 'projects__project_pk__call_systems__project_fk',
  );

  $$CallSystemsTableProcessedTableManager get callSystemsRefs {
    final manager = $$CallSystemsTableTableManager($_db, $_db.callSystems)
        .filter(
          (f) => f.project_fk.project_pk.sqlEquals(
            $_itemColumn<int>('project_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_callSystemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$NexusDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get project_pk => $composableBuilder(
    column: $table.project_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orchestrationState => $composableBuilder(
    column: $table.orchestrationState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get workHoursEnabled => $composableBuilder(
    column: $table.workHoursEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workHoursStart => $composableBuilder(
    column: $table.workHoursStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workHoursEnd => $composableBuilder(
    column: $table.workHoursEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workDaysMask => $composableBuilder(
    column: $table.workDaysMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orchestratorPromptsJson => $composableBuilder(
    column: $table.orchestratorPromptsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setupStatus => $composableBuilder(
    column: $table.setupStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setupTranscriptJson => $composableBuilder(
    column: $table.setupTranscriptJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explorationStatus => $composableBuilder(
    column: $table.explorationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateStatus => $composableBuilder(
    column: $table.templateStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentMilestone => $composableBuilder(
    column: $table.currentMilestone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get milestoneCount => $composableBuilder(
    column: $table.milestoneCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectSummaryMd => $composableBuilder(
    column: $table.projectSummaryMd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get summaryUpdatedAt => $composableBuilder(
    column: $table.summaryUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get experienceMode => $composableBuilder(
    column: $table.experienceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableFilterComposer get agent_persona_fk {
    final $$AgentPersonasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_persona_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableFilterComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> chatSessionsRefs(
    Expression<bool> Function($$ChatSessionsTableFilterComposer f) f,
  ) {
    final $$ChatSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableFilterComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userStoriesRefs(
    Expression<bool> Function($$UserStoriesTableFilterComposer f) f,
  ) {
    final $$UserStoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableFilterComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deploymentsRefs(
    Expression<bool> Function($$DeploymentsTableFilterComposer f) f,
  ) {
    final $$DeploymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.deployments,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeploymentsTableFilterComposer(
            $db: $db,
            $table: $db.deployments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activityLogsRefs(
    Expression<bool> Function($$ActivityLogsTableFilterComposer f) f,
  ) {
    final $$ActivityLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.activityLogs,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogsTableFilterComposer(
            $db: $db,
            $table: $db.activityLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ciRunsRefs(
    Expression<bool> Function($$CiRunsTableFilterComposer f) f,
  ) {
    final $$CiRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableFilterComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectTagsRefs(
    Expression<bool> Function($$ProjectTagsTableFilterComposer f) f,
  ) {
    final $$ProjectTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.projectTags,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectTagsTableFilterComposer(
            $db: $db,
            $table: $db.projectTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> callSystemsRefs(
    Expression<bool> Function($$CallSystemsTableFilterComposer f) f,
  ) {
    final $$CallSystemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.callSystems,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CallSystemsTableFilterComposer(
            $db: $db,
            $table: $db.callSystems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get project_pk => $composableBuilder(
    column: $table.project_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orchestrationState => $composableBuilder(
    column: $table.orchestrationState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get workHoursEnabled => $composableBuilder(
    column: $table.workHoursEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workHoursStart => $composableBuilder(
    column: $table.workHoursStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workHoursEnd => $composableBuilder(
    column: $table.workHoursEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workDaysMask => $composableBuilder(
    column: $table.workDaysMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orchestratorPromptsJson => $composableBuilder(
    column: $table.orchestratorPromptsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setupStatus => $composableBuilder(
    column: $table.setupStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setupTranscriptJson => $composableBuilder(
    column: $table.setupTranscriptJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explorationStatus => $composableBuilder(
    column: $table.explorationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateStatus => $composableBuilder(
    column: $table.templateStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentMilestone => $composableBuilder(
    column: $table.currentMilestone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get milestoneCount => $composableBuilder(
    column: $table.milestoneCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectSummaryMd => $composableBuilder(
    column: $table.projectSummaryMd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get summaryUpdatedAt => $composableBuilder(
    column: $table.summaryUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get experienceMode => $composableBuilder(
    column: $table.experienceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableOrderingComposer get agent_persona_fk {
    final $$AgentPersonasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_persona_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableOrderingComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get project_pk => $composableBuilder(
    column: $table.project_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orchestrationState => $composableBuilder(
    column: $table.orchestrationState,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get workHoursEnabled => $composableBuilder(
    column: $table.workHoursEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get workHoursStart => $composableBuilder(
    column: $table.workHoursStart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get workHoursEnd => $composableBuilder(
    column: $table.workHoursEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get workDaysMask => $composableBuilder(
    column: $table.workDaysMask,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orchestratorPromptsJson => $composableBuilder(
    column: $table.orchestratorPromptsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get setupStatus => $composableBuilder(
    column: $table.setupStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get setupTranscriptJson => $composableBuilder(
    column: $table.setupTranscriptJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explorationStatus => $composableBuilder(
    column: $table.explorationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateStatus => $composableBuilder(
    column: $table.templateStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentMilestone => $composableBuilder(
    column: $table.currentMilestone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get milestoneCount => $composableBuilder(
    column: $table.milestoneCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectSummaryMd => $composableBuilder(
    column: $table.projectSummaryMd,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get summaryUpdatedAt => $composableBuilder(
    column: $table.summaryUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get experienceMode => $composableBuilder(
    column: $table.experienceMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableAnnotationComposer get agent_persona_fk {
    final $$AgentPersonasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.agent_persona_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableAnnotationComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> chatSessionsRefs<T extends Object>(
    Expression<T> Function($$ChatSessionsTableAnnotationComposer a) f,
  ) {
    final $$ChatSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userStoriesRefs<T extends Object>(
    Expression<T> Function($$UserStoriesTableAnnotationComposer a) f,
  ) {
    final $$UserStoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deploymentsRefs<T extends Object>(
    Expression<T> Function($$DeploymentsTableAnnotationComposer a) f,
  ) {
    final $$DeploymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.deployments,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeploymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.deployments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activityLogsRefs<T extends Object>(
    Expression<T> Function($$ActivityLogsTableAnnotationComposer a) f,
  ) {
    final $$ActivityLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.activityLogs,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.activityLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ciRunsRefs<T extends Object>(
    Expression<T> Function($$CiRunsTableAnnotationComposer a) f,
  ) {
    final $$CiRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectTagsRefs<T extends Object>(
    Expression<T> Function($$ProjectTagsTableAnnotationComposer a) f,
  ) {
    final $$ProjectTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.projectTags,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> callSystemsRefs<T extends Object>(
    Expression<T> Function($$CallSystemsTableAnnotationComposer a) f,
  ) {
    final $$CallSystemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_pk,
      referencedTable: $db.callSystems,
      getReferencedColumn: (t) => t.project_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CallSystemsTableAnnotationComposer(
            $db: $db,
            $table: $db.callSystems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool client_fk,
            bool agent_persona_fk,
            bool chatSessionsRefs,
            bool userStoriesRefs,
            bool tasksRefs,
            bool deploymentsRefs,
            bool activityLogsRefs,
            bool ciRunsRefs,
            bool projectTagsRefs,
            bool callSystemsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$NexusDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> project_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int?> agent_persona_fk = const Value.absent(),
                Value<String> orchestrationState = const Value.absent(),
                Value<bool> workHoursEnabled = const Value.absent(),
                Value<int?> workHoursStart = const Value.absent(),
                Value<int?> workHoursEnd = const Value.absent(),
                Value<int?> workDaysMask = const Value.absent(),
                Value<String?> orchestratorPromptsJson = const Value.absent(),
                Value<String> setupStatus = const Value.absent(),
                Value<String?> setupTranscriptJson = const Value.absent(),
                Value<String> explorationStatus = const Value.absent(),
                Value<String> templateStatus = const Value.absent(),
                Value<int> currentMilestone = const Value.absent(),
                Value<int> milestoneCount = const Value.absent(),
                Value<String?> projectSummaryMd = const Value.absent(),
                Value<DateTime?> summaryUpdatedAt = const Value.absent(),
                Value<String> projectType = const Value.absent(),
                Value<String?> subCategory = const Value.absent(),
                Value<String> experienceMode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProjectsCompanion(
                project_pk: project_pk,
                client_fk: client_fk,
                name: name,
                description: description,
                agent_persona_fk: agent_persona_fk,
                orchestrationState: orchestrationState,
                workHoursEnabled: workHoursEnabled,
                workHoursStart: workHoursStart,
                workHoursEnd: workHoursEnd,
                workDaysMask: workDaysMask,
                orchestratorPromptsJson: orchestratorPromptsJson,
                setupStatus: setupStatus,
                setupTranscriptJson: setupTranscriptJson,
                explorationStatus: explorationStatus,
                templateStatus: templateStatus,
                currentMilestone: currentMilestone,
                milestoneCount: milestoneCount,
                projectSummaryMd: projectSummaryMd,
                summaryUpdatedAt: summaryUpdatedAt,
                projectType: projectType,
                subCategory: subCategory,
                experienceMode: experienceMode,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> project_pk = const Value.absent(),
                required int client_fk,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<int?> agent_persona_fk = const Value.absent(),
                Value<String> orchestrationState = const Value.absent(),
                Value<bool> workHoursEnabled = const Value.absent(),
                Value<int?> workHoursStart = const Value.absent(),
                Value<int?> workHoursEnd = const Value.absent(),
                Value<int?> workDaysMask = const Value.absent(),
                Value<String?> orchestratorPromptsJson = const Value.absent(),
                Value<String> setupStatus = const Value.absent(),
                Value<String?> setupTranscriptJson = const Value.absent(),
                Value<String> explorationStatus = const Value.absent(),
                Value<String> templateStatus = const Value.absent(),
                Value<int> currentMilestone = const Value.absent(),
                Value<int> milestoneCount = const Value.absent(),
                Value<String?> projectSummaryMd = const Value.absent(),
                Value<DateTime?> summaryUpdatedAt = const Value.absent(),
                Value<String> projectType = const Value.absent(),
                Value<String?> subCategory = const Value.absent(),
                Value<String> experienceMode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProjectsCompanion.insert(
                project_pk: project_pk,
                client_fk: client_fk,
                name: name,
                description: description,
                agent_persona_fk: agent_persona_fk,
                orchestrationState: orchestrationState,
                workHoursEnabled: workHoursEnabled,
                workHoursStart: workHoursStart,
                workHoursEnd: workHoursEnd,
                workDaysMask: workDaysMask,
                orchestratorPromptsJson: orchestratorPromptsJson,
                setupStatus: setupStatus,
                setupTranscriptJson: setupTranscriptJson,
                explorationStatus: explorationStatus,
                templateStatus: templateStatus,
                currentMilestone: currentMilestone,
                milestoneCount: milestoneCount,
                projectSummaryMd: projectSummaryMd,
                summaryUpdatedAt: summaryUpdatedAt,
                projectType: projectType,
                subCategory: subCategory,
                experienceMode: experienceMode,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                client_fk = false,
                agent_persona_fk = false,
                chatSessionsRefs = false,
                userStoriesRefs = false,
                tasksRefs = false,
                deploymentsRefs = false,
                activityLogsRefs = false,
                ciRunsRefs = false,
                projectTagsRefs = false,
                callSystemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chatSessionsRefs) db.chatSessions,
                    if (userStoriesRefs) db.userStories,
                    if (tasksRefs) db.tasks,
                    if (deploymentsRefs) db.deployments,
                    if (activityLogsRefs) db.activityLogs,
                    if (ciRunsRefs) db.ciRuns,
                    if (projectTagsRefs) db.projectTags,
                    if (callSystemsRefs) db.callSystems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (client_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.client_fk,
                                    referencedTable: $$ProjectsTableReferences
                                        ._client_fkTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._client_fkTable(db)
                                        .client_pk,
                                  )
                                  as T;
                        }
                        if (agent_persona_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.agent_persona_fk,
                                    referencedTable: $$ProjectsTableReferences
                                        ._agent_persona_fkTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._agent_persona_fkTable(db)
                                        .agent_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chatSessionsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ChatSession
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._chatSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).chatSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (userStoriesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          UserStory
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._userStoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).userStoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.task_project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (deploymentsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Deployment
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._deploymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).deploymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (activityLogsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ActivityLog
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._activityLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).activityLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (ciRunsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          CiRun
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._ciRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).ciRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (projectTagsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ProjectTag
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                      if (callSystemsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          CallSystem
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._callSystemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).callSystemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.project_fk == item.project_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool client_fk,
        bool agent_persona_fk,
        bool chatSessionsRefs,
        bool userStoriesRefs,
        bool tasksRefs,
        bool deploymentsRefs,
        bool activityLogsRefs,
        bool ciRunsRefs,
        bool projectTagsRefs,
        bool callSystemsRefs,
      })
    >;
typedef $$ChatSessionsTableCreateCompanionBuilder =
    ChatSessionsCompanion Function({
      Value<int> session_pk,
      required int project_fk,
      Value<String?> plan_path,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ChatSessionsTableUpdateCompanionBuilder =
    ChatSessionsCompanion Function({
      Value<int> session_pk,
      Value<int> project_fk,
      Value<String?> plan_path,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ChatSessionsTableReferences
    extends BaseReferences<_$NexusDatabase, $ChatSessionsTable, ChatSession> {
  $$ChatSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) => db.projects
      .createAlias('chat_sessions__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager get project_fk {
    final $_column = $_itemColumn<int>('project_fk')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _creatorTasksTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'chat_sessions__session_pk__tasks__task_chat_session_fk',
  );

  $$TasksTableProcessedTableManager get creatorTasks {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.task_chat_session_fk.session_pk.sqlEquals(
        $_itemColumn<int>('session_pk')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_creatorTasksTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _workerTasksTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'chat_sessions__session_pk__tasks__worker_session_fk',
  );

  $$TasksTableProcessedTableManager get workerTasks {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.worker_session_fk.session_pk.sqlEquals(
        $_itemColumn<int>('session_pk')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_workerTasksTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChatMessagesTable, List<ChatMessage>>
  _chatMessagesRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.chatMessages,
    aliasName: 'chat_sessions__session_pk__chat_messages__session_fk',
  );

  $$ChatMessagesTableProcessedTableManager get chatMessagesRefs {
    final manager = $$ChatMessagesTableTableManager($_db, $_db.chatMessages)
        .filter(
          (f) => f.session_fk.session_pk.sqlEquals(
            $_itemColumn<int>('session_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_chatMessagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChatSessionsTableFilterComposer
    extends Composer<_$NexusDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get session_pk => $composableBuilder(
    column: $table.session_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plan_path => $composableBuilder(
    column: $table.plan_path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> creatorTasks(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_chat_session_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workerTasks(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.worker_session_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chatMessagesRefs(
    Expression<bool> Function($$ChatMessagesTableFilterComposer f) f,
  ) {
    final $$ChatMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_pk,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.session_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatMessagesTableFilterComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChatSessionsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get session_pk => $composableBuilder(
    column: $table.session_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plan_path => $composableBuilder(
    column: $table.plan_path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatSessionsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get session_pk => $composableBuilder(
    column: $table.session_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plan_path =>
      $composableBuilder(column: $table.plan_path, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> creatorTasks<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_chat_session_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workerTasks<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.worker_session_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> chatMessagesRefs<T extends Object>(
    Expression<T> Function($$ChatMessagesTableAnnotationComposer a) f,
  ) {
    final $$ChatMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_pk,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.session_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChatSessionsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ChatSessionsTable,
          ChatSession,
          $$ChatSessionsTableFilterComposer,
          $$ChatSessionsTableOrderingComposer,
          $$ChatSessionsTableAnnotationComposer,
          $$ChatSessionsTableCreateCompanionBuilder,
          $$ChatSessionsTableUpdateCompanionBuilder,
          (ChatSession, $$ChatSessionsTableReferences),
          ChatSession,
          PrefetchHooks Function({
            bool project_fk,
            bool creatorTasks,
            bool workerTasks,
            bool chatMessagesRefs,
          })
        > {
  $$ChatSessionsTableTableManager(_$NexusDatabase db, $ChatSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> session_pk = const Value.absent(),
                Value<int> project_fk = const Value.absent(),
                Value<String?> plan_path = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChatSessionsCompanion(
                session_pk: session_pk,
                project_fk: project_fk,
                plan_path: plan_path,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> session_pk = const Value.absent(),
                required int project_fk,
                Value<String?> plan_path = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChatSessionsCompanion.insert(
                session_pk: session_pk,
                project_fk: project_fk,
                plan_path: plan_path,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChatSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                project_fk = false,
                creatorTasks = false,
                workerTasks = false,
                chatMessagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (creatorTasks) db.tasks,
                    if (workerTasks) db.tasks,
                    if (chatMessagesRefs) db.chatMessages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (project_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.project_fk,
                                    referencedTable:
                                        $$ChatSessionsTableReferences
                                            ._project_fkTable(db),
                                    referencedColumn:
                                        $$ChatSessionsTableReferences
                                            ._project_fkTable(db)
                                            .project_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (creatorTasks)
                        await $_getPrefetchedData<
                          ChatSession,
                          $ChatSessionsTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$ChatSessionsTableReferences
                              ._creatorTasksTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChatSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).creatorTasks,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) =>
                                    e.task_chat_session_fk == item.session_pk,
                              ),
                          typedResults: items,
                        ),
                      if (workerTasks)
                        await $_getPrefetchedData<
                          ChatSession,
                          $ChatSessionsTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$ChatSessionsTableReferences
                              ._workerTasksTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChatSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).workerTasks,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.worker_session_fk == item.session_pk,
                              ),
                          typedResults: items,
                        ),
                      if (chatMessagesRefs)
                        await $_getPrefetchedData<
                          ChatSession,
                          $ChatSessionsTable,
                          ChatMessage
                        >(
                          currentTable: table,
                          referencedTable: $$ChatSessionsTableReferences
                              ._chatMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChatSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).chatMessagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.session_fk == item.session_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChatSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ChatSessionsTable,
      ChatSession,
      $$ChatSessionsTableFilterComposer,
      $$ChatSessionsTableOrderingComposer,
      $$ChatSessionsTableAnnotationComposer,
      $$ChatSessionsTableCreateCompanionBuilder,
      $$ChatSessionsTableUpdateCompanionBuilder,
      (ChatSession, $$ChatSessionsTableReferences),
      ChatSession,
      PrefetchHooks Function({
        bool project_fk,
        bool creatorTasks,
        bool workerTasks,
        bool chatMessagesRefs,
      })
    >;
typedef $$UserStoriesTableCreateCompanionBuilder =
    UserStoriesCompanion Function({
      Value<int> story_pk,
      required int project_fk,
      Value<int?> parent_story_fk,
      required String title,
      Value<String> narrative,
      Value<String?> acceptanceCriteria,
      Value<String> kind,
      Value<String> status,
      Value<double?> posX,
      Value<double?> posY,
      Value<int> orderIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$UserStoriesTableUpdateCompanionBuilder =
    UserStoriesCompanion Function({
      Value<int> story_pk,
      Value<int> project_fk,
      Value<int?> parent_story_fk,
      Value<String> title,
      Value<String> narrative,
      Value<String?> acceptanceCriteria,
      Value<String> kind,
      Value<String> status,
      Value<double?> posX,
      Value<double?> posY,
      Value<int> orderIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$UserStoriesTableReferences
    extends BaseReferences<_$NexusDatabase, $UserStoriesTable, UserStory> {
  $$UserStoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) =>
      db.projects.createAlias('user_stories__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager get project_fk {
    final $_column = $_itemColumn<int>('project_fk')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UserStoriesTable _parent_story_fkTable(_$NexusDatabase db) => db
      .userStories
      .createAlias('user_stories__parent_story_fk__user_stories__story_pk');

  $$UserStoriesTableProcessedTableManager? get parent_story_fk {
    final $_column = $_itemColumn<int>('parent_story_fk');
    if ($_column == null) return null;
    final manager = $$UserStoriesTableTableManager(
      $_db,
      $_db.userStories,
    ).filter((f) => f.story_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parent_story_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'user_stories__story_pk__tasks__task_story_fk',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.task_story_fk.story_pk.sqlEquals($_itemColumn<int>('story_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StoryNotesTable, List<StoryNote>>
  _storyNotesRefsTable(_$NexusDatabase db) => MultiTypedResultKey.fromTable(
    db.storyNotes,
    aliasName: 'user_stories__story_pk__story_notes__story_fk',
  );

  $$StoryNotesTableProcessedTableManager get storyNotesRefs {
    final manager = $$StoryNotesTableTableManager($_db, $_db.storyNotes).filter(
      (f) => f.story_fk.story_pk.sqlEquals($_itemColumn<int>('story_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_storyNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserStoriesTableFilterComposer
    extends Composer<_$NexusDatabase, $UserStoriesTable> {
  $$UserStoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get story_pk => $composableBuilder(
    column: $table.story_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptanceCriteria => $composableBuilder(
    column: $table.acceptanceCriteria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserStoriesTableFilterComposer get parent_story_fk {
    final $$UserStoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parent_story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableFilterComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_story_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> storyNotesRefs(
    Expression<bool> Function($$StoryNotesTableFilterComposer f) f,
  ) {
    final $$StoryNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_pk,
      referencedTable: $db.storyNotes,
      getReferencedColumn: (t) => t.story_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryNotesTableFilterComposer(
            $db: $db,
            $table: $db.storyNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserStoriesTableOrderingComposer
    extends Composer<_$NexusDatabase, $UserStoriesTable> {
  $$UserStoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get story_pk => $composableBuilder(
    column: $table.story_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptanceCriteria => $composableBuilder(
    column: $table.acceptanceCriteria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserStoriesTableOrderingComposer get parent_story_fk {
    final $$UserStoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parent_story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableOrderingComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserStoriesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $UserStoriesTable> {
  $$UserStoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get story_pk =>
      $composableBuilder(column: $table.story_pk, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get narrative =>
      $composableBuilder(column: $table.narrative, builder: (column) => column);

  GeneratedColumn<String> get acceptanceCriteria => $composableBuilder(
    column: $table.acceptanceCriteria,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get posX =>
      $composableBuilder(column: $table.posX, builder: (column) => column);

  GeneratedColumn<double> get posY =>
      $composableBuilder(column: $table.posY, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserStoriesTableAnnotationComposer get parent_story_fk {
    final $$UserStoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parent_story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_pk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_story_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> storyNotesRefs<T extends Object>(
    Expression<T> Function($$StoryNotesTableAnnotationComposer a) f,
  ) {
    final $$StoryNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_pk,
      referencedTable: $db.storyNotes,
      getReferencedColumn: (t) => t.story_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.storyNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserStoriesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $UserStoriesTable,
          UserStory,
          $$UserStoriesTableFilterComposer,
          $$UserStoriesTableOrderingComposer,
          $$UserStoriesTableAnnotationComposer,
          $$UserStoriesTableCreateCompanionBuilder,
          $$UserStoriesTableUpdateCompanionBuilder,
          (UserStory, $$UserStoriesTableReferences),
          UserStory,
          PrefetchHooks Function({
            bool project_fk,
            bool parent_story_fk,
            bool tasksRefs,
            bool storyNotesRefs,
          })
        > {
  $$UserStoriesTableTableManager(_$NexusDatabase db, $UserStoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> story_pk = const Value.absent(),
                Value<int> project_fk = const Value.absent(),
                Value<int?> parent_story_fk = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> narrative = const Value.absent(),
                Value<String?> acceptanceCriteria = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> posX = const Value.absent(),
                Value<double?> posY = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserStoriesCompanion(
                story_pk: story_pk,
                project_fk: project_fk,
                parent_story_fk: parent_story_fk,
                title: title,
                narrative: narrative,
                acceptanceCriteria: acceptanceCriteria,
                kind: kind,
                status: status,
                posX: posX,
                posY: posY,
                orderIndex: orderIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> story_pk = const Value.absent(),
                required int project_fk,
                Value<int?> parent_story_fk = const Value.absent(),
                required String title,
                Value<String> narrative = const Value.absent(),
                Value<String?> acceptanceCriteria = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> posX = const Value.absent(),
                Value<double?> posY = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserStoriesCompanion.insert(
                story_pk: story_pk,
                project_fk: project_fk,
                parent_story_fk: parent_story_fk,
                title: title,
                narrative: narrative,
                acceptanceCriteria: acceptanceCriteria,
                kind: kind,
                status: status,
                posX: posX,
                posY: posY,
                orderIndex: orderIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserStoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                project_fk = false,
                parent_story_fk = false,
                tasksRefs = false,
                storyNotesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tasksRefs) db.tasks,
                    if (storyNotesRefs) db.storyNotes,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (project_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.project_fk,
                                    referencedTable:
                                        $$UserStoriesTableReferences
                                            ._project_fkTable(db),
                                    referencedColumn:
                                        $$UserStoriesTableReferences
                                            ._project_fkTable(db)
                                            .project_pk,
                                  )
                                  as T;
                        }
                        if (parent_story_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parent_story_fk,
                                    referencedTable:
                                        $$UserStoriesTableReferences
                                            ._parent_story_fkTable(db),
                                    referencedColumn:
                                        $$UserStoriesTableReferences
                                            ._parent_story_fkTable(db)
                                            .story_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tasksRefs)
                        await $_getPrefetchedData<
                          UserStory,
                          $UserStoriesTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$UserStoriesTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserStoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.task_story_fk == item.story_pk,
                              ),
                          typedResults: items,
                        ),
                      if (storyNotesRefs)
                        await $_getPrefetchedData<
                          UserStory,
                          $UserStoriesTable,
                          StoryNote
                        >(
                          currentTable: table,
                          referencedTable: $$UserStoriesTableReferences
                              ._storyNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserStoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).storyNotesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.story_fk == item.story_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UserStoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $UserStoriesTable,
      UserStory,
      $$UserStoriesTableFilterComposer,
      $$UserStoriesTableOrderingComposer,
      $$UserStoriesTableAnnotationComposer,
      $$UserStoriesTableCreateCompanionBuilder,
      $$UserStoriesTableUpdateCompanionBuilder,
      (UserStory, $$UserStoriesTableReferences),
      UserStory,
      PrefetchHooks Function({
        bool project_fk,
        bool parent_story_fk,
        bool tasksRefs,
        bool storyNotesRefs,
      })
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      Value<int> task_pk,
      required int task_client_fk,
      required int task_project_fk,
      Value<int?> task_parent_fk,
      Value<String?> task_plan_path,
      Value<int?> task_chat_session_fk,
      Value<int?> task_agent_fk,
      Value<int?> task_story_fk,
      required String title,
      Value<String?> description,
      Value<String> status,
      Value<String> priority,
      Value<String?> thinkingMode,
      Value<int> tokenCost,
      Value<double> usdCost,
      Value<String?> acceptanceCriteria,
      Value<String?> verification,
      Value<String> executionStatus,
      Value<String?> submissionJson,
      Value<int?> worker_session_fk,
      Value<String?> workBranch,
      Value<int?> milestoneOrder,
      Value<bool> isEdit,
      Value<bool> requiresBuild,
      Value<String?> dockerfilePath,
      Value<String?> workflowPath,
      Value<String?> imageTag,
      Value<DateTime?> startDate,
      Value<DateTime?> dueDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<int> task_pk,
      Value<int> task_client_fk,
      Value<int> task_project_fk,
      Value<int?> task_parent_fk,
      Value<String?> task_plan_path,
      Value<int?> task_chat_session_fk,
      Value<int?> task_agent_fk,
      Value<int?> task_story_fk,
      Value<String> title,
      Value<String?> description,
      Value<String> status,
      Value<String> priority,
      Value<String?> thinkingMode,
      Value<int> tokenCost,
      Value<double> usdCost,
      Value<String?> acceptanceCriteria,
      Value<String?> verification,
      Value<String> executionStatus,
      Value<String?> submissionJson,
      Value<int?> worker_session_fk,
      Value<String?> workBranch,
      Value<int?> milestoneOrder,
      Value<bool> isEdit,
      Value<bool> requiresBuild,
      Value<String?> dockerfilePath,
      Value<String?> workflowPath,
      Value<String?> imageTag,
      Value<DateTime?> startDate,
      Value<DateTime?> dueDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$NexusDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _task_client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('tasks__task_client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get task_client_fk {
    final $_column = $_itemColumn<int>('task_client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_task_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _task_project_fkTable(_$NexusDatabase db) =>
      db.projects.createAlias('tasks__task_project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager get task_project_fk {
    final $_column = $_itemColumn<int>('task_project_fk')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_task_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TasksTable _task_parent_fkTable(_$NexusDatabase db) =>
      db.tasks.createAlias('tasks__task_parent_fk__tasks__task_pk');

  $$TasksTableProcessedTableManager? get task_parent_fk {
    final $_column = $_itemColumn<int>('task_parent_fk');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.task_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_task_parent_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChatSessionsTable _task_chat_session_fkTable(_$NexusDatabase db) => db
      .chatSessions
      .createAlias('tasks__task_chat_session_fk__chat_sessions__session_pk');

  $$ChatSessionsTableProcessedTableManager? get task_chat_session_fk {
    final $_column = $_itemColumn<int>('task_chat_session_fk');
    if ($_column == null) return null;
    final manager = $$ChatSessionsTableTableManager(
      $_db,
      $_db.chatSessions,
    ).filter((f) => f.session_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _task_chat_session_fkTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AgentPersonasTable _task_agent_fkTable(_$NexusDatabase db) => db
      .agentPersonas
      .createAlias('tasks__task_agent_fk__agent_personas__agent_pk');

  $$AgentPersonasTableProcessedTableManager? get task_agent_fk {
    final $_column = $_itemColumn<int>('task_agent_fk');
    if ($_column == null) return null;
    final manager = $$AgentPersonasTableTableManager(
      $_db,
      $_db.agentPersonas,
    ).filter((f) => f.agent_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_task_agent_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UserStoriesTable _task_story_fkTable(_$NexusDatabase db) => db
      .userStories
      .createAlias('tasks__task_story_fk__user_stories__story_pk');

  $$UserStoriesTableProcessedTableManager? get task_story_fk {
    final $_column = $_itemColumn<int>('task_story_fk');
    if ($_column == null) return null;
    final manager = $$UserStoriesTableTableManager(
      $_db,
      $_db.userStories,
    ).filter((f) => f.story_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_task_story_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChatSessionsTable _worker_session_fkTable(_$NexusDatabase db) => db
      .chatSessions
      .createAlias('tasks__worker_session_fk__chat_sessions__session_pk');

  $$ChatSessionsTableProcessedTableManager? get worker_session_fk {
    final $_column = $_itemColumn<int>('worker_session_fk');
    if ($_column == null) return null;
    final manager = $$ChatSessionsTableTableManager(
      $_db,
      $_db.chatSessions,
    ).filter((f) => f.session_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_worker_session_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CiRunsTable, List<CiRun>> _ciRunsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ciRuns,
    aliasName: 'tasks__task_pk__ci_runs__task_fk',
  );

  $$CiRunsTableProcessedTableManager get ciRunsRefs {
    final manager = $$CiRunsTableTableManager(
      $_db,
      $_db.ciRuns,
    ).filter((f) => f.task_fk.task_pk.sqlEquals($_itemColumn<int>('task_pk')!));

    final cache = $_typedResult.readTableOrNull(_ciRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer
    extends Composer<_$NexusDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get task_pk => $composableBuilder(
    column: $table.task_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get task_plan_path => $composableBuilder(
    column: $table.task_plan_path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thinkingMode => $composableBuilder(
    column: $table.thinkingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokenCost => $composableBuilder(
    column: $table.tokenCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get usdCost => $composableBuilder(
    column: $table.usdCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptanceCriteria => $composableBuilder(
    column: $table.acceptanceCriteria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verification => $composableBuilder(
    column: $table.verification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionStatus => $composableBuilder(
    column: $table.executionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get submissionJson => $composableBuilder(
    column: $table.submissionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workBranch => $composableBuilder(
    column: $table.workBranch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get milestoneOrder => $composableBuilder(
    column: $table.milestoneOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdit => $composableBuilder(
    column: $table.isEdit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresBuild => $composableBuilder(
    column: $table.requiresBuild,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dockerfilePath => $composableBuilder(
    column: $table.dockerfilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowPath => $composableBuilder(
    column: $table.workflowPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get task_client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get task_project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableFilterComposer get task_parent_fk {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_parent_fk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChatSessionsTableFilterComposer get task_chat_session_fk {
    final $$ChatSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_chat_session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableFilterComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableFilterComposer get task_agent_fk {
    final $$AgentPersonasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_agent_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableFilterComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserStoriesTableFilterComposer get task_story_fk {
    final $$UserStoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableFilterComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChatSessionsTableFilterComposer get worker_session_fk {
    final $$ChatSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worker_session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableFilterComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> ciRunsRefs(
    Expression<bool> Function($$CiRunsTableFilterComposer f) f,
  ) {
    final $$CiRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_pk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.task_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableFilterComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$NexusDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get task_pk => $composableBuilder(
    column: $table.task_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get task_plan_path => $composableBuilder(
    column: $table.task_plan_path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thinkingMode => $composableBuilder(
    column: $table.thinkingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokenCost => $composableBuilder(
    column: $table.tokenCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get usdCost => $composableBuilder(
    column: $table.usdCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptanceCriteria => $composableBuilder(
    column: $table.acceptanceCriteria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verification => $composableBuilder(
    column: $table.verification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionStatus => $composableBuilder(
    column: $table.executionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get submissionJson => $composableBuilder(
    column: $table.submissionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workBranch => $composableBuilder(
    column: $table.workBranch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get milestoneOrder => $composableBuilder(
    column: $table.milestoneOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdit => $composableBuilder(
    column: $table.isEdit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresBuild => $composableBuilder(
    column: $table.requiresBuild,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dockerfilePath => $composableBuilder(
    column: $table.dockerfilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowPath => $composableBuilder(
    column: $table.workflowPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get task_client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get task_project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableOrderingComposer get task_parent_fk {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_parent_fk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChatSessionsTableOrderingComposer get task_chat_session_fk {
    final $$ChatSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_chat_session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableOrderingComposer get task_agent_fk {
    final $$AgentPersonasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_agent_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableOrderingComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserStoriesTableOrderingComposer get task_story_fk {
    final $$UserStoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableOrderingComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChatSessionsTableOrderingComposer get worker_session_fk {
    final $$ChatSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worker_session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$NexusDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get task_pk =>
      $composableBuilder(column: $table.task_pk, builder: (column) => column);

  GeneratedColumn<String> get task_plan_path => $composableBuilder(
    column: $table.task_plan_path,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get thinkingMode => $composableBuilder(
    column: $table.thinkingMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tokenCost =>
      $composableBuilder(column: $table.tokenCost, builder: (column) => column);

  GeneratedColumn<double> get usdCost =>
      $composableBuilder(column: $table.usdCost, builder: (column) => column);

  GeneratedColumn<String> get acceptanceCriteria => $composableBuilder(
    column: $table.acceptanceCriteria,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verification => $composableBuilder(
    column: $table.verification,
    builder: (column) => column,
  );

  GeneratedColumn<String> get executionStatus => $composableBuilder(
    column: $table.executionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get submissionJson => $composableBuilder(
    column: $table.submissionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workBranch => $composableBuilder(
    column: $table.workBranch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get milestoneOrder => $composableBuilder(
    column: $table.milestoneOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEdit =>
      $composableBuilder(column: $table.isEdit, builder: (column) => column);

  GeneratedColumn<bool> get requiresBuild => $composableBuilder(
    column: $table.requiresBuild,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dockerfilePath => $composableBuilder(
    column: $table.dockerfilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workflowPath => $composableBuilder(
    column: $table.workflowPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get task_client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get task_project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableAnnotationComposer get task_parent_fk {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_parent_fk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChatSessionsTableAnnotationComposer get task_chat_session_fk {
    final $$ChatSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_chat_session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AgentPersonasTableAnnotationComposer get task_agent_fk {
    final $$AgentPersonasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_agent_fk,
      referencedTable: $db.agentPersonas,
      getReferencedColumn: (t) => t.agent_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentPersonasTableAnnotationComposer(
            $db: $db,
            $table: $db.agentPersonas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserStoriesTableAnnotationComposer get task_story_fk {
    final $$UserStoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChatSessionsTableAnnotationComposer get worker_session_fk {
    final $$ChatSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worker_session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> ciRunsRefs<T extends Object>(
    Expression<T> Function($$CiRunsTableAnnotationComposer a) f,
  ) {
    final $$CiRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_pk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.task_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({
            bool task_client_fk,
            bool task_project_fk,
            bool task_parent_fk,
            bool task_chat_session_fk,
            bool task_agent_fk,
            bool task_story_fk,
            bool worker_session_fk,
            bool ciRunsRefs,
          })
        > {
  $$TasksTableTableManager(_$NexusDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> task_pk = const Value.absent(),
                Value<int> task_client_fk = const Value.absent(),
                Value<int> task_project_fk = const Value.absent(),
                Value<int?> task_parent_fk = const Value.absent(),
                Value<String?> task_plan_path = const Value.absent(),
                Value<int?> task_chat_session_fk = const Value.absent(),
                Value<int?> task_agent_fk = const Value.absent(),
                Value<int?> task_story_fk = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> thinkingMode = const Value.absent(),
                Value<int> tokenCost = const Value.absent(),
                Value<double> usdCost = const Value.absent(),
                Value<String?> acceptanceCriteria = const Value.absent(),
                Value<String?> verification = const Value.absent(),
                Value<String> executionStatus = const Value.absent(),
                Value<String?> submissionJson = const Value.absent(),
                Value<int?> worker_session_fk = const Value.absent(),
                Value<String?> workBranch = const Value.absent(),
                Value<int?> milestoneOrder = const Value.absent(),
                Value<bool> isEdit = const Value.absent(),
                Value<bool> requiresBuild = const Value.absent(),
                Value<String?> dockerfilePath = const Value.absent(),
                Value<String?> workflowPath = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TasksCompanion(
                task_pk: task_pk,
                task_client_fk: task_client_fk,
                task_project_fk: task_project_fk,
                task_parent_fk: task_parent_fk,
                task_plan_path: task_plan_path,
                task_chat_session_fk: task_chat_session_fk,
                task_agent_fk: task_agent_fk,
                task_story_fk: task_story_fk,
                title: title,
                description: description,
                status: status,
                priority: priority,
                thinkingMode: thinkingMode,
                tokenCost: tokenCost,
                usdCost: usdCost,
                acceptanceCriteria: acceptanceCriteria,
                verification: verification,
                executionStatus: executionStatus,
                submissionJson: submissionJson,
                worker_session_fk: worker_session_fk,
                workBranch: workBranch,
                milestoneOrder: milestoneOrder,
                isEdit: isEdit,
                requiresBuild: requiresBuild,
                dockerfilePath: dockerfilePath,
                workflowPath: workflowPath,
                imageTag: imageTag,
                startDate: startDate,
                dueDate: dueDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> task_pk = const Value.absent(),
                required int task_client_fk,
                required int task_project_fk,
                Value<int?> task_parent_fk = const Value.absent(),
                Value<String?> task_plan_path = const Value.absent(),
                Value<int?> task_chat_session_fk = const Value.absent(),
                Value<int?> task_agent_fk = const Value.absent(),
                Value<int?> task_story_fk = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> thinkingMode = const Value.absent(),
                Value<int> tokenCost = const Value.absent(),
                Value<double> usdCost = const Value.absent(),
                Value<String?> acceptanceCriteria = const Value.absent(),
                Value<String?> verification = const Value.absent(),
                Value<String> executionStatus = const Value.absent(),
                Value<String?> submissionJson = const Value.absent(),
                Value<int?> worker_session_fk = const Value.absent(),
                Value<String?> workBranch = const Value.absent(),
                Value<int?> milestoneOrder = const Value.absent(),
                Value<bool> isEdit = const Value.absent(),
                Value<bool> requiresBuild = const Value.absent(),
                Value<String?> dockerfilePath = const Value.absent(),
                Value<String?> workflowPath = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TasksCompanion.insert(
                task_pk: task_pk,
                task_client_fk: task_client_fk,
                task_project_fk: task_project_fk,
                task_parent_fk: task_parent_fk,
                task_plan_path: task_plan_path,
                task_chat_session_fk: task_chat_session_fk,
                task_agent_fk: task_agent_fk,
                task_story_fk: task_story_fk,
                title: title,
                description: description,
                status: status,
                priority: priority,
                thinkingMode: thinkingMode,
                tokenCost: tokenCost,
                usdCost: usdCost,
                acceptanceCriteria: acceptanceCriteria,
                verification: verification,
                executionStatus: executionStatus,
                submissionJson: submissionJson,
                worker_session_fk: worker_session_fk,
                workBranch: workBranch,
                milestoneOrder: milestoneOrder,
                isEdit: isEdit,
                requiresBuild: requiresBuild,
                dockerfilePath: dockerfilePath,
                workflowPath: workflowPath,
                imageTag: imageTag,
                startDate: startDate,
                dueDate: dueDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                task_client_fk = false,
                task_project_fk = false,
                task_parent_fk = false,
                task_chat_session_fk = false,
                task_agent_fk = false,
                task_story_fk = false,
                worker_session_fk = false,
                ciRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (ciRunsRefs) db.ciRuns],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (task_client_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_client_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._task_client_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._task_client_fkTable(db)
                                        .client_pk,
                                  )
                                  as T;
                        }
                        if (task_project_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_project_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._task_project_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._task_project_fkTable(db)
                                        .project_pk,
                                  )
                                  as T;
                        }
                        if (task_parent_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_parent_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._task_parent_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._task_parent_fkTable(db)
                                        .task_pk,
                                  )
                                  as T;
                        }
                        if (task_chat_session_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_chat_session_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._task_chat_session_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._task_chat_session_fkTable(db)
                                        .session_pk,
                                  )
                                  as T;
                        }
                        if (task_agent_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_agent_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._task_agent_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._task_agent_fkTable(db)
                                        .agent_pk,
                                  )
                                  as T;
                        }
                        if (task_story_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_story_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._task_story_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._task_story_fkTable(db)
                                        .story_pk,
                                  )
                                  as T;
                        }
                        if (worker_session_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.worker_session_fk,
                                    referencedTable: $$TasksTableReferences
                                        ._worker_session_fkTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._worker_session_fkTable(db)
                                        .session_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (ciRunsRefs)
                        await $_getPrefetchedData<Task, $TasksTable, CiRun>(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._ciRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(db, table, p0).ciRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.task_fk == item.task_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({
        bool task_client_fk,
        bool task_project_fk,
        bool task_parent_fk,
        bool task_chat_session_fk,
        bool task_agent_fk,
        bool task_story_fk,
        bool worker_session_fk,
        bool ciRunsRefs,
      })
    >;
typedef $$SkillsTableCreateCompanionBuilder =
    SkillsCompanion Function({
      Value<int> skill_pk,
      required int client_fk,
      required String name,
      Value<String?> description,
      Value<String> category,
      Value<String> riskLevel,
      Value<String> defaultPermission,
      Value<String> configJson,
      Value<bool> isPrefab,
      Value<int?> prefab_fk,
      Value<String> overridesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$SkillsTableUpdateCompanionBuilder =
    SkillsCompanion Function({
      Value<int> skill_pk,
      Value<int> client_fk,
      Value<String> name,
      Value<String?> description,
      Value<String> category,
      Value<String> riskLevel,
      Value<String> defaultPermission,
      Value<String> configJson,
      Value<bool> isPrefab,
      Value<int?> prefab_fk,
      Value<String> overridesJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$SkillsTableReferences
    extends BaseReferences<_$NexusDatabase, $SkillsTable, Skill> {
  $$SkillsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('skills__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SkillsTable _prefab_fkTable(_$NexusDatabase db) =>
      db.skills.createAlias('skills__prefab_fk__skills__skill_pk');

  $$SkillsTableProcessedTableManager? get prefab_fk {
    final $_column = $_itemColumn<int>('prefab_fk');
    if ($_column == null) return null;
    final manager = $$SkillsTableTableManager(
      $_db,
      $_db.skills,
    ).filter((f) => f.skill_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_prefab_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SkillsTableFilterComposer
    extends Composer<_$NexusDatabase, $SkillsTable> {
  $$SkillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get skill_pk => $composableBuilder(
    column: $table.skill_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultPermission => $composableBuilder(
    column: $table.defaultPermission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrefab => $composableBuilder(
    column: $table.isPrefab,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SkillsTableFilterComposer get prefab_fk {
    final $$SkillsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prefab_fk,
      referencedTable: $db.skills,
      getReferencedColumn: (t) => t.skill_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillsTableFilterComposer(
            $db: $db,
            $table: $db.skills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkillsTableOrderingComposer
    extends Composer<_$NexusDatabase, $SkillsTable> {
  $$SkillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get skill_pk => $composableBuilder(
    column: $table.skill_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultPermission => $composableBuilder(
    column: $table.defaultPermission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrefab => $composableBuilder(
    column: $table.isPrefab,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SkillsTableOrderingComposer get prefab_fk {
    final $$SkillsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prefab_fk,
      referencedTable: $db.skills,
      getReferencedColumn: (t) => t.skill_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillsTableOrderingComposer(
            $db: $db,
            $table: $db.skills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkillsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $SkillsTable> {
  $$SkillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get skill_pk =>
      $composableBuilder(column: $table.skill_pk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get riskLevel =>
      $composableBuilder(column: $table.riskLevel, builder: (column) => column);

  GeneratedColumn<String> get defaultPermission => $composableBuilder(
    column: $table.defaultPermission,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrefab =>
      $composableBuilder(column: $table.isPrefab, builder: (column) => column);

  GeneratedColumn<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SkillsTableAnnotationComposer get prefab_fk {
    final $$SkillsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.prefab_fk,
      referencedTable: $db.skills,
      getReferencedColumn: (t) => t.skill_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillsTableAnnotationComposer(
            $db: $db,
            $table: $db.skills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkillsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $SkillsTable,
          Skill,
          $$SkillsTableFilterComposer,
          $$SkillsTableOrderingComposer,
          $$SkillsTableAnnotationComposer,
          $$SkillsTableCreateCompanionBuilder,
          $$SkillsTableUpdateCompanionBuilder,
          (Skill, $$SkillsTableReferences),
          Skill,
          PrefetchHooks Function({bool client_fk, bool prefab_fk})
        > {
  $$SkillsTableTableManager(_$NexusDatabase db, $SkillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> skill_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> riskLevel = const Value.absent(),
                Value<String> defaultPermission = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<bool> isPrefab = const Value.absent(),
                Value<int?> prefab_fk = const Value.absent(),
                Value<String> overridesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SkillsCompanion(
                skill_pk: skill_pk,
                client_fk: client_fk,
                name: name,
                description: description,
                category: category,
                riskLevel: riskLevel,
                defaultPermission: defaultPermission,
                configJson: configJson,
                isPrefab: isPrefab,
                prefab_fk: prefab_fk,
                overridesJson: overridesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> skill_pk = const Value.absent(),
                required int client_fk,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> riskLevel = const Value.absent(),
                Value<String> defaultPermission = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<bool> isPrefab = const Value.absent(),
                Value<int?> prefab_fk = const Value.absent(),
                Value<String> overridesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SkillsCompanion.insert(
                skill_pk: skill_pk,
                client_fk: client_fk,
                name: name,
                description: description,
                category: category,
                riskLevel: riskLevel,
                defaultPermission: defaultPermission,
                configJson: configJson,
                isPrefab: isPrefab,
                prefab_fk: prefab_fk,
                overridesJson: overridesJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SkillsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({client_fk = false, prefab_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (client_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.client_fk,
                                referencedTable: $$SkillsTableReferences
                                    ._client_fkTable(db),
                                referencedColumn: $$SkillsTableReferences
                                    ._client_fkTable(db)
                                    .client_pk,
                              )
                              as T;
                    }
                    if (prefab_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.prefab_fk,
                                referencedTable: $$SkillsTableReferences
                                    ._prefab_fkTable(db),
                                referencedColumn: $$SkillsTableReferences
                                    ._prefab_fkTable(db)
                                    .skill_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SkillsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $SkillsTable,
      Skill,
      $$SkillsTableFilterComposer,
      $$SkillsTableOrderingComposer,
      $$SkillsTableAnnotationComposer,
      $$SkillsTableCreateCompanionBuilder,
      $$SkillsTableUpdateCompanionBuilder,
      (Skill, $$SkillsTableReferences),
      Skill,
      PrefetchHooks Function({bool client_fk, bool prefab_fk})
    >;
typedef $$DeploymentsTableCreateCompanionBuilder =
    DeploymentsCompanion Function({
      Value<int> deployment_pk,
      required int client_fk,
      Value<int?> project_fk,
      required String name,
      Value<String> environment,
      Value<String> status,
      Value<String?> triggeredBy,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<String> metadataJson,
    });
typedef $$DeploymentsTableUpdateCompanionBuilder =
    DeploymentsCompanion Function({
      Value<int> deployment_pk,
      Value<int> client_fk,
      Value<int?> project_fk,
      Value<String> name,
      Value<String> environment,
      Value<String> status,
      Value<String?> triggeredBy,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<String> metadataJson,
    });

final class $$DeploymentsTableReferences
    extends BaseReferences<_$NexusDatabase, $DeploymentsTable, Deployment> {
  $$DeploymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('deployments__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) =>
      db.projects.createAlias('deployments__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager? get project_fk {
    final $_column = $_itemColumn<int>('project_fk');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeploymentsTableFilterComposer
    extends Composer<_$NexusDatabase, $DeploymentsTable> {
  $$DeploymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get deployment_pk => $composableBuilder(
    column: $table.deployment_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggeredBy => $composableBuilder(
    column: $table.triggeredBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeploymentsTableOrderingComposer
    extends Composer<_$NexusDatabase, $DeploymentsTable> {
  $$DeploymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get deployment_pk => $composableBuilder(
    column: $table.deployment_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggeredBy => $composableBuilder(
    column: $table.triggeredBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeploymentsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $DeploymentsTable> {
  $$DeploymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get deployment_pk => $composableBuilder(
    column: $table.deployment_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get environment => $composableBuilder(
    column: $table.environment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get triggeredBy => $composableBuilder(
    column: $table.triggeredBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeploymentsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $DeploymentsTable,
          Deployment,
          $$DeploymentsTableFilterComposer,
          $$DeploymentsTableOrderingComposer,
          $$DeploymentsTableAnnotationComposer,
          $$DeploymentsTableCreateCompanionBuilder,
          $$DeploymentsTableUpdateCompanionBuilder,
          (Deployment, $$DeploymentsTableReferences),
          Deployment,
          PrefetchHooks Function({bool client_fk, bool project_fk})
        > {
  $$DeploymentsTableTableManager(_$NexusDatabase db, $DeploymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeploymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeploymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeploymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> deployment_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<int?> project_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> environment = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> triggeredBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
              }) => DeploymentsCompanion(
                deployment_pk: deployment_pk,
                client_fk: client_fk,
                project_fk: project_fk,
                name: name,
                environment: environment,
                status: status,
                triggeredBy: triggeredBy,
                createdAt: createdAt,
                completedAt: completedAt,
                metadataJson: metadataJson,
              ),
          createCompanionCallback:
              ({
                Value<int> deployment_pk = const Value.absent(),
                required int client_fk,
                Value<int?> project_fk = const Value.absent(),
                required String name,
                Value<String> environment = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> triggeredBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
              }) => DeploymentsCompanion.insert(
                deployment_pk: deployment_pk,
                client_fk: client_fk,
                project_fk: project_fk,
                name: name,
                environment: environment,
                status: status,
                triggeredBy: triggeredBy,
                createdAt: createdAt,
                completedAt: completedAt,
                metadataJson: metadataJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeploymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({client_fk = false, project_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (client_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.client_fk,
                                referencedTable: $$DeploymentsTableReferences
                                    ._client_fkTable(db),
                                referencedColumn: $$DeploymentsTableReferences
                                    ._client_fkTable(db)
                                    .client_pk,
                              )
                              as T;
                    }
                    if (project_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.project_fk,
                                referencedTable: $$DeploymentsTableReferences
                                    ._project_fkTable(db),
                                referencedColumn: $$DeploymentsTableReferences
                                    ._project_fkTable(db)
                                    .project_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeploymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $DeploymentsTable,
      Deployment,
      $$DeploymentsTableFilterComposer,
      $$DeploymentsTableOrderingComposer,
      $$DeploymentsTableAnnotationComposer,
      $$DeploymentsTableCreateCompanionBuilder,
      $$DeploymentsTableUpdateCompanionBuilder,
      (Deployment, $$DeploymentsTableReferences),
      Deployment,
      PrefetchHooks Function({bool client_fk, bool project_fk})
    >;
typedef $$ActivityLogsTableCreateCompanionBuilder =
    ActivityLogsCompanion Function({
      Value<int> activity_pk,
      required int client_fk,
      Value<int?> project_fk,
      Value<String> actorType,
      Value<String?> actorId,
      required String action,
      Value<String?> targetType,
      Value<String?> targetId,
      Value<String?> summary,
      Value<String> metadataJson,
      Value<DateTime> createdAt,
    });
typedef $$ActivityLogsTableUpdateCompanionBuilder =
    ActivityLogsCompanion Function({
      Value<int> activity_pk,
      Value<int> client_fk,
      Value<int?> project_fk,
      Value<String> actorType,
      Value<String?> actorId,
      Value<String> action,
      Value<String?> targetType,
      Value<String?> targetId,
      Value<String?> summary,
      Value<String> metadataJson,
      Value<DateTime> createdAt,
    });

final class $$ActivityLogsTableReferences
    extends BaseReferences<_$NexusDatabase, $ActivityLogsTable, ActivityLog> {
  $$ActivityLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('activity_logs__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) => db.projects
      .createAlias('activity_logs__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager? get project_fk {
    final $_column = $_itemColumn<int>('project_fk');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActivityLogsTableFilterComposer
    extends Composer<_$NexusDatabase, $ActivityLogsTable> {
  $$ActivityLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get activity_pk => $composableBuilder(
    column: $table.activity_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorType => $composableBuilder(
    column: $table.actorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityLogsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ActivityLogsTable> {
  $$ActivityLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get activity_pk => $composableBuilder(
    column: $table.activity_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorType => $composableBuilder(
    column: $table.actorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityLogsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ActivityLogsTable> {
  $$ActivityLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get activity_pk => $composableBuilder(
    column: $table.activity_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorType =>
      $composableBuilder(column: $table.actorType, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityLogsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ActivityLogsTable,
          ActivityLog,
          $$ActivityLogsTableFilterComposer,
          $$ActivityLogsTableOrderingComposer,
          $$ActivityLogsTableAnnotationComposer,
          $$ActivityLogsTableCreateCompanionBuilder,
          $$ActivityLogsTableUpdateCompanionBuilder,
          (ActivityLog, $$ActivityLogsTableReferences),
          ActivityLog,
          PrefetchHooks Function({bool client_fk, bool project_fk})
        > {
  $$ActivityLogsTableTableManager(_$NexusDatabase db, $ActivityLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> activity_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<int?> project_fk = const Value.absent(),
                Value<String> actorType = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ActivityLogsCompanion(
                activity_pk: activity_pk,
                client_fk: client_fk,
                project_fk: project_fk,
                actorType: actorType,
                actorId: actorId,
                action: action,
                targetType: targetType,
                targetId: targetId,
                summary: summary,
                metadataJson: metadataJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> activity_pk = const Value.absent(),
                required int client_fk,
                Value<int?> project_fk = const Value.absent(),
                Value<String> actorType = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                required String action,
                Value<String?> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ActivityLogsCompanion.insert(
                activity_pk: activity_pk,
                client_fk: client_fk,
                project_fk: project_fk,
                actorType: actorType,
                actorId: actorId,
                action: action,
                targetType: targetType,
                targetId: targetId,
                summary: summary,
                metadataJson: metadataJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActivityLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({client_fk = false, project_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (client_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.client_fk,
                                referencedTable: $$ActivityLogsTableReferences
                                    ._client_fkTable(db),
                                referencedColumn: $$ActivityLogsTableReferences
                                    ._client_fkTable(db)
                                    .client_pk,
                              )
                              as T;
                    }
                    if (project_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.project_fk,
                                referencedTable: $$ActivityLogsTableReferences
                                    ._project_fkTable(db),
                                referencedColumn: $$ActivityLogsTableReferences
                                    ._project_fkTable(db)
                                    .project_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ActivityLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ActivityLogsTable,
      ActivityLog,
      $$ActivityLogsTableFilterComposer,
      $$ActivityLogsTableOrderingComposer,
      $$ActivityLogsTableAnnotationComposer,
      $$ActivityLogsTableCreateCompanionBuilder,
      $$ActivityLogsTableUpdateCompanionBuilder,
      (ActivityLog, $$ActivityLogsTableReferences),
      ActivityLog,
      PrefetchHooks Function({bool client_fk, bool project_fk})
    >;
typedef $$CiRunsTableCreateCompanionBuilder =
    CiRunsCompanion Function({
      Value<int> ci_run_pk,
      required int client_fk,
      Value<int?> project_fk,
      Value<int?> task_fk,
      required String name,
      Value<String> status,
      Value<String> kind,
      Value<String> backend,
      Value<String?> branch,
      Value<String?> commitOid,
      Value<String?> dockerfilePath,
      Value<String?> imageTag,
      Value<String?> workflowPath,
      Value<String?> triggeredBy,
      Value<String?> errorText,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<String> metadataJson,
    });
typedef $$CiRunsTableUpdateCompanionBuilder =
    CiRunsCompanion Function({
      Value<int> ci_run_pk,
      Value<int> client_fk,
      Value<int?> project_fk,
      Value<int?> task_fk,
      Value<String> name,
      Value<String> status,
      Value<String> kind,
      Value<String> backend,
      Value<String?> branch,
      Value<String?> commitOid,
      Value<String?> dockerfilePath,
      Value<String?> imageTag,
      Value<String?> workflowPath,
      Value<String?> triggeredBy,
      Value<String?> errorText,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<String> metadataJson,
    });

final class $$CiRunsTableReferences
    extends BaseReferences<_$NexusDatabase, $CiRunsTable, CiRun> {
  $$CiRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientsTable _client_fkTable(_$NexusDatabase db) =>
      db.clients.createAlias('ci_runs__client_fk__clients__client_pk');

  $$ClientsTableProcessedTableManager get client_fk {
    final $_column = $_itemColumn<int>('client_fk')!;

    final manager = $$ClientsTableTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.client_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_client_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) =>
      db.projects.createAlias('ci_runs__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager? get project_fk {
    final $_column = $_itemColumn<int>('project_fk');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TasksTable _task_fkTable(_$NexusDatabase db) =>
      db.tasks.createAlias('ci_runs__task_fk__tasks__task_pk');

  $$TasksTableProcessedTableManager? get task_fk {
    final $_column = $_itemColumn<int>('task_fk');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.task_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_task_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CiJobsTable, List<CiJob>> _ciJobsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ciJobs,
    aliasName: 'ci_runs__ci_run_pk__ci_jobs__ci_run_fk',
  );

  $$CiJobsTableProcessedTableManager get ciJobsRefs {
    final manager = $$CiJobsTableTableManager($_db, $_db.ciJobs).filter(
      (f) => f.ci_run_fk.ci_run_pk.sqlEquals($_itemColumn<int>('ci_run_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_ciJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CiRunsTableFilterComposer
    extends Composer<_$NexusDatabase, $CiRunsTable> {
  $$CiRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ci_run_pk => $composableBuilder(
    column: $table.ci_run_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backend => $composableBuilder(
    column: $table.backend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commitOid => $composableBuilder(
    column: $table.commitOid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dockerfilePath => $composableBuilder(
    column: $table.dockerfilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowPath => $composableBuilder(
    column: $table.workflowPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggeredBy => $composableBuilder(
    column: $table.triggeredBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientsTableFilterComposer get client_fk {
    final $$ClientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableFilterComposer get task_fk {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_fk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> ciJobsRefs(
    Expression<bool> Function($$CiJobsTableFilterComposer f) f,
  ) {
    final $$CiJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_run_pk,
      referencedTable: $db.ciJobs,
      getReferencedColumn: (t) => t.ci_run_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiJobsTableFilterComposer(
            $db: $db,
            $table: $db.ciJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CiRunsTableOrderingComposer
    extends Composer<_$NexusDatabase, $CiRunsTable> {
  $$CiRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ci_run_pk => $composableBuilder(
    column: $table.ci_run_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backend => $composableBuilder(
    column: $table.backend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commitOid => $composableBuilder(
    column: $table.commitOid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dockerfilePath => $composableBuilder(
    column: $table.dockerfilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowPath => $composableBuilder(
    column: $table.workflowPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggeredBy => $composableBuilder(
    column: $table.triggeredBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientsTableOrderingComposer get client_fk {
    final $$ClientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableOrderingComposer get task_fk {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_fk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CiRunsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $CiRunsTable> {
  $$CiRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ci_run_pk =>
      $composableBuilder(column: $table.ci_run_pk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get backend =>
      $composableBuilder(column: $table.backend, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get commitOid =>
      $composableBuilder(column: $table.commitOid, builder: (column) => column);

  GeneratedColumn<String> get dockerfilePath => $composableBuilder(
    column: $table.dockerfilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<String> get workflowPath => $composableBuilder(
    column: $table.workflowPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggeredBy => $composableBuilder(
    column: $table.triggeredBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorText =>
      $composableBuilder(column: $table.errorText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  $$ClientsTableAnnotationComposer get client_fk {
    final $$ClientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.client_fk,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.client_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientsTableAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TasksTableAnnotationComposer get task_fk {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.task_fk,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.task_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> ciJobsRefs<T extends Object>(
    Expression<T> Function($$CiJobsTableAnnotationComposer a) f,
  ) {
    final $$CiJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_run_pk,
      referencedTable: $db.ciJobs,
      getReferencedColumn: (t) => t.ci_run_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CiRunsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $CiRunsTable,
          CiRun,
          $$CiRunsTableFilterComposer,
          $$CiRunsTableOrderingComposer,
          $$CiRunsTableAnnotationComposer,
          $$CiRunsTableCreateCompanionBuilder,
          $$CiRunsTableUpdateCompanionBuilder,
          (CiRun, $$CiRunsTableReferences),
          CiRun,
          PrefetchHooks Function({
            bool client_fk,
            bool project_fk,
            bool task_fk,
            bool ciJobsRefs,
          })
        > {
  $$CiRunsTableTableManager(_$NexusDatabase db, $CiRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CiRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CiRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CiRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> ci_run_pk = const Value.absent(),
                Value<int> client_fk = const Value.absent(),
                Value<int?> project_fk = const Value.absent(),
                Value<int?> task_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> backend = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<String?> commitOid = const Value.absent(),
                Value<String?> dockerfilePath = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<String?> workflowPath = const Value.absent(),
                Value<String?> triggeredBy = const Value.absent(),
                Value<String?> errorText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
              }) => CiRunsCompanion(
                ci_run_pk: ci_run_pk,
                client_fk: client_fk,
                project_fk: project_fk,
                task_fk: task_fk,
                name: name,
                status: status,
                kind: kind,
                backend: backend,
                branch: branch,
                commitOid: commitOid,
                dockerfilePath: dockerfilePath,
                imageTag: imageTag,
                workflowPath: workflowPath,
                triggeredBy: triggeredBy,
                errorText: errorText,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                metadataJson: metadataJson,
              ),
          createCompanionCallback:
              ({
                Value<int> ci_run_pk = const Value.absent(),
                required int client_fk,
                Value<int?> project_fk = const Value.absent(),
                Value<int?> task_fk = const Value.absent(),
                required String name,
                Value<String> status = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> backend = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<String?> commitOid = const Value.absent(),
                Value<String?> dockerfilePath = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<String?> workflowPath = const Value.absent(),
                Value<String?> triggeredBy = const Value.absent(),
                Value<String?> errorText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
              }) => CiRunsCompanion.insert(
                ci_run_pk: ci_run_pk,
                client_fk: client_fk,
                project_fk: project_fk,
                task_fk: task_fk,
                name: name,
                status: status,
                kind: kind,
                backend: backend,
                branch: branch,
                commitOid: commitOid,
                dockerfilePath: dockerfilePath,
                imageTag: imageTag,
                workflowPath: workflowPath,
                triggeredBy: triggeredBy,
                errorText: errorText,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                metadataJson: metadataJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CiRunsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                client_fk = false,
                project_fk = false,
                task_fk = false,
                ciJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (ciJobsRefs) db.ciJobs],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (client_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.client_fk,
                                    referencedTable: $$CiRunsTableReferences
                                        ._client_fkTable(db),
                                    referencedColumn: $$CiRunsTableReferences
                                        ._client_fkTable(db)
                                        .client_pk,
                                  )
                                  as T;
                        }
                        if (project_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.project_fk,
                                    referencedTable: $$CiRunsTableReferences
                                        ._project_fkTable(db),
                                    referencedColumn: $$CiRunsTableReferences
                                        ._project_fkTable(db)
                                        .project_pk,
                                  )
                                  as T;
                        }
                        if (task_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.task_fk,
                                    referencedTable: $$CiRunsTableReferences
                                        ._task_fkTable(db),
                                    referencedColumn: $$CiRunsTableReferences
                                        ._task_fkTable(db)
                                        .task_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (ciJobsRefs)
                        await $_getPrefetchedData<CiRun, $CiRunsTable, CiJob>(
                          currentTable: table,
                          referencedTable: $$CiRunsTableReferences
                              ._ciJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CiRunsTableReferences(db, table, p0).ciJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ci_run_fk == item.ci_run_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CiRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $CiRunsTable,
      CiRun,
      $$CiRunsTableFilterComposer,
      $$CiRunsTableOrderingComposer,
      $$CiRunsTableAnnotationComposer,
      $$CiRunsTableCreateCompanionBuilder,
      $$CiRunsTableUpdateCompanionBuilder,
      (CiRun, $$CiRunsTableReferences),
      CiRun,
      PrefetchHooks Function({
        bool client_fk,
        bool project_fk,
        bool task_fk,
        bool ciJobsRefs,
      })
    >;
typedef $$CiJobsTableCreateCompanionBuilder =
    CiJobsCompanion Function({
      Value<int> ci_job_pk,
      required int ci_run_fk,
      required String name,
      Value<String> status,
      Value<String?> runsOn,
      Value<int> orderIndex,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
    });
typedef $$CiJobsTableUpdateCompanionBuilder =
    CiJobsCompanion Function({
      Value<int> ci_job_pk,
      Value<int> ci_run_fk,
      Value<String> name,
      Value<String> status,
      Value<String?> runsOn,
      Value<int> orderIndex,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
    });

final class $$CiJobsTableReferences
    extends BaseReferences<_$NexusDatabase, $CiJobsTable, CiJob> {
  $$CiJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CiRunsTable _ci_run_fkTable(_$NexusDatabase db) =>
      db.ciRuns.createAlias('ci_jobs__ci_run_fk__ci_runs__ci_run_pk');

  $$CiRunsTableProcessedTableManager get ci_run_fk {
    final $_column = $_itemColumn<int>('ci_run_fk')!;

    final manager = $$CiRunsTableTableManager(
      $_db,
      $_db.ciRuns,
    ).filter((f) => f.ci_run_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ci_run_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CiStepsTable, List<CiStep>> _ciStepsRefsTable(
    _$NexusDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.ciSteps,
    aliasName: 'ci_jobs__ci_job_pk__ci_steps__ci_job_fk',
  );

  $$CiStepsTableProcessedTableManager get ciStepsRefs {
    final manager = $$CiStepsTableTableManager($_db, $_db.ciSteps).filter(
      (f) => f.ci_job_fk.ci_job_pk.sqlEquals($_itemColumn<int>('ci_job_pk')!),
    );

    final cache = $_typedResult.readTableOrNull(_ciStepsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CiJobsTableFilterComposer
    extends Composer<_$NexusDatabase, $CiJobsTable> {
  $$CiJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ci_job_pk => $composableBuilder(
    column: $table.ci_job_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runsOn => $composableBuilder(
    column: $table.runsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CiRunsTableFilterComposer get ci_run_fk {
    final $$CiRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_run_fk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.ci_run_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableFilterComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> ciStepsRefs(
    Expression<bool> Function($$CiStepsTableFilterComposer f) f,
  ) {
    final $$CiStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_job_pk,
      referencedTable: $db.ciSteps,
      getReferencedColumn: (t) => t.ci_job_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiStepsTableFilterComposer(
            $db: $db,
            $table: $db.ciSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CiJobsTableOrderingComposer
    extends Composer<_$NexusDatabase, $CiJobsTable> {
  $$CiJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ci_job_pk => $composableBuilder(
    column: $table.ci_job_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runsOn => $composableBuilder(
    column: $table.runsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CiRunsTableOrderingComposer get ci_run_fk {
    final $$CiRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_run_fk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.ci_run_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableOrderingComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CiJobsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $CiJobsTable> {
  $$CiJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ci_job_pk =>
      $composableBuilder(column: $table.ci_job_pk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get runsOn =>
      $composableBuilder(column: $table.runsOn, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$CiRunsTableAnnotationComposer get ci_run_fk {
    final $$CiRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_run_fk,
      referencedTable: $db.ciRuns,
      getReferencedColumn: (t) => t.ci_run_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> ciStepsRefs<T extends Object>(
    Expression<T> Function($$CiStepsTableAnnotationComposer a) f,
  ) {
    final $$CiStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_job_pk,
      referencedTable: $db.ciSteps,
      getReferencedColumn: (t) => t.ci_job_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CiJobsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $CiJobsTable,
          CiJob,
          $$CiJobsTableFilterComposer,
          $$CiJobsTableOrderingComposer,
          $$CiJobsTableAnnotationComposer,
          $$CiJobsTableCreateCompanionBuilder,
          $$CiJobsTableUpdateCompanionBuilder,
          (CiJob, $$CiJobsTableReferences),
          CiJob,
          PrefetchHooks Function({bool ci_run_fk, bool ciStepsRefs})
        > {
  $$CiJobsTableTableManager(_$NexusDatabase db, $CiJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CiJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CiJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CiJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> ci_job_pk = const Value.absent(),
                Value<int> ci_run_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> runsOn = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => CiJobsCompanion(
                ci_job_pk: ci_job_pk,
                ci_run_fk: ci_run_fk,
                name: name,
                status: status,
                runsOn: runsOn,
                orderIndex: orderIndex,
                startedAt: startedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> ci_job_pk = const Value.absent(),
                required int ci_run_fk,
                required String name,
                Value<String> status = const Value.absent(),
                Value<String?> runsOn = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => CiJobsCompanion.insert(
                ci_job_pk: ci_job_pk,
                ci_run_fk: ci_run_fk,
                name: name,
                status: status,
                runsOn: runsOn,
                orderIndex: orderIndex,
                startedAt: startedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CiJobsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({ci_run_fk = false, ciStepsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ciStepsRefs) db.ciSteps],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (ci_run_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ci_run_fk,
                                referencedTable: $$CiJobsTableReferences
                                    ._ci_run_fkTable(db),
                                referencedColumn: $$CiJobsTableReferences
                                    ._ci_run_fkTable(db)
                                    .ci_run_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ciStepsRefs)
                    await $_getPrefetchedData<CiJob, $CiJobsTable, CiStep>(
                      currentTable: table,
                      referencedTable: $$CiJobsTableReferences
                          ._ciStepsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CiJobsTableReferences(db, table, p0).ciStepsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.ci_job_fk == item.ci_job_pk,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CiJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $CiJobsTable,
      CiJob,
      $$CiJobsTableFilterComposer,
      $$CiJobsTableOrderingComposer,
      $$CiJobsTableAnnotationComposer,
      $$CiJobsTableCreateCompanionBuilder,
      $$CiJobsTableUpdateCompanionBuilder,
      (CiJob, $$CiJobsTableReferences),
      CiJob,
      PrefetchHooks Function({bool ci_run_fk, bool ciStepsRefs})
    >;
typedef $$CiStepsTableCreateCompanionBuilder =
    CiStepsCompanion Function({
      Value<int> ci_step_pk,
      required int ci_job_fk,
      required String name,
      Value<String> status,
      Value<int> orderIndex,
      Value<String?> command,
      Value<int?> exitCode,
      Value<String> logText,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
    });
typedef $$CiStepsTableUpdateCompanionBuilder =
    CiStepsCompanion Function({
      Value<int> ci_step_pk,
      Value<int> ci_job_fk,
      Value<String> name,
      Value<String> status,
      Value<int> orderIndex,
      Value<String?> command,
      Value<int?> exitCode,
      Value<String> logText,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
    });

final class $$CiStepsTableReferences
    extends BaseReferences<_$NexusDatabase, $CiStepsTable, CiStep> {
  $$CiStepsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CiJobsTable _ci_job_fkTable(_$NexusDatabase db) =>
      db.ciJobs.createAlias('ci_steps__ci_job_fk__ci_jobs__ci_job_pk');

  $$CiJobsTableProcessedTableManager get ci_job_fk {
    final $_column = $_itemColumn<int>('ci_job_fk')!;

    final manager = $$CiJobsTableTableManager(
      $_db,
      $_db.ciJobs,
    ).filter((f) => f.ci_job_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ci_job_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CiStepsTableFilterComposer
    extends Composer<_$NexusDatabase, $CiStepsTable> {
  $$CiStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ci_step_pk => $composableBuilder(
    column: $table.ci_step_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logText => $composableBuilder(
    column: $table.logText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CiJobsTableFilterComposer get ci_job_fk {
    final $$CiJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_job_fk,
      referencedTable: $db.ciJobs,
      getReferencedColumn: (t) => t.ci_job_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiJobsTableFilterComposer(
            $db: $db,
            $table: $db.ciJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CiStepsTableOrderingComposer
    extends Composer<_$NexusDatabase, $CiStepsTable> {
  $$CiStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ci_step_pk => $composableBuilder(
    column: $table.ci_step_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logText => $composableBuilder(
    column: $table.logText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CiJobsTableOrderingComposer get ci_job_fk {
    final $$CiJobsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_job_fk,
      referencedTable: $db.ciJobs,
      getReferencedColumn: (t) => t.ci_job_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiJobsTableOrderingComposer(
            $db: $db,
            $table: $db.ciJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CiStepsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $CiStepsTable> {
  $$CiStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ci_step_pk => $composableBuilder(
    column: $table.ci_step_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<int> get exitCode =>
      $composableBuilder(column: $table.exitCode, builder: (column) => column);

  GeneratedColumn<String> get logText =>
      $composableBuilder(column: $table.logText, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$CiJobsTableAnnotationComposer get ci_job_fk {
    final $$CiJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ci_job_fk,
      referencedTable: $db.ciJobs,
      getReferencedColumn: (t) => t.ci_job_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CiJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.ciJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CiStepsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $CiStepsTable,
          CiStep,
          $$CiStepsTableFilterComposer,
          $$CiStepsTableOrderingComposer,
          $$CiStepsTableAnnotationComposer,
          $$CiStepsTableCreateCompanionBuilder,
          $$CiStepsTableUpdateCompanionBuilder,
          (CiStep, $$CiStepsTableReferences),
          CiStep,
          PrefetchHooks Function({bool ci_job_fk})
        > {
  $$CiStepsTableTableManager(_$NexusDatabase db, $CiStepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CiStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CiStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CiStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> ci_step_pk = const Value.absent(),
                Value<int> ci_job_fk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String?> command = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String> logText = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => CiStepsCompanion(
                ci_step_pk: ci_step_pk,
                ci_job_fk: ci_job_fk,
                name: name,
                status: status,
                orderIndex: orderIndex,
                command: command,
                exitCode: exitCode,
                logText: logText,
                startedAt: startedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> ci_step_pk = const Value.absent(),
                required int ci_job_fk,
                required String name,
                Value<String> status = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String?> command = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String> logText = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => CiStepsCompanion.insert(
                ci_step_pk: ci_step_pk,
                ci_job_fk: ci_job_fk,
                name: name,
                status: status,
                orderIndex: orderIndex,
                command: command,
                exitCode: exitCode,
                logText: logText,
                startedAt: startedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CiStepsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ci_job_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (ci_job_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ci_job_fk,
                                referencedTable: $$CiStepsTableReferences
                                    ._ci_job_fkTable(db),
                                referencedColumn: $$CiStepsTableReferences
                                    ._ci_job_fkTable(db)
                                    .ci_job_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CiStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $CiStepsTable,
      CiStep,
      $$CiStepsTableFilterComposer,
      $$CiStepsTableOrderingComposer,
      $$CiStepsTableAnnotationComposer,
      $$CiStepsTableCreateCompanionBuilder,
      $$CiStepsTableUpdateCompanionBuilder,
      (CiStep, $$CiStepsTableReferences),
      CiStep,
      PrefetchHooks Function({bool ci_job_fk})
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<int> message_pk,
      required int session_fk,
      required String role,
      Value<String> content,
      Value<String?> audioPath,
      Value<int> seq,
      Value<DateTime> createdAt,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<int> message_pk,
      Value<int> session_fk,
      Value<String> role,
      Value<String> content,
      Value<String?> audioPath,
      Value<int> seq,
      Value<DateTime> createdAt,
    });

final class $$ChatMessagesTableReferences
    extends BaseReferences<_$NexusDatabase, $ChatMessagesTable, ChatMessage> {
  $$ChatMessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChatSessionsTable _session_fkTable(_$NexusDatabase db) => db
      .chatSessions
      .createAlias('chat_messages__session_fk__chat_sessions__session_pk');

  $$ChatSessionsTableProcessedTableManager get session_fk {
    final $_column = $_itemColumn<int>('session_fk')!;

    final manager = $$ChatSessionsTableTableManager(
      $_db,
      $_db.chatSessions,
    ).filter((f) => f.session_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_session_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChatMessagesTableFilterComposer
    extends Composer<_$NexusDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get message_pk => $composableBuilder(
    column: $table.message_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChatSessionsTableFilterComposer get session_fk {
    final $$ChatSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableFilterComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$NexusDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get message_pk => $composableBuilder(
    column: $table.message_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChatSessionsTableOrderingComposer get session_fk {
    final $$ChatSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get message_pk => $composableBuilder(
    column: $table.message_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChatSessionsTableAnnotationComposer get session_fk {
    final $$ChatSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.session_fk,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.session_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChatSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (ChatMessage, $$ChatMessagesTableReferences),
          ChatMessage,
          PrefetchHooks Function({bool session_fk})
        > {
  $$ChatMessagesTableTableManager(_$NexusDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> message_pk = const Value.absent(),
                Value<int> session_fk = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChatMessagesCompanion(
                message_pk: message_pk,
                session_fk: session_fk,
                role: role,
                content: content,
                audioPath: audioPath,
                seq: seq,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> message_pk = const Value.absent(),
                required int session_fk,
                required String role,
                Value<String> content = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                message_pk: message_pk,
                session_fk: session_fk,
                role: role,
                content: content,
                audioPath: audioPath,
                seq: seq,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChatMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({session_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (session_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.session_fk,
                                referencedTable: $$ChatMessagesTableReferences
                                    ._session_fkTable(db),
                                referencedColumn: $$ChatMessagesTableReferences
                                    ._session_fkTable(db)
                                    .session_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (ChatMessage, $$ChatMessagesTableReferences),
      ChatMessage,
      PrefetchHooks Function({bool session_fk})
    >;
typedef $$ProjectTagsTableCreateCompanionBuilder =
    ProjectTagsCompanion Function({
      Value<int> tag_pk,
      required int project_fk,
      required String category,
      required String value,
      Value<String> source,
      Value<String> origin,
      Value<String> status,
      Value<String?> layerKey,
      Value<String?> forLanguage,
      Value<String?> rationale,
      Value<String?> sourceUrl,
      Value<String?> verdict,
      Value<DateTime?> verifiedAt,
      Value<DateTime> createdAt,
    });
typedef $$ProjectTagsTableUpdateCompanionBuilder =
    ProjectTagsCompanion Function({
      Value<int> tag_pk,
      Value<int> project_fk,
      Value<String> category,
      Value<String> value,
      Value<String> source,
      Value<String> origin,
      Value<String> status,
      Value<String?> layerKey,
      Value<String?> forLanguage,
      Value<String?> rationale,
      Value<String?> sourceUrl,
      Value<String?> verdict,
      Value<DateTime?> verifiedAt,
      Value<DateTime> createdAt,
    });

final class $$ProjectTagsTableReferences
    extends BaseReferences<_$NexusDatabase, $ProjectTagsTable, ProjectTag> {
  $$ProjectTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) =>
      db.projects.createAlias('project_tags__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager get project_fk {
    final $_column = $_itemColumn<int>('project_fk')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProjectTagsTableFilterComposer
    extends Composer<_$NexusDatabase, $ProjectTagsTable> {
  $$ProjectTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tag_pk => $composableBuilder(
    column: $table.tag_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layerKey => $composableBuilder(
    column: $table.layerKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forLanguage => $composableBuilder(
    column: $table.forLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rationale => $composableBuilder(
    column: $table.rationale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectTagsTableOrderingComposer
    extends Composer<_$NexusDatabase, $ProjectTagsTable> {
  $$ProjectTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tag_pk => $composableBuilder(
    column: $table.tag_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layerKey => $composableBuilder(
    column: $table.layerKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forLanguage => $composableBuilder(
    column: $table.forLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rationale => $composableBuilder(
    column: $table.rationale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectTagsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $ProjectTagsTable> {
  $$ProjectTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tag_pk =>
      $composableBuilder(column: $table.tag_pk, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get layerKey =>
      $composableBuilder(column: $table.layerKey, builder: (column) => column);

  GeneratedColumn<String> get forLanguage => $composableBuilder(
    column: $table.forLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rationale =>
      $composableBuilder(column: $table.rationale, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => column);

  GeneratedColumn<DateTime> get verifiedAt => $composableBuilder(
    column: $table.verifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectTagsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $ProjectTagsTable,
          ProjectTag,
          $$ProjectTagsTableFilterComposer,
          $$ProjectTagsTableOrderingComposer,
          $$ProjectTagsTableAnnotationComposer,
          $$ProjectTagsTableCreateCompanionBuilder,
          $$ProjectTagsTableUpdateCompanionBuilder,
          (ProjectTag, $$ProjectTagsTableReferences),
          ProjectTag,
          PrefetchHooks Function({bool project_fk})
        > {
  $$ProjectTagsTableTableManager(_$NexusDatabase db, $ProjectTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tag_pk = const Value.absent(),
                Value<int> project_fk = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> layerKey = const Value.absent(),
                Value<String?> forLanguage = const Value.absent(),
                Value<String?> rationale = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> verdict = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProjectTagsCompanion(
                tag_pk: tag_pk,
                project_fk: project_fk,
                category: category,
                value: value,
                source: source,
                origin: origin,
                status: status,
                layerKey: layerKey,
                forLanguage: forLanguage,
                rationale: rationale,
                sourceUrl: sourceUrl,
                verdict: verdict,
                verifiedAt: verifiedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> tag_pk = const Value.absent(),
                required int project_fk,
                required String category,
                required String value,
                Value<String> source = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> layerKey = const Value.absent(),
                Value<String?> forLanguage = const Value.absent(),
                Value<String?> rationale = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> verdict = const Value.absent(),
                Value<DateTime?> verifiedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProjectTagsCompanion.insert(
                tag_pk: tag_pk,
                project_fk: project_fk,
                category: category,
                value: value,
                source: source,
                origin: origin,
                status: status,
                layerKey: layerKey,
                forLanguage: forLanguage,
                rationale: rationale,
                sourceUrl: sourceUrl,
                verdict: verdict,
                verifiedAt: verifiedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({project_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (project_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.project_fk,
                                referencedTable: $$ProjectTagsTableReferences
                                    ._project_fkTable(db),
                                referencedColumn: $$ProjectTagsTableReferences
                                    ._project_fkTable(db)
                                    .project_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProjectTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $ProjectTagsTable,
      ProjectTag,
      $$ProjectTagsTableFilterComposer,
      $$ProjectTagsTableOrderingComposer,
      $$ProjectTagsTableAnnotationComposer,
      $$ProjectTagsTableCreateCompanionBuilder,
      $$ProjectTagsTableUpdateCompanionBuilder,
      (ProjectTag, $$ProjectTagsTableReferences),
      ProjectTag,
      PrefetchHooks Function({bool project_fk})
    >;
typedef $$LibraryVerificationsTableCreateCompanionBuilder =
    LibraryVerificationsCompanion Function({
      Value<int> verification_pk,
      required String ecosystem,
      required String name,
      Value<String?> repoUrl,
      Value<DateTime?> lastCommit,
      Value<DateTime?> lastRelease,
      Value<bool> archived,
      Value<int?> popularity,
      Value<String?> owner,
      required String verdict,
      Value<DateTime> checkedAt,
    });
typedef $$LibraryVerificationsTableUpdateCompanionBuilder =
    LibraryVerificationsCompanion Function({
      Value<int> verification_pk,
      Value<String> ecosystem,
      Value<String> name,
      Value<String?> repoUrl,
      Value<DateTime?> lastCommit,
      Value<DateTime?> lastRelease,
      Value<bool> archived,
      Value<int?> popularity,
      Value<String?> owner,
      Value<String> verdict,
      Value<DateTime> checkedAt,
    });

class $$LibraryVerificationsTableFilterComposer
    extends Composer<_$NexusDatabase, $LibraryVerificationsTable> {
  $$LibraryVerificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get verification_pk => $composableBuilder(
    column: $table.verification_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ecosystem => $composableBuilder(
    column: $table.ecosystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoUrl => $composableBuilder(
    column: $table.repoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCommit => $composableBuilder(
    column: $table.lastCommit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRelease => $composableBuilder(
    column: $table.lastRelease,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryVerificationsTableOrderingComposer
    extends Composer<_$NexusDatabase, $LibraryVerificationsTable> {
  $$LibraryVerificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get verification_pk => $composableBuilder(
    column: $table.verification_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ecosystem => $composableBuilder(
    column: $table.ecosystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoUrl => $composableBuilder(
    column: $table.repoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCommit => $composableBuilder(
    column: $table.lastCommit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRelease => $composableBuilder(
    column: $table.lastRelease,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryVerificationsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $LibraryVerificationsTable> {
  $$LibraryVerificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get verification_pk => $composableBuilder(
    column: $table.verification_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ecosystem =>
      $composableBuilder(column: $table.ecosystem, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get repoUrl =>
      $composableBuilder(column: $table.repoUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCommit => $composableBuilder(
    column: $table.lastCommit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastRelease => $composableBuilder(
    column: $table.lastRelease,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$LibraryVerificationsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $LibraryVerificationsTable,
          LibraryVerification,
          $$LibraryVerificationsTableFilterComposer,
          $$LibraryVerificationsTableOrderingComposer,
          $$LibraryVerificationsTableAnnotationComposer,
          $$LibraryVerificationsTableCreateCompanionBuilder,
          $$LibraryVerificationsTableUpdateCompanionBuilder,
          (
            LibraryVerification,
            BaseReferences<
              _$NexusDatabase,
              $LibraryVerificationsTable,
              LibraryVerification
            >,
          ),
          LibraryVerification,
          PrefetchHooks Function()
        > {
  $$LibraryVerificationsTableTableManager(
    _$NexusDatabase db,
    $LibraryVerificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryVerificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryVerificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LibraryVerificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> verification_pk = const Value.absent(),
                Value<String> ecosystem = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> repoUrl = const Value.absent(),
                Value<DateTime?> lastCommit = const Value.absent(),
                Value<DateTime?> lastRelease = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int?> popularity = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                Value<String> verdict = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
              }) => LibraryVerificationsCompanion(
                verification_pk: verification_pk,
                ecosystem: ecosystem,
                name: name,
                repoUrl: repoUrl,
                lastCommit: lastCommit,
                lastRelease: lastRelease,
                archived: archived,
                popularity: popularity,
                owner: owner,
                verdict: verdict,
                checkedAt: checkedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> verification_pk = const Value.absent(),
                required String ecosystem,
                required String name,
                Value<String?> repoUrl = const Value.absent(),
                Value<DateTime?> lastCommit = const Value.absent(),
                Value<DateTime?> lastRelease = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int?> popularity = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                required String verdict,
                Value<DateTime> checkedAt = const Value.absent(),
              }) => LibraryVerificationsCompanion.insert(
                verification_pk: verification_pk,
                ecosystem: ecosystem,
                name: name,
                repoUrl: repoUrl,
                lastCommit: lastCommit,
                lastRelease: lastRelease,
                archived: archived,
                popularity: popularity,
                owner: owner,
                verdict: verdict,
                checkedAt: checkedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryVerificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $LibraryVerificationsTable,
      LibraryVerification,
      $$LibraryVerificationsTableFilterComposer,
      $$LibraryVerificationsTableOrderingComposer,
      $$LibraryVerificationsTableAnnotationComposer,
      $$LibraryVerificationsTableCreateCompanionBuilder,
      $$LibraryVerificationsTableUpdateCompanionBuilder,
      (
        LibraryVerification,
        BaseReferences<
          _$NexusDatabase,
          $LibraryVerificationsTable,
          LibraryVerification
        >,
      ),
      LibraryVerification,
      PrefetchHooks Function()
    >;
typedef $$CallSystemsTableCreateCompanionBuilder =
    CallSystemsCompanion Function({
      Value<int> call_system_pk,
      required int project_fk,
      Value<String> json,
      Value<DateTime> updatedAt,
    });
typedef $$CallSystemsTableUpdateCompanionBuilder =
    CallSystemsCompanion Function({
      Value<int> call_system_pk,
      Value<int> project_fk,
      Value<String> json,
      Value<DateTime> updatedAt,
    });

final class $$CallSystemsTableReferences
    extends BaseReferences<_$NexusDatabase, $CallSystemsTable, CallSystem> {
  $$CallSystemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _project_fkTable(_$NexusDatabase db) =>
      db.projects.createAlias('call_systems__project_fk__projects__project_pk');

  $$ProjectsTableProcessedTableManager get project_fk {
    final $_column = $_itemColumn<int>('project_fk')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.project_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_project_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CallSystemsTableFilterComposer
    extends Composer<_$NexusDatabase, $CallSystemsTable> {
  $$CallSystemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get call_system_pk => $composableBuilder(
    column: $table.call_system_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get project_fk {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CallSystemsTableOrderingComposer
    extends Composer<_$NexusDatabase, $CallSystemsTable> {
  $$CallSystemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get call_system_pk => $composableBuilder(
    column: $table.call_system_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get project_fk {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CallSystemsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $CallSystemsTable> {
  $$CallSystemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get call_system_pk => $composableBuilder(
    column: $table.call_system_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get project_fk {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.project_fk,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.project_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CallSystemsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $CallSystemsTable,
          CallSystem,
          $$CallSystemsTableFilterComposer,
          $$CallSystemsTableOrderingComposer,
          $$CallSystemsTableAnnotationComposer,
          $$CallSystemsTableCreateCompanionBuilder,
          $$CallSystemsTableUpdateCompanionBuilder,
          (CallSystem, $$CallSystemsTableReferences),
          CallSystem,
          PrefetchHooks Function({bool project_fk})
        > {
  $$CallSystemsTableTableManager(_$NexusDatabase db, $CallSystemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CallSystemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CallSystemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CallSystemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> call_system_pk = const Value.absent(),
                Value<int> project_fk = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CallSystemsCompanion(
                call_system_pk: call_system_pk,
                project_fk: project_fk,
                json: json,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> call_system_pk = const Value.absent(),
                required int project_fk,
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CallSystemsCompanion.insert(
                call_system_pk: call_system_pk,
                project_fk: project_fk,
                json: json,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CallSystemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({project_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (project_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.project_fk,
                                referencedTable: $$CallSystemsTableReferences
                                    ._project_fkTable(db),
                                referencedColumn: $$CallSystemsTableReferences
                                    ._project_fkTable(db)
                                    .project_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CallSystemsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $CallSystemsTable,
      CallSystem,
      $$CallSystemsTableFilterComposer,
      $$CallSystemsTableOrderingComposer,
      $$CallSystemsTableAnnotationComposer,
      $$CallSystemsTableCreateCompanionBuilder,
      $$CallSystemsTableUpdateCompanionBuilder,
      (CallSystem, $$CallSystemsTableReferences),
      CallSystem,
      PrefetchHooks Function({bool project_fk})
    >;
typedef $$SetupFlowsTableCreateCompanionBuilder =
    SetupFlowsCompanion Function({
      Value<int> setup_flow_pk,
      required String projectType,
      Value<String?> subCategory,
      required String json,
      Value<DateTime> updatedAt,
    });
typedef $$SetupFlowsTableUpdateCompanionBuilder =
    SetupFlowsCompanion Function({
      Value<int> setup_flow_pk,
      Value<String> projectType,
      Value<String?> subCategory,
      Value<String> json,
      Value<DateTime> updatedAt,
    });

class $$SetupFlowsTableFilterComposer
    extends Composer<_$NexusDatabase, $SetupFlowsTable> {
  $$SetupFlowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get setup_flow_pk => $composableBuilder(
    column: $table.setup_flow_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetupFlowsTableOrderingComposer
    extends Composer<_$NexusDatabase, $SetupFlowsTable> {
  $$SetupFlowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get setup_flow_pk => $composableBuilder(
    column: $table.setup_flow_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetupFlowsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $SetupFlowsTable> {
  $$SetupFlowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get setup_flow_pk => $composableBuilder(
    column: $table.setup_flow_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectType => $composableBuilder(
    column: $table.projectType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subCategory => $composableBuilder(
    column: $table.subCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SetupFlowsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $SetupFlowsTable,
          SetupFlow,
          $$SetupFlowsTableFilterComposer,
          $$SetupFlowsTableOrderingComposer,
          $$SetupFlowsTableAnnotationComposer,
          $$SetupFlowsTableCreateCompanionBuilder,
          $$SetupFlowsTableUpdateCompanionBuilder,
          (
            SetupFlow,
            BaseReferences<_$NexusDatabase, $SetupFlowsTable, SetupFlow>,
          ),
          SetupFlow,
          PrefetchHooks Function()
        > {
  $$SetupFlowsTableTableManager(_$NexusDatabase db, $SetupFlowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetupFlowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetupFlowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetupFlowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> setup_flow_pk = const Value.absent(),
                Value<String> projectType = const Value.absent(),
                Value<String?> subCategory = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SetupFlowsCompanion(
                setup_flow_pk: setup_flow_pk,
                projectType: projectType,
                subCategory: subCategory,
                json: json,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> setup_flow_pk = const Value.absent(),
                required String projectType,
                Value<String?> subCategory = const Value.absent(),
                required String json,
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SetupFlowsCompanion.insert(
                setup_flow_pk: setup_flow_pk,
                projectType: projectType,
                subCategory: subCategory,
                json: json,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetupFlowsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $SetupFlowsTable,
      SetupFlow,
      $$SetupFlowsTableFilterComposer,
      $$SetupFlowsTableOrderingComposer,
      $$SetupFlowsTableAnnotationComposer,
      $$SetupFlowsTableCreateCompanionBuilder,
      $$SetupFlowsTableUpdateCompanionBuilder,
      (SetupFlow, BaseReferences<_$NexusDatabase, $SetupFlowsTable, SetupFlow>),
      SetupFlow,
      PrefetchHooks Function()
    >;
typedef $$SetupScopesTableCreateCompanionBuilder =
    SetupScopesCompanion Function({
      Value<int> setup_scope_pk,
      required String axis,
      required String value,
      Value<int?> parent_scope_fk,
      Value<String?> subAxisName,
      Value<String?> subAxisKey,
    });
typedef $$SetupScopesTableUpdateCompanionBuilder =
    SetupScopesCompanion Function({
      Value<int> setup_scope_pk,
      Value<String> axis,
      Value<String> value,
      Value<int?> parent_scope_fk,
      Value<String?> subAxisName,
      Value<String?> subAxisKey,
    });

final class $$SetupScopesTableReferences
    extends BaseReferences<_$NexusDatabase, $SetupScopesTable, SetupScope> {
  $$SetupScopesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SetupScopesTable _parent_scope_fkTable(_$NexusDatabase db) =>
      db.setupScopes.createAlias(
        'setup_scopes__parent_scope_fk__setup_scopes__setup_scope_pk',
      );

  $$SetupScopesTableProcessedTableManager? get parent_scope_fk {
    final $_column = $_itemColumn<int>('parent_scope_fk');
    if ($_column == null) return null;
    final manager = $$SetupScopesTableTableManager(
      $_db,
      $_db.setupScopes,
    ).filter((f) => f.setup_scope_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parent_scope_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SetupScopeOptionsTable, List<SetupScopeOption>>
  _setupScopeOptionsRefsTable(_$NexusDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.setupScopeOptions,
        aliasName:
            'setup_scopes__setup_scope_pk__setup_scope_options__setup_scope_fk',
      );

  $$SetupScopeOptionsTableProcessedTableManager get setupScopeOptionsRefs {
    final manager =
        $$SetupScopeOptionsTableTableManager(
          $_db,
          $_db.setupScopeOptions,
        ).filter(
          (f) => f.setup_scope_fk.setup_scope_pk.sqlEquals(
            $_itemColumn<int>('setup_scope_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _setupScopeOptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SetupScopesTableFilterComposer
    extends Composer<_$NexusDatabase, $SetupScopesTable> {
  $$SetupScopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get setup_scope_pk => $composableBuilder(
    column: $table.setup_scope_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get axis => $composableBuilder(
    column: $table.axis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subAxisName => $composableBuilder(
    column: $table.subAxisName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subAxisKey => $composableBuilder(
    column: $table.subAxisKey,
    builder: (column) => ColumnFilters(column),
  );

  $$SetupScopesTableFilterComposer get parent_scope_fk {
    final $$SetupScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parent_scope_fk,
      referencedTable: $db.setupScopes,
      getReferencedColumn: (t) => t.setup_scope_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopesTableFilterComposer(
            $db: $db,
            $table: $db.setupScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> setupScopeOptionsRefs(
    Expression<bool> Function($$SetupScopeOptionsTableFilterComposer f) f,
  ) {
    final $$SetupScopeOptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setup_scope_pk,
      referencedTable: $db.setupScopeOptions,
      getReferencedColumn: (t) => t.setup_scope_fk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopeOptionsTableFilterComposer(
            $db: $db,
            $table: $db.setupScopeOptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SetupScopesTableOrderingComposer
    extends Composer<_$NexusDatabase, $SetupScopesTable> {
  $$SetupScopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get setup_scope_pk => $composableBuilder(
    column: $table.setup_scope_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get axis => $composableBuilder(
    column: $table.axis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subAxisName => $composableBuilder(
    column: $table.subAxisName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subAxisKey => $composableBuilder(
    column: $table.subAxisKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$SetupScopesTableOrderingComposer get parent_scope_fk {
    final $$SetupScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parent_scope_fk,
      referencedTable: $db.setupScopes,
      getReferencedColumn: (t) => t.setup_scope_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopesTableOrderingComposer(
            $db: $db,
            $table: $db.setupScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetupScopesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $SetupScopesTable> {
  $$SetupScopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get setup_scope_pk => $composableBuilder(
    column: $table.setup_scope_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get axis =>
      $composableBuilder(column: $table.axis, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get subAxisName => $composableBuilder(
    column: $table.subAxisName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subAxisKey => $composableBuilder(
    column: $table.subAxisKey,
    builder: (column) => column,
  );

  $$SetupScopesTableAnnotationComposer get parent_scope_fk {
    final $$SetupScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parent_scope_fk,
      referencedTable: $db.setupScopes,
      getReferencedColumn: (t) => t.setup_scope_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.setupScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> setupScopeOptionsRefs<T extends Object>(
    Expression<T> Function($$SetupScopeOptionsTableAnnotationComposer a) f,
  ) {
    final $$SetupScopeOptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.setup_scope_pk,
          referencedTable: $db.setupScopeOptions,
          getReferencedColumn: (t) => t.setup_scope_fk,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SetupScopeOptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.setupScopeOptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SetupScopesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $SetupScopesTable,
          SetupScope,
          $$SetupScopesTableFilterComposer,
          $$SetupScopesTableOrderingComposer,
          $$SetupScopesTableAnnotationComposer,
          $$SetupScopesTableCreateCompanionBuilder,
          $$SetupScopesTableUpdateCompanionBuilder,
          (SetupScope, $$SetupScopesTableReferences),
          SetupScope,
          PrefetchHooks Function({
            bool parent_scope_fk,
            bool setupScopeOptionsRefs,
          })
        > {
  $$SetupScopesTableTableManager(_$NexusDatabase db, $SetupScopesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetupScopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetupScopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetupScopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> setup_scope_pk = const Value.absent(),
                Value<String> axis = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int?> parent_scope_fk = const Value.absent(),
                Value<String?> subAxisName = const Value.absent(),
                Value<String?> subAxisKey = const Value.absent(),
              }) => SetupScopesCompanion(
                setup_scope_pk: setup_scope_pk,
                axis: axis,
                value: value,
                parent_scope_fk: parent_scope_fk,
                subAxisName: subAxisName,
                subAxisKey: subAxisKey,
              ),
          createCompanionCallback:
              ({
                Value<int> setup_scope_pk = const Value.absent(),
                required String axis,
                required String value,
                Value<int?> parent_scope_fk = const Value.absent(),
                Value<String?> subAxisName = const Value.absent(),
                Value<String?> subAxisKey = const Value.absent(),
              }) => SetupScopesCompanion.insert(
                setup_scope_pk: setup_scope_pk,
                axis: axis,
                value: value,
                parent_scope_fk: parent_scope_fk,
                subAxisName: subAxisName,
                subAxisKey: subAxisKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetupScopesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({parent_scope_fk = false, setupScopeOptionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (setupScopeOptionsRefs) db.setupScopeOptions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parent_scope_fk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parent_scope_fk,
                                    referencedTable:
                                        $$SetupScopesTableReferences
                                            ._parent_scope_fkTable(db),
                                    referencedColumn:
                                        $$SetupScopesTableReferences
                                            ._parent_scope_fkTable(db)
                                            .setup_scope_pk,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (setupScopeOptionsRefs)
                        await $_getPrefetchedData<
                          SetupScope,
                          $SetupScopesTable,
                          SetupScopeOption
                        >(
                          currentTable: table,
                          referencedTable: $$SetupScopesTableReferences
                              ._setupScopeOptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SetupScopesTableReferences(
                                db,
                                table,
                                p0,
                              ).setupScopeOptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.setup_scope_fk == item.setup_scope_pk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SetupScopesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $SetupScopesTable,
      SetupScope,
      $$SetupScopesTableFilterComposer,
      $$SetupScopesTableOrderingComposer,
      $$SetupScopesTableAnnotationComposer,
      $$SetupScopesTableCreateCompanionBuilder,
      $$SetupScopesTableUpdateCompanionBuilder,
      (SetupScope, $$SetupScopesTableReferences),
      SetupScope,
      PrefetchHooks Function({bool parent_scope_fk, bool setupScopeOptionsRefs})
    >;
typedef $$SetupScopeOptionsTableCreateCompanionBuilder =
    SetupScopeOptionsCompanion Function({
      Value<int> setup_scope_option_pk,
      required int setup_scope_fk,
      required String category,
      required String value,
      Value<String?> platform,
      Value<String?> forLanguage,
      Value<int> sort,
    });
typedef $$SetupScopeOptionsTableUpdateCompanionBuilder =
    SetupScopeOptionsCompanion Function({
      Value<int> setup_scope_option_pk,
      Value<int> setup_scope_fk,
      Value<String> category,
      Value<String> value,
      Value<String?> platform,
      Value<String?> forLanguage,
      Value<int> sort,
    });

final class $$SetupScopeOptionsTableReferences
    extends
        BaseReferences<
          _$NexusDatabase,
          $SetupScopeOptionsTable,
          SetupScopeOption
        > {
  $$SetupScopeOptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SetupScopesTable _setup_scope_fkTable(_$NexusDatabase db) =>
      db.setupScopes.createAlias(
        'setup_scope_options__setup_scope_fk__setup_scopes__setup_scope_pk',
      );

  $$SetupScopesTableProcessedTableManager get setup_scope_fk {
    final $_column = $_itemColumn<int>('setup_scope_fk')!;

    final manager = $$SetupScopesTableTableManager(
      $_db,
      $_db.setupScopes,
    ).filter((f) => f.setup_scope_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setup_scope_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetupScopeOptionsTableFilterComposer
    extends Composer<_$NexusDatabase, $SetupScopeOptionsTable> {
  $$SetupScopeOptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get setup_scope_option_pk => $composableBuilder(
    column: $table.setup_scope_option_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forLanguage => $composableBuilder(
    column: $table.forLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  $$SetupScopesTableFilterComposer get setup_scope_fk {
    final $$SetupScopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setup_scope_fk,
      referencedTable: $db.setupScopes,
      getReferencedColumn: (t) => t.setup_scope_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopesTableFilterComposer(
            $db: $db,
            $table: $db.setupScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetupScopeOptionsTableOrderingComposer
    extends Composer<_$NexusDatabase, $SetupScopeOptionsTable> {
  $$SetupScopeOptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get setup_scope_option_pk => $composableBuilder(
    column: $table.setup_scope_option_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forLanguage => $composableBuilder(
    column: $table.forLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  $$SetupScopesTableOrderingComposer get setup_scope_fk {
    final $$SetupScopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setup_scope_fk,
      referencedTable: $db.setupScopes,
      getReferencedColumn: (t) => t.setup_scope_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopesTableOrderingComposer(
            $db: $db,
            $table: $db.setupScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetupScopeOptionsTableAnnotationComposer
    extends Composer<_$NexusDatabase, $SetupScopeOptionsTable> {
  $$SetupScopeOptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get setup_scope_option_pk => $composableBuilder(
    column: $table.setup_scope_option_pk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get forLanguage => $composableBuilder(
    column: $table.forLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  $$SetupScopesTableAnnotationComposer get setup_scope_fk {
    final $$SetupScopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setup_scope_fk,
      referencedTable: $db.setupScopes,
      getReferencedColumn: (t) => t.setup_scope_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetupScopesTableAnnotationComposer(
            $db: $db,
            $table: $db.setupScopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetupScopeOptionsTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $SetupScopeOptionsTable,
          SetupScopeOption,
          $$SetupScopeOptionsTableFilterComposer,
          $$SetupScopeOptionsTableOrderingComposer,
          $$SetupScopeOptionsTableAnnotationComposer,
          $$SetupScopeOptionsTableCreateCompanionBuilder,
          $$SetupScopeOptionsTableUpdateCompanionBuilder,
          (SetupScopeOption, $$SetupScopeOptionsTableReferences),
          SetupScopeOption,
          PrefetchHooks Function({bool setup_scope_fk})
        > {
  $$SetupScopeOptionsTableTableManager(
    _$NexusDatabase db,
    $SetupScopeOptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetupScopeOptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetupScopeOptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetupScopeOptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> setup_scope_option_pk = const Value.absent(),
                Value<int> setup_scope_fk = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<String?> forLanguage = const Value.absent(),
                Value<int> sort = const Value.absent(),
              }) => SetupScopeOptionsCompanion(
                setup_scope_option_pk: setup_scope_option_pk,
                setup_scope_fk: setup_scope_fk,
                category: category,
                value: value,
                platform: platform,
                forLanguage: forLanguage,
                sort: sort,
              ),
          createCompanionCallback:
              ({
                Value<int> setup_scope_option_pk = const Value.absent(),
                required int setup_scope_fk,
                required String category,
                required String value,
                Value<String?> platform = const Value.absent(),
                Value<String?> forLanguage = const Value.absent(),
                Value<int> sort = const Value.absent(),
              }) => SetupScopeOptionsCompanion.insert(
                setup_scope_option_pk: setup_scope_option_pk,
                setup_scope_fk: setup_scope_fk,
                category: category,
                value: value,
                platform: platform,
                forLanguage: forLanguage,
                sort: sort,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetupScopeOptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setup_scope_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setup_scope_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setup_scope_fk,
                                referencedTable:
                                    $$SetupScopeOptionsTableReferences
                                        ._setup_scope_fkTable(db),
                                referencedColumn:
                                    $$SetupScopeOptionsTableReferences
                                        ._setup_scope_fkTable(db)
                                        .setup_scope_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetupScopeOptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $SetupScopeOptionsTable,
      SetupScopeOption,
      $$SetupScopeOptionsTableFilterComposer,
      $$SetupScopeOptionsTableOrderingComposer,
      $$SetupScopeOptionsTableAnnotationComposer,
      $$SetupScopeOptionsTableCreateCompanionBuilder,
      $$SetupScopeOptionsTableUpdateCompanionBuilder,
      (SetupScopeOption, $$SetupScopeOptionsTableReferences),
      SetupScopeOption,
      PrefetchHooks Function({bool setup_scope_fk})
    >;
typedef $$StoryNotesTableCreateCompanionBuilder =
    StoryNotesCompanion Function({
      Value<int> note_pk,
      required int story_fk,
      required String body,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$StoryNotesTableUpdateCompanionBuilder =
    StoryNotesCompanion Function({
      Value<int> note_pk,
      Value<int> story_fk,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$StoryNotesTableReferences
    extends BaseReferences<_$NexusDatabase, $StoryNotesTable, StoryNote> {
  $$StoryNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UserStoriesTable _story_fkTable(_$NexusDatabase db) => db.userStories
      .createAlias('story_notes__story_fk__user_stories__story_pk');

  $$UserStoriesTableProcessedTableManager get story_fk {
    final $_column = $_itemColumn<int>('story_fk')!;

    final manager = $$UserStoriesTableTableManager(
      $_db,
      $_db.userStories,
    ).filter((f) => f.story_pk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_story_fkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StoryNotesTableFilterComposer
    extends Composer<_$NexusDatabase, $StoryNotesTable> {
  $$StoryNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get note_pk => $composableBuilder(
    column: $table.note_pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UserStoriesTableFilterComposer get story_fk {
    final $$UserStoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableFilterComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryNotesTableOrderingComposer
    extends Composer<_$NexusDatabase, $StoryNotesTable> {
  $$StoryNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get note_pk => $composableBuilder(
    column: $table.note_pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserStoriesTableOrderingComposer get story_fk {
    final $$UserStoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableOrderingComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryNotesTableAnnotationComposer
    extends Composer<_$NexusDatabase, $StoryNotesTable> {
  $$StoryNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get note_pk =>
      $composableBuilder(column: $table.note_pk, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$UserStoriesTableAnnotationComposer get story_fk {
    final $$UserStoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.story_fk,
      referencedTable: $db.userStories,
      getReferencedColumn: (t) => t.story_pk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserStoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.userStories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryNotesTableTableManager
    extends
        RootTableManager<
          _$NexusDatabase,
          $StoryNotesTable,
          StoryNote,
          $$StoryNotesTableFilterComposer,
          $$StoryNotesTableOrderingComposer,
          $$StoryNotesTableAnnotationComposer,
          $$StoryNotesTableCreateCompanionBuilder,
          $$StoryNotesTableUpdateCompanionBuilder,
          (StoryNote, $$StoryNotesTableReferences),
          StoryNote,
          PrefetchHooks Function({bool story_fk})
        > {
  $$StoryNotesTableTableManager(_$NexusDatabase db, $StoryNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> note_pk = const Value.absent(),
                Value<int> story_fk = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StoryNotesCompanion(
                note_pk: note_pk,
                story_fk: story_fk,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> note_pk = const Value.absent(),
                required int story_fk,
                required String body,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StoryNotesCompanion.insert(
                note_pk: note_pk,
                story_fk: story_fk,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoryNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({story_fk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (story_fk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.story_fk,
                                referencedTable: $$StoryNotesTableReferences
                                    ._story_fkTable(db),
                                referencedColumn: $$StoryNotesTableReferences
                                    ._story_fkTable(db)
                                    .story_pk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StoryNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$NexusDatabase,
      $StoryNotesTable,
      StoryNote,
      $$StoryNotesTableFilterComposer,
      $$StoryNotesTableOrderingComposer,
      $$StoryNotesTableAnnotationComposer,
      $$StoryNotesTableCreateCompanionBuilder,
      $$StoryNotesTableUpdateCompanionBuilder,
      (StoryNote, $$StoryNotesTableReferences),
      StoryNote,
      PrefetchHooks Function({bool story_fk})
    >;

class $NexusDatabaseManager {
  final _$NexusDatabase _db;
  $NexusDatabaseManager(this._db);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
  $$InferenceServersTableTableManager get inferenceServers =>
      $$InferenceServersTableTableManager(_db, _db.inferenceServers);
  $$AgentPersonasTableTableManager get agentPersonas =>
      $$AgentPersonasTableTableManager(_db, _db.agentPersonas);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db, _db.chatSessions);
  $$UserStoriesTableTableManager get userStories =>
      $$UserStoriesTableTableManager(_db, _db.userStories);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$SkillsTableTableManager get skills =>
      $$SkillsTableTableManager(_db, _db.skills);
  $$DeploymentsTableTableManager get deployments =>
      $$DeploymentsTableTableManager(_db, _db.deployments);
  $$ActivityLogsTableTableManager get activityLogs =>
      $$ActivityLogsTableTableManager(_db, _db.activityLogs);
  $$CiRunsTableTableManager get ciRuns =>
      $$CiRunsTableTableManager(_db, _db.ciRuns);
  $$CiJobsTableTableManager get ciJobs =>
      $$CiJobsTableTableManager(_db, _db.ciJobs);
  $$CiStepsTableTableManager get ciSteps =>
      $$CiStepsTableTableManager(_db, _db.ciSteps);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$ProjectTagsTableTableManager get projectTags =>
      $$ProjectTagsTableTableManager(_db, _db.projectTags);
  $$LibraryVerificationsTableTableManager get libraryVerifications =>
      $$LibraryVerificationsTableTableManager(_db, _db.libraryVerifications);
  $$CallSystemsTableTableManager get callSystems =>
      $$CallSystemsTableTableManager(_db, _db.callSystems);
  $$SetupFlowsTableTableManager get setupFlows =>
      $$SetupFlowsTableTableManager(_db, _db.setupFlows);
  $$SetupScopesTableTableManager get setupScopes =>
      $$SetupScopesTableTableManager(_db, _db.setupScopes);
  $$SetupScopeOptionsTableTableManager get setupScopeOptions =>
      $$SetupScopeOptionsTableTableManager(_db, _db.setupScopeOptions);
  $$StoryNotesTableTableManager get storyNotes =>
      $$StoryNotesTableTableManager(_db, _db.storyNotes);
}
