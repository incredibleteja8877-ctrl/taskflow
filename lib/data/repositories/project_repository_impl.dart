import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/mock_json_data_source.dart';
import '../models/project_model.dart';

/// Mock-backed implementation of [ProjectRepository].
class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({
    required this._dataSource,
    this._uuid = const Uuid(),
  });

  static const String _collection = 'projects';
  static const String _tasksCollection = 'tasks';
  static const int _maxNameLength = 80;

  final MockJsonDataSource _dataSource;
  final Uuid _uuid;

  @override
  Future<List<Project>> getProjects(String orgId) async {
    final rows = await _guard(() => _dataSource.readCollection(_collection));
    final counts = await _taskCounts();
    return rows
        .map(ProjectModel.fromJson)
        .where((project) => project.orgId == orgId)
        .map((project) => project.copyWith(taskCount: counts[project.id] ?? 0))
        .toList();
  }

  @override
  Future<Project> getProject(String projectId) async {
    final row = await _guard(() => _dataSource.readById(_collection, projectId));
    final counts = await _taskCounts();
    final project = ProjectModel.fromJson(row);
    return project.copyWith(taskCount: counts[project.id] ?? 0);
  }

  @override
  Future<Project> createProject(CreateProjectRequest request) async {
    _validateName(request.name);

    final project = Project(
      id: 'proj_${_uuid.v4()}',
      orgId: request.orgId,
      name: request.name.trim(),
      description: request.description.trim(),
      taskCount: 0,
      status: ProjectStatus.active,
      createdAt: DateTime.now().toUtc(),
    );

    final row = await _guard(
      () => _dataSource.insert(_collection, ProjectModel.toJson(project)),
    );
    return ProjectModel.fromJson(row);
  }

  @override
  Future<Project> updateProject(Project project) async {
    _validateName(project.name);

    final row = await _guard(
      () => _dataSource.update(
        _collection,
        project.id,
        ProjectModel.toJson(project),
      ),
    );
    final counts = await _taskCounts();
    final updated = ProjectModel.fromJson(row);
    return updated.copyWith(taskCount: counts[updated.id] ?? 0);
  }

  @override
  Future<void> deleteProject(String projectId) async {
    // Delete the children first. If the project delete then fails we would
    // have orphaned tasks — but the alternative, orphaning them on success,
    // is worse. A real backend would wrap both in a transaction; this is the
    // honest limitation to note in the README.
    final tasks = await _guard(
      () => _dataSource.readCollection(_tasksCollection),
    );
    for (final task in tasks) {
      if (task['project_id'] == projectId) {
        await _guard(
          () => _dataSource.delete(_tasksCollection, task['id'] as String),
        );
      }
    }
    await _guard(() => _dataSource.delete(_collection, projectId));
  }

  /// Live task counts per project id.
  ///
  /// The JSON's `task_count` is denormalised and goes stale the moment a task
  /// is created or deleted, so we never trust it — we count.
  Future<Map<String, int>> _taskCounts() async {
    final tasks = await _guard(
      () => _dataSource.readCollection(_tasksCollection),
    );
    final counts = <String, int>{};
    for (final task in tasks) {
      final projectId = task['project_id'] as String?;
      if (projectId == null) continue;
      counts[projectId] = (counts[projectId] ?? 0) + 1;
    }
    return counts;
  }

  void _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(
        'A project needs a name.',
        fieldErrors: {'name': 'Name is required.'},
      );
    }
    if (trimmed.length > _maxNameLength) {
      throw const ValidationException(
        'That name is too long.',
        fieldErrors: {'name': 'Keep the name under $_maxNameLength characters.'},
      );
    }
  }

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
