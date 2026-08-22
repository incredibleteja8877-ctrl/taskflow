import 'package:equatable/equatable.dart';

import 'auth_tokens.dart';
import 'org_member.dart';
import 'user.dart';

/// Who is signed in, which organization they are acting inside, what they are
/// allowed to do there, and the tokens proving it.
///
/// Note what is absent: the password. It is checked at login and discarded.
/// Nothing in the app stores or remembers it.
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.orgId,
    required this.role,
    required this.tokens,
  });

  final User user;

  /// The organization this session is scoped to. Every project and task query
  /// is filtered by this, so a user can never see another tenant's data.
  final String orgId;

  final OrgRole role;
  final AuthTokens tokens;

  /// The single source of truth for "can this person do admin things".
  /// Task 03's authorization checks read this — never a widget's own guess.
  bool get isAdmin => role == OrgRole.orgAdmin;

  /// Used after a refresh, which swaps the tokens and nothing else.
  AuthSession copyWith({AuthTokens? tokens}) {
    return AuthSession(
      user: user,
      orgId: orgId,
      role: role,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  List<Object?> get props => [user, orgId, role, tokens];
}
