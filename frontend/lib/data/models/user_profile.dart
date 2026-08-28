import 'package:cloud_firestore/cloud_firestore.dart';

/// App user profile stored in Firestore at `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final DateTime? createdAt;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    DateTime? createdAt;
    final Object? created = data['createdAt'];
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    }

    return UserProfile(
      uid: uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Friend',
      email: (data['email'] as String?) ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'createdAt': createdAt ?? DateTime.now().toUtc(),
      'updatedAt': DateTime.now().toUtc(),
    };
  }
}
