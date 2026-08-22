import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/di/providers.dart';
import 'package:taskflow/core/network/mock_api_config.dart';
import 'package:taskflow/data/datasources/local_cache.dart';
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
    localCacheProvider.overrideWithValue(InMemoryLocalCache()),
    mockApiConfigProvider.overrideWith(() => _FixedConfig(config)),
    // overrideWith, not overrideWithValue: the real provider pushes config
    // changes into the existing data source via ref.listen, and a value
    // override would skip that — so flipping a debug toggle in a test would
    // silently do nothing.
    mockJsonDataSourceProvider.overrideWith((ref) {
      final dataSource =
          createTestDataSource(config: ref.read(mockApiConfigProvider));
      ref.listen<MockApiConfig>(
        mockApiConfigProvider,
        (_, next) => dataSource.config = next,
      );
      return dataSource;
    }),
  ];
}

class _FixedConfig extends MockApiConfigNotifier {
  _FixedConfig(this._initial);

  final MockApiConfig _initial;

  @override
  MockApiConfig build() => _initial;
}

/// The app wrapped in a test ProviderScope, un-pumped.
Widget buildApp({MockApiConfig config = MockApiConfig.instant}) {
  return ProviderScope(
    overrides: testOverrides(config: config),
    child: const TaskFlowApp(),
  );
}

/// Boots the real app with the test overrides applied and settles the splash.
///
/// The surface is deliberately tall. The default 800x600 test viewport cannot
/// fit eleven task cards, and `find.text` only matches widgets that were
/// actually built — so a correct list would fail the test purely for being
/// off-screen. A tall surface tests the content rather than the scroll offset.
Future<void> pumpApp(
  WidgetTester tester, {
  MockApiConfig config = MockApiConfig.instant,
  Size surfaceSize = const Size(1000, 3000),
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(buildApp(config: config));
  await tester.pumpAndSettle();
}

/// The running app's ProviderContainer, for poking at state from a test.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TaskFlowApp)));

/// Flips the debug switches a reviewer would use on the Profile screen.
void setOffline(WidgetTester tester, bool value) =>
    containerOf(tester).read(mockApiConfigProvider.notifier).setOffline(value);

void setForceServerError(WidgetTester tester, bool value) => containerOf(tester)
    .read(mockApiConfigProvider.notifier)
    .setForceServerError(value);

void setForceTimeout(WidgetTester tester, bool value) => containerOf(tester)
    .read(mockApiConfigProvider.notifier)
    .setForceTimeout(value);

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

/// Switches to a bottom-nav tab by its label.
Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
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
