import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_session.dart';
import '../models/auth_session_model.dart';

/// Where the signed-in session lives between app launches.
///
/// An interface, not just a class, so tests can swap in
/// [InMemorySessionStorage] — the real one needs Android Keystore, which does
/// not exist in a `flutter test` process.
abstract interface class SessionStorage {
  Future<void> save(AuthSession session);

  /// Null when nobody is signed in.
  Future<AuthSession?> read();

  Future<void> clear();
}

/// Keystore-backed (Android) / Keychain-backed (iOS) implementation.
///
/// As of flutter_secure_storage 11 the Android default is AES-GCM with RSA
/// key wrapping, so no extra options are needed to get real encryption.
class SecureSessionStorage implements SessionStorage {
    SecureSessionStorage({this._storage = const FlutterSecureStorage()});


  static const String _key = 'taskflow.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(AuthSession session) {
    return _storage.write(
      key: _key,
      value: jsonEncode(AuthSessionModel.toJson(session)),
    );
  }

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;

    try {
      return AuthSessionModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupt, or written by an older version of the app. Treating this as
      // "signed out" is far better than crashing on every launch with no way
      // for the user to recover. Clean it up on the way past.
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Test double. Also the fallback on platforms without a secure enclave.
class InMemorySessionStorage implements SessionStorage {
  AuthSession? _session;

  @override
  Future<void> save(AuthSession session) async => _session = session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> clear() async => _session = null;
}
