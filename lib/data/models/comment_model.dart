import '../../domain/entities/comment.dart';

/// Wire translator for [Comment].
abstract final class CommentModel {
  static Comment fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toJson(Comment comment) {
    return <String, dynamic>{
      'id': comment.id,
      'task_id': comment.taskId,
      'author_id': comment.authorId,
      'body': comment.body,
      'created_at': comment.createdAt.toUtc().toIso8601String(),
    };
  }
}
