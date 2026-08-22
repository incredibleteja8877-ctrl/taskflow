import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskflow/main.dart' as app;

/// Task 11's required integration coverage, against the real app on a device:
/// login flow, project listing, task listing, create/update task, and task
/// assignment.
///
/// Deliberately ONE test that walks the whole journey rather than five
/// separate ones. `app.main()` calls `runApp`, and calling it repeatedly in a
/// single process stacks app instances so finders match stale trees.
///
/// Nothing here is mocked: real secure storage, real SharedPreferences, the
/// real asset bundle, and a real 300-800ms delay on every call.
///
/// Run with:  flutter test integration_test
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const admin = 'ava.admin@nimbusdigital.test';
  const password = 'Password123!';

  testWidgets('login, projects, tasks, create, update and assign',
      (tester) async {
    // NOTE: pumpAndSettle's FIRST argument is the interval between frames,
    // not a timeout. It also only waits for frames — during a Future.delayed
    // no frame is scheduled, so it returns while async work is still in
    // flight. Hence waitUntil below for anything that crosses the data layer.
    Future<void> pump() => tester.pumpAndSettle();

    bool sees(Finder finder) => finder.evaluate().isNotEmpty;

    /// Pumps until [ready] holds, or fails with a useful message.
    ///
    /// This is what makes the test reliable against a real 300-800ms mock
    /// latency without sprinkling arbitrary sleeps everywhere.
    Future<void> waitUntil(
      bool Function() ready, {
      required String describe,
      Duration timeout = const Duration(seconds: 30),
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (ready()) return;
        await tester.pump(const Duration(milliseconds: 200));
      }
      fail('Timed out after $timeout waiting for $describe');
    }

    /// Scrolls the primary list until [target] is built and on screen.
    ///
    /// A phone shows about four cards at once, and `find.text` only matches
    /// widgets that exist — so an item further down a perfectly correct list
    /// would otherwise fail the test for being off-screen.
    Future<void> scrollTo(Finder target) async {
      if (sees(target)) return;
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await pump();
    }

    /// Bottom-nav tabs are found by icon, not label: icons are unambiguous,
    /// whereas "Tasks" and "Projects" also appear as AppBar titles.
    Future<void> goToTab(IconData outlined, IconData filled) async {
      final tab = sees(find.byIcon(outlined))
          ? find.byIcon(outlined)
          : find.byIcon(filled);
      await tester.tap(tab.first);
      await pump();
    }

    // ------------------------------------------------------------- boot
    await app.main();
    await pump();

    // A previous run may have left a session in the Keystore, so we cannot
    // assume we start at Login. Sign out via the Projects AppBar icon, which
    // is always on screen (the Profile button is below the fold on a phone).
    await waitUntil(
      () => sees(find.text('Welcome back')) || sees(find.byIcon(Icons.home)),
      describe: 'the app to finish its session check',
    );
    if (!sees(find.text('Welcome back'))) {
      await goToTab(Icons.folder_outlined, Icons.folder);
      await tester.tap(find.byTooltip('Sign out'));
      await waitUntil(
        () => sees(find.text('Welcome back')),
        describe: 'sign out to return to Login',
      );
    }
    expect(find.text('Welcome back'), findsOneWidget);

    // -------------------------------------------------- login: bad password
    await tester.enterText(find.byType(TextFormField).first, admin);
    await tester.enterText(find.byType(TextFormField).last, 'Wrong123!');
    await pump();
    await tester.tap(find.text('Sign in'));
    await waitUntil(
      () => sees(find.text('Incorrect email or password.')),
      describe: 'the wrong-password error',
    );
    expect(
      find.text('Welcome back'),
      findsOneWidget,
      reason: 'a wrong password must not get past Login',
    );

    // ------------------------------------------------- login: real password
    await tester.enterText(find.byType(TextFormField).first, admin);
    await tester.enterText(find.byType(TextFormField).last, password);
    await pump();
    await tester.tap(find.text('Sign in'));
    await waitUntil(
      () => !sees(find.text('Welcome back')),
      describe: 'the router redirect after a successful login',
    );
    await pump();

    // --------------------------------------------------- project listing
    await goToTab(Icons.folder_outlined, Icons.folder);
    await waitUntil(
      () => sees(find.text('Website Relaunch')),
      describe: 'the project list to load',
    );

    await scrollTo(find.text('Mobile App v2'));
    expect(find.text('Mobile App v2'), findsOneWidget);
    expect(
      find.text('Client Onboarding Revamp'),
      findsNothing,
      reason: 'a project from another organization must never appear',
    );

    // ------------------------------------------------------ task listing
    await goToTab(Icons.checklist_outlined, Icons.checklist);
    await waitUntil(
      () => sees(find.text('Fix broken contact form')),
      describe: 'the task list to load',
    );

    await scrollTo(find.text('Build responsive nav component'));
    expect(find.text('Build responsive nav component'), findsOneWidget);
    expect(find.text('Draft onboarding checklist'), findsNothing);

    // ------------------------------------------------------- create a task
    await tester.tap(find.text('New task'));
    await pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Integration test task',
    );
    await pump();
    await tester.tap(find.text('Create task'));
    await waitUntil(
      () => !sees(find.text('Create task')),
      describe: 'the create sheet to close after saving',
    );
    await pump();

    // New tasks land at the end of the list.
    await scrollTo(find.text('Integration test task'));
    expect(find.text('Integration test task'), findsOneWidget);

    // -------------------------------------------------- update its status
    await tester.tap(find.text('Integration test task'));
    await waitUntil(
      () => sees(find.widgetWithText(ChoiceChip, 'In progress')),
      describe: 'the task detail screen to load',
    );

    await scrollTo(find.widgetWithText(ChoiceChip, 'In progress'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'In progress'));
    await waitUntil(
      () {
        final chip = find.widgetWithText(ChoiceChip, 'In progress');
        return sees(chip) && tester.widget<ChoiceChip>(chip).selected;
      },
      describe: 'the status chip to become selected',
    );

    // ------------------------------------------------ assign and unassign
    await scrollTo(find.widgetWithText(ActionChip, 'Marcus Lee'));
    expect(find.text('Unassigned'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Marcus Lee'));
    await waitUntil(
      () => sees(find.text('Unassign')),
      describe: 'the task to become assigned',
    );

    await tester.tap(find.text('Unassign'));
    await waitUntil(
      () => sees(find.text('Unassigned')),
      describe: 'the task to become unassigned again',
    );

    // Harborlight's people are never offered in a Nimbus session.
    expect(find.widgetWithText(ActionChip, 'Elena Vargas'), findsNothing);
  });
}
