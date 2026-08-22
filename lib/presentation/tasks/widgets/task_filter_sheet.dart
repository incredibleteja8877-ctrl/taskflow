import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_filter.dart';
import '../../../domain/entities/user.dart';
import '../../shared/task_display.dart';
import '../providers/task_providers.dart';

/// Task 04's filters: status, priority, assignee, due-date range.
///
/// Edits a local copy and only writes it to [taskFilterProvider] on Apply, so
/// the list behind the sheet does not thrash while the user is still choosing.
class TaskFilterSheet extends ConsumerStatefulWidget {
  const TaskFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const TaskFilterSheet(),
    );
  }

  @override
  ConsumerState<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends ConsumerState<TaskFilterSheet> {
  late TaskFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(taskFilterProvider);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _draft.dueFrom != null && _draft.dueTo != null
          ? DateTimeRange(start: _draft.dueFrom!, end: _draft.dueTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _draft = _draft.copyWith(dueFrom: picked.start, dueTo: picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(orgMembersProvider).valueOrNull ?? const <User>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Filters', style: theme.textTheme.titleLarge),
                  ),
                  if (_draft.isActive)
                    TextButton(
                      onPressed: () =>
                          setState(() => _draft = TaskFilter.none),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Status'),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final status in TaskStatus.values)
                    FilterChip(
                      label: Text(status.label),
                      selected: _draft.statuses.contains(status),
                      onSelected: (selected) => setState(() {
                        final next = {..._draft.statuses};
                        selected ? next.add(status) : next.remove(status);
                        _draft = _draft.copyWith(statuses: next);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Priority'),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final priority in TaskPriority.values)
                    FilterChip(
                      label: Text(priority.label),
                      selected: _draft.priorities.contains(priority),
                      onSelected: (selected) => setState(() {
                        final next = {..._draft.priorities};
                        selected ? next.add(priority) : next.remove(priority);
                        _draft = _draft.copyWith(priorities: next);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Assignee'),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  FilterChip(
                    label: const Text('Unassigned'),
                    selected: _draft.unassignedOnly,
                    onSelected: (selected) => setState(() {
                      _draft = _draft.copyWith(
                        unassignedOnly: selected,
                        // The two are mutually exclusive: "unassigned" and
                        // "assigned to Ava" can never both be true.
                        assigneeIds: selected ? const {} : _draft.assigneeIds,
                      );
                    }),
                  ),
                  for (final member in members)
                    FilterChip(
                      label: Text(member.name),
                      selected: _draft.assigneeIds.contains(member.id),
                      onSelected: (selected) => setState(() {
                        final next = {..._draft.assigneeIds};
                        selected ? next.add(member.id) : next.remove(member.id);
                        _draft = _draft.copyWith(
                          assigneeIds: next,
                          unassignedOnly:
                              next.isEmpty && _draft.unassignedOnly,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Due date range'),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _draft.dueFrom == null
                          ? 'Any date'
                          : '${Formatters.date(_draft.dueFrom)} — '
                              '${Formatters.date(_draft.dueTo)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (_draft.dueFrom != null)
                    IconButton(
                      tooltip: 'Clear range',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(
                        () => _draft = _draft.copyWith(
                          dueFrom: null,
                          dueTo: null,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Pick a range',
                    icon: const Icon(Icons.date_range_outlined),
                    onPressed: _pickRange,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  ref.read(taskFilterProvider.notifier).replace(_draft);
                  Navigator.of(context).pop();
                },
                child: const Text('Apply filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
