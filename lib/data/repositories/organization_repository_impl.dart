import '../../core/error/app_exception.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/organization_repository.dart';
import '../datasources/mock_json_data_source.dart';
import '../models/org_member_model.dart';
import '../models/organization_model.dart';
import '../models/user_model.dart';

/// Mock-backed implementation of [OrganizationRepository].
class OrganizationRepositoryImpl implements OrganizationRepository {
  OrganizationRepositoryImpl({required this._dataSource});

  static const String _organizations = 'organizations';
  static const String _users = 'users';
  static const String _members = 'org_members';

  final MockJsonDataSource _dataSource;

  @override
  Future<Organization> getOrganization(String orgId) async {
    final row = await _guard(
      () => _dataSource.readById(_organizations, orgId),
    );
    return OrganizationModel.fromJson(row);
  }

  @override
  Future<List<OrgMember>> getMemberships(String orgId) async {
    final rows = await _guard(() => _dataSource.readCollection(_members));
    return rows
        .map(OrgMemberModel.fromJson)
        .where((member) => member.orgId == orgId)
        .toList();
  }

  @override
  Future<List<User>> getMembers(String orgId) async {
    final memberships = await getMemberships(orgId);
    final ids = memberships.map((member) => member.userId).toSet();

    final rows = await _guard(() => _dataSource.readCollection(_users));
    final members = rows
        .map(UserModel.fromJson)
        .where((user) => ids.contains(user.id))
        .toList();

    members.sort((a, b) => a.name.compareTo(b.name));
    return members;
  }

  @override
  Future<OrgMember?> findMembership({
    required String orgId,
    required String userId,
  }) async {
    final memberships = await getMemberships(orgId);
    for (final membership in memberships) {
      if (membership.userId == userId) return membership;
    }
    // Null rather than throwing: "is this person a member?" is a question,
    // and "no" is a valid answer. Callers that require membership raise
    // ForbiddenException themselves, with a message that fits their context.
    return null;
  }

  @override
  Future<User> getUser(String userId) async {
    final row = await _guard(() => _dataSource.readById(_users, userId));
    return UserModel.fromJson(row);
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
