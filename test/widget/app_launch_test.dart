import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/main.dart';

import '../support/test_harness.dart';

void main() {
  testWidgets('an unauthenticated launch lands on the login screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: const TaskFlowApp(),
      ),
    );

    // First frame: splash, while restoreSession() is still in flight.
    expect(find.text('TaskFlow'), findsOneWidget);

    await tester.pumpAndSettle();

    // Session check came back empty, so the router guard redirected to Login.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('the login form rejects an empty submission', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('a wrong password is rejected without naming which field failed',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin, password: 'Wrong123!');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets("signing in shows only the caller's own org projects",
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Website Relaunch'), findsOneWidget);
    expect(find.text('Mobile App v2'), findsOneWidget);

    // Live counts, recomputed rather than read from the stale `task_count`
    // field in the JSON.
    expect(find.text('6 tasks'), findsOneWidget);
    expect(find.text('5 tasks'), findsOneWidget);

    // Harborlight's project is invisible to a Nimbus user.
    expect(find.text('Client Onboarding Revamp'), findsNothing);
  });

  testWidgets('a Harborlight user sees only their own single project',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.harborlightAdmin);

    expect(find.text('Client Onboarding Revamp'), findsOneWidget);
    expect(find.text('4 tasks'), findsOneWidget);
    expect(find.text('Website Relaunch'), findsNothing);
  });

  testWidgets('an org_admin is offered Edit and Delete', (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a member is offered Edit but never Delete', (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusMember);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(
      find.text('Delete'),
      findsNothing,
      reason: 'members must not be offered a destructive admin action',
    );
  });

  testWidgets('creating a project adds it to the list', (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Q3 Campaign');
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();

    expect(find.text('Q3 Campaign'), findsOneWidget);
    expect(find.text('0 tasks'), findsOneWidget);
  });

  testWidgets('the create form refuses an empty name', (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required.'), findsOneWidget);
  });

  testWidgets('deleting a project asks for confirmation first',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete project?'), findsOneWidget);

    // Cancelling leaves everything alone.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Website Relaunch'), findsOneWidget);
  });

  testWidgets('confirming the dialog removes the project', (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);

    await tester.tap(find.byTooltip('Project actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Website Relaunch'), findsNothing);
    expect(find.text('Mobile App v2'), findsOneWidget);
  });

  testWidgets('signing out returns to the login screen', (tester) async {
    await pumpApp(tester);
    await signIn(tester, TestAccounts.nimbusAdmin);
    expect(find.text('Website Relaunch'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Website Relaunch'), findsNothing);
  });
}
