import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/di/providers.dart';
import 'package:taskflow/core/network/mock_api_config.dart';
import 'package:taskflow/data/datasources/mock_json_data_source.dart';
import 'package:taskflow/data/datasources/session_storage.dart';
import 'package:taskflow/main.dart';

/// Serves the mock JSON from memory instead of the asset bundle.
///
/// This exists because of a real Flutter test-framework constraint:
/// `testWidgets` runs inside FakeAsync, and `rootBundle.loadString` resolves
/// only in the FIRST test of a file — every later test hangs forever waiting
/// on I/O that FakeAsync will not advance.
///
/// The fix is the `AssetBundle? bundle` parameter on [MockJsonDataSource]:
/// production passes rootBundle, tests pass this. Without that seam the
/// widget tests would be impossible to write, which is the practical argument
/// for injecting dependencies rather than reaching for globals.
class InMemoryAssetBundle extends CachingAssetBundle {
  InMemoryAssetBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
}

/// Loaded once per test run, straight off disk with dart:io — no FakeAsync
/// involved, because this happens outside a test body.
final String mockDataJson =
    File(MockJsonDataSource.assetPath).readAsStringSync();

/// A data source wired to the in-memory bundle with zero simulated latency.
MockJsonDataSource createTestDataSource({
  MockApiConfig config = MockApiConfig.instant,
}) {
  return MockJsonDataSource(
    config: config,
    bundle: InMemoryAssetBundle(mockDataJson),
  );
}

/// Provider overrides shared by every widget test.
///
/// - session storage: the real one needs an Android Keystore platform channel
/// - data source: see [InMemoryAssetBundle]
/// - api config: zero delay, so tests do not sleep
List<Override> testOverrides({MockApiConfig config = MockApiConfig.instant}) {
  return [
    sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
    mockApiConfigProvider.overrideWith(() => _FixedConfig(config)),
    mockJsonDataSourceProvider
        .overrideWithValue(createTestDataSource(config: config)),
  ];
}

class _FixedConfig extends MockApiConfigNotifier {
  _FixedConfig(this._initial);

  final MockApiConfig _initial;

  @override
  MockApiConfig build() => _initial;
}

/// Boots the real app with the test overrides applied and settles the splash.
Future<void> pumpApp(
  WidgetTester tester, {
  MockApiConfig config = MockApiConfig.instant,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(config: config),
      child: const TaskFlowApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fills the login form and submits it.
Future<void> signIn(
  WidgetTester tester,
  String email, {
  String password = 'Password123!',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

/// The four accounts from `auth_mock.test_credentials`.
abstract final class TestAccounts {
  static const String nimbusAdmin = 'ava.admin@nimbusdigital.test';
  static const String nimbusMember = 'marcus.member@nimbusdigital.test';
  static const String harborlightAdmin =
      'daniel.admin@harborlightstudios.test';
  static const String harborlightMember =
      'elena.member@harborlightstudios.test';
  static const String password = 'Password123!';
}
