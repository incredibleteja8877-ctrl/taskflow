import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/user.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../shared/task_display.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../../core/router/app_router.dart';
import '../../shared/widgets/task_chips.dart';
import '../providers/task_providers.dart';


/// Task Details (Tasks 04 and 05): view everything, change status and
/// priority inline, assign or unassign, edit, delete.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          if (task.hasValue) ...[
            IconButton(
              tooltip: 'Edit task',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(Routes.taskEdit(taskId)),
            ),
            IconButton(
              tooltip: 'Delete task',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, task.requireValue),
            ),
          ],
        ],
      ),
      body: task.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (data) => _Body(task: data),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirmed = await ConfirmDialog.confirmed(
      context,
      title: 'Delete task?',
      message: '"${task.title}" will be removed. This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(taskActionsProvider).delete(task.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${task.title}".')),
      );
      if (router.canPop()) router.pop();
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(orgMembersProvider).valueOrNull ?? const <User>[];
    final lookup = ref.watch(orgMemberLookupProvider);
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <Project>[];
    final projectName = projects
        .where((project) => project.id == task.projectId)
        .map((project) => project.name)
        .firstOrNull;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (projectName != null)
          Text(
            projectName,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(task.title, style: theme.textTheme.headlineSmall),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(task.description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),

        // Inline status change — Task 04's "update task status and priority".
        _SectionCard(
          title: 'Status',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in TaskStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  avatar: Icon(
                    status.icon,
                    size: 16,
                    color: status.color(theme.colorScheme),
                  ),
                  selected: task.status == status,
                  onSelected: (selected) {
                    if (!selected) return;
                    _run(
                      context,
                      () => ref
                          .read(taskActionsProvider)
                          .setStatus(task.id, status),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          title: 'Priority',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final priority in TaskPriority.values)
                ChoiceChip(
                  label: Text(priority.label),
                  selected: task.priority == priority,
                  onSelected: (selected) {
                    if (!selected) return;
                    _run(
                      context,
                      () => ref
                          .read(taskActionsProvider)
                          .setPriority(task.id, priority),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          title: 'Assignee',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AssigneeLabel(
                      user: task.assigneeId == null
                          ? null
                          : lookup[task.assigneeId],
                    ),
                  ),
                  if (task.isAssigned)
                    TextButton(
                      onPressed: () => _run(
                        context,
                        () => ref
                            .read(taskActionsProvider)
                            .assign(task.id, null),
                      ),
                      child: const Text('Unassign'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Only org members appear here. The usecase re-checks anyway,
              // because Task 05 requires the rule to hold even if the picker
              // is bypassed.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final member in members)
                    ActionChip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          member.initials,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      label: Text(member.name),
                      onPressed: task.assigneeId == member.id
                          ? null
                          : () => _run(
                                context,
                                () => ref
                                    .read(taskActionsProvider)
                                    .assign(task.id, member.id),
                              ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SectionCard(
          title: 'Details',
          child: Column(
            children: [
              _DetailRow(
                label: 'Due',
                value: Formatters.relativeDue(task.dueDate, now),
                isAlert: task.isOverdue(now),
              ),
              _DetailRow(
                label: 'Due date',
                value: Formatters.date(task.dueDate),
              ),
              _DetailRow(
                label: 'Created',
                value: Formatters.dateTime(task.createdAt),
              ),
              _DetailRow(label: 'Task id', value: task.id),
            ],
          ),
        ),
      ],
    );
  }

  /// Runs a mutation and surfaces any AppException as a snackbar.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on AppException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isAlert = false,
  });

  final String label;
  final String value;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isAlert ? theme.colorScheme.error : null,
                fontWeight: isAlert ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
