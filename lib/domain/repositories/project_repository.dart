import 'package:equatable/equatable.dart';

import '../entities/project.dart';

/// Everything the app can do to projects.
///
/// Every read is scoped by `orgId`. There is deliberately no "get all
/// projects" method — a caller that cannot name an organization has no
/// business seeing projects, and leaving the door shut here means the
/// cross-tenant leak can never be written by accident upstairs.
abstract interface class ProjectRepository {
  Future<List<Project>> getProjects(String orgId);

  /// Throws [NotFoundException] if no such project exists.
  Future<Project> getProject(String projectId);

  Future<Project> createProject(CreateProjectRequest request);

  /// Full replacement. Build it with [Project.copyWith].
  Future<Project> updateProject(Project project);

  /// Also removes the project's tasks, the way a cascading delete would.
  Future<void> deleteProject(String projectId);
}

/// The payload for creating a project. See [CreateTaskRequest] for why
/// creates take a request while updates take the entity.
class CreateProjectRequest extends Equatable {
  const CreateProjectRequest({
    required this.orgId,
    required this.name,
    this.description = '',
  });

  final String orgId;
  final String name;
  final String description;

  @override
  List<Object?> get props => [orgId, name, description];
}
