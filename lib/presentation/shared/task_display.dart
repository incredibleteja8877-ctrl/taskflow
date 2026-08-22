import 'package:flutter/material.dart';

import '../../domain/entities/project.dart';
import '../../domain/entities/task.dart';

/// Presentation-only mappings for domain enums.
///
/// This is the "UI model" separation Task 01 asks for: the domain knows there
/// is a `TaskStatus.inProgress`; only this file knows it is spelled
/// "In progress", is blue, and shows a half-filled circle. Change the wording
/// or the palette and nothing in domain/ or data/ moves.
extension TaskStatusDisplay on TaskStatus {
  String get label => switch (this) {
        TaskStatus.todo => 'To do',
        TaskStatus.inProgress => 'In progress',
        TaskStatus.review => 'In review',
        TaskStatus.done => 'Done',
      };

  IconData get icon => switch (this) {
        TaskStatus.todo => Icons.radio_button_unchecked,
        TaskStatus.inProgress => Icons.timelapse_outlined,
        TaskStatus.review => Icons.rate_review_outlined,
        TaskStatus.done => Icons.check_circle_outline,
      };

  Color color(ColorScheme scheme) => switch (this) {
        TaskStatus.todo => scheme.outline,
        TaskStatus.inProgress => scheme.primary,
        TaskStatus.review => scheme.tertiary,
        TaskStatus.done => Colors.green.shade600,
      };
}

extension TaskPriorityDisplay on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };

  IconData get icon => switch (this) {
        TaskPriority.low => Icons.keyboard_arrow_down,
        TaskPriority.medium => Icons.remove,
        TaskPriority.high => Icons.keyboard_arrow_up,
        TaskPriority.urgent => Icons.priority_high,
      };

  Color color(ColorScheme scheme) => switch (this) {
        TaskPriority.low => scheme.outline,
        TaskPriority.medium => scheme.onSurfaceVariant,
        TaskPriority.high => Colors.orange.shade700,
        TaskPriority.urgent => scheme.error,
      };
}

extension ProjectStatusDisplay on ProjectStatus {
  String get label => switch (this) {
        ProjectStatus.active => 'Active',
        ProjectStatus.archived => 'Archived',
      };
}
