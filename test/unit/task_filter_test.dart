import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/domain/entities/task.dart';
import 'package:taskflow/domain/entities/task_filter.dart';

/// Task 11: "Unit tests — task filtering logic."
///
/// No Flutter, no async, no data source. This is the payoff for making
/// TaskFilter a plain value object with a pure `matches` method.
void main() {
  Task task({
    String id = 'task_1',
    String title = 'Build the nav',
    String description = 'Header navigation with a mobile drawer',
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    String? assigneeId,
    DateTime? dueDate,
  }) {
    return Task(
      id: id,
      projectId: 'proj_1',
      title: title,
      description: description,
      status: status,
      priority: priority,
      createdAt: DateTime.utc(2026, 1, 1),
      assigneeId: assigneeId,
      dueDate: dueDate,
    );
  }

  group('an empty filter', () {
    test('matches everything', () {
      expect(TaskFilter.none.matches(task()), isTrue);
      expect(
        TaskFilter.none.matches(task(status: TaskStatus.done)),
        isTrue,
      );
      expect(TaskFilter.none.isActive, isFalse);
    });

    test('an empty status set is "no constraint", not "match nothing"', () {
      // The classic bug: reading `!statuses.contains(x)` without first
      // checking the set is non-empty hides every task.
      const filter = TaskFilter(statuses: {});
      expect(filter.matches(task()), isTrue);
    });
  });

  group('status', () {
    test('keeps only the selected statuses', () {
      const filter = TaskFilter(statuses: {TaskStatus.done});
      expect(filter.matches(task(status: TaskStatus.done)), isTrue);
      expect(filter.matches(task(status: TaskStatus.todo)), isFalse);
    });

    test('several selected statuses are an OR', () {
      const filter = TaskFilter(
        statuses: {TaskStatus.todo, TaskStatus.review},
      );
      expect(filter.matches(task(status: TaskStatus.todo)), isTrue);
      expect(filter.matches(task(status: TaskStatus.review)), isTrue);
      expect(filter.matches(task(status: TaskStatus.done)), isFalse);
    });
  });

  group('priority', () {
    test('keeps only the selected priorities', () {
      const filter = TaskFilter(priorities: {TaskPriority.urgent});
      expect(filter.matches(task(priority: TaskPriority.urgent)), isTrue);
      expect(filter.matches(task(priority: TaskPriority.low)), isFalse);
    });
  });

  group('assignee', () {
    test('matches a specific person', () {
      const filter = TaskFilter(assigneeIds: {'user_002'});
      expect(filter.matches(task(assigneeId: 'user_002')), isTrue);
      expect(filter.matches(task(assigneeId: 'user_003')), isFalse);
      expect(filter.matches(task()), isFalse, reason: 'unassigned');
    });

    test('unassignedOnly excludes every assigned task', () {
      const filter = TaskFilter(unassignedOnly: true);
      expect(filter.matches(task()), isTrue);
      expect(filter.matches(task(assigneeId: 'user_002')), isFalse);
    });
  });

  group('due-date range', () {
    final jan10 = DateTime.utc(2026, 1, 10);
    final jan20 = DateTime.utc(2026, 1, 20);
    final jan15 = DateTime.utc(2026, 1, 15);

    test('keeps tasks inside the range, inclusive at both ends', () {
      final filter = TaskFilter(dueFrom: jan10, dueTo: jan20);
      expect(filter.matches(task(dueDate: jan15)), isTrue);
      expect(filter.matches(task(dueDate: jan10)), isTrue);
      expect(filter.matches(task(dueDate: jan20)), isTrue);
    });

    test('drops tasks outside the range', () {
      final filter = TaskFilter(dueFrom: jan10, dueTo: jan20);
      expect(filter.matches(task(dueDate: DateTime.utc(2026, 1, 5))), isFalse);
      expect(filter.matches(task(dueDate: DateTime.utc(2026, 2, 1))), isFalse);
    });

    test('an undated task cannot satisfy a date range', () {
      final filter = TaskFilter(dueFrom: jan10);
      expect(filter.matches(task()), isFalse);
    });
  });

  group('text query', () {
    test('searches title and description, case-insensitively', () {
      const byTitle = TaskFilter(query: 'NAV');
      expect(byTitle.matches(task()), isTrue);

      const byDescription = TaskFilter(query: 'drawer');
      expect(byDescription.matches(task()), isTrue);

      const noMatch = TaskFilter(query: 'invoice');
      expect(noMatch.matches(task()), isFalse);
    });

    test('a whitespace-only query is treated as no query', () {
      const filter = TaskFilter(query: '   ');
      expect(filter.matches(task()), isTrue);
      expect(filter.isActive, isFalse);
    });
  });

  group('combinations', () {
    test('separate criteria are ANDed together', () {
      const filter = TaskFilter(
        statuses: {TaskStatus.todo},
        priorities: {TaskPriority.urgent},
      );
      expect(
        filter.matches(
          task(status: TaskStatus.todo, priority: TaskPriority.urgent),
        ),
        isTrue,
      );
      expect(
        filter.matches(
          task(status: TaskStatus.todo, priority: TaskPriority.low),
        ),
        isFalse,
      );
    });
  });

  group('copyWith', () {
    test('clearing a date range is possible, thanks to the sentinel', () {
      final filter = TaskFilter(dueFrom: DateTime.utc(2026, 1, 1));
      expect(filter.isActive, isTrue);

      final cleared = filter.copyWith(dueFrom: null);
      expect(cleared.dueFrom, isNull);
      expect(cleared.isActive, isFalse);
    });

    test('omitting an argument leaves the value alone', () {
      final filter = TaskFilter(dueFrom: DateTime.utc(2026, 1, 1));
      final unchanged = filter.copyWith(query: 'x');
      expect(unchanged.dueFrom, filter.dueFrom);
    });
  });

  group('isOverdue', () {
    final due = DateTime.utc(2026, 1, 10);

    test('is false before the due date', () {
      expect(
        task(dueDate: due).isOverdue(DateTime.utc(2026, 1, 9)),
        isFalse,
      );
    });

    test('is false on the due date itself', () {
      expect(
        task(dueDate: due).isOverdue(DateTime.utc(2026, 1, 10, 23)),
        isFalse,
      );
    });

    test('is true the day after', () {
      expect(
        task(dueDate: due).isOverdue(DateTime.utc(2026, 1, 11)),
        isTrue,
      );
    });

    test('a completed task is never overdue', () {
      expect(
        task(dueDate: due, status: TaskStatus.done)
            .isOverdue(DateTime.utc(2027)),
        isFalse,
      );
    });

    test('an undated task is never overdue', () {
      expect(task().isOverdue(DateTime.utc(2030)), isFalse);
    });
  });
}
