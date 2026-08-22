import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_filter.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/mock_json_data_source.dart';
import '../models/task_model.dart';

/// Mock-backed implementation of [TaskRepository].
///
/// The class name ends in `Impl` and the file lives in `data/` so it is
/// obvious this is one interchangeable implementation. A future
/// `HttpTaskRepository` would sit beside it, and only the dependency-injection
/// wiring would change.
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    required this._dataSource,
    this._uuid = const Uuid(),
  });

  /// The top-level key in the mock JSON. A real implementation would hold a
  /// path like `/api/v1/tasks` here instead — same idea, different transport.
  static const String _collection = 'tasks';

  static const int _maxTitleLength = 120;

  final MockJsonDataSource _dataSource;
  final Uuid _uuid;

  @override
  Future<List<Task>> getTasks({
    String? projectId,
    TaskFilter filter = TaskFilter.none,
  }) async {
    final rows = await _guard(() => _dataSource.readCollection(_collection));
    return rows
        .map(TaskModel.fromJson)
        .where((task) => projectId == null || task.projectId == projectId)
        .where(filter.matches)
        .toList();
  }

  @override
  Future<Task> getTask(String taskId) async {
    final row = await _guard(() => _dataSource.readById(_collection, taskId));
    return TaskModel.fromJson(row);
  }

  @override
  Future<Task> createTask(CreateTaskRequest request) async {
    _validateTitle(request.title);

    final task = Task(
      // Prefixed to match the ids already in the mock data, so a reviewer
      // scrolling the list cannot tell seeded rows from created ones.
      id: 'task_${_uuid.v4()}',
      projectId: request.projectId,
      title: request.title.trim(),
      description: request.description.trim(),
      status: request.status,
      priority: request.priority,
      createdAt: DateTime.now().toUtc(),
      assigneeId: request.assigneeId,
      dueDate: request.dueDate,
    );

    final row = await _guard(
      () => _dataSource.insert(_collection, TaskModel.toJson(task)),
    );
    return TaskModel.fromJson(row);
  }

  @override
  Future<Task> updateTask(Task task) async {
    _validateTitle(task.title);

    final row = await _guard(
      () => _dataSource.update(_collection, task.id, TaskModel.toJson(task)),
    );
    return TaskModel.fromJson(row);
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _guard(() => _dataSource.delete(_collection, taskId));
  }

  /// Server-side validation, deliberately duplicated from the form.
  ///
  /// The Create/Edit screen validates for fast feedback; this validates
  /// because a real backend would never trust a client. Task 11 tests this
  /// directly, with no widget involved.
  void _validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(
        'A task needs a title.',
        fieldErrors: {'title': 'Title is required.'},
      );
    }
    if (trimmed.length > _maxTitleLength) {
      throw const ValidationException(
        'That title is too long.',
        fieldErrors: {'title': 'Keep the title under $_maxTitleLength characters.'},
      );
    }
  }

  /// Upholds the interface's promise that only [AppException] escapes.
  ///
  /// Without this, a malformed row would surface a raw `TypeError` in the UI.
  /// A future HTTP implementation would catch `SocketException` here and
  /// rethrow [NetworkTimeoutException] — callers above never notice.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownException();
    }
  }
}
