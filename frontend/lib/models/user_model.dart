// models/user_model.dart
// ============================================================
// UserModel — represents the logged-in user across the app.
//
// AVATAR CHANGES (Step 4):
//   • Added avatarType and avatarData fields
//   • fromJson() reads avatar fields gracefully (nullable)
//   • toJson() serialises avatar fields for SharedPreferences
//   • copyWith() lets callers update only avatar without
//     rebuilding the entire object
// ============================================================

class UserModel {
  final int    id;
  final String name;
  final String email;
  final String token;
  final bool isVerified;

  /// Which kind of avatar the user has selected.
  /// Values: 'initial' | 'predefined' | 'custom'
  final String avatarType;

  /// For 'predefined': the avatar ID string (e.g. "fox", "robot").
  /// For 'custom':     base64-encoded JPEG string of the uploaded photo.
  /// For 'initial':    null — the app will render the first letter of name.
  final String? avatarData;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.avatarType = 'initial',
    this.avatarData,
    this.isVerified = true,
  });

  // ── Deserialize from API / SharedPreferences JSON ─────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:         json['id']          as int,
      name:       json['name']        as String,
      email:      json['email']       as String,
      // token may be absent in /me responses — fall back to empty string.
      // StorageService always merges the saved token when restoring.
      token:      (json['token']      as String?) ?? '',
      avatarType: (json['avatar_type'] as String?) ?? 'initial',
      avatarData:  json['avatar_data'] as String?,
      isVerified: (json['is_verified'] as bool?) ?? true,
    );
  }

  // ── Serialise to JSON for SharedPreferences storage ───────────
  Map<String, dynamic> toJson() => {
    'id':          id,
    'name':        name,
    'email':       email,
    'token':       token,
    'avatar_type': avatarType,
    'avatar_data': avatarData,
    'is_verified': isVerified,
  };

  // ── Return a new UserModel with only the changed fields ───────
  // Usage: savedUser.copyWith(avatarType: 'predefined', avatarData: 'fox')
  UserModel copyWith({
    int?    id,
    String? name,
    String? email,
    String? token,
    String? avatarType,
    String? avatarData,
    bool    clearAvatarData = false,  // pass true to set avatarData → null
    bool? isVerified,
  }) {
    return UserModel(
      id:         id         ?? this.id,
      name:       name       ?? this.name,
      email:      email      ?? this.email,
      token:      token      ?? this.token,
      avatarType: avatarType ?? this.avatarType,
      avatarData: clearAvatarData ? null : (avatarData ?? this.avatarData),
      isVerified: isVerified ?? this.isVerified,

    );
  }
}