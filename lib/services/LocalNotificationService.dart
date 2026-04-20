import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
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
    // system settings. Try exact first; fall back to inexact on PlatformException
    // so the app doesn't crash - the notification will still fire.
    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Time to snipe! 🏒',
        "Don't forget to train today. Every shot counts!",
        scheduled,
        _details(_practiceChannelId, 'Practice Reminders', importance: Importance.high, priority: Priority.high, badgeNumber: 1),
        androidScheduleMode: Platform.isAndroid ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'train',
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          _dailyReminderId,
          'Time to snipe! 🏒',
          "Don't forget to train today. Every shot counts!",
          scheduled,
          _details(_practiceChannelId, 'Practice Reminders', importance: Importance.high, priority: Priority.high, badgeNumber: 1),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'train',
        );
      } else {
        rethrow;
      }
    }
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  /// On Android 12+, open the system "Alarms & reminders" settings so the
  /// user can grant SCHEDULE_EXACT_ALARM. No-op on iOS / older Android.
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  /// On Android, request that the system exclude this app from battery
  /// optimisation ("Sleeping apps" on Samsung One UI). Without this,
  /// AlarmManager alarms can be deferred or suppressed entirely on devices
  /// with aggressive power management such as the Samsung Galaxy S-series.
  /// No-op on iOS.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    // Sends ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS which opens the system
    // dialog letting the user whitelist this app for unrestricted background
    // operation. Required permission: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
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

    try {
      await _plugin.zonedSchedule(
        _streakAtRiskId,
        '🔥 Don\'t break your streak!',
        '$streakDays-day streak on the line - log a session today to keep it alive!',
        scheduled,
        _details(_streakChannelId, 'Streak Alerts', importance: Importance.high, priority: Priority.high),
        androidScheduleMode: Platform.isAndroid ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'train',
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          _streakAtRiskId,
          '🔥 Don\'t break your streak!',
          '$streakDays-day streak on the line - log a session today to keep it alive!',
          scheduled,
          _details(_streakChannelId, 'Streak Alerts', importance: Importance.high, priority: Priority.high),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'train',
        );
      } else {
        rethrow;
      }
    }
  }

  static Future<void> cancelStreakAtRisk() async {
    await _plugin.cancel(_streakAtRiskId);
  }

  // ── 3. Active shooting session (persistent, updated live) ─────────────────

  /// Stores the latest shot count so [tickActiveSession] can update the
  /// notification every second without needing the caller to pass it again.
  static int _activeSessionShotCount = 0;

  /// Show (or update) a persistent notification while a shooting session is
  /// active. Call this when the session starts and whenever the shot count
  /// changes. The notification is dismissed by [cancelActiveSession].
  static Future<void> showActiveSession({
    required int shotCount,
    required Duration duration,
  }) async {
    _activeSessionShotCount = shotCount;
    await _postActiveSession(shotCount: shotCount, duration: duration);
  }

  /// Called every second by the session timer so the elapsed-time display
  /// stays current. Uses the shot count last set by [showActiveSession].
  static Future<void> tickActiveSession(Duration duration) async {
    await _postActiveSession(shotCount: _activeSessionShotCount, duration: duration);
  }

  static Future<void> _postActiveSession({
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
      '🏒 Session in progress',
      '$shotCount shots • $durationStr • Tap to return',
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
    _activeSessionShotCount = 0;
    await _plugin.cancel(_activeSessionId);
  }

  // ── 4. Achievement unlocked (in-app only) ───────────────────────────────
  //
  // Achievements only unlock during an active session, so the user is already
  // looking at the app. Return a record with the display data instead of
  // posting a system notification - the caller shows an in-app banner/dialog.

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
