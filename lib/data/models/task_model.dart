import '../../core/error/app_exception.dart';
import '../../domain/entities/task.dart';

/// Translates between the mock JSON wire format and the [Task] entity.
///
/// Lives in `data/` on purpose: [Task] must never learn that `status` arrives
/// as the string "in_progress". If a real API later sends `status: 2`, only
/// this file changes.
///
/// `abstract final class` makes this a pure namespace: it cannot be
/// instantiated and cannot be extended. It is a bag of functions, not a thing.
abstract final class TaskModel {
  static Task fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: statusFromWire(json['status'] as String),
      priority: priorityFromWire(json['priority'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      assigneeId: json['assignee_id'] as String?,
      dueDate: _parseDate(json['due_date'] as String?),
    );
  }

  static Map<String, dynamic> toJson(Task task) {
    return <String, dynamic>{
      'id': task.id,
      'project_id': task.projectId,
      'title': task.title,
      'description': task.description,
      'status': statusToWire(task.status),
      'priority': priorityToWire(task.priority),
      'assignee_id': task.assigneeId,
      'due_date': _formatDate(task.dueDate),
      'created_at': task.createdAt.toUtc().toIso8601String(),
    };
  }

  static TaskStatus statusFromWire(String value) => switch (value) {
        'todo' => TaskStatus.todo,
        'in_progress' => TaskStatus.inProgress,
        'review' => TaskStatus.review,
        'done' => TaskStatus.done,
        _ => throw ValidationException('Unknown task status "$value".'),
      };

  static String statusToWire(TaskStatus status) => switch (status) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.review => 'review',
        TaskStatus.done => 'done',
      };

  static TaskPriority priorityFromWire(String value) => switch (value) {
        'low' => TaskPriority.low,
        'medium' => TaskPriority.medium,
        'high' => TaskPriority.high,
        'urgent' => TaskPriority.urgent,
        _ => throw ValidationException('Unknown task priority "$value".'),
      };

  static String priorityToWire(TaskPriority priority) => switch (priority) {
        TaskPriority.low => 'low',
        TaskPriority.medium => 'medium',
        TaskPriority.high => 'high',
        TaskPriority.urgent => 'urgent',
      };

  /// `due_date` is a plain calendar date ("2026-01-20"), not a timestamp like
  /// `created_at` ("2025-12-02T09:00:00Z"). Both parse, but only one has a
  /// time zone, so we format them back differently.
  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.parse(value);
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
