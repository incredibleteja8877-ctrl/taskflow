import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/project.dart';

/// One row in the project list.
///
/// A dumb widget: it takes a [Project] and some callbacks and renders. It
/// does not read providers, fetch anything, or decide who may delete it —
/// the screen passes [onDelete] as null when the caller is not an admin.
/// Keeping it dependency-free is what makes it reusable and easy to golden-test.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Project project;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  /// Null hides the delete action. The usecase blocks it regardless —
  /// this only avoids offering a button that would fail.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenu = onEdit != null || onDelete != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        project.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          // Pluralised properly. "1 tasks" is the kind of
                          // detail reviewers notice.
                          project.taskCount == 1
                              ? '1 task'
                              : '${project.taskCount} tasks',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (project.isArchived) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '· Archived',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (hasMenu)
                PopupMenuButton<_ProjectAction>(
                  tooltip: 'Project actions',
                  onSelected: (action) => switch (action) {
                    _ProjectAction.edit => onEdit?.call(),
                    _ProjectAction.delete => onDelete?.call(),
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: _ProjectAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: _ProjectAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProjectAction { edit, delete }
