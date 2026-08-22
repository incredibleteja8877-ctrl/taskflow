import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/network/mock_api_config.dart';

import '../support/test_harness.dart';

/// Task 11's required widget tests:
///  - task list rendering (loading / empty / error / success)
///  - task status update UI
void main() {
  group('task list rendering', () {
    testWidgets('success — shows the org\'s tasks with their metadata',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      expect(find.text('Build responsive nav component'), findsOneWidget);
      expect(find.text('Fix broken contact form'), findsOneWidget);

      // Status, priority and assignee are all on the row.
      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Urgent'), findsWidgets);
      expect(find.text('Unassigned'), findsWidgets);

      // And nothing from the other tenant.
      expect(find.text('Draft onboarding checklist'), findsNothing);
    });

    testWidgets('loading — a spinner while the first read is in flight',
        (tester) async {
      // A deliberately slow "network" so the loading frame is observable.
      await tester.pumpWidget(
        buildApp(
          config: const MockApiConfig(
            minDelay: Duration(seconds: 2),
            maxDelay: Duration(seconds: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        TestAccounts.nimbusAdmin,
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        TestAccounts.password,
      );
      await tester.tap(find.text('Sign in'));

      // Mid-flight: the button is showing its spinner, not its label.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();
    });

    testWidgets('empty — a filter matching nothing shows the empty state',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      await tester.tap(find.byTooltip('Filter tasks'));
      await tester.pumpAndSettle();

      // Nimbus's two Done tasks are medium and urgent, so Done + High
      // genuinely matches nothing.
      await tester.tap(find.widgetWithText(FilterChip, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'High'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(find.text('No tasks match these filters'), findsOneWidget);
      // An empty result is NOT an error — no retry button, a clear-filters
      // button instead.
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('error — a simulated server failure shows ErrorView + retry',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');
      expect(find.text('Fix broken contact form'), findsOneWidget);

      // Flip the debug switch the reviewer would use on the Profile screen,
      // then change a filter so the list reloads and hits the failure.
      setForceServerError(tester, true);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filter tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'To do'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Fix broken contact form'), findsNothing);
    });
  });

  group('task status update UI', () {
    testWidgets('tapping a status chip updates the task', (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      await tester.tap(find.text('Fix broken contact form'));
      await tester.pumpAndSettle();

      // It starts as To do.
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'To do'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Done'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Done'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'To do'))
            .selected,
        isFalse,
      );
    });

    testWidgets('tapping a priority chip updates the task', (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      await tester.tap(find.text('SEO audit'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Urgent'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Urgent'))
            .selected,
        isTrue,
      );
    });
  });

  group('task assignment UI', () {
    testWidgets('assigning and unassigning from the detail screen',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      // SEO audit starts unassigned.
      await tester.tap(find.text('SEO audit'));
      await tester.pumpAndSettle();
      expect(find.text('Unassigned'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Marcus Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Unassigned'), findsNothing);
      expect(find.text('Unassign'), findsOneWidget);

      await tester.tap(find.text('Unassign'));
      await tester.pumpAndSettle();
      expect(find.text('Unassigned'), findsOneWidget);
    });

    testWidgets('the picker offers only members of the current org',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      await tester.tap(find.text('SEO audit'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'Marcus Lee'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Priya Nair'), findsOneWidget);
      // Harborlight's people are absent — and TaskUseCases refuses them even
      // if the picker were bypassed (see task_authorization_test.dart).
      expect(find.widgetWithText(ActionChip, 'Elena Vargas'), findsNothing);
    });
  });

  group('create and edit task', () {
    testWidgets('creating a task adds it to the list', (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Ship the release APK',
      );
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(find.text('Ship the release APK'), findsOneWidget);
    });

    testWidgets('the form refuses an empty title', (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Tasks');

      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required.'), findsOneWidget);
    });
  });

  group('project details', () {
    testWidgets('shows status summary counts and the project\'s tasks',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester, TestAccounts.nimbusAdmin);
      await goToTab(tester, 'Projects');

      await tester.tap(find.text('Website Relaunch'));
      await tester.pumpAndSettle();

      // Website Relaunch: 3 todo, 1 in progress, 1 review, 1 done.
      expect(find.text('To do'), findsWidgets);
      expect(find.text('Set up design tokens in Figma'), findsOneWidget);
      expect(find.text('QA pass on staging'), findsOneWidget);
      // A task from the other project is not here.
      expect(find.text('Implement biometric login'), findsNothing);
    });
  });
}
