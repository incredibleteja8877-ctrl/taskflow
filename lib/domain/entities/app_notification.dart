import 'package:equatable/equatable.dart';

/// The kind of event a notification describes. Only `task_assigned` appears
/// in the mock data, so that is the only value modelled — inventing wire
/// values the backend never sends would be dishonest documentation.
enum NotificationType { taskAssigned }

/// An inbox item. Named `AppNotification` rather than `Notification` because
/// `package:flutter/widgets.dart` already exports a `Notification` class, and
/// the collision would force awkward import aliases in every screen.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.taskId,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String message;

  /// `read` on the wire. Renamed here because `read` reads like a verb.
  final bool isRead;

  final DateTime createdAt;

  /// The task this notification points at, if any. Drives deep linking.
  final String? taskId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      taskId: taskId,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, type, message, isRead, createdAt, taskId];
}
