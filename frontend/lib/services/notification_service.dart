// services/notification_service.dart
// ============================================================
// Handles all local push notifications:
//   - Daily streak reminder at 8:00 PM
//   - Badge progress reminder when close to unlocking
//   - Permission request on first launch
//   - User can enable/disable via profile settings
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
class NotificationService {

  // ── Singleton ─────────────────────────────────────────────────
  static final NotificationService _instance =
  NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ── Plugin instance ───────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  // ── SharedPreferences keys ────────────────────────────────────
  static const _kStreakNotif = 'notif_streak_enabled';
  static const _kBadgeNotif  = 'notif_badge_enabled';

  // ── Notification IDs ─────────────────────────────────────────
  static const int _streakNotifId = 1001;
  static const int _badgeNotifId  = 1002;

  // ── Notification channel ──────────────────────────────────────
  static const _channel = AndroidNotificationChannel(
    'truthlens_channel',
    'TruthLens AI Notifications',
    description: 'Streak reminders and badge progress updates',
    importance:  Importance.high,
  );


  // ── Initialise (call once in main.dart) ───────────────────────
  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
    } catch (_) {}

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
    InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create the notification channel on Android
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }


  // ── Request permission (Android 13+) ─────────────────────────
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }


  // ── Check if notifications are enabled ───────────────────────
  Future<bool> isStreakNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kStreakNotif) ?? true; // Default ON
  }

  Future<bool> isBadgeNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBadgeNotif) ?? true; // Default ON
  }


  // ── Toggle notifications ──────────────────────────────────────
  Future<void> setStreakNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreakNotif, enabled);
    if (enabled) {
      await scheduleStreakReminder();
    } else {
      await _plugin.cancel(_streakNotifId);
    }
  }

  Future<void> setBadgeNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBadgeNotif, enabled);
    if (!enabled) {
      await _plugin.cancel(_badgeNotifId);
    }
  }


  // ── Schedule daily streak reminder at 8:00 PM ─────────────────
  Future<void> scheduleStreakReminder() async {
    final enabled = await isStreakNotifEnabled();
    if (!enabled) return;

    // Cancel existing before rescheduling
    await _plugin.cancel(_streakNotifId);

    // Build 8:00 PM today — if already past 8PM, schedule for tomorrow
    final now   = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year, now.month, now.day,
      20, 0, 0,  // 8:00:00 PM
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _streakNotifId,
      '🔥 Don\'t break your streak!',
      'Scan a face today to keep your streak alive. Every day counts!',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:  Importance.high,
          priority:    Priority.high,
          icon:        '@mipmap/ic_launcher',
          color:       const Color(0xFF4F8EF7),
        ),
      ),
      // Repeat daily at the same time
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }


  // ── Show badge progress notification ─────────────────────────
  // Called when user is within 2 steps of unlocking a badge.
  Future<void> showBadgeProgressNotification({
    required String badgeName,
    required String badgeEmoji,
    required int    stepsLeft,
  }) async {
    final enabled = await isBadgeNotifEnabled();
    if (!enabled) return;

    // stepsLeft == 0 means badge was just earned
    final title = stepsLeft == 0
        ? '🏆 Badge Unlocked!'
        : '🏆 Badge almost unlocked!';

    final body = stepsLeft == 0
        ? 'You just earned the $badgeName badge! $badgeEmoji Keep it up!'
        : '$stepsLeft more scans to unlock the $badgeName badge! $badgeEmoji';

    await _plugin.show(
      _badgeNotifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:  Importance.high,
          priority:    Priority.high,
          icon:        '@mipmap/ic_launcher',
          color:       const Color(0xFFF5A623),
        ),
      ),
    );
  }

  // ── Batch scan complete notification ──────────────────────────
  static const int _batchNotifId = 1003;

  Future<void> showBatchCompleteNotification({
    required int total,
    required int realCount,
    required int fakeCount,
  }) async {
    await _plugin.show(
      _batchNotifId,
      '✅ Batch Scan Complete!',
      'Scanned $total images — $realCount Authentic, '
          '$fakeCount Deepfake${fakeCount > 0 ? ' ⚠️' : ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:  Importance.high,
          priority:    Priority.high,
          icon:        '@mipmap/ic_launcher',
          color:       const Color(0xFF4F8EF7),
        ),
      ),
    );
  }


  // ── Cancel all notifications ──────────────────────────────────
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }


  // ── Handle notification tap ───────────────────────────────────
  void _onNotificationTapped(NotificationResponse response) {
    // Navigation on tap can be added here later if needed
    debugPrint('Notification tapped: ${response.id}');
  }
}