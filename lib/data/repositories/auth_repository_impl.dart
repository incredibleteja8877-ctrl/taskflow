import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/org_member.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/mock_json_data_source.dart';
import '../datasources/session_storage.dart';
import '../models/auth_tokens_model.dart';
import '../models/org_member_model.dart';
import '../models/user_model.dart';

/// Simulated authentication against `auth_mock` in the mock JSON.
///
/// Every credential lives behind this class. No widget, provider or usecase
/// can reach the test accounts except by calling [login].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._dataSource,
    required this._storage,
    this._uuid = const Uuid(),
    this._clock = _systemClock,
  });

  /// Injected so tests can jump the clock forward past a token expiry
  /// instead of sleeping for fifteen minutes.
  static DateTime _systemClock() => DateTime.now().toUtc();

  static const String _authKey = 'auth_mock';
  static const String _usersKey = 'users';
  static const String _membersKey = 'org_members';
  static const String _orgsKey = 'organizations';

  final MockJsonDataSource _dataSource;
  final SessionStorage _storage;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    _validate({
      'email': Validators.email(request.email),
      'password': Validators.password(request.password),
    });

    final auth = await _guard(() => _dataSource.readObject(_authKey));
    final credentials = (auth['test_credentials'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    final email = request.email.trim().toLowerCase();
    Map<String, dynamic>? match;
    for (final credential in credentials) {
      final candidate = (credential['email'] as String?)?.toLowerCase();
      // Password compared verbatim — never trimmed, never lower-cased.
      if (candidate == email && credential['password'] == request.password) {
        match = credential;
        break;
      }
    }

    if (match == null) {
      // One message for both "no such account" and "wrong password", on
      // purpose. Distinguishing them tells an attacker which addresses are
      // registered, which is how account enumeration works.
      throw const UnauthorizedException('Incorrect email or password.');
    }

    final session = AuthSession(
      user: await _findUserByEmail(email),
      orgId: match['org_id'] as String,
      role: OrgMemberModel.roleFromWire(match['role'] as String),
      tokens: _mintTokens(auth),
    );

    await _storage.save(session);
    // request.password goes out of scope here. It is never written to storage,
    // never logged, and never held on the session object.
    return session;
  }

  @override
  Future<AuthSession> register(RegisterRequest request) async {
    _validate({
      'name': Validators.name(request.name),
      'email': Validators.email(request.email),
      'password': Validators.password(request.password),
    });

    final email = request.email.trim().toLowerCase();
    if (await _emailExists(email)) {
      throw const ValidationException(
        'That email is already registered.',
        fieldErrors: {'email': 'This email is already in use.'},
      );
    }

    final now = _clock();
    final name = request.name.trim();
    final orgId = 'org_${_uuid.v4()}';
    final userId = 'user_${_uuid.v4()}';

    // A new signup gets their own workspace, the way real SaaS signup works.
    // The alternative — silently dropping them into Nimbus or Harborlight —
    // would be inventing a membership the mock data never describes.
    await _guard(
      () => _dataSource.insert(_orgsKey, <String, dynamic>{
        'id': orgId,
        'name': "$name's Workspace",
        'created_at': now.toUtc().toIso8601String(),
      }),
    );

    final user = User(id: userId, name: name, email: email);
    await _guard(() => _dataSource.insert(_usersKey, UserModel.toJson(user)));

    const role = OrgRole.orgAdmin;
    await _guard(
      () => _dataSource.insert(
        _membersKey,
        OrgMemberModel.toJson(
          OrgMember(orgId: orgId, userId: userId, role: role),
        ),
      ),
    );

    final auth = await _guard(() => _dataSource.readObject(_authKey));
    final session = AuthSession(
      user: user,
      orgId: orgId,
      role: role,
      tokens: _mintTokens(auth),
    );

    await _storage.save(session);
    // The password is validated and then discarded — it is deliberately NOT
    // added to test_credentials, because Task 02 forbids storing passwords.
    // Consequence: a registered user cannot sign in again after logging out.
    // Documented in the README under known limitations.
    return session;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final session = await _storage.read();
    if (session == null) return null;

    final now = _clock();

    if (session.tokens.isRefreshTokenExpired(now)) {
      // Nothing left to refresh with. Clear it so the next cold start is fast
      // and the router sends the user straight to Login.
      await _storage.clear();
      return null;
    }

    if (session.tokens.needsRefresh(now)) {
      return refreshSession(session);
    }

    return session;
  }

  @override
  Future<AuthSession> refreshSession(AuthSession session) async {
    final now = _clock();

    if (session.tokens.isRefreshTokenExpired(now)) {
      await _storage.clear();
      throw const UnauthorizedException();
    }

    final auth = await _guard(() => _dataSource.readObject(_authKey));
    final response = auth['mock_login_response'] as Map<String, dynamic>?;
    if (response == null) {
      throw const UnknownException();
    }

    final lifetime =
        (response['access_token_expires_in_seconds'] as num?)?.toInt() ?? 900;

    // The mock response always contains the same literal access token string,
    // so a naive refresh would hand back a byte-identical token and no test
    // could prove the refresh actually ran. Suffixing with the issue instant
    // makes the new token verifiably different.
    final refreshed = session.tokens.copyWith(
      accessToken: '${response['access_token']}.${now.millisecondsSinceEpoch}',
      accessTokenExpiresAt: now.add(Duration(seconds: lifetime)),
    );

    final updated = session.copyWith(tokens: refreshed);
    await _storage.save(updated);
    return updated;
  }

  @override
  Future<void> logout() => _storage.clear();

  // ------------------------------------------------------------- internals

  /// Collects field errors and raises one [ValidationException] carrying all
  /// of them, so a form can light up every bad field at once instead of
  /// making the user fix them one submit at a time.
  void _validate(Map<String, String?> checks) {
    final errors = <String, String>{};
    checks.forEach((field, error) {
      if (error != null) errors[field] = error;
    });
    if (errors.isNotEmpty) {
      throw ValidationException(
        'Please check your details and try again.',
        fieldErrors: errors,
      );
    }
  }

  AuthTokens _mintTokens(Map<String, dynamic> auth) {
    final response = auth['mock_login_response'] as Map<String, dynamic>?;
    if (response == null) {
      throw const UnknownException();
    }
    return AuthTokensModel.fromLoginResponse(response, issuedAt: _clock());
  }

  Future<User> _findUserByEmail(String email) async {
    final rows = await _guard(() => _dataSource.readCollection(_usersKey));
    for (final row in rows) {
      if ((row['email'] as String?)?.toLowerCase() == email) {
        return UserModel.fromJson(row);
      }
    }
    // `test_credentials` and `users` are separate collections in the mock
    // data, so they can disagree. Fail loudly rather than inventing a profile.
    throw const UnknownException(
      'That account has no profile. Please contact support.',
    );
  }

  Future<bool> _emailExists(String email) async {
    final rows = await _guard(() => _dataSource.readCollection(_usersKey));
    return rows.any((row) => (row['email'] as String?)?.toLowerCase() == email);
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
