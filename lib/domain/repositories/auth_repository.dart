import 'package:equatable/equatable.dart';

import '../entities/auth_session.dart';

/// The simulated authentication contract.
///
/// Nothing here mentions the mock JSON, secure storage, or the credential
/// list. Task 02's rule — "do not hardcode the mock credentials inside UI
/// widgets" — is satisfied structurally: the UI can only reach credentials by
/// calling [login], and only the implementation knows where they live.
abstract interface class AuthRepository {
  /// Throws [UnauthorizedException] when the credentials do not match, and
  /// [ValidationException] when the input is malformed.
  Future<AuthSession> login(LoginRequest request);

  /// Simulated sign-up. Creates the user, a workspace for them, and an
  /// admin membership — all in local state only, as Task 02 permits.
  Future<AuthSession> register(RegisterRequest request);

  /// The stored session, or null if nobody is signed in.
  ///
  /// Called by the splash screen. Returns null — rather than throwing — when
  /// the refresh token has also expired, because "not signed in" is a normal
  /// outcome on a cold start, not an error.
  Future<AuthSession?> restoreSession();

  /// Issues a fresh access token using the refresh token.
  ///
  /// Throws [UnauthorizedException] if the refresh token has itself expired,
  /// which is the app's signal to force a re-login.
  Future<AuthSession> refreshSession(AuthSession session);

  /// Clears stored state. After this, [restoreSession] returns null and the
  /// router's guard blocks every authenticated route.
  Future<void> logout();
}

class LoginRequest extends Equatable {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  /// Redacted. See the note on [AuthTokens.toString].
  @override
  String toString() => 'LoginRequest(email: $email)';

  @override
  List<Object?> get props => [email, password];
}

class RegisterRequest extends Equatable {
  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  @override
  String toString() => 'RegisterRequest(name: $name, email: $email)';

  @override
  List<Object?> get props => [name, email, password];
}
