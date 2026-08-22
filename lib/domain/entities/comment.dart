import 'package:equatable/equatable.dart';

/// A message left on a task. Read-only in this build — the brief never asks
/// for comment creation, so the repository exposes reads only.
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, taskId, authorId, body, createdAt];
}
