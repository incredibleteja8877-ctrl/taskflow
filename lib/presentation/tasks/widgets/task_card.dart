import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/user.dart';
import '../../shared/widgets/task_chips.dart';

/// One row in a task list: title, status, priority, assignee, due date —
/// exactly the fields Task 04 requires the list to show.
///
/// Reads no providers. The screen resolves the assignee and passes it in,
/// so a list of 50 rows does not fire 50 user lookups.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    this.assignee,
    this.projectName,
    this.onTap,
  });

  final Task task;
  final User? assignee;

  /// Shown only on the org-wide list, where tasks come from several projects.
  final String? projectName;

  /// Passed in so every row in a list judges "overdue" against the same
  /// instant, and so a widget test can pin the clock.
  final DateTime now;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue(now);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (projectName != null) ...[
                Text(
                  projectName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
              ],
              Text(
                task.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  decoration:
                      task.isComplete ? TextDecoration.lineThrough : null,
                  color: task.isComplete
                      ? theme.colorScheme.onSurfaceVariant
                      : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  StatusChip(status: task.status),
                  PriorityChip(priority: task.priority),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AssigneeLabel(user: assignee, compact: true),
                  ),
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: overdue
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.relativeDue(task.dueDate, now),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: overdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: overdue ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
