import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../auth/providers/auth_controller.dart';
import '../../shared/task_display.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/widgets/task_card.dart';

import '../providers/project_detail_provider.dart';
import '../providers/project_list_controller.dart';
import '../widgets/project_form_sheet.dart';

/// Task 03's Project Details: task summary counts grouped by status, plus the
/// project's task list.
///
/// Reached by deep link as well as by tapping a card, so an id belonging to
/// another org must fail gracefully — ProjectUseCases.getById throws
/// NotFoundException and ErrorView renders it.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectDetailProvider(projectId));
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.valueOrNull?.name ?? 'Project'),
        actions: [
          if (project.hasValue)
            PopupMenuButton<String>(
              tooltip: 'Project actions',
              onSelected: (value) async {
                if (value == 'edit') {
                  await ProjectFormSheet.show(
                    context,
                    project: project.requireValue,
                  );
                  ref.invalidate(projectDetailProvider(projectId));
                } else if (value == 'delete') {
                  await _confirmDelete(context, ref, project.requireValue);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (isAdmin)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      floatingActionButton: project.hasValue
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(Routes.taskNew(projectId: projectId)),
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            )
          : null,
      body: project.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(projectDetailProvider(projectId)),
        ),
        data: (data) => _Body(project: data),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirmed = await ConfirmDialog.confirmed(
      context,
      title: 'Delete project?',
      message: '"${project.name}" and all of its tasks will be removed. '
          'This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(projectListProvider.notifier).deleteProject(project.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${project.name}".')),
      );
      router.go(Routes.projects);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(project.id));
    final members = ref.watch(orgMemberLookupProvider);
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(projectDetailProvider(project.id));
        await ref.read(projectTasksProvider(project.id).notifier).refresh();
      },
      child: tasks.when(
        loading: () => const LoadingView(),
        error: (error, _) => PullableCenter(
          child: ErrorView(
            error: error,
            onRetry: () =>
                ref.read(projectTasksProvider(project.id).notifier).retry(),
          ),
        ),
        data: (items) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            96,
          ),
          children: [
            _Header(project: project),
            const SizedBox(height: AppSpacing.lg),
            _StatusSummary(tasks: items),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: EmptyView(
                  icon: Icons.checklist_outlined,
                  title: 'No tasks in this project',
                  message: 'Add the first one with the button below.',
                ),
              )
            else
              for (final task in items) ...[
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
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.name, style: theme.textTheme.titleLarge),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                project.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              '${project.status.label} · created '
              '${Formatters.date(project.createdAt)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Task 03: "task summary counts grouped by status".
class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <TaskStatus, int>{
      for (final status in TaskStatus.values)
        status: tasks.where((task) => task.status == status).length,
    };

    return Row(
      children: [
        for (final status in TaskStatus.values) ...[
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    Icon(
                      status.icon,
                      size: 18,
                      color: status.color(theme.colorScheme),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${counts[status]}',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      status.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (status != TaskStatus.values.last)
            const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}
