import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/app_exception.dart';
import 'package:taskflow/core/network/mock_api_config.dart';
import 'package:taskflow/data/datasources/mock_json_data_source.dart';
import 'package:taskflow/data/datasources/session_storage.dart';
import 'package:taskflow/data/repositories/auth_repository_impl.dart';
import 'package:taskflow/data/repositories/organization_repository_impl.dart';
import 'package:taskflow/data/repositories/project_repository_impl.dart';
import 'package:taskflow/data/repositories/task_repository_impl.dart';
import 'package:taskflow/domain/entities/auth_session.dart';
import 'package:taskflow/domain/entities/task.dart';
import 'package:taskflow/domain/entities/task_filter.dart';
import 'package:taskflow/domain/repositories/auth_repository.dart';
import 'package:taskflow/domain/repositories/task_repository.dart';
import 'package:taskflow/domain/usecases/task_usecases.dart';

/// Task 05's central rule, proven in the business-logic layer:
/// "Prevent assigning a user who does not belong to the current org (validate
/// this in the business-logic layer, not just by filtering the picker list)."
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJsonDataSource dataSource;
  late TaskUseCases useCases;
  late AuthRepository auth;

  const password = 'Password123!';
  const ava = 'ava.admin@nimbusdigital.test'; // Nimbus
  const daniel = 'daniel.admin@harborlightstudios.test'; // Harborlight

  const elenaId = 'user_005'; // Harborlight member
  const marcusId = 'user_002'; // Nimbus member
  const nimbusTask = 'task_2002'; // Website Relaunch
  const harborlightTask = 'task_2012'; // Client Onboarding Revamp

  Future<AuthSession> signIn(String email) =>
      auth.login(LoginRequest(email: email, password: password));

  setUp(() {
    dataSource = MockJsonDataSource(config: MockApiConfig.instant);
    auth = AuthRepositoryImpl(
      dataSource: dataSource,
      storage: InMemorySessionStorage(),
    );
    useCases = TaskUseCases(
      tasks: TaskRepositoryImpl(dataSource: dataSource),
      projects: ProjectRepositoryImpl(dataSource: dataSource),
      organizations: OrganizationRepositoryImpl(dataSource: dataSource),
    );
  });

  group('org scoping', () {
    test('a user only sees tasks from their own org', () async {
      final nimbus = await useCases.list(await signIn(ava));
      final harborlight = await useCases.list(await signIn(daniel));

      expect(nimbus, hasLength(11), reason: '6 + 5 across two projects');
      expect(harborlight, hasLength(4));

      final overlap = nimbus.map((t) => t.id).toSet()
        ..retainAll(harborlight.map((t) => t.id));
      expect(overlap, isEmpty);
    });

    test('reading another org\'s task by id reports NOT FOUND', () async {
      final session = await signIn(ava);
      expect(
        () => useCases.getById(session, harborlightTask),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('deleting another org\'s task reports NOT FOUND', () async {
      final session = await signIn(ava);
      expect(
        () => useCases.delete(session, harborlightTask),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('creating a task in another org\'s project reports NOT FOUND',
        () async {
      final session = await signIn(ava);
      expect(
        () => useCases.create(
          session,
          const CreateTaskRequest(projectId: 'proj_1003', title: 'Sneaky'),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('assignment', () {
    test('assigns a member of the same org', () async {
      final session = await signIn(ava);
      final updated = await useCases.assign(
        session,
        taskId: nimbusTask,
        assigneeId: marcusId,
      );
      expect(updated.assigneeId, marcusId);
    });

    test('REFUSES someone from another org, even called directly', () async {
      final session = await signIn(ava);

      expect(
        () => useCases.assign(
          session,
          taskId: nimbusTask,
          assigneeId: elenaId, // Elena is Harborlight
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors,
            'fieldErrors',
            contains('assignee'),
          ),
        ),
      );

      // And the task was left alone.
      final task = await useCases.getById(session, nimbusTask);
      expect(task.assigneeId, isNot(elenaId));
    });

    test('refuses a cross-org assignee on create too', () async {
      final session = await signIn(ava);
      expect(
        () => useCases.create(
          session,
          const CreateTaskRequest(
            projectId: 'proj_1001',
            title: 'Cross-org attempt',
            assigneeId: elenaId,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('unassigning clears the assignee', () async {
      final session = await signIn(ava);
      expect(
        (await useCases.getById(session, nimbusTask)).assigneeId,
        isNotNull,
      );

      final updated = await useCases.assign(
        session,
        taskId: nimbusTask,
        assigneeId: null,
      );
      expect(updated.assigneeId, isNull);
      expect(updated.isAssigned, isFalse);
    });

    test('the picker only offers members of the current org', () async {
      final members = await useCases.assignableUsers(await signIn(ava));
      final ids = members.map((u) => u.id).toSet();

      expect(ids, containsAll(['user_001', 'user_002', 'user_003']));
      expect(ids, isNot(contains(elenaId)));
    });
  });

  group('status and priority', () {
    test('setStatus persists', () async {
      final session = await signIn(ava);
      final updated =
          await useCases.setStatus(session, nimbusTask, TaskStatus.done);
      expect(updated.status, TaskStatus.done);
      expect(
        (await useCases.getById(session, nimbusTask)).status,
        TaskStatus.done,
      );
    });

    test('setPriority persists', () async {
      final session = await signIn(ava);
      final updated =
          await useCases.setPriority(session, nimbusTask, TaskPriority.low);
      expect(updated.priority, TaskPriority.low);
    });

    test('cannot change status on another org\'s task', () async {
      final session = await signIn(ava);
      expect(
        () => useCases.setStatus(
          session,
          harborlightTask,
          TaskStatus.done,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('filtering through the usecase', () {
    test('narrows to a project', () async {
      final tasks = await useCases.list(
        await signIn(ava),
        projectId: 'proj_1002',
      );
      expect(tasks, hasLength(5));
    });

    test('applies a status filter on top of org scoping', () async {
      final tasks = await useCases.list(
        await signIn(ava),
        filter: const TaskFilter(statuses: {TaskStatus.done}),
      );
      // Two done tasks in Nimbus; the third done task is Harborlight's.
      expect(tasks, hasLength(2));
      expect(tasks.every((t) => t.status == TaskStatus.done), isTrue);
    });
  });

  group('create and delete', () {
    test('creating then deleting round-trips', () async {
      final session = await signIn(ava);
      final before = (await useCases.list(session)).length;

      final created = await useCases.create(
        session,
        const CreateTaskRequest(
          projectId: 'proj_1001',
          title: 'Write the README',
        ),
      );
      expect((await useCases.list(session)), hasLength(before + 1));

      await useCases.delete(session, created.id);
      expect((await useCases.list(session)), hasLength(before));
    });

    test('an empty title is rejected with a field error', () async {
      final session = await signIn(ava);
      expect(
        () => useCases.create(
          session,
          const CreateTaskRequest(projectId: 'proj_1001', title: '  '),
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
  });
}
