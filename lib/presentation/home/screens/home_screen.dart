import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/user.dart';
import '../../auth/providers/auth_controller.dart';
import '../../shared/task_display.dart';
import '../../shared/widgets/state_views.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/widgets/task_card.dart';

/// The Home / Dashboard screen required by Task 09.
///
/// Reads [allTasksProvider] rather than [taskListProvider] on purpose: the
/// dashboard must show true totals, not whatever the user last filtered to.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final organization = ref.watch(currentOrganizationProvider).valueOrNull;
    final tasks = ref.watch(allTasksProvider);
    final members = ref.watch(orgMemberLookupProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allTasksProvider);
          await ref.read(allTasksProvider.future);
        },
        child: tasks.when(
          loading: () => const LoadingView(),
          error: (error, _) => PullableCenter(
            child: ErrorView(
              error: error,
              onRetry: () => ref.invalidate(allTasksProvider),
            ),
          ),
          data: (items) {
            final mine = items
                .where((task) =>
                    task.assigneeId == session?.user.id && !task.isComplete)
                .toList()
              ..sort(_byDueDate);
            final overdue = items.where((task) => task.isOverdue(now)).toList()
              ..sort(_byDueDate);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Text(
                  'Hello, ${session?.user.name.split(' ').first ?? 'there'}',
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  organization?.name ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _StatGrid(tasks: items, now: now),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Assigned to you',
                  emptyMessage: 'Nothing on your plate right now.',
                  tasks: mine.take(5).toList(),
                  now: now,
                  members: members,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (overdue.isNotEmpty)
                  _Section(
                    title: 'Overdue',
                    emptyMessage: '',
                    tasks: overdue.take(5).toList(),
                    now: now,
                    members: members,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static int _byDueDate(Task a, Task b) {
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue == null && bDue == null) return 0;
    if (aDue == null) return 1; // undated tasks sink to the bottom
    if (bDue == null) return -1;
    return aDue.compareTo(bDue);
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tasks, required this.now});

  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = tasks.where((task) => task.isOverdue(now)).length;

    return Column(
      children: [
        Row(
          children: [
            for (final status in TaskStatus.values) ...[
              Expanded(
                child: _StatTile(
                  value: tasks.where((t) => t.status == status).length,
                  label: status.label,
                  color: status.color(theme.colorScheme),
                  icon: status.icon,
                ),
              ),
              if (status != TaskStatus.values.last)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        if (overdue > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(Formatters.count(overdue, 'overdue task')),
              subtitle: const Text('Past their due date and not done'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text('$value', style: theme.textTheme.titleLarge),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyMessage,
    required this.tasks,
    required this.now,
    required this.members,
  });

  final String title;
  final String emptyMessage;
  final List<Task> tasks;
  final DateTime now;
  final Map<String, User> members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (tasks.isEmpty)
          Text(
            emptyMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final task in tasks) ...[
            TaskCard(
              task: task,
              now: now,
              assignee: task.assigneeId == null
                  ? null
                  : members[task.assigneeId],
              onTap: () => context.push(Routes.taskDetail(task.id)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
