// services/storage_service.dart
// ============================================================
// Handles saving, reading and clearing user session data
// locally on the device using shared_preferences.
// Called after login/signup and on app launch.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  // ── Storage Keys ──────────────────────────────────────────────
  // Using constants avoids typos when reading/writing
  static const String _keyToken          = 'auth_token';
  static const String _keyId             = 'user_id';
  static const String _keyName           = 'user_name';
  static const String _keyEmail          = 'user_email';
  static const String _keyOnboarding     = 'has_seen_onboarding';

  // ── Save User Session ─────────────────────────────────────────
  /// Saves user info + JWT token to device storage after login/signup
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, user.token);
    await prefs.setInt(_keyId,       user.id);
    await prefs.setString(_keyName,  user.name);
    await prefs.setString(_keyEmail, user.email);
  }

  // ── Read Saved User ───────────────────────────────────────────
  /// Returns saved UserModel if a session exists, null otherwise
  static Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(_keyToken);
    final id    = prefs.getInt(_keyId);
    final name  = prefs.getString(_keyName);
    final email = prefs.getString(_keyEmail);

    // If any field is missing, no valid session exists
    if (token == null || id == null || name == null || email == null) {
      return null;
    }

    return UserModel(id: id, name: name, email: email, token: token);
  }

  // ── Clear Session ─────────────────────────────────────────────
  /// Removes all saved user data — called on logout
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyId);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
  }

  // ── Check if Logged In ────────────────────────────────────────
  /// Quick check — returns true if a token is saved
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) != null;
  }

  // ── Onboarding ────────────────────────────────────────────────

  /// Returns true if the user has already seen onboarding
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarding) ?? false;
  }

  /// Marks onboarding as completed — never shown again
  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }
}