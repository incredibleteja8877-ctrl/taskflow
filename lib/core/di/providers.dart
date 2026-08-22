import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/mock_json_data_source.dart';
import '../../data/datasources/session_storage.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/organization_repository_impl.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/organization_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/project_usecases.dart';
import '../../domain/usecases/task_usecases.dart';
import '../network/mock_api_config.dart';

/// The simulated-network switches, as mutable app state.
///
/// The debug panel on the Settings screen writes here; the data source reads
/// from here. Task 07's "debug toggle" and Task 08's "connectivity toggle"
/// are both this provider.
final mockApiConfigProvider =
    NotifierProvider<MockApiConfigNotifier, MockApiConfig>(
  MockApiConfigNotifier.new,
);

class MockApiConfigNotifier extends Notifier<MockApiConfig> {
  @override
  MockApiConfig build() => const MockApiConfig();

  void setOffline(bool value) => state = state.copyWith(isOffline: value);

  void setForceTimeout(bool value) =>
      state = state.copyWith(forceTimeout: value);

  void setForceServerError(bool value) =>
      state = state.copyWith(forceServerError: value);

  void reset() => state = const MockApiConfig();
}

/// The in-memory mock database.
///
/// Deliberately built ONCE and never rebuilt. It holds every task and project
/// the user has created this session; rebuilding it would silently throw all
/// of that away. So instead of `ref.watch`ing the config — which would
/// recreate this provider on every toggle — we read it once and then push
/// later changes into the existing instance.
final mockJsonDataSourceProvider = Provider<MockJsonDataSource>((ref) {
  final dataSource = MockJsonDataSource(
    config: ref.read(mockApiConfigProvider),
  );

  ref.listen<MockApiConfig>(
    mockApiConfigProvider,
    (_, next) => dataSource.config = next,
  );

  return dataSource;
});

/// Keystore/Keychain-backed session storage.
///
/// Declared as the [SessionStorage] interface so a widget test can override
/// it with [InMemorySessionStorage] — the real one needs a platform channel
/// that does not exist in a test process.
final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);

// --------------------------------------------------------------------------
// Repositories.
//
// Every one is typed as its INTERFACE, never as the Impl. That is what makes
// the swap real: replacing these four lines with Http*RepositoryImpl would
// migrate the entire app to a live backend, and nothing above this file would
// need to change. It is also what lets a test call
// `overrideWithValue(FakeTaskRepository())` in one line.
// --------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    dataSource: ref.watch(mockJsonDataSourceProvider),
    storage: ref.watch(sessionStorageProvider),
  ),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepositoryImpl(
    dataSource: ref.watch(mockJsonDataSourceProvider),
  ),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepositoryImpl(
    dataSource: ref.watch(mockJsonDataSourceProvider),
  ),
);

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepositoryImpl(
    dataSource: ref.watch(mockJsonDataSourceProvider),
  ),
);

// --------------------------------------------------------------------------
// Usecases — the business-rule layer. Providers talk to these, never straight
// to a repository, so no screen can bypass an authorization check.
// --------------------------------------------------------------------------

final projectUseCasesProvider = Provider<ProjectUseCases>(
  (ref) => ProjectUseCases(
    projects: ref.watch(projectRepositoryProvider),
    organizations: ref.watch(organizationRepositoryProvider),
  ),
);

final taskUseCasesProvider = Provider<TaskUseCases>(
  (ref) => TaskUseCases(
    tasks: ref.watch(taskRepositoryProvider),
    projects: ref.watch(projectRepositoryProvider),
    organizations: ref.watch(organizationRepositoryProvider),
  ),
);
