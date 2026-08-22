import 'package:equatable/equatable.dart';

/// Lifecycle of a project. The mock data only ever contains "active", but a
/// single-value enum would be pointless and archiving is the obvious second
/// state, so both are modelled.
enum ProjectStatus { active, archived }

/// A container for tasks, owned by exactly one organization.
class Project extends Equatable {
  const Project({
    required this.id,
    required this.orgId,
    required this.name,
    required this.description,
    required this.taskCount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String name;
  final String description;

  /// Denormalised in the source JSON, and therefore stale the moment a task
  /// is created or deleted. Treat it as a hint only — the repository
  /// recomputes it from the tasks collection before handing a Project to the
  /// UI. Kept on the entity because a real API would send exactly this.
  final int taskCount;

  final ProjectStatus status;
  final DateTime createdAt;

  bool get isArchived => status == ProjectStatus.archived;

  Project copyWith({
    String? name,
    String? description,
    int? taskCount,
    ProjectStatus? status,
  }) {
    return Project(
      id: id,
      orgId: orgId,
      name: name ?? this.name,
      description: description ?? this.description,
      taskCount: taskCount ?? this.taskCount,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, orgId, name, description, taskCount, status, createdAt];
}
