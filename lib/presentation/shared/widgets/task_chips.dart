import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/user.dart';
import '../task_display.dart';

/// Small coloured label. The one place a chip's shape and density is decided.
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MetaChip(
      label: status.label,
      color: status.color(scheme),
      icon: status.icon,
    );
  }
}

class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MetaChip(
      label: priority.label,
      color: priority.color(scheme),
      icon: priority.icon,
    );
  }
}

/// Avatar plus name, or an "Unassigned" placeholder.
///
/// Three tasks in the mock data have no assignee, so the null path is the
/// normal case rather than an edge case.
class AssigneeLabel extends StatelessWidget {
  const AssigneeLabel({
    super.key,
    required this.user,
    this.compact = false,
  });

  final User? user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final person = user;

    if (person == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: compact ? 16 : 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Unassigned',
            style: (compact
                    ? theme.textTheme.labelMedium
                    : theme.textTheme.bodyMedium)
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 9 : 14,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            person.initials,
            style: TextStyle(
              fontSize: compact ? 8 : 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          person.name,
          style: compact
              ? theme.textTheme.labelMedium
              : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
