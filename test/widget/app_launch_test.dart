import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/di/providers.dart';
import 'package:taskflow/core/network/mock_api_config.dart';
import 'package:taskflow/data/datasources/session_storage.dart';
import 'package:taskflow/main.dart';

/// Proves the whole app boots and the router guard works.
///
/// Note the two overrides. This is the payoff for declaring every provider as
/// an interface in core/di/providers.dart: the real SecureSessionStorage needs
/// an Android Keystore platform channel that does not exist in a test process,
/// and the real config would make every test sleep 300-800ms. Two lines swap
/// both out, and nothing else in the app changes.
class _InstantConfig extends MockApiConfigNotifier {
  @override
  MockApiConfig build() => MockApiConfig.instant;
}

void main() {
  testWidgets('an unauthenticated launch lands on the login screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
          mockApiConfigProvider.overrideWith(_InstantConfig.new),
        ],
        child: const TaskFlowApp(),
      ),
    );

    // First frame: the splash screen, while restoreSession() is in flight.
    expect(find.text('TaskFlow'), findsOneWidget);

    await tester.pumpAndSettle();

    // Session check came back empty, so the router redirected to Login.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('the login form rejects an empty submission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
          mockApiConfigProvider.overrideWith(_InstantConfig.new),
        ],
        child: const TaskFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('signing in with valid credentials reaches the app',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
          mockApiConfigProvider.overrideWith(_InstantConfig.new),
        ],
        child: const TaskFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'ava.admin@nimbusdigital.test',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'Password123!',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Ava Thompson'), findsOneWidget);
    expect(find.text('org_admin'), findsOneWidget);
  });
}
