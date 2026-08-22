import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_filter.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/task_repository.dart';
import '../../auth/providers/auth_controller.dart';
import '../../projects/providers/project_list_controller.dart';

/// The filter the user has built in the filter sheet.
///
/// Held separately from the list so changing a filter does not require
/// re-running any list logic by hand — [taskListProvider] watches this and
/// Riverpod reloads it automatically.
final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.none;

  void replace(TaskFilter filter) => state = filter;

  void clear() => state = TaskFilter.none;
}

/// Every task in the caller's org, honouring [taskFilterProvider].
final taskListProvider =
    AsyncNotifierProvider<TaskListController, List<Task>>(
  TaskListController.new,
);

class TaskListController extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const [];

    // Watching the filter is what makes the list reactive: adjust a chip in
    // the filter sheet and this rebuilds, with no imperative reload call.
    final filter = ref.watch(taskFilterProvider);

    return ref.read(taskUseCasesProvider).list(session, filter: filter);
  }

  Future<void> refresh() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    final filter = ref.read(taskFilterProvider);
    state = await AsyncValue.guard(
      () => ref.read(taskUseCasesProvider).list(session, filter: filter),
    );
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    await refresh();
  }
}

/// Every task in the org, ignoring the user's filter.
///
/// The dashboard needs true totals; [taskListProvider] deliberately reflects
/// whatever the user has filtered to, so it is the wrong source for stats.
final allTasksProvider = FutureProvider<List<Task>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref.read(taskUseCasesProvider).list(session);
});

/// Tasks belonging to one project. Used by the Project Details screen.
final projectTasksProvider =
    AsyncNotifierProvider.family<ProjectTasksController, List<Task>, String>(
  ProjectTasksController.new,
);

class ProjectTasksController extends FamilyAsyncNotifier<List<Task>, String> {
  @override
  Future<List<Task>> build(String projectId) async {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const [];
    return ref
        .read(taskUseCasesProvider)
        .list(session, projectId: projectId);
  }

  Future<void> refresh() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    state = await AsyncValue.guard(
      () => ref.read(taskUseCasesProvider).list(session, projectId: arg),
    );
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    await refresh();
  }
}

/// One task by id. Throws NotFoundException for an unknown or cross-org id,
/// which the Task Details screen renders through ErrorView.
final taskDetailProvider =
    FutureProvider.family<Task, String>((ref, taskId) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) throw const UnauthorizedException();
  return ref.read(taskUseCasesProvider).getById(session, taskId);
});

/// Members of the current org — the assignee picker's contents.
final orgMembersProvider = FutureProvider<List<User>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref.read(taskUseCasesProvider).assignableUsers(session);
});

/// id -> User, so a task row can show an assignee's name without each row
/// firing its own lookup.
final orgMemberLookupProvider = Provider<Map<String, User>>((ref) {
  final members = ref.watch(orgMembersProvider).valueOrNull ?? const <User>[];
  return {for (final member in members) member.id: member};
});

/// Task mutations.
///
/// Kept off the list controllers because a single write can invalidate
/// several views at once: creating a task changes the org-wide list, that
/// project's list, and the project's task count. One place to get that right.
final taskActionsProvider = Provider<TaskActions>(TaskActions.new);

class TaskActions {
  const TaskActions(this._ref);

  final Ref _ref;

  Future<Task> create(CreateTaskRequest request) async {
    final session = _requireSession();
    final created =
        await _ref.read(taskUseCasesProvider).create(session, request);
    _invalidate();
    return created;
  }

  Future<Task> update(Task task) async {
    final session = _requireSession();
    final updated = await _ref.read(taskUseCasesProvider).update(session, task);
    _invalidate();
    return updated;
  }

  Future<void> delete(String taskId) async {
    final session = _requireSession();
    await _ref.read(taskUseCasesProvider).delete(session, taskId);
    _invalidate();
  }

  Future<Task> assign(String taskId, String? assigneeId) async {
    final session = _requireSession();
    final updated = await _ref.read(taskUseCasesProvider).assign(
          session,
          taskId: taskId,
          assigneeId: assigneeId,
        );
    _invalidate();
    return updated;
  }

  Future<Task> setStatus(String taskId, TaskStatus status) async {
    final session = _requireSession();
    final updated = await _ref
        .read(taskUseCasesProvider)
        .setStatus(session, taskId, status);
    _invalidate();
    return updated;
  }

  Future<Task> setPriority(String taskId, TaskPriority priority) async {
    final session = _requireSession();
    final updated = await _ref
        .read(taskUseCasesProvider)
        .setPriority(session, taskId, priority);
    _invalidate();
    return updated;
  }

  /// Invalidating a family provider without an argument invalidates every
  /// instance of it, which is what we want: any project's task list may have
  /// changed, and so may a project's task count.
  void _invalidate() {
    _ref.invalidate(taskListProvider);
    _ref.invalidate(allTasksProvider);
    _ref.invalidate(projectTasksProvider);
    _ref.invalidate(taskDetailProvider);
    _ref.invalidate(projectListProvider);
  }

  AuthSession _requireSession() {
    final session = _ref.read(currentSessionProvider);
    if (session == null) throw const UnauthorizedException();
    return session;
  }
}
