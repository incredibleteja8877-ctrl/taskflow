import 'package:equatable/equatable.dart';

/// A token pair with absolute expiry instants.
///
/// The mock login response gives *relative* lifetimes
/// (`access_token_expires_in_seconds: 900`). We convert those to wall-clock
/// deadlines at login, because "900 seconds from now" is meaningless once the
/// app restarts. Every check downstream is then a simple comparison.
class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  /// [now] is a parameter, never DateTime.now(), so a test can jump the clock
  /// forward 16 minutes without waiting 16 minutes.
  bool isAccessTokenExpired(DateTime now) =>
      !now.isBefore(accessTokenExpiresAt);

  /// Once this is true the user must log in again — there is nothing left to
  /// refresh with.
  bool isRefreshTokenExpired(DateTime now) =>
      !now.isBefore(refreshTokenExpiresAt);

  /// Refresh slightly *before* expiry.
  ///
  /// Without the leeway, a token that expires in 200ms passes the check and
  /// then fails mid-request. Real clients all do this.
  bool needsRefresh(
    DateTime now, {
    Duration leeway = const Duration(seconds: 30),
  }) =>
      !now.isBefore(accessTokenExpiresAt.subtract(leeway));

  AuthTokens copyWith({
    String? accessToken,
    DateTime? accessTokenExpiresAt,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
    );
  }

  /// Deliberately redacted.
  ///
  /// The brief says "do not log tokens". Anything can end up in a log line —
  /// a crash report, a `print` in a debug session, a widget error dump. The
  /// only reliable defence is for the object to refuse to print itself.
  @override
  String toString() =>
      'AuthTokens(accessExpiresAt: $accessTokenExpiresAt, '
      'refreshExpiresAt: $refreshTokenExpiresAt)';

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        accessTokenExpiresAt,
        refreshTokenExpiresAt,
      ];
}
