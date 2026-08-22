import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/app_exception.dart';
import 'package:taskflow/core/network/mock_api_config.dart';
import 'package:taskflow/data/datasources/mock_json_data_source.dart';
import 'package:taskflow/data/datasources/session_storage.dart';
import 'package:taskflow/data/repositories/auth_repository_impl.dart';
import 'package:taskflow/data/repositories/organization_repository_impl.dart';
import 'package:taskflow/data/repositories/project_repository_impl.dart';
import 'package:taskflow/data/repositories/task_repository_impl.dart';
import 'package:taskflow/domain/entities/task.dart';
import 'package:taskflow/domain/entities/task_filter.dart';
import 'package:taskflow/domain/repositories/auth_repository.dart';
import 'package:taskflow/domain/repositories/task_repository.dart';

/// End-to-end smoke test of the data layer against the real mock asset.
///
/// Not the final test suite — this exists to prove the JSON actually parses
/// and the repositories actually work before we build UI on top of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJsonDataSource dataSource;

  setUp(() {
    dataSource = MockJsonDataSource(config: MockApiConfig.instant);
  });

  group('MockJsonDataSource', () {
    test('loads every top-level collection from the asset', () async {
      expect((await dataSource.readCollection('organizations')).length, 2);
      expect((await dataSource.readCollection('users')).length, 5);
      expect((await dataSource.readCollection('org_members')).length, 5);
      expect((await dataSource.readCollection('projects')).length, 3);
      expect((await dataSource.readCollection('tasks')).length, 15);
      expect((await dataSource.readCollection('comments')).length, 4);
      expect((await dataSource.readCollection('notifications')).length, 3);
      expect(await dataSource.readObject('auth_mock'), isNotEmpty);
    });

    test('the _404 marker triggers a simulated not-found', () async {
      expect(
        () => dataSource.readById('tasks', 'task_404'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('the offline switch throws OfflineException', () async {
      dataSource.config = const MockApiConfig(isOffline: true);
      expect(
        () => dataSource.readCollection('tasks'),
        throwsA(isA<OfflineException>()),
      );
    });

    test('the timeout switch throws NetworkTimeoutException', () async {
      dataSource.config = const MockApiConfig(
        minDelay: Duration.zero,
        maxDelay: Duration.zero,
        forceTimeout: true,
      );
      expect(
        () => dataSource.readCollection('tasks'),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });
  });

  group('TaskRepositoryImpl', () {
    late TaskRepository repository;

    setUp(() => repository = TaskRepositoryImpl(dataSource: dataSource));

    test('parses all 15 tasks into entities', () async {
      final tasks = await repository.getTasks();
      expect(tasks.length, 15);
      expect(tasks.first.status, isA<TaskStatus>());
    });

    test('scopes to a project', () async {
      final tasks = await repository.getTasks(projectId: 'proj_1001');
      expect(tasks.length, 6);
    });

    test('applies a status filter', () async {
      final tasks = await repository.getTasks(
        filter: const TaskFilter(statuses: {TaskStatus.done}),
      );
      expect(tasks.length, 3);
      expect(tasks.every((t) => t.status == TaskStatus.done), isTrue);
    });

    test('an empty filter matches everything', () async {
      final tasks = await repository.getTasks(filter: TaskFilter.none);
      expect(tasks.length, 15);
    });

    test('handles the three unassigned tasks without crashing', () async {
      final tasks = await repository.getTasks(
        filter: const TaskFilter(unassignedOnly: true),
      );
      expect(tasks.length, 3);
      expect(tasks.every((t) => t.assigneeId == null), isTrue);
    });

    test('create then read back', () async {
      final created = await repository.createTask(
        const CreateTaskRequest(projectId: 'proj_1001', title: 'Smoke test'),
      );
      expect(created.id, startsWith('task_'));
      expect((await repository.getTasks(projectId: 'proj_1001')).length, 7);

      final fetched = await repository.getTask(created.id);
      expect(fetched.title, 'Smoke test');
    });

    test('rejects an empty title with field errors', () async {
      expect(
        () => repository.createTask(
          const CreateTaskRequest(projectId: 'proj_1001', title: '   '),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors,
            'fieldErrors',
            contains('title'),
          ),
        ),
      );
    });

    test('unassigning a task actually clears the assignee', () async {
      final task = await repository.getTask('task_2002');
      expect(task.assigneeId, 'user_003');

      final updated = await repository.updateTask(
        task.copyWith(assigneeId: null),
      );
      expect(updated.assigneeId, isNull);
    });
  });

  group('ProjectRepositoryImpl', () {
    test('scopes projects to an org and recomputes task counts', () async {
      final repository = ProjectRepositoryImpl(dataSource: dataSource);

      final nimbus = await repository.getProjects('org_a1b2c3');
      expect(nimbus.length, 2);
      expect(nimbus.map((p) => p.taskCount).toList(), [6, 5]);

      final harborlight = await repository.getProjects('org_d4e5f6');
      expect(harborlight.length, 1);
      expect(harborlight.single.taskCount, 4);
    });
  });

  group('OrganizationRepositoryImpl', () {
    test('joins memberships to users, scoped to one org', () async {
      final repository = OrganizationRepositoryImpl(dataSource: dataSource);

      final members = await repository.getMembers('org_a1b2c3');
      expect(members.map((u) => u.name).toList(),
          ['Ava Thompson', 'Marcus Lee', 'Priya Nair']..sort());

      final elena = await repository.findMembership(
        orgId: 'org_a1b2c3',
        userId: 'user_005',
      );
      expect(elena, isNull, reason: 'Elena belongs to Harborlight, not Nimbus');
    });
  });

  group('AuthRepositoryImpl', () {
    late AuthRepository auth;
    late InMemorySessionStorage storage;
    final loginTime = DateTime.utc(2026, 8, 22, 12);

    setUp(() {
      storage = InMemorySessionStorage();
      auth = AuthRepositoryImpl(
        dataSource: dataSource,
        storage: storage,
        clock: () => loginTime,
      );
    });

    test('signs in an admin and scopes the session to their org', () async {
      final session = await auth.login(
        const LoginRequest(
          email: 'ava.admin@nimbusdigital.test',
          password: 'Password123!',
        ),
      );

      expect(session.user.name, 'Ava Thompson');
      expect(session.orgId, 'org_a1b2c3');
      expect(session.isAdmin, isTrue);
      expect(await storage.read(), isNotNull);
    });

    test('a member is not an admin', () async {
      final session = await auth.login(
        const LoginRequest(
          email: 'marcus.member@nimbusdigital.test',
          password: 'Password123!',
        ),
      );
      expect(session.isAdmin, isFalse);
    });

    test('rejects a wrong password', () async {
      expect(
        () => auth.login(
          const LoginRequest(
            email: 'ava.admin@nimbusdigital.test',
            password: 'Wrong123!',
          ),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('access token expires 15 minutes after issue', () async {
      final session = await auth.login(
        const LoginRequest(
          email: 'ava.admin@nimbusdigital.test',
          password: 'Password123!',
        ),
      );

      expect(
        session.tokens.accessTokenExpiresAt,
        loginTime.add(const Duration(minutes: 15)),
      );
      expect(session.tokens.isAccessTokenExpired(loginTime), isFalse);
      expect(
        session.tokens.isAccessTokenExpired(
          loginTime.add(const Duration(minutes: 16)),
        ),
        isTrue,
      );
    });

    test('refresh issues a genuinely new access token', () async {
      final session = await auth.login(
        const LoginRequest(
          email: 'ava.admin@nimbusdigital.test',
          password: 'Password123!',
        ),
      );

      final later = loginTime.add(const Duration(minutes: 16));
      final refreshedAuth = AuthRepositoryImpl(
        dataSource: dataSource,
        storage: storage,
        clock: () => later,
      );

      final refreshed = await refreshedAuth.refreshSession(session);
      expect(refreshed.tokens.accessToken,
          isNot(session.tokens.accessToken));
      expect(refreshed.tokens.isAccessTokenExpired(later), isFalse);
      expect(refreshed.user, session.user);
    });

    test('logout clears the stored session', () async {
      await auth.login(
        const LoginRequest(
          email: 'ava.admin@nimbusdigital.test',
          password: 'Password123!',
        ),
      );
      await auth.logout();
      expect(await storage.read(), isNull);
      expect(await auth.restoreSession(), isNull);
    });

    test('register creates a workspace and signs the user in as its admin',
        () async {
      final session = await auth.register(
        const RegisterRequest(
          name: 'Sai Teja',
          email: 'sai@example.test',
          password: 'Password123!',
        ),
      );

      expect(session.isAdmin, isTrue);
      expect(session.orgId, startsWith('org_'));

      final projects =
          await ProjectRepositoryImpl(dataSource: dataSource)
              .getProjects(session.orgId);
      expect(projects, isEmpty, reason: 'a fresh workspace has no projects');
    });

    test('register rejects an email that already exists', () async {
      expect(
        () => auth.register(
          const RegisterRequest(
            name: 'Impostor',
            email: 'ava.admin@nimbusdigital.test',
            password: 'Password123!',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
