import '../../core/error/app_exception.dart';
import '../../domain/entities/org_member.dart';

/// Wire translator for [OrgMember].
///
/// Note there is no `id` field on the wire — an org membership is identified
/// by the (org_id, user_id) pair, which is normal for a join table.
abstract final class OrgMemberModel {
  static OrgMember fromJson(Map<String, dynamic> json) {
    return OrgMember(
      orgId: json['org_id'] as String,
      userId: json['user_id'] as String,
      role: roleFromWire(json['role'] as String),
    );
  }

  static Map<String, dynamic> toJson(OrgMember member) {
    return <String, dynamic>{
      'org_id': member.orgId,
      'user_id': member.userId,
      'role': roleToWire(member.role),
    };
  }

  static OrgRole roleFromWire(String value) => switch (value) {
        'org_admin' => OrgRole.orgAdmin,
        'member' => OrgRole.member,
        _ => throw ValidationException('Unknown org role "$value".'),
      };

  static String roleToWire(OrgRole role) => switch (role) {
        OrgRole.orgAdmin => 'org_admin',
        OrgRole.member => 'member',
      };
}
