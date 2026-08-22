import '../entities/org_member.dart';
import '../entities/organization.dart';
import '../entities/user.dart';

/// The org directory: organizations, the people in them, and their roles.
///
/// These three collections are joined constantly — "show me the members of
/// this org so I can assign a task" needs all of them — so they share one
/// repository rather than forcing every caller to stitch three together.
abstract interface class OrganizationRepository {
  /// Throws [NotFoundException] if no such organization exists.
  Future<Organization> getOrganization(String orgId);

  /// Raw membership rows for an org. Use this when you need the *role*.
  Future<List<OrgMember>> getMemberships(String orgId);

  /// Memberships joined to users. Use this to populate an assignee picker.
  Future<List<User>> getMembers(String orgId);

  /// The membership row for one person in one org, or null if they are not
  /// a member. This is the lookup every authorization check depends on.
  Future<OrgMember?> findMembership({
    required String orgId,
    required String userId,
  });

  /// Throws [NotFoundException] if no such user exists.
  Future<User> getUser(String userId);
}
