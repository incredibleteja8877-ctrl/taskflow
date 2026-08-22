import '../../domain/entities/auth_session.dart';
import 'auth_tokens_model.dart';
import 'org_member_model.dart';
import 'user_model.dart';

/// Serializes a whole [AuthSession] for secure storage.
///
/// Unlike the other models this is not a wire format — no backend ever sends
/// this shape. It exists purely so the session survives an app restart. It
/// lives here anyway because it is the same job: entity in, JSON out.
abstract final class AuthSessionModel {
  static Map<String, dynamic> toJson(AuthSession session) {
    return <String, dynamic>{
      'user': UserModel.toJson(session.user),
      'org_id': session.orgId,
      'role': OrgMemberModel.roleToWire(session.role),
      'tokens': AuthTokensModel.toJson(session.tokens),
    };
  }

  static AuthSession fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      orgId: json['org_id'] as String,
      role: OrgMemberModel.roleFromWire(json['role'] as String),
      tokens: AuthTokensModel.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}
