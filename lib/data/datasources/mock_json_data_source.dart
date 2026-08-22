import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../core/error/app_exception.dart';
import '../../core/network/mock_api_config.dart';
import 'local_cache.dart';

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
    this._cache,
  })  : _bundle = bundle ?? rootBundle,
        _random = random ?? Random();

  static const String assetPath = 'assets/mock_data/taskflow_mock_data.json';

  /// Deliberately mutable: a debug toggle changes simulation behaviour at
  /// runtime, and we must not throw away the in-memory database to do it.
  MockApiConfig config;

  final AssetBundle _bundle;
  final Random _random;

  /// Where the last-known-good database snapshot lives. Optional so unit
  /// tests can run without touching preferences.
  final LocalCache? _cache;

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
    await _simulateRoundTrip(isWrite: true);
    final rows = await _liveCollection(key);
    rows.add(_copy(row));
    await _persist();
    return _copy(row);
  }

  /// Merges [changes] into the row with this id and returns the result.
  Future<Map<String, dynamic>> update(
    String key,
    String id,
    Map<String, dynamic> changes,
  ) async {
    await _simulateRoundTrip(isWrite: true);
    _guardNotFoundMarker(id);
    final rows = await _liveCollection(key);
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index == -1) {
      throw NotFoundException('No $key record with id "$id".');
    }
    rows[index] = {...rows[index], ...changes};
    await _persist();
    return _copy(rows[index]);
  }

  /// Removes the row with this id.
  Future<void> delete(String key, String id) async {
    await _simulateRoundTrip(isWrite: true);
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

  Future<Map<String, dynamic>> _database() => _pending ??= _loadDatabase();

  /// Offline, we serve the persisted snapshot. Online, we seed from the asset
  /// and immediately snapshot it so the next offline launch has something to
  /// show — Task 08's "persist last successfully loaded data locally".
  Future<Map<String, dynamic>> _loadDatabase() async {
    if (config.isOffline) {
      final snapshot = await _cache?.read(LocalCache.snapshot);
      if (snapshot is! Map) {
        // Offline on a cold start with nothing cached. There is genuinely
        // nothing to show, so say so rather than pretending.
        throw const OfflineException(
          'You are offline and no data has been saved yet.',
        );
      }
      return Map<String, dynamic>.from(snapshot);
    }

    final raw = await _bundle.loadString(assetPath);
    final database = jsonDecode(raw) as Map<String, dynamic>;
    await _cache?.write(LocalCache.snapshot, database);
    return database;
  }

  /// Snapshots the current database after a write, so a task created just now
  /// is still there after going offline and relaunching.
  Future<void> _persist() async {
    final cache = _cache;
    if (cache == null) return;
    final database = await _database();
    await cache.write(LocalCache.snapshot, database);
  }

  /// When the cache was last written. Drives the "showing data from …" line
  /// in the offline banner.
  Future<DateTime?> lastSyncedAt() =>
      _cache?.writtenAt(LocalCache.snapshot) ?? Future.value();

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
  ///
  /// Offline behaviour is deliberately asymmetric, matching how a real
  /// offline-first app behaves: reads fall back to the cached snapshot, but
  /// writes fail, because there is nowhere to send them.
  Future<void> _simulateRoundTrip({bool isWrite = false}) async {
    if (config.isOffline) {
      if (isWrite) {
        throw const OfflineException(
          'You are offline. This change cannot be saved yet.',
        );
      }
      // Reads continue, served from the snapshot by _loadDatabase.
      return;
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
