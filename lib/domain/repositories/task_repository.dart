import 'package:equatable/equatable.dart';

import '../entities/task.dart';
import '../entities/task_filter.dart';

/// Everything the app can do to tasks.
///
/// `abstract interface class` (Dart 3) means this can only be *implemented*,
/// never extended — nobody can inherit half of it and quietly leave a method
/// behind. It is a contract, not a base class.
///
/// Implementations must throw only [AppException] subtypes. A future HTTP
/// implementation catches `SocketException` and rethrows
/// `NetworkTimeoutException`, so nothing above this line ever learns that the
/// transport changed. That is the whole point of the layer.
abstract interface class TaskRepository {
  /// Tasks, optionally narrowed to one project and/or a [filter].
  ///
  /// Filtering is a repository concern because a real API would do it in the
  /// query string. Doing it here keeps the provider layer thin.
  Future<List<Task>> getTasks({
    String? projectId,
    TaskFilter filter = TaskFilter.none,
  });

  /// Throws [NotFoundException] if no such task exists.
  Future<Task> getTask(String taskId);

  Future<Task> createTask(CreateTaskRequest request);

  /// Full replacement, like an HTTP PUT.
  ///
  /// There is no `UpdateTaskRequest` on purpose: [Task.copyWith] already
  /// solves partial updates correctly, including clearing a nullable
  /// assignee. A second half-populated request object would duplicate that
  /// logic and get the null case wrong.
  Future<Task> updateTask(Task task);

  /// Throws [NotFoundException] if no such task exists.
  Future<void> deleteTask(String taskId);
}

/// The payload for creating a task.
///
/// A request model rather than a [Task] because a task that does not exist
/// yet has no `id` and no `createdAt` — the data layer mints both. Modelling
/// it as a `Task` would force callers to invent fake values for fields they
/// have no business setting.
class CreateTaskRequest extends Equatable {
  const CreateTaskRequest({
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.assigneeId,
    this.dueDate,
  });

  final String projectId;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? assigneeId;
  final DateTime? dueDate;

  @override
  List<Object?> get props => [
        projectId,
        title,
        description,
        status,
        priority,
        assigneeId,
        dueDate,
      ];
}
