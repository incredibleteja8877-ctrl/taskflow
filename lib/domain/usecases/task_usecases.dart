import '../../core/error/app_exception.dart';
import '../entities/auth_session.dart';
import '../entities/org_member.dart';
import '../entities/task.dart';
import '../entities/task_filter.dart';
import '../entities/user.dart';
import '../repositories/organization_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/task_repository.dart';

/// Business rules for tasks and assignment (Tasks 04 and 05).
///
/// Tasks have no `org_id` of their own — they belong to a project, which
/// belongs to an org. Every rule here therefore resolves the owning project
/// first. Skipping that step is how a task list leaks across tenants.
class TaskUseCases {
  const TaskUseCases({
    required this._tasks,
    required this._projects,
    required this._organizations,
  });

  final TaskRepository _tasks;
  final ProjectRepository _projects;
  final OrganizationRepository _organizations;

  /// Tasks visible to the caller: everything in their org, optionally narrowed
  /// to one project and/or a [filter].
  Future<List<Task>> list(
    AuthSession session, {
    String? projectId,
    TaskFilter filter = TaskFilter.none,
  }) async {
    await _requireMembership(session);
    final allowed = await _projectIdsInOrg(session);

    if (projectId != null) {
      if (!allowed.contains(projectId)) throw const NotFoundException();
      return _tasks.getTasks(projectId: projectId, filter: filter);
    }

    final tasks = await _tasks.getTasks(filter: filter);
    return tasks.where((task) => allowed.contains(task.projectId)).toList();
  }

  Future<Task> getById(AuthSession session, String taskId) async {
    await _requireMembership(session);
    final task = await _tasks.getTask(taskId);
    await _requireTaskInOrg(task, session);
    return task;
  }

  Future<Task> create(AuthSession session, CreateTaskRequest request) async {
    await _requireMembership(session);

    final allowed = await _projectIdsInOrg(session);
    if (!allowed.contains(request.projectId)) {
      throw const NotFoundException();
    }
    if (request.assigneeId != null) {
      await _requireAssignable(session, request.assigneeId!);
    }

    return _tasks.createTask(request);
  }

  Future<Task> update(AuthSession session, Task task) async {
    await _requireMembership(session);

    // Re-read from the store: the caller handed us an object whose projectId
    // and assigneeId came from the client and cannot be trusted.
    final existing = await _tasks.getTask(task.id);
    await _requireTaskInOrg(existing, session);

    if (task.projectId != existing.projectId) {
      final allowed = await _projectIdsInOrg(session);
      if (!allowed.contains(task.projectId)) throw const NotFoundException();
    }
    if (task.assigneeId != null) {
      await _requireAssignable(session, task.assigneeId!);
    }

    return _tasks.updateTask(task);
  }

  Future<void> delete(AuthSession session, String taskId) async {
    await _requireMembership(session);
    final task = await _tasks.getTask(taskId);
    await _requireTaskInOrg(task, session);
    return _tasks.deleteTask(taskId);
  }

  /// Assign or unassign. Pass null for [assigneeId] to unassign.
  ///
  /// Task 05: "Prevent assigning a user who does not belong to the current org
  /// (validate this in the business-logic layer, not just by filtering the
  /// picker list)." That check is [_requireAssignable] below.
  Future<Task> assign(
    AuthSession session, {
    required String taskId,
    required String? assigneeId,
  }) async {
    await _requireMembership(session);
    final task = await _tasks.getTask(taskId);
    await _requireTaskInOrg(task, session);

    if (assigneeId != null) {
      await _requireAssignable(session, assigneeId);
    }

    return _tasks.updateTask(task.copyWith(assigneeId: assigneeId));
  }

  Future<Task> setStatus(
    AuthSession session,
    String taskId,
    TaskStatus status,
  ) async {
    final task = await getById(session, taskId);
    return _tasks.updateTask(task.copyWith(status: status));
  }

  Future<Task> setPriority(
    AuthSession session,
    String taskId,
    TaskPriority priority,
  ) async {
    final task = await getById(session, taskId);
    return _tasks.updateTask(task.copyWith(priority: priority));
  }

  /// Everyone who may be assigned work in this org. Drives the picker.
  Future<List<User>> assignableUsers(AuthSession session) async {
    await _requireMembership(session);
    return _organizations.getMembers(session.orgId);
  }

  // ------------------------------------------------------------- guards

  Future<Set<String>> _projectIdsInOrg(AuthSession session) async {
    final projects = await _projects.getProjects(session.orgId);
    return projects.map((project) => project.id).toSet();
  }

  Future<void> _requireTaskInOrg(Task task, AuthSession session) async {
    final project = await _projects.getProject(task.projectId);
    if (project.orgId != session.orgId) {
      // Not-found rather than forbidden, so we do not confirm to one tenant
      // that another tenant's task exists.
      throw const NotFoundException();
    }
  }

  Future<void> _requireAssignable(AuthSession session, String userId) async {
    final membership = await _organizations.findMembership(
      orgId: session.orgId,
      userId: userId,
    );
    if (membership == null) {
      throw const ValidationException(
        'That person is not a member of this organization.',
        fieldErrors: {'assignee': 'Not a member of this organization.'},
      );
    }
  }

  Future<OrgMember> _requireMembership(AuthSession session) async {
    final membership = await _organizations.findMembership(
      orgId: session.orgId,
      userId: session.user.id,
    );
    if (membership == null) {
      throw const ForbiddenException(
        'You are no longer a member of this organization.',
      );
    }
    return membership;
  }
}
