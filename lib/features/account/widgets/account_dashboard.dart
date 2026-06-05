// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

/// Signed-in dashboard: identity header, usage meter, subscription summary,
/// plan + add-on catalog (with checkout), manage-billing, sign out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../infrastructure/lemonade/api/exceptions.dart';
import '../../../infrastructure/nexus/models/nexus_account_models.dart';
import '../../../infrastructure/nexus/nexus_url_launcher.dart';
import '../../../infrastructure/nexus/providers/nexus_account_providers.dart';
import '../../../shared/ui/nexus_ui.dart';
import 'usage_meter_card.dart';
import 'plan_catalog_section.dart';

class AccountDashboard extends ConsumerWidget {
  const AccountDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(nexusAuthProvider);
    final usageAsync = ref.watch(nexusUsageProvider);
    final accountAsync = ref.watch(nexusAccountSummaryProvider);

    // No inner scroll: AccountView wraps the whole page (settings cards + this
    // dashboard) in ONE scroll view so it all scrolls together.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IdentityHeader(
              user: auth.user,
              client: auth.client,
              onRefresh: () {
                ref.invalidate(nexusUsageProvider);
                ref.invalidate(nexusAccountSummaryProvider);
              },
              onSignOut: () => ref.read(nexusAuthProvider.notifier).logout(),
            ),
            Gap.lg,

            // Usage meter.
            usageAsync.when(
              data: (usage) => UsageMeterCard(usage: usage),
              loading: () => const _LoadingCard(label: 'Loading usage…'),
              error: (e, _) => _ErrorCard(
                label: 'Usage unavailable',
                message: _messageOf(e),
                onRetry: () => ref.invalidate(nexusUsageProvider),
              ),
            ),
            Gap.sm,

            // Full history (12-month token usage) lives on the website dashboard.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openExternalUrl(
                  _websiteDashboardUrl(ref.read(nexusGatewayBaseUrlProvider)),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('View usage history on website'),
              ),
            ),
            Gap.lg,

            // Subscription summary.
            accountAsync.when(
              data: (account) =>
                  _SubscriptionCard(subscription: account.subscription),
              loading: () => const _LoadingCard(label: 'Loading subscription…'),
              error: (e, _) => _ErrorCard(
                label: 'Subscription unavailable',
                message: _messageOf(e),
                onRetry: () => ref.invalidate(nexusAccountSummaryProvider),
              ),
            ),
            Gap.lg,

            // Manage billing button.
            Align(
              alignment: Alignment.centerLeft,
              child: _ManageBillingButton(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Plans + add-ons catalog.
            const PlanCatalogSection(),
          ],
        ),
      ),
    );
  }
}

String _messageOf(Object e) =>
    e is LemonadeApiException ? e.message : e.toString();

/// Maps the API gateway base URL to the customer website's usage-history page.
/// The API is served from the `api.` host (e.g. api.nexus-projects.ai) while the
/// site dashboard lives at the `www.` host, so we swap `api.` → `www.` and point
/// at `/dashboard`. Falls back to the production site for bare/odd inputs.
String _websiteDashboardUrl(String gatewayBaseUrl) {
  var raw = gatewayBaseUrl.trim();
  if (!raw.contains('://')) raw = 'https://$raw';
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) {
    return 'https://www.nexus-projects.ai/dashboard';
  }
  // Normalize to the `www.` site host: drop a leading `api.`, then ensure a
  // `www.` prefix on real (dotted) domains. Bare hosts like `localhost` are
  // left as-is so dev overrides still work.
  var host = uri.host.startsWith('api.') ? uri.host.substring(4) : uri.host;
  if (host.contains('.') && !host.startsWith('www.')) {
    host = 'www.$host';
  }
  return Uri(
    scheme: uri.scheme,
    host: host,
    port: uri.hasPort ? uri.port : null,
    path: '/dashboard',
  ).toString();
}

// ─────────────────────────────────────────────────────────────────────────────

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.user,
    required this.client,
    required this.onRefresh,
    required this.onSignOut,
  });

  final NexusUser? user;
  final NexusClient? client;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email ?? '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (user?.role != null)
                      StatusChip(
                        user!.role,
                        intent: ChipIntent.accent,
                        dense: true,
                      ),
                    if (client?.name != null && client!.name.isNotEmpty)
                      Text(
                        client!.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});
  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    final s = subscription;
    final period = (s.currentPeriodStart != null && s.currentPeriodEnd != null)
        ? '${df.format(s.currentPeriodStart!)} – ${df.format(s.currentPeriodEnd!)}'
        : null;
    final active = s.status == 'Active' || s.status == 'Trialing';
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Subscription',
            trailing: StatusChip(
              s.status.isEmpty ? 'None' : s.status,
              intent: active ? ChipIntent.success : ChipIntent.neutral,
              dense: true,
            ),
          ),
          Gap.md,
          _kv(context, 'Plan', s.planKey ?? '—'),
          if (period != null) _kv(context, 'Current period', period),
          Gap.md,
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Token limit',
                  value: _fmtInt(s.tokenLimit),
                  icon: Icons.toll_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: 'Image limit',
                  value: _fmtInt(s.imageLimit),
                  icon: Icons.image_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: 'Agent sessions',
                  value: _fmtInt(s.agentLimit),
                  icon: Icons.smart_toy_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ManageBillingButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManageBillingButton> createState() =>
      _ManageBillingButtonState();
}

class _ManageBillingButtonState extends ConsumerState<_ManageBillingButton> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final client = ref.read(nexusAuthProvider.notifier).authedClient();
      final url = await client.openBillingPortal();
      final ok = await openExternalUrl(url);
      if (!ok && mounted) {
        _snack('Could not open billing portal. URL: $url');
      }
    } on LemonadeApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _open,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.credit_card, size: 18),
      label: const Text('Manage billing'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.label,
    required this.message,
    required this.onRetry,
  });
  final String label;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return NexusCard(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _fmtInt(int v) => NumberFormat.decimalPattern().format(v);
