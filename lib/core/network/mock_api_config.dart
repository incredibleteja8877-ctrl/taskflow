import 'package:equatable/equatable.dart';

/// Runtime switches that make our local JSON behave like a flaky network.
///
/// This is injected into the data source, never read as a global. That keeps
/// tests fast (they pass [instant]) and lets a debug panel on the Settings
/// screen flip these live for the reviewer's demo.
class MockApiConfig extends Equatable {
  const MockApiConfig({
    this.minDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(milliseconds: 800),
    this.isOffline = false,
    this.forceTimeout = false,
    this.forceServerError = false,
  });

  /// No latency, no forced failures. Tests use this so they don't sleep.
  static const MockApiConfig instant = MockApiConfig(
    minDelay: Duration.zero,
    maxDelay: Duration.zero,
  );

  /// Any record id containing this suffix always raises a NotFoundException,
  /// so a 404 can be demonstrated without touching a toggle.
  /// Documented in the README under "triggering simulated errors".
  static const String notFoundIdMarker = '_404';

  /// Lower bound of the artificial round-trip delay.
  final Duration minDelay;

  /// Upper bound of the artificial round-trip delay.
  final Duration maxDelay;

  /// Simulated airplane mode. Reads fail; cached data is shown instead.
  final bool isOffline;

  /// Every request waits, then throws NetworkTimeoutException.
  final bool forceTimeout;

  /// Every request throws UnknownException, standing in for a 500.
  final bool forceServerError;

  /// True when any failure switch is on. Handy for showing a warning banner
  /// so nobody mistakes a deliberate failure for a real bug.
  bool get hasForcedFailure => isOffline || forceTimeout || forceServerError;

  MockApiConfig copyWith({
    Duration? minDelay,
    Duration? maxDelay,
    bool? isOffline,
    bool? forceTimeout,
    bool? forceServerError,
  }) {
    return MockApiConfig(
      minDelay: minDelay ?? this.minDelay,
      maxDelay: maxDelay ?? this.maxDelay,
      isOffline: isOffline ?? this.isOffline,
      forceTimeout: forceTimeout ?? this.forceTimeout,
      forceServerError: forceServerError ?? this.forceServerError,
    );
  }

  @override
  List<Object?> get props =>
      [minDelay, maxDelay, isOffline, forceTimeout, forceServerError];
}
