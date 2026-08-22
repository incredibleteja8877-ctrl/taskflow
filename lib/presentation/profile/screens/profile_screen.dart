import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_controller.dart';
import '../../shared/widgets/confirm_dialog.dart';

/// Profile / Settings (Task 09), and the reviewer's control panel for the
/// simulated failures required by Tasks 07 and 08.
///
/// The toggles write to [mockApiConfigProvider], which the data source reads
/// on every call — so flipping one changes behaviour immediately with no
/// restart and no source edit. How to use them is documented in the README.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final organization = ref.watch(currentOrganizationProvider).valueOrNull;
    final config = ref.watch(mockApiConfigProvider);
    final configNotifier = ref.read(mockApiConfigProvider.notifier);
    final theme = Theme.of(context);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      session.user.initials,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.user.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          session.user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Chip(
                          label: Text(
                            session.isAdmin ? 'Org admin' : 'Member',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            title: 'Organization',
            children: [
              _Row(label: 'Name', value: organization?.name ?? '—'),
              _Row(label: 'Id', value: session.orgId),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            title: 'Session',
            children: [
              _Row(
                label: 'Access token expires',
                value: Formatters.dateTime(
                  session.tokens.accessTokenExpiresAt,
                ),
              ),
              _Row(
                label: 'Refresh token expires',
                value: Formatters.dateTime(
                  session.tokens.refreshTokenExpiresAt,
                ),
              ),
              // Tokens themselves are never displayed. AuthTokens.toString is
              // redacted for the same reason.
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.autorenew),
                label: const Text('Refresh access token now'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(authControllerProvider.notifier).refresh();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Issued a new access token.'),
                      ),
                    );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            title: 'Developer tools',
            subtitle: 'Simulate failures without editing any source. '
                'See the README for what each one does.',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.cloud_off_outlined),
                title: const Text('Offline mode'),
                subtitle: const Text('Reads fail; cached data is shown'),
                value: config.isOffline,
                onChanged: configNotifier.setOffline,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.timer_off_outlined),
                title: const Text('Force network timeout'),
                subtitle: const Text('Every request times out'),
                value: config.forceTimeout,
                onChanged: configNotifier.setForceTimeout,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.error_outline),
                title: const Text('Force server error'),
                subtitle: const Text('Every request returns a simulated 500'),
                value: config.forceServerError,
                onChanged: configNotifier.setForceServerError,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search_off),
                title: const Text('Simulated 404'),
                subtitle: Text(
                  'Any id containing '
                  '"$_notFoundMarkerHint" always fails. '
                  'Open a deep link such as /task/task_404.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_bottom),
                title: const Text('Artificial latency'),
                subtitle: Text(
                  '${config.minDelay.inMilliseconds}'
                  '–${config.maxDelay.inMilliseconds} ms per request',
                ),
              ),
              if (config.hasForcedFailure)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset all toggles'),
                    onPressed: configNotifier.reset,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () async {
              final confirmed = await ConfirmDialog.confirmed(
                context,
                title: 'Sign out?',
                message: 'Your session will be cleared from this device.',
                confirmLabel: 'Sign out',
              );
              if (!confirmed) return;
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

const String _notFoundMarkerHint = '_404';

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
