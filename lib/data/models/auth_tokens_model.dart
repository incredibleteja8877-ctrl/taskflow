import '../../core/error/app_exception.dart';
import '../../domain/entities/auth_tokens.dart';

/// Builds and persists [AuthTokens].
///
/// Note there are TWO different JSON shapes here, and that is deliberate:
///
///  * [fromLoginResponse] reads what the "server" sends — relative lifetimes
///    in seconds.
///  * [toJson] / [fromJson] handle what WE store on the device — absolute
///    instants.
///
/// Conflating them is the classic bug: store "900 seconds" and after a restart
/// nobody knows 900 seconds from when.
abstract final class AuthTokensModel {
  /// Converts `auth_mock.mock_login_response` into a token pair.
  ///
  /// [issuedAt] is injected rather than read from the clock, so a test can
  /// mint a token that expired an hour ago without waiting an hour.
  static AuthTokens fromLoginResponse(
    Map<String, dynamic> json, {
    required DateTime issuedAt,
  }) {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    final accessSeconds =
        (json['access_token_expires_in_seconds'] as num?)?.toInt();
    final refreshSeconds =
        (json['refresh_token_expires_in_seconds'] as num?)?.toInt();

    if (accessToken == null ||
        refreshToken == null ||
        accessSeconds == null ||
        refreshSeconds == null) {
      throw const ValidationException(
        'The sign-in response was incomplete. Please try again.',
      );
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: issuedAt.add(Duration(seconds: accessSeconds)),
      refreshTokenExpiresAt: issuedAt.add(Duration(seconds: refreshSeconds)),
    );
  }

  /// The on-device format. Instants are written as UTC ISO-8601 strings so a
  /// device time-zone change cannot silently move a deadline.
  static Map<String, dynamic> toJson(AuthTokens tokens) {
    return <String, dynamic>{
      'access_token': tokens.accessToken,
      'refresh_token': tokens.refreshToken,
      'access_token_expires_at':
          tokens.accessTokenExpiresAt.toUtc().toIso8601String(),
      'refresh_token_expires_at':
          tokens.refreshTokenExpiresAt.toUtc().toIso8601String(),
    };
  }

  static AuthTokens fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessTokenExpiresAt:
          DateTime.parse(json['access_token_expires_at'] as String),
      refreshTokenExpiresAt:
          DateTime.parse(json['refresh_token_expires_at'] as String),
    );
  }
}
