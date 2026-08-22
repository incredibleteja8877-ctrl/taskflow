import 'package:equatable/equatable.dart';

/// A person. Note that a user is not tied to an organization here — that
/// relationship lives in [OrgMember], because in principle one person could
/// belong to several orgs with a different role in each.
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;

  /// May be null, and may fail to load. Always pair it with [initials].
  final String? avatarUrl;

  /// "Ava Thompson" -> "AT". The fallback shown inside a CircleAvatar when
  /// there is no image or the image fails to load.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  List<Object?> get props => [id, name, email, avatarUrl];
}
