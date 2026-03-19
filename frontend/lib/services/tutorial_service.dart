// services/tutorial_service.dart
// ============================================================
// Manages tutorial state via SharedPreferences.
//
// KEY FIX: Added a separate `_keyNewSignup` flag.
//
// WHY THIS IS NEEDED:
//   hasSeenIntro() alone is not enough to detect new users.
//   If a previous account on the same device already completed
//   the tutorial, hasSeenIntro() returns true for the NEW user
//   too — so the tutorial never shows.
//
//   Solution: signup_screen sets markNewSignup() on success.
//   email_verification_screen checks isNewSignup() instead of
//   hasSeenIntro() to decide whether to show TutorialScreen.
//   Once tutorial is shown, clearNewSignup() is called.
//
// FLOW:
//   Signup success      → markNewSignup()
//   Email verified      → isNewSignup()? → show TutorialScreen
//   Tutorial completes  → markIntroSeen() + clearNewSignup()
//   Login (existing)    → hasSeenIntro()? → skip tutorial
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  // ── Preference Keys ────────────────────────────────────────
  static const String _keyIntroSeen  = 'tutorial_intro_seen';
  static const String _keyNewSignup  = 'tutorial_new_signup'; // ← NEW
  static const String _keyCoachPrefix = 'coach_seen_';

  // ── Singleton ──────────────────────────────────────────────
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  // ── Intro Seen (for login flow) ────────────────────────────

  /// True if this device has ever completed the tutorial intro.
  /// Used by login flow to skip tutorial for returning users.
  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIntroSeen) ?? false;
  }

  /// Called by TutorialScreen when user taps "Get Started" or "Skip".
  Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIntroSeen, true);
    await prefs.remove(_keyNewSignup); // Clear signup flag once tutorial done
  }

  // ── New Signup Flag (for signup → verify → tutorial flow) ──

  /// Called immediately after a successful signup API response.
  /// Signals that the NEXT navigation after email verification
  /// should show the tutorial, regardless of hasSeenIntro().
  Future<void> markNewSignup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNewSignup, true);
  }

  /// True if the user just completed signup on this device.
  /// EmailVerificationScreen uses this to route to TutorialScreen.
  Future<bool> isNewSignup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNewSignup) ?? false;
  }

  /// Clears the new signup flag (called by markIntroSeen internally).
  Future<void> clearNewSignup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNewSignup);
  }

  // ── Coach Marks ────────────────────────────────────────────

  /// True if coach marks for [screenName] have already been shown.
  Future<bool> hasSeenCoach(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyCoachPrefix$screenName') ?? false;
  }

  /// Marks coach marks for [screenName] as completed.
  Future<void> markCoachSeen(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyCoachPrefix$screenName', true);
  }

  // ── Full Reset (for "Replay Tutorial" in settings) ─────────

  /// Resets ALL tutorial state — tutorial will show again from scratch.
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where(
          (k) => k == _keyIntroSeen ||
          k == _keyNewSignup ||
          k.startsWith(_keyCoachPrefix),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}