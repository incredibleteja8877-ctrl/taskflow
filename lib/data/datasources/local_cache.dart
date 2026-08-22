import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Durable storage for the last-known-good copy of the mock database
/// (Task 08: "Persist last successfully loaded project/task data locally").
///
/// Deliberately separate from SessionStorage. Tokens are secrets and belong in
/// the Keystore; a cached project list is not sensitive and belongs in plain
/// preferences. Mixing them would either leak secrets into cleartext or make
/// every cache read pay Keystore decryption.
abstract interface class LocalCache {
  Future<void> write(String key, Object value);

  /// Null when nothing has been cached under this key.
  Future<Object?> read(String key);

  /// When [key] was last written, or null.
  Future<DateTime?> writtenAt(String key);

  Future<void> clear();

  /// The whole mock database, including anything the user created this
  /// session. One snapshot rather than per-collection entries, because the
  /// collections reference each other and a half-updated cache would show
  /// tasks belonging to projects that are not there.
  static const String snapshot = 'cache.snapshot.v1';
}

class SharedPrefsLocalCache implements LocalCache {
  const SharedPrefsLocalCache(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<void> write(String key, Object value) async {
    await _prefs.setString(key, jsonEncode(value));
    await _prefs.setString(
      _stampKey(key),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<Object?> read(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      // Corrupt, or written by an older version. Drop it rather than crash —
      // a missing cache is recoverable, a crash on launch is not.
      await _prefs.remove(key);
      return null;
    }
  }

  @override
  Future<DateTime?> writtenAt(String key) async {
    final raw = _prefs.getString(_stampKey(key));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(LocalCache.snapshot);
    await _prefs.remove(_stampKey(LocalCache.snapshot));
  }

  String _stampKey(String key) => '$key.writtenAt';
}

/// Test double, and the fallback where preferences are unavailable.
class InMemoryLocalCache implements LocalCache {
  final Map<String, Object> _values = {};
  final Map<String, DateTime> _stamps = {};

  @override
  Future<void> write(String key, Object value) async {
    // Round-trip through JSON so this behaves exactly like the real one,
    // including turning objects into plain maps and lists.
    _values[key] = jsonDecode(jsonEncode(value)) as Object;
    _stamps[key] = DateTime.now().toUtc();
  }

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<DateTime?> writtenAt(String key) async => _stamps[key];

  @override
  Future<void> clear() async {
    _values.clear();
    _stamps.clear();
  }
}
