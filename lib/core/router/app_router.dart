import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/providers/auth_controller.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/auth/screens/register_screen.dart';
import '../../presentation/auth/screens/splash_screen.dart';
import '../../presentation/projects/screens/projects_screen.dart';

/// Every route path in one place, so no screen ever hardcodes a string.
abstract final class Routes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String projects = '/projects';
  static const String profile = '/profile';
}

/// Bridges Riverpod state to go_router, which wants a plain [Listenable].
///
/// Without this the router would have to `ref.watch` the auth state, which
/// rebuilds the entire GoRouter — discarding the navigation stack — every
/// time the session changes. This way the router instance is built once and
/// merely re-evaluates its redirect.
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
/// The [GoRouter.redirect] callback below is Task 02's "logout blocks access
/// to authenticated screens" and part of Task 03's "a non-admin attempting an
/// admin action via a direct deep link should still be blocked". It runs on
/// EVERY navigation, including deep links and browser back — which is exactly
/// why a guard belongs here rather than in each screen's initState.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: ref.watch(_routerRefreshProvider),
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final atSplash = location == Routes.splash;

      // The stored-session check is still running. Hold on the splash screen
      // rather than flashing Login and then bouncing straight to Projects.
      if (auth.isLoading && atSplash) return null;

      final signedIn = auth.valueOrNull != null;
      final atAuthScreen =
          location == Routes.login || location == Routes.register;

      // Not signed in: only Login and Register are reachable. Everything
      // else — including a pasted deep link — lands on Login.
      if (!signedIn) return atAuthScreen ? null : Routes.login;

      // Signed in: Splash, Login and Register are dead ends. Send them home.
      if (atSplash || atAuthScreen) return Routes.projects;

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
        path: Routes.projects,
        builder: (context, state) => const ProjectsScreen(),
      ),
    ],
  );
});
