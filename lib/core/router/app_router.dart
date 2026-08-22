import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/providers/auth_controller.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/auth/screens/register_screen.dart';
import '../../presentation/auth/screens/splash_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/profile/screens/profile_screen.dart';
import '../../presentation/projects/screens/project_detail_screen.dart';
import '../../presentation/projects/screens/projects_screen.dart';
import '../../presentation/shared/widgets/app_shell.dart';
import '../../presentation/tasks/screens/task_detail_screen.dart';
import '../../presentation/tasks/screens/task_list_screen.dart';

/// Every route path in one place, so no screen hardcodes a string.
abstract final class Routes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Shell branches.
  static const String home = '/home';
  static const String projects = '/projects';
  static const String tasks = '/tasks';
  static const String profile = '/profile';

  // Detail routes, pushed above the shell so they cover the bottom bar.
  // Singular prefixes on purpose: '/project/:id' cannot collide with the
  // '/projects' branch.
  static const String projectDetailPattern = '/project/:projectId';
  static const String taskDetailPattern = '/task/:taskId';

  static String projectDetail(String projectId) => '/project/$projectId';
  static String taskDetail(String taskId) => '/task/$taskId';

  static bool isAuthScreen(String location) =>
      location == login || location == register;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges Riverpod state to go_router, which wants a plain [Listenable].
///
/// Without this the router would have to `ref.watch` the auth state, which
/// rebuilds the whole GoRouter — discarding the navigation stack — on every
/// session change. This way the router is built once and merely re-evaluates
/// its redirect.
final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);
  return refresh;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// The app's router, including the authentication guard.
///
/// The redirect below is Task 02's "logout blocks access to authenticated
/// screens" and the navigation half of Task 03's deep-link rule. It runs on
/// EVERY navigation — including a pasted URL and the Android back button —
/// which is why a guard belongs here rather than in each screen's initState.
///
/// It is only the first line of defence. Authorization is re-checked in the
/// usecase layer, so a deep link that slips past the router still fails.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: ref.watch(_routerRefreshProvider),
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final atSplash = location == Routes.splash;

      // The stored-session check is still running. Hold on the splash screen
      // rather than flashing Login and then bouncing to Home.
      if (auth.isLoading && atSplash) return null;

      final signedIn = auth.valueOrNull != null;
      final atAuthScreen = Routes.isAuthScreen(location);

      // Signed out: only Login and Register are reachable.
      if (!signedIn) return atAuthScreen ? null : Routes.login;

      // Signed in: Splash, Login and Register are dead ends.
      if (atSplash || atAuthScreen) return Routes.home;

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.projectDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProjectDetailScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),
      GoRoute(
        path: Routes.taskDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.projects,
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (context, state) => const TaskListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // GoRouter holds listeners and a route-information provider. Without this
  // the instance outlives its ProviderScope — a leak in the app, and in tests
  // a stale router keeps scheduling frames so pumpAndSettle never settles.
  ref.onDispose(router.dispose);

  return router;
});
