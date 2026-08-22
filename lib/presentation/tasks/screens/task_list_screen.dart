import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/project.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../shared/widgets/state_views.dart';
import '../providers/task_providers.dart';
import '../widgets/task_card.dart';
import '../widgets/task_filter_sheet.dart';
import '../widgets/task_form_sheet.dart';

/// Task 04's task list: title, priority, status, assignee, due date, plus
/// filters and the full set of loading/empty/error states.
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    final filter = ref.watch(taskFilterProvider);
    final members = ref.watch(orgMemberLookupProvider);
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <Project>[];
    final projectNames = {for (final p in projects) p.id: p.name};

    // One instant for the whole list, so two rows can never disagree about
    // whether "today" has passed.
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Filter tasks',
            onPressed: () => TaskFilterSheet.show(context),
            icon: Badge(
              isLabelVisible: filter.isActive,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: Column(
        children: [
          if (filter.isActive)
            _ActiveFilterBar(
              onClear: () => ref.read(taskFilterProvider.notifier).clear(),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
              child: tasks.when(
                loading: () => const LoadingView(message: 'Loading tasks…'),
                error: (error, _) => PullableCenter(
                  child: ErrorView(
                    error: error,
                    onRetry: () =>
                        ref.read(taskListProvider.notifier).retry(),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return PullableCenter(
                      child: EmptyView(
                        icon: Icons.checklist_outlined,
                        title: filter.isActive
                            ? 'No tasks match these filters'
                            : 'No tasks yet',
                        message: filter.isActive
                            ? 'Try widening or clearing the filters.'
                            : 'Create a task to get started.',
                        actionLabel:
                            filter.isActive ? 'Clear filters' : 'New task',
                        onAction: filter.isActive
                            ? () =>
                                ref.read(taskFilterProvider.notifier).clear()
                            : () => TaskFormSheet.show(context),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.page,
                      AppSpacing.page,
                      96,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final task = items[index];
                      return TaskCard(
                        task: task,
                        now: now,
                        assignee: task.assigneeId == null
                            ? null
                            : members[task.assigneeId],
                        projectName: projectNames[task.projectId],
                        onTap: () =>
                            context.push(Routes.taskDetail(task.id)),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Filters applied',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
      ),
    );
  }
}
