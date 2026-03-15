// models/user_model.dart
// ============================================================
// Represents the User object returned by the backend API.
// token is optional because the profile endpoint doesn't return it.
// ============================================================

class UserModel {
  final int id;
  final String name;
  final String email;
  final String token; // JWT token — empty string for profile responses

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.token = '', // Default to empty for profile endpoint
  });

  /// Creates a UserModel from the JSON map returned by the API
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:    json['id']    as int,
      name:  json['name']  as String,
      email: json['email'] as String,
      token: json['token'] as String? ?? '', // token is optional
    );
  }

  @override
  String toString() => 'UserModel(id: $id, name: $name, email: $email)';
}