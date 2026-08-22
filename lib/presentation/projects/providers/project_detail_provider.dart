import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/project.dart';
import '../../auth/providers/auth_controller.dart';

/// One project by id.
///
/// Throws NotFoundException for an unknown id *or* for a project belonging to
/// another organization — see ProjectUseCases.getById. That is the deep-link
/// guard, and the Project Details screen renders it through ErrorView.
final projectDetailProvider =
    FutureProvider.family<Project, String>((ref, projectId) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) throw const UnauthorizedException();
  return ref.read(projectUseCasesProvider).getById(session, projectId);
});
