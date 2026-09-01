/// App user profile stored in PostgreSQL (`app_user`) via the FastAPI backend.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.createdAt,
    this.forecastLocationId,
    this.forecastLocationName,
  });

  final String uid;
  final String name;
  final String email;
  final DateTime? createdAt;
  final String? forecastLocationId;
  final String? forecastLocationName;

  factory UserProfile.fromJson(Map<String, dynamic> data) {
    final Object? created = data['created_at'];
    DateTime? createdAt;
    if (created is String && created.isNotEmpty) {
      createdAt = DateTime.tryParse(created);
    }

    return UserProfile(
      uid: (data['id'] as String?) ?? '',
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Friend',
      email: (data['email'] as String?) ?? '',
      createdAt: createdAt,
      forecastLocationId: data['forecast_location_id'] as String?,
      forecastLocationName: data['forecast_location_name'] as String?,
    );
  }
}
