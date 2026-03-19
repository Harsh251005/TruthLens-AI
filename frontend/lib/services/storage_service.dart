// services/storage_service.dart
// ============================================================
// StorageService — persists user session data locally using
// SharedPreferences so the user stays logged in between app
// restarts.
//
// AVATAR CHANGES (Step 5):
//   • saveUser() now serialises avatarType + avatarData
//   • getSavedUser() restores avatar fields on app start
//   • updateAvatar() lets profile/home screens update avatar
//     locally without a full re-login
//
// Key layout in SharedPreferences:
//   user_id          → int
//   user_name        → String
//   user_email       → String
//   user_token       → String
//   user_avatar_type → String  ('initial' | 'predefined' | 'custom')
//   user_avatar_data → String? (avatar ID or base64; absent for 'initial')
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {

  // ── SharedPreferences keys ─────────────────────────────────────
  static const _kId          = 'user_id';
  static const _kName        = 'user_name';
  static const _kEmail       = 'user_email';
  static const _kToken       = 'user_token';
  static const _kAvatarType  = 'user_avatar_type';
  static const _kAvatarData  = 'user_avatar_data';
  // Safety net: SplashScreen reads this before routing to home.
  // Guards against any future code accidentally persisting an
  // unverified user and granting them access to the app.
  static const _kIsVerified  = 'user_is_verified';


  // ── Save / overwrite the full user session ────────────────────
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt   (_kId,         user.id);
    await prefs.setString(_kName,       user.name);
    await prefs.setString(_kEmail,      user.email);
    await prefs.setString(_kToken,      user.token);
    await prefs.setBool  (_kIsVerified, user.isVerified); // safety net
    await prefs.setString(_kAvatarType, user.avatarType);

    // Only write avatar_data when it has a value; remove it when null
    // (e.g. when user resets to initial avatar)
    if (user.avatarData != null) {
      await prefs.setString(_kAvatarData, user.avatarData!);
    } else {
      await prefs.remove(_kAvatarData);
    }
  }


  // ── Restore the saved user on app start ───────────────────────
  static Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();

    final id         = prefs.getInt(_kId);
    final name       = prefs.getString(_kName);
    final email      = prefs.getString(_kEmail);
    final token      = prefs.getString(_kToken);
    // Safety net: treat missing key as unverified (false) so that
    // sessions created before this key existed are re-authenticated.
    final isVerified = prefs.getBool(_kIsVerified) ?? false;

    // If any core field is missing the user isn't logged in
    if (id == null || name == null || email == null || token == null) {
      return null;
    }

    // Guard: an unverified session saved by old code must not auto-login.
    // Clear it so the user goes through signup + verification properly.
    if (!isVerified) {
      await clearUser();
      return null;
    }

    return UserModel(
      id:         id,
      name:       name,
      email:      email,
      token:      token,
      isVerified: true,
      avatarType: prefs.getString(_kAvatarType) ?? 'initial',
      avatarData: prefs.getString(_kAvatarData),   // null if key absent
    );
  }


  // ── Update ONLY the avatar fields (used after avatar pick) ────
  // Avoids re-saving the whole user just for an avatar change.
  static Future<void> updateAvatar({
    required String avatarType,
    String?         avatarData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAvatarType, avatarType);
    if (avatarData != null) {
      await prefs.setString(_kAvatarData, avatarData);
    } else {
      await prefs.remove(_kAvatarData);
    }
  }


  // ── Update ONLY the display name ──────────────────────────────
  static Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
  }


  // ── Clear everything on logout ────────────────────────────────
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kId);
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kToken);
    await prefs.remove(_kAvatarType);
    await prefs.remove(_kAvatarData);
  }

  // ── Onboarding ────────────────────────────────────────────────
  // Tracks whether the user has seen the onboarding screen.
  static const _kOnboarding = 'has_seen_onboarding';

  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboarding) ?? false;
  }
}