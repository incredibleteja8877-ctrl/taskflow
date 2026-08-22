import 'package:equatable/equatable.dart';

/// What a user is allowed to do inside one organization.
///
/// Declared admin-last is deliberate: never compare roles with `.index`.
/// Use [OrgMember.isAdmin] so the check reads as intent, not arithmetic.
enum OrgRole { member, orgAdmin }

/// Joins a [User] to an [Organization] with a role.
///
/// This is the entity every authorization check in the domain layer consults.
/// Task 03: "Only org_admin should be able to delete projects or manage
/// members" — and that must be enforced here, not by hiding a button.
class OrgMember extends Equatable {
  const OrgMember({
    required this.orgId,
    required this.userId,
    required this.role,
  });

  final String orgId;
  final String userId;
  final OrgRole role;

  bool get isAdmin => role == OrgRole.orgAdmin;

  @override
  List<Object?> get props => [orgId, userId, role];
}
