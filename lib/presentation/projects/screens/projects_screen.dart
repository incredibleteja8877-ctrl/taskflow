import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../auth/providers/auth_controller.dart';

/// TEMPORARY placeholder so the app runs end to end.
///
/// Replaced in the Projects lesson with the real list: pull-to-refresh,
/// loading/empty/error states, and create/edit/delete.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _Row(label: 'Name', value: session?.user.name ?? '—'),
            _Row(label: 'Email', value: session?.user.email ?? '—'),
            _Row(label: 'Org', value: session?.orgId ?? '—'),
            _Row(
              label: 'Role',
              value: session == null
                  ? '—'
                  : (session.isAdmin ? 'org_admin' : 'member'),
            ),
            _Row(
              label: 'Token expires',
              value: session == null
                  ? '—'
                  : session.tokens.accessTokenExpiresAt.toLocal().toString(),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
