import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/project.dart';
import '../../auth/providers/auth_controller.dart';

final projectListProvider =
    AsyncNotifierProvider<ProjectListController, List<Project>>(
  ProjectListController.new,
);

class ProjectListController extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    // ref.watch, not ref.read. Signing out tears this provider down; signing
    // in as someone else rebuilds it for THEIR org. No manual invalidation,
    // and no chance of showing the previous user's projects.
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const [];

    return ref.read(projectUseCasesProvider).list(session);
  }

  /// Pull-to-refresh and post-mutation reload.
  ///
  /// Deliberately does not set AsyncLoading first: RefreshIndicator already
  /// draws a spinner, and blanking the list would make the content vanish
  /// and reappear under the user's finger.
  Future<void> refresh() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    state = await AsyncValue.guard(
      () => ref.read(projectUseCasesProvider).list(session),
    );
  }

  /// Retry after an error, from the ErrorView button. Unlike [refresh] this
  /// DOES show a spinner, because there is no content on screen to preserve.
  Future<void> retry() async {
    state = const AsyncLoading();
    await refresh();
  }

  // ------------------------------------------------------------ mutations
  //
  // These rethrow rather than writing to `state`. The caller is a form that
  // needs the ValidationException's fieldErrors to mark its own inputs; if
  // we captured the error here, a too-long name would replace the entire
  // screen with an error page.

  Future<Project> createProject({
    required String name,
    String description = '',
  }) async {
    final session = _requireSession();
    final created = await ref.read(projectUseCasesProvider).create(
          session,
          name: name,
          description: description,
        );
    await refresh();
    return created;
  }

  Future<Project> updateProject(Project project) async {
    final session = _requireSession();
    final updated =
        await ref.read(projectUseCasesProvider).update(session, project);
    await refresh();
    return updated;
  }

  Future<void> deleteProject(String projectId) async {
    final session = _requireSession();
    await ref.read(projectUseCasesProvider).delete(session, projectId);
    await refresh();
  }

  AuthSession _requireSession() {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      // Should be unreachable — the router guard blocks these screens when
      // signed out. Throwing beats returning silently, because a silent
      // no-op looks to the user like the button is broken.
      throw const UnauthorizedException();
    }
    return session;
  }
}
