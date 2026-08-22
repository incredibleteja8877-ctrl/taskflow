import 'package:equatable/equatable.dart';

/// A tenant. Every user, project and task in the app belongs to exactly one.
///
/// The logged-in user's [id] is what scopes every query — see Task 03's
/// "read projects scoped to the logged-in user's org_id".
class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, name, createdAt];
}
