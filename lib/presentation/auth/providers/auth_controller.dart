import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/organization.dart';
import '../../../domain/repositories/auth_repository.dart';

/// The signed-in session, or null.
///
/// Note that `null` is a *success* value here, not an error — "nobody is
/// signed in" is a perfectly normal thing for this provider to hold. An
/// AsyncError means something actually went wrong. Conflating the two is how
/// you end up showing a red error screen to a user who simply logged out.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() {
    // Runs once at startup. While this future is pending the state is
    // AsyncLoading — which IS the splash screen's "checking session" state.
    // Task 02's "Splash / Session Check" requirement is this one line.
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(
            LoginRequest(email: email, password: password),
          ),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).register(
            RegisterRequest(name: name, email: email, password: password),
          ),
    );
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).logout();
      return null;
    });
  }

  /// Called when a request comes back 401, and by the inactivity timer.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).refreshSession(current),
    );
  }
}

/// The current session, or null while loading or on error.
///
/// A separate provider so widgets that only care "who is signed in" do not
/// rebuild on every loading flicker of the controller.
final currentSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(authControllerProvider).valueOrNull,
);

/// Whether the signed-in user administers their org.
///
/// The UI reads this to decide what to SHOW. It is never the only defence —
/// the usecase layer re-checks before acting, exactly as Task 03 demands.
final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(currentSessionProvider)?.isAdmin ?? false,
);

/// The org every project and task query is scoped to.
final currentOrgIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider)?.orgId,
);

/// The organization record itself, for showing its name in the UI.
final currentOrganizationProvider = FutureProvider<Organization?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  return ref
      .read(organizationRepositoryProvider)
      .getOrganization(session.orgId);
});
