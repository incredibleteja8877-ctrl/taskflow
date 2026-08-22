import '../../core/error/app_exception.dart';
import '../../domain/entities/project.dart';

/// Wire translator for [Project].
abstract final class ProjectModel {
  static Project fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      // `num` first, then toInt(): JSON numbers decode as int here, but a real
      // API sending 6.0 would otherwise blow up on a straight `as int` cast.
      taskCount: (json['task_count'] as num?)?.toInt() ?? 0,
      status: statusFromWire(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toJson(Project project) {
    return <String, dynamic>{
      'id': project.id,
      'org_id': project.orgId,
      'name': project.name,
      'description': project.description,
      'task_count': project.taskCount,
      'status': statusToWire(project.status),
      'created_at': project.createdAt.toUtc().toIso8601String(),
    };
  }

  static ProjectStatus statusFromWire(String value) => switch (value) {
        'active' => ProjectStatus.active,
        'archived' => ProjectStatus.archived,
        _ => throw ValidationException('Unknown project status "$value".'),
      };

  static String statusToWire(ProjectStatus status) => switch (status) {
        ProjectStatus.active => 'active',
        ProjectStatus.archived => 'archived',
      };
}
