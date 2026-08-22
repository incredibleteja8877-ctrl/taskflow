import '../../core/error/app_exception.dart';
import '../../domain/entities/app_notification.dart';

/// Wire translator for [AppNotification].
///
/// Two renames happen here, and this file is the only place that knows about
/// them: `read` on the wire becomes `isRead` on the entity, and the class
/// itself is prefixed to dodge Flutter's own `Notification`.
abstract final class AppNotificationModel {
  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: typeFromWire(json['type'] as String),
      message: json['message'] as String,
      isRead: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      taskId: json['task_id'] as String?,
    );
  }

  static Map<String, dynamic> toJson(AppNotification notification) {
    return <String, dynamic>{
      'id': notification.id,
      'user_id': notification.userId,
      'type': typeToWire(notification.type),
      'task_id': notification.taskId,
      'message': notification.message,
      'read': notification.isRead,
      'created_at': notification.createdAt.toUtc().toIso8601String(),
    };
  }

  static NotificationType typeFromWire(String value) => switch (value) {
        'task_assigned' => NotificationType.taskAssigned,
        _ => throw ValidationException('Unknown notification type "$value".'),
      };

  static String typeToWire(NotificationType type) => switch (type) {
        NotificationType.taskAssigned => 'task_assigned',
      };
}
