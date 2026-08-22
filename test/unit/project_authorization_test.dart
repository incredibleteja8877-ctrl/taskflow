import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/app_exception.dart';
import 'package:taskflow/core/network/mock_api_config.dart';
import 'package:taskflow/data/datasources/mock_json_data_source.dart';
import 'package:taskflow/data/datasources/session_storage.dart';
import 'package:taskflow/data/repositories/auth_repository_impl.dart';
import 'package:taskflow/data/repositories/organization_repository_impl.dart';
import 'package:taskflow/data/repositories/project_repository_impl.dart';
import 'package:taskflow/domain/entities/auth_session.dart';
import 'package:taskflow/domain/entities/org_member.dart';
import 'package:taskflow/domain/repositories/auth_repository.dart';
import 'package:taskflow/domain/usecases/project_usecases.dart';

/// Task 03's authorization requirement, proven at the business-logic layer.
///
/// Every call below goes straight to the usecase. There is no widget, no
/// router and no hidden button anywhere in this file — which is the point.
/// A reviewer who deep-links past the UI hits exactly this code path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJsonDataSource dataSource;
  late ProjectUseCases useCases;
  late AuthRepository auth;

  const password = 'Password123!';
  const avaEmail = 'ava.admin@nimbusdigital.test'; // Nimbus, org_admin
  const marcusEmail = 'marcus.member@nimbusdigital.test'; // Nimbus, member
  const danielEmail = 'daniel.admin@harborlightstudios.test'; // Harborlight

  Future<AuthSession> signIn(String email) =>
      auth.login(LoginRequest(email: email, password: password));

  setUp(() {
    dataSource = MockJsonDataSource(config: MockApiConfig.instant);
    auth = AuthRepositoryImpl(
      dataSource: dataSource,
      storage: InMemorySessionStorage(),
    );
    useCases = ProjectUseCases(
      projects: ProjectRepositoryImpl(dataSource: dataSource),
      organizations: OrganizationRepositoryImpl(dataSource: dataSource),
    );
  });

  group('org scoping', () {
    test('a member only ever sees their own org', () async {
      final ava = await signIn(avaEmail);
      final daniel = await signIn(danielEmail);

      final nimbus = await useCases.list(ava);
      final harborlight = await useCases.list(daniel);

      expect(nimbus.map((p) => p.name),
          containsAll(['Website Relaunch', 'Mobile App v2']));
      expect(harborlight.single.name, 'Client Onboarding Revamp');

      // No overlap whatsoever.
      final nimbusIds = nimbus.map((p) => p.id).toSet();
      final harborlightIds = harborlight.map((p) => p.id).toSet();
      expect(nimbusIds.intersection(harborlightIds), isEmpty);
    });

    test('reading another org\'s project by id reports NOT FOUND, '
        'not FORBIDDEN', () async {
      final ava = await signIn(avaEmail);

      // proj_1003 belongs to Harborlight. Ava is a Nimbus admin.
      expect(
        () => useCases.getById(ava, 'proj_1003'),
        throwsA(isA<NotFoundException>()),
        reason: 'Forbidden would confirm the project exists to a stranger',
      );
    });

    test('an admin cannot delete another org\'s project', () async {
      final ava = await signIn(avaEmail);

      expect(
        () => useCases.delete(ava, 'proj_1003'),
        throwsA(isA<NotFoundException>()),
      );

      // And it is genuinely still there.
      final daniel = await signIn(danielEmail);
      expect(await useCases.list(daniel), hasLength(1));
    });
  });

  group('role enforcement', () {
    test('an org_admin CAN delete a project in their own org', () async {
      final ava = await signIn(avaEmail);
      expect(await useCases.list(ava), hasLength(2));

      await useCases.delete(ava, 'proj_1001');

      expect(await useCases.list(ava), hasLength(1));
    });

    test('a member CANNOT delete a project, even calling the usecase '
        'directly', () async {
      final marcus = await signIn(marcusEmail);

      expect(
        () => useCases.delete(marcus, 'proj_1001'),
        throwsA(
          isA<ForbiddenException>().having(
            (e) => e.message,
            'message',
            contains('admin'),
          ),
        ),
      );

      // Nothing was deleted.
      expect(await useCases.list(marcus), hasLength(2));
    });

    test('a member CAN create and edit projects', () async {
      final marcus = await signIn(marcusEmail);

      final created = await useCases.create(
        marcus,
        name: 'Q3 Campaign',
        description: 'Planning for the autumn push.',
      );
      expect(created.orgId, marcus.orgId);
      expect(await useCases.list(marcus), hasLength(3));

      final renamed = await useCases.update(
        marcus,
        created.copyWith(name: 'Q3 Campaign (revised)'),
      );
      expect(renamed.name, 'Q3 Campaign (revised)');
    });

    test('the role is re-read from the directory, not taken from the '
        'session object', () async {
      final marcus = await signIn(marcusEmail);

      // Forge a session claiming admin — exactly what a tampered client would
      // send. The usecase looks the real membership up and refuses anyway.
      final forged = AuthSession(
        user: marcus.user,
        orgId: marcus.orgId,
        role: OrgRole.orgAdmin,
        tokens: marcus.tokens,
      );
      expect(forged.isAdmin, isTrue, reason: 'the forged claim looks valid');

      expect(
        () => useCases.delete(forged, 'proj_1001'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  group('validation', () {
    test('a project needs a name', () async {
      final ava = await signIn(avaEmail);
      expect(
        () => useCases.create(ava, name: '   '),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('cascading delete', () {
    test('deleting a project removes its tasks too', () async {
      final ava = await signIn(avaEmail);

      expect((await dataSource.readCollection('tasks')).length, 15);
      await useCases.delete(ava, 'proj_1001'); // 6 tasks
      expect((await dataSource.readCollection('tasks')).length, 9);
    });
  });
}
