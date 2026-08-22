import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/project.dart';
import '../../auth/providers/auth_controller.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../providers/project_list_controller.dart';
import '../widgets/project_card.dart';
import '../widgets/project_form_sheet.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ProjectFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
        // Task 06's five states, all handled here and nowhere else.
        child: projects.when(
          loading: () => const LoadingView(message: 'Loading projects…'),
          error: (error, _) => PullableCenter(
            child: ErrorView(
              error: error,
              onRetry: () => ref.read(projectListProvider.notifier).retry(),
            ),
          ),
          data: (items) {
            // `empty` is DERIVED from the data, not stored as its own state.
            // A separate flag could drift out of sync with the list; this
            // cannot.
            if (items.isEmpty) {
              return PullableCenter(
                child: EmptyView(
                  icon: Icons.folder_open_outlined,
                  title: 'No projects yet',
                  message: 'Create your first project to start tracking work.',
                  actionLabel: 'New project',
                  onAction: () => ProjectFormSheet.show(context),
                ),
              );
            }

            return ListView.separated(
              // Required so a short list can still be pulled down to refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.page,
                AppSpacing.page,
                // Extra bottom room so the FAB never covers the last card.
                96,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final project = items[index];
                return ProjectCard(
                  project: project,
                  onTap: () => context.push(Routes.projectDetail(project.id)),
                  onEdit: () =>
                      ProjectFormSheet.show(context, project: project),
                  // Non-admins are not offered the action at all. The usecase
                  // refuses it regardless — this only avoids showing a button
                  // that would fail.
                  onDelete: isAdmin
                      ? () => _confirmDelete(context, ref, project)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    // Captured before the FIRST await. Once any await has run, `context` is
    // suspect for the rest of the method — the widget may already be gone.
    // That is what use_build_context_synchronously warns about.
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await ConfirmDialog.confirmed(
      context,
      title: 'Delete project?',
      message: '"${project.name}" and its '
          '${project.taskCount == 1 ? '1 task' : '${project.taskCount} tasks'} '
          'will be removed. This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(projectListProvider.notifier).deleteProject(project.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted "${project.name}".')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

