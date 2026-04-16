import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages all on-device (local) notifications.
///
/// Call [initialize] once from [main] before [runApp].
/// All other methods are safe to call from any widget or service.
class LocalNotificationService {
  LocalNotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static GoRouter? _router;

  /// Call this once after [createAppRouter] so that notification taps can
  /// navigate without a [BuildContext].
  static void setRouter(GoRouter router) => _router = router;

  // ── Channel IDs ──────────────────────────────────────────────────────────
  static const _practiceChannelId = 'practice_reminders';
  static const _streakChannelId = 'streak_alerts';
  static const _motivationChannelId = 'motivation';
  static const _achievementChannelId = 'achievements';
  static const _activeSessionChannelId = 'active_session';

  // ── Fixed notification IDs so repeating ones can be cancelled ────────────
  static const int _dailyReminderId = 1;
  static const int _streakAtRiskId = 2;
  static const int _weeklyProgressId = 3;
  static const int _activeSessionId = 10;
  // Immediate notifications use base + (counter % 50) so they don't stomp each other
  static const int _milestoneBase = 300;

  // ── Initialisation ───────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Set up timezone database.
    tz.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      // Permissions are already requested via firebase_messaging at startup.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onTapped,
    );

    // Create Android notification channels.
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _practiceChannelId,
        'Practice Reminders',
        description: 'Daily practice reminder notifications',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _streakChannelId,
        'Streak Alerts',
        description: 'Streak-at-risk notifications',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _motivationChannelId,
        'Motivation',
        description: 'Session complete and weekly progress notifications',
        importance: Importance.defaultImportance,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _achievementChannelId,
        'Achievements',
        description: 'Achievement and milestone notifications',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _activeSessionChannelId,
        'Active Session',
        description: 'Live status of your current shooting session',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ));
    }

    _initialized = true;
  }

  static void _onTapped(NotificationResponse response) {
    final router = _router;
    if (router == null) return;

    switch (response.payload) {
      case 'history':
        router.go('/history');
      case 'achievements':
        router.go('/profile/achievements');
      case 'session':
        router.go('/app?tab=train');
      case 'train':
      default:
        router.go('/app?tab=train');
    }
  }

  // ── Helper: build NotificationDetails ────────────────────────────────────

  static NotificationDetails _details(
    String channelId,
    String channelName, {
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    int? badgeNumber,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default',
        badgeNumber: badgeNumber,
      ),
    );
  }

  // ── 1. Daily practice reminder (scheduled, repeating) ────────────────────

  /// Schedule (or reschedule) the daily local practice reminder.
  /// [hour] and [minute] are in 24-hour local time.
  /// Cancels any previously scheduled reminder first.
  static Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    await _plugin.cancel(_dailyReminderId);

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('local_practice_reminders') ?? true)) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    // On Android 12+, SCHEDULE_EXACT_ALARM requires the user to grant it via
    // system settings. Fall back to inexact scheduling when not permitted so the
    // app doesn't crash — the notification will still fire, just within a short
    // delivery window rather than at the exact second.
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactAlarms() ?? false;
      if (canExact) scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Time to hit the ice! 🏒',
      "Don't forget to log your shots today. Every rep counts!",
      scheduled,
      _details(_practiceChannelId, 'Practice Reminders', importance: Importance.high, priority: Priority.high, badgeNumber: 1),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time, // repeat at same time every day
      payload: 'train',
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  // ── 2. Streak-at-risk (scheduled once for 6 PM today) ───────────────────

  /// Schedule a 6 PM streak-alert if the user has a streak ≥ 2 and hasn't
  /// practiced today.  Cancels any existing streak alert first.
  static Future<void> scheduleStreakAtRisk({required int streakDays}) async {
    await _plugin.cancel(_streakAtRiskId);
    if (streakDays < 2) return;

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('streak_notifications') ?? true)) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 0);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _streakAtRiskId,
      '🔥 Don\'t break your streak!',
      '$streakDays-day streak on the line — log a session today to keep it alive!',
      scheduled,
      _details(_streakChannelId, 'Streak Alerts', importance: Importance.high, priority: Priority.high),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'train',
    );
  }

  static Future<void> cancelStreakAtRisk() async {
    await _plugin.cancel(_streakAtRiskId);
  }

  // ── 3. Active shooting session (persistent, updated live) ─────────────────

  /// Show (or update) a persistent notification while a shooting session is
  /// active. Call this when the session starts and whenever the shot count
  /// or duration changes. The notification is dismissed by [cancelActiveSession].
  static Future<void> showActiveSession({
    required int shotCount,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('active_session_notification') ?? true)) return;

    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final durationStr = '${minutes}m ${seconds}s';

    await _plugin.show(
      _activeSessionId,
      '🏒 Session in progress — $shotCount shots',
      'Duration: $durationStr • Tap to return to your session',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _activeSessionChannelId,
          'Active Session',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/launcher_icon',
          playSound: false,
          enableVibration: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'session',
    );
  }

  static Future<void> cancelActiveSession() async {
    await _plugin.cancel(_activeSessionId);
  }

  // ── 4. Achievement unlocked (in-app only) ───────────────────────────────
  //
  // Achievements only unlock during an active session, so the user is already
  // looking at the app. Return a record with the display data instead of
  // posting a system notification — the caller shows an in-app banner/dialog.

  static ({String title, String body}) buildAchievementUnlockedMessage({
    required String achievementName,
    bool isPro = false,
  }) {
    return (
      title: 'Achievement Unlocked! 🏆',
      body: isPro ? 'You earned: $achievementName. Check your profile to see all badges.' : 'You earned: $achievementName!',
    );
  }

  // ── 5. Milestone reached (immediate) ─────────────────────────────────────

  static Future<void> showMilestoneReached({
    required int totalShots,
    bool isPro = false,
  }) async {
    await _plugin.show(
      _milestoneBase + (totalShots ~/ 1000),
      'Milestone Reached! 🎖️',
      isPro ? '$totalShots shots! You\'re closing in on 10,000. Check your profile for full progress.' : '$totalShots shots logged! Keep pushing toward 10,000!',
      _details(_achievementChannelId, 'Achievements', importance: Importance.high, priority: Priority.high),
      payload: 'achievements',
    );
  }

  // ── 6. Weekly wrap-up (Pro only, Friday 6 PM, repeating) ─────────────────

  static Future<void> scheduleWeeklyProgress() async {
    await _plugin.cancel(_weeklyProgressId);

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('weekly_progress_notifications') ?? true)) return;

    final now = tz.TZDateTime.now(tz.local);
    int daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    if (daysUntilFriday == 0 && now.hour >= 18) daysUntilFriday = 7;

    final scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day + daysUntilFriday, 18, 0);

    await _plugin.zonedSchedule(
      _weeklyProgressId,
      'Weekly Wrap-Up 📊',
      'Check how many shots you logged this week. Are you on track for your goal?',
      scheduled,
      _details(_motivationChannelId, 'Motivation'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'history',
    );
  }

  static Future<void> cancelWeeklyProgress() async {
    await _plugin.cancel(_weeklyProgressId);
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  static Future<void> cancelAll() async => _plugin.cancelAll();

  // ── Foreground FCM helper ─────────────────────────────────────────────────

  /// Display an FCM notification that arrived while the app is in the foreground.
  static Future<void> showForegroundMessage({
    required int id,
    required String title,
    String? body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _details(_motivationChannelId, 'Motivation'),
      payload: 'train',
    );
  }
}
