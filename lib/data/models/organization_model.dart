import '../../domain/entities/organization.dart';

/// Wire translator for [Organization]. See TaskModel for the pattern.
abstract final class OrganizationModel {
  static Organization fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toJson(Organization organization) {
    return <String, dynamic>{
      'id': organization.id,
      'name': organization.name,
      'created_at': organization.createdAt.toUtc().toIso8601String(),
    };
  }
}
