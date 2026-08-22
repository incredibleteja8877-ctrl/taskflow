import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../core/error/app_exception.dart';
import '../../core/network/mock_api_config.dart';

/// The only class in this application permitted to touch the asset bundle.
///
/// Behaves like a small in-memory REST server: the JSON asset seeds a mutable
/// database, every call pays a simulated round-trip cost, and the failure
/// switches in [MockApiConfig] let a reviewer trigger each error on demand.
///
/// To move to a real backend you would write an `HttpTaskFlowApi` exposing
/// these same methods and repoint the repositories at it. Nothing above this
/// file would change.
class MockJsonDataSource {
  MockJsonDataSource({
    this.config = const MockApiConfig(),
    AssetBundle? bundle,
    Random? random,
  })  : _bundle = bundle ?? rootBundle,
        _random = random ?? Random();

  static const String assetPath = 'assets/mock_data/taskflow_mock_data.json';

  /// Deliberately mutable: a debug toggle changes simulation behaviour at
  /// runtime, and we must not throw away the in-memory database to do it.
  MockApiConfig config;

  final AssetBundle _bundle;
  final Random _random;

  /// Caches the *future*, not the result, so two concurrent callers on a cold
  /// start share a single asset read instead of racing each other.
  Future<Map<String, dynamic>>? _pending;

  // ---------------------------------------------------------------- reads

  /// Returns every row of a top-level collection, e.g. `'tasks'`.
  Future<List<Map<String, dynamic>>> readCollection(String key) async {
    await _simulateRoundTrip();
    final rows = await _liveCollection(key);
    return rows.map(_copy).toList();
  }

  /// Returns a top-level object rather than a list, e.g. `'auth_mock'`.
  Future<Map<String, dynamic>> readObject(String key) async {
    await _simulateRoundTrip();
    final db = await _database();
    final value = db[key];
    if (value is! Map<String, dynamic>) {
      throw NotFoundException('No object named "$key" in the mock data.');
    }
    return _copy(value);
  }

  /// Returns a single row by its `id` field.
  Future<Map<String, dynamic>> readById(String key, String id) async {
    await _simulateRoundTrip();
    _guardNotFoundMarker(id);
    final rows = await _liveCollection(key);
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      throw NotFoundException('No $key record with id "$id".');
    }
    return _copy(rows[index]);
  }

  // --------------------------------------------------------------- writes

  /// Appends a row and returns the stored copy.
  Future<Map<String, dynamic>> insert(
    String key,
    Map<String, dynamic> row,
  ) async {
    await _simulateRoundTrip();
    final rows = await _liveCollection(key);
    rows.add(_copy(row));
    return _copy(row);
  }

  /// Merges [changes] into the row with this id and returns the result.
  Future<Map<String, dynamic>> update(
    String key,
    String id,
    Map<String, dynamic> changes,
  ) async {
    await _simulateRoundTrip();
    _guardNotFoundMarker(id);
    final rows = await _liveCollection(key);
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      throw NotFoundException('No $key record with id "$id".');
    }
    rows[index] = {...rows[index], ...changes};
    return _copy(rows[index]);
  }

  /// Removes the row with this id.
  Future<void> delete(String key, String id) async {
    await _simulateRoundTrip();
    _guardNotFoundMarker(id);
    final rows = await _liveCollection(key);
    final before = rows.length;
    rows.removeWhere((row) => row['id'] == id);
    if (rows.length == before) {
      throw NotFoundException('No $key record with id "$id".');
    }
  }

  /// Throws away every in-memory mutation. Tests call this between cases so
  /// they never depend on each other's leftovers.
  void reset() => _pending = null;

  // ------------------------------------------------------------- internals

  Future<Map<String, dynamic>> _database() => _pending ??= _loadAsset();

  Future<Map<String, dynamic>> _loadAsset() async {
    final raw = await _bundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// The real, mutable list inside the database — writes go here.
  /// Callers outside this class only ever receive copies.
  Future<List<Map<String, dynamic>>> _liveCollection(String key) async {
    final db = await _database();
    final rows = db[key];
    if (rows is! List) {
      throw NotFoundException('No collection named "$key" in the mock data.');
    }
    if (rows is List<Map<String, dynamic>>) return rows;

    // jsonDecode hands back List<dynamic>. Re-type it once and store it back
    // so every later call gets the typed list for free.
    final typed = rows.cast<Map<String, dynamic>>().toList();
    db[key] = typed;
    return typed;
  }

  /// Deep copy via a JSON round trip, so a caller mutating what it received
  /// can never corrupt our database.
  Map<String, dynamic> _copy(Map<String, dynamic> row) =>
      jsonDecode(jsonEncode(row)) as Map<String, dynamic>;

  /// Any id containing `_404` always fails. Lets a reviewer demonstrate
  /// not-found handling without flipping a global switch.
  void _guardNotFoundMarker(String id) {
    if (id.contains(MockApiConfig.notFoundIdMarker)) {
      throw NotFoundException('No record with id "$id" (simulated 404).');
    }
  }

  /// The cost of a "network" call. Every public method pays it exactly once.
  Future<void> _simulateRoundTrip() async {
    if (config.isOffline) {
      throw const OfflineException();
    }
    await _delay();
    if (config.forceTimeout) {
      throw const NetworkTimeoutException();
    }
    if (config.forceServerError) {
      throw const UnknownException(
        'The server returned an unexpected error (simulated 500).',
      );
    }
  }

  Future<void> _delay() async {
    final min = config.minDelay.inMilliseconds;
    final max = config.maxDelay.inMilliseconds;
    if (max <= 0) return;
    final span = max - min;
    final ms = span <= 0 ? min : min + _random.nextInt(span + 1);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }
}
