// services/tutorial_service.dart
// ============================================================
// Manages tutorial intro slide state via SharedPreferences.
// Coach mark system removed — only intro slides are used.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _keyIntroSeen = 'tutorial_intro_seen';
  static const String _keyNewSignup = 'tutorial_new_signup';

  // ── Singleton ──────────────────────────────────────────────
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  // ── Intro Seen (login flow) ────────────────────────────────

  /// True if this device has completed the tutorial intro before.
  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIntroSeen) ?? false;
  }

  /// Called when user taps "Get Started" or "Skip" on tutorial.
  Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIntroSeen, true);
    await prefs.remove(_keyNewSignup);
  }

  // ── New Signup Flag (signup → verify → tutorial flow) ──────

  /// Called after successful signup to flag that the next
  /// navigation after email verification should show tutorial.
  Future<void> markNewSignup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNewSignup, true);
  }

  /// True if the user just completed signup on this device.
  Future<bool> isNewSignup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNewSignup) ?? false;
  }

  // ── Reset (for "Replay Tutorial" in settings) ──────────────

  /// Resets tutorial state so intro slides show again.
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIntroSeen);
    await prefs.remove(_keyNewSignup);
  }
}