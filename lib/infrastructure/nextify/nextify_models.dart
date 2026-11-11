// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

// Data models for the Nextify cloud-hosting REST API
// (`https://api.nextifynow.com/v1`).
//
// The API is JSON-over-HTTPS, Bearer-token authenticated. Async operations
// (create/delete/start/stop) answer immediately with a `job_id`; the caller
// follows it via NextifyJob. Parsers are deliberately lenient — they read
// only the fields the app needs and ignore anything else, so an evolving API
// never breaks a read.

/// A typed API error. The API returns `{"error": {code, message}}` with a
/// stable [code] (e.g. `unauthorized`, `quota_exceeded`, `name_taken`).
class NextifyApiException implements Exception {
  final int status;
  final String code;
  final String message;
  const NextifyApiException(this.status, this.code, this.message);

  @override
  String toString() =>
      'Nextify error $status ($code): $message';
}

/// The account a token belongs to (from `GET /v1/me`).
class NextifyAccount {
  final String accountId;
  final String accountName;
  final String plan;
  final String tenantStatus;

  const NextifyAccount({
    required this.accountId,
    required this.accountName,
    required this.plan,
    required this.tenantStatus,
  });

  factory NextifyAccount.fromJson(Map<String, dynamic> j) {
    final acct = (j['account'] as Map?)?.cast<String, dynamic>() ?? const {};
    final tenant = (j['tenant'] as Map?)?.cast<String, dynamic>() ?? const {};
    return NextifyAccount(
      accountId: (acct['id'] as String?) ?? '',
      accountName: (acct['name'] as String?) ?? '',
      plan: (tenant['plan'] as String?) ?? '',
      tenantStatus: (tenant['status'] as String?) ?? '',
    );
  }
}

/// Progress within a background job.
class NextifyJobProgress {
  final int percent;
  final String stage;
  const NextifyJobProgress({required this.percent, required this.stage});

  factory NextifyJobProgress.fromJson(Map<String, dynamic> j) =>
      NextifyJobProgress(
        percent: (j['percent'] as num?)?.toInt() ?? 0,
        stage: (j['stage'] as String?) ?? '',
      );
}

/// A background job (`GET /v1/jobs/{id}`). [status] is one of `queued`,
/// `running`, `retrying`, `succeeded`, `failed`.
class NextifyJob {
  final String id;
  final String type;
  final String action;
  final String status;
  final NextifyJobProgress? progress;
  final int attempts;
  final String? errorCode;
  final String? errorMessage;

  const NextifyJob({
    required this.id,
    required this.type,
    required this.action,
    required this.status,
    this.progress,
    required this.attempts,
    this.errorCode,
    this.errorMessage,
  });

  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';
  bool get isTerminal => isSucceeded || isFailed;

  factory NextifyJob.fromJson(Map<String, dynamic> j) {
    final p = (j['progress'] as Map?)?.cast<String, dynamic>();
    final err = (j['error'] as Map?)?.cast<String, dynamic>();
    return NextifyJob(
      id: (j['id'] as String?) ?? '',
      type: (j['type'] as String?) ?? '',
      action: (j['action'] as String?) ?? '',
      status: (j['status'] as String?) ?? '',
      progress: p == null ? null : NextifyJobProgress.fromJson(p),
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      errorCode: err?['code'] as String?,
      errorMessage: err?['message'] as String?,
    );
  }
}

/// A compute instance (`GET /v1/instances[/{id}]`). [status] is e.g.
/// `creating`, `running`, `stopped`, `deleted`.
class NextifyInstance {
  final String id;
  final String name;
  final String status;
  final String? desiredStatus;
  final String? publicIp;
  final String? machineType;
  final String? region;
  final String? image;
  final String? error;
  final String? powerError;
  final Map<String, String> labels;

  const NextifyInstance({
    required this.id,
    required this.name,
    required this.status,
    this.desiredStatus,
    this.publicIp,
    this.machineType,
    this.region,
    this.image,
    this.error,
    this.powerError,
    this.labels = const {},
  });

  bool get isRunning => status == 'running';
  bool get isDeleted => status == 'deleted';

  factory NextifyInstance.fromJson(Map<String, dynamic> j) {
    final labels = (j['labels'] is Map)
        ? (j['labels'] as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          )
        : const <String, String>{};
    return NextifyInstance(
      id: (j['id'] as String?) ?? '',
      name: (j['name'] as String?) ?? '',
      status: (j['status'] as String?) ?? '',
      desiredStatus: j['desired_status'] as String?,
      publicIp: j['public_ip'] as String?,
      machineType: j['machine_type'] as String?,
      region: j['region'] as String?,
      image: j['image'] as String?,
      error: j['error'] as String?,
      powerError: j['power_error'] as String?,
      labels: labels,
    );
  }
}

/// The response of `POST /v1/instances` — the (transitional) instance plus the
/// [jobId] to follow to completion.
class NextifyInstanceCreate {
  final NextifyInstance instance;
  final String jobId;
  const NextifyInstanceCreate({required this.instance, required this.jobId});

  factory NextifyInstanceCreate.fromJson(Map<String, dynamic> j) =>
      NextifyInstanceCreate(
        instance: NextifyInstance.fromJson(j.cast<String, dynamic>()),
        jobId: (j['job_id'] as String?) ?? '',
      );
}

/// A machine type from `GET /v1/machines`.
class NextifyMachine {
  final String code;
  final int vcpu;
  final int ramGb;
  final double priceMonthCents;

  const NextifyMachine({
    required this.code,
    required this.vcpu,
    required this.ramGb,
    required this.priceMonthCents,
  });

  String get priceLabel =>
      '\$${(priceMonthCents / 100).toStringAsFixed(2)}/mo';

  factory NextifyMachine.fromJson(Map<String, dynamic> j) => NextifyMachine(
        code: (j['code'] as String?) ?? '',
        vcpu: (j['vcpu'] as num?)?.toInt() ?? 1,
        ramGb: (j['ram_gb'] as num?)?.toInt() ?? 1,
        priceMonthCents: (j['price_month_cents'] as num?)?.toDouble() ?? 0,
      );
}

/// An app template from `GET /v1/apps` (WordPress, Gitea, …).
class NextifyApp {
  final String slug;
  final String name;
  final String category;
  final List<int> publicPorts;

  const NextifyApp({
    required this.slug,
    required this.name,
    required this.category,
    required this.publicPorts,
  });

  factory NextifyApp.fromJson(Map<String, dynamic> j) => NextifyApp(
        slug: (j['slug'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        category: (j['category'] as String?) ?? '',
        publicPorts: (j['ports_public'] as List?)
                ?.whereType<num>()
                .map((e) => e.toInt())
                .toList() ??
            const [],
      );
}
