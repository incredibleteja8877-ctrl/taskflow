import 'package:equatable/equatable.dart';

import 'task.dart';

/// The query a user has built in the task-list filter sheet.
///
/// A plain value object with a pure [matches] method. No Flutter, no async,
/// no data source — so a unit test can exercise every branch in milliseconds.
class TaskFilter extends Equatable {
  const TaskFilter({
    this.statuses = const {},
    this.priorities = const {},
    this.assigneeIds = const {},
    this.unassignedOnly = false,
    this.dueFrom,
    this.dueTo,
    this.query = '',
  });

  /// The "show everything" filter.
  static const TaskFilter none = TaskFilter();

  /// An EMPTY set means "no constraint on status", not "match nothing".
  /// Getting this backwards is the classic filter bug.
  final Set<TaskStatus> statuses;

  final Set<TaskPriority> priorities;

  /// Specific people. Combine with [unassignedOnly] to get "mine or nobody's".
  final Set<String> assigneeIds;

  final bool unassignedOnly;

  /// Inclusive lower bound on due date.
  final DateTime? dueFrom;

  /// Inclusive upper bound on due date.
  final DateTime? dueTo;

  /// Free-text search over title and description.
  final String query;

  /// True when at least one constraint is set. Drives the "Filters (3)" badge
  /// and the "Clear all" button.
  bool get isActive =>
      statuses.isNotEmpty ||
      priorities.isNotEmpty ||
      assigneeIds.isNotEmpty ||
      unassignedOnly ||
      dueFrom != null ||
      dueTo != null ||
      query.trim().isNotEmpty;

  /// Does this task survive the filter?
  ///
  /// Written as a series of early rejections rather than one giant boolean:
  /// each rule reads independently and a failing test points at one line.
  bool matches(Task task) {
    if (statuses.isNotEmpty && !statuses.contains(task.status)) {
      return false;
    }
    if (priorities.isNotEmpty && !priorities.contains(task.priority)) {
      return false;
    }
    if (unassignedOnly && task.isAssigned) {
      return false;
    }
    if (assigneeIds.isNotEmpty) {
      final id = task.assigneeId;
      if (id == null || !assigneeIds.contains(id)) return false;
    }

    final due = task.dueDate;
    if (dueFrom != null && (due == null || due.isBefore(dueFrom!))) {
      return false;
    }
    if (dueTo != null && (due == null || due.isAfter(dueTo!))) {
      return false;
    }

    final trimmed = query.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      final haystack = '${task.title} ${task.description}'.toLowerCase();
      if (!haystack.contains(trimmed)) return false;
    }

    return true;
  }

  /// Same `_unset` sentinel trick as [Task.copyWith] — without it, clearing a
  /// date range would be impossible, because `dueFrom: null` would read as
  /// "not supplied".
  static const Object _unset = Object();

  TaskFilter copyWith({
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
    Set<String>? assigneeIds,
    bool? unassignedOnly,
    Object? dueFrom = _unset,
    Object? dueTo = _unset,
    String? query,
  }) {
    return TaskFilter(
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      dueFrom: identical(dueFrom, _unset) ? this.dueFrom : dueFrom as DateTime?,
      dueTo: identical(dueTo, _unset) ? this.dueTo : dueTo as DateTime?,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [
        statuses,
        priorities,
        assigneeIds,
        unassignedOnly,
        dueFrom,
        dueTo,
        query,
      ];
}
