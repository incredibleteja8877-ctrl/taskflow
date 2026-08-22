import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskflow/main.dart' as app;

/// Task 11's required integration tests, run against the real app on a
/// device: login, project listing, task listing, create/update task, and
/// task assignment.
///
/// Unlike the widget tests these boot `main()` itself, so nothing is mocked —
/// real secure storage, real SharedPreferences, the real asset bundle. That
/// is the point: it proves the wiring holds outside a test harness.
///
/// Run with:  flutter test integration_test
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const admin = 'ava.admin@nimbusdigital.test';
  const password = 'Password123!';

  /// Boots the app and gets to a signed-out state.
  ///
  /// A previous run may have left a session in the Keystore, so we cannot
  /// assume we start at Login. Tests that depend on execution order are
  /// explicitly disallowed by the brief.
  Future<void> startSignedOut(WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    if (find.text('Welcome back').evaluate().isEmpty) {
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    expect(find.text('Welcome back'), findsOneWidget);
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, admin);
    await tester.enterText(find.byType(TextFormField).last, password);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  Future<void> goToTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('login flow against the mock credentials', (tester) async {
    await startSignedOut(tester);

    // Bad password first: the app must reject it and stay put.
    await tester.enterText(find.byType(TextFormField).first, admin);
    await tester.enterText(find.byType(TextFormField).last, 'Wrong123!');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Welcome back'), findsOneWidget);

    await signIn(tester);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('project listing is scoped to the org', (tester) async {
    await startSignedOut(tester);
    await signIn(tester);
    await goToTab(tester, 'Projects');

    expect(find.text('Website Relaunch'), findsOneWidget);
    expect(find.text('Mobile App v2'), findsOneWidget);
    expect(find.text('Client Onboarding Revamp'), findsNothing);
  });

  testWidgets('task listing shows the org\'s tasks', (tester) async {
    await startSignedOut(tester);
    await signIn(tester);
    await goToTab(tester, 'Tasks');

    expect(find.text('Build responsive nav component'), findsOneWidget);
    expect(find.text('Draft onboarding checklist'), findsNothing);
  });

  testWidgets('create then update a task', (tester) async {
    await startSignedOut(tester);
    await signIn(tester);
    await goToTab(tester, 'Tasks');

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Integration test task',
    );
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Integration test task'), findsOneWidget);

    // Update its status from the detail screen.
    await tester.tap(find.text('Integration test task'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.widgetWithText(ChoiceChip, 'In progress'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'In progress'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('assign and unassign a user', (tester) async {
    await startSignedOut(tester);
    await signIn(tester);
    await goToTab(tester, 'Tasks');

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Assignment test task',
    );
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('Assignment test task'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Unassigned'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Marcus Lee'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Unassign'), findsOneWidget);

    await tester.tap(find.text('Unassign'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Unassigned'), findsOneWidget);
  });
}
