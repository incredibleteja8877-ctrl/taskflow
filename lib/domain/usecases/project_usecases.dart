import '../../core/error/app_exception.dart';
import '../entities/auth_session.dart';
import '../entities/org_member.dart';
import '../entities/project.dart';
import '../repositories/organization_repository.dart';
import '../repositories/project_repository.dart';

/// Business rules for projects — the layer that decides what is *allowed*,
/// as distinct from the repository, which only knows what is *stored*.
///
/// Nothing here imports Flutter. Every rule below is unit-testable without a
/// widget tree, which is what Task 11's "state-management/business logic"
/// tests will exercise.
class ProjectUseCases {
  const ProjectUseCases({
    required this._projects,
    required this._organizations,
  });

  final ProjectRepository _projects;
  final OrganizationRepository _organizations;

  /// Every project in the caller's own organization. Never another tenant's.
  Future<List<Project>> list(AuthSession session) async {
    await _requireMembership(session);
    return _projects.getProjects(session.orgId);
  }

  /// One project, but only if it belongs to the caller's org.
  ///
  /// This is the deep-link guard: navigating straight to a Harborlight
  /// project id while signed in as Nimbus fails here, in the domain layer,
  /// with no help from the router or the widget.
  Future<Project> getById(AuthSession session, String projectId) async {
    await _requireMembership(session);
    final project = await _projects.getProject(projectId);
    _requireSameOrg(project.orgId, session);
    return project;
  }

  /// Any member may create a project. Only deletion and member management
  /// are admin-only, per the brief.
  Future<Project> create(
    AuthSession session, {
    required String name,
    String description = '',
  }) async {
    await _requireMembership(session);
    return _projects.createProject(
      CreateProjectRequest(
        orgId: session.orgId,
        name: name,
        description: description,
      ),
    );
  }

  Future<Project> update(AuthSession session, Project project) async {
    await _requireMembership(session);
    // Re-read from the store rather than trusting the orgId on the object
    // the caller handed us — that field came from the client.
    final existing = await _projects.getProject(project.id);
    _requireSameOrg(existing.orgId, session);
    return _projects.updateProject(project);
  }

  /// Admin only. This is the rule Task 03 names explicitly.
  Future<void> delete(AuthSession session, String projectId) async {
    await _requireAdmin(session);
    final existing = await _projects.getProject(projectId);
    _requireSameOrg(existing.orgId, session);
    return _projects.deleteProject(projectId);
  }

  // ------------------------------------------------------------- guards

  /// Confirms the caller really is a member of the org their session claims,
  /// and returns their authoritative role.
  ///
  /// We do NOT read `session.isAdmin`. That value came from the client, and a
  /// backend never trusts the client's account of its own privileges.
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

  Future<void> _requireAdmin(AuthSession session) async {
    final membership = await _requireMembership(session);
    if (!membership.isAdmin) {
      throw const ForbiddenException(
        'Only organization admins can do that.',
      );
    }
  }

  /// Cross-tenant access fails as NOT FOUND, not FORBIDDEN.
  ///
  /// "Forbidden" would confirm the resource exists, which leaks one tenant's
  /// data to another. "Not found" reveals nothing. Real multi-tenant systems
  /// behave this way and it is worth being able to explain why.
  void _requireSameOrg(String resourceOrgId, AuthSession session) {
    if (resourceOrgId != session.orgId) {
      throw const NotFoundException();
    }
  }
}
