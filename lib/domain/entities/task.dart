import 'package:equatable/equatable.dart';

/// Where a task sits in the workflow.
/// The JSON spellings ("in_progress") live in TaskModel, not here.
enum TaskStatus { todo, inProgress, review, done }

/// How urgent a task is. Declared low → urgent so `.index` sorts correctly.
enum TaskPriority { low, medium, high, urgent }

/// A unit of work inside a project. Pure Dart — no Flutter, no JSON.
class Task extends Equatable {
  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.assigneeId,
    this.dueDate,
  });

  final String id;
  final String projectId;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime createdAt;

  /// Null means unassigned. Three tasks in the mock data are.
  final String? assigneeId;

  final DateTime? dueDate;

  bool get isAssigned => assigneeId != null;

  bool get isComplete => status == TaskStatus.done;

  /// Past its due date and not finished.
  ///
  /// [now] is a parameter rather than a call to DateTime.now() so a test can
  /// pin the clock. A getter reading the real clock is untestable.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isComplete) return false;
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Sentinel meaning "this argument was not supplied".
  /// See the note on [copyWith] below.
  static const Object _unset = Object();

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    Object? assigneeId = _unset,
    Object? dueDate = _unset,
  }) {
    return Task(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      assigneeId:
          identical(assigneeId, _unset) ? this.assigneeId : assigneeId as String?,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        title,
        description,
        status,
        priority,
        createdAt,
        assigneeId,
        dueDate,
      ];
}
