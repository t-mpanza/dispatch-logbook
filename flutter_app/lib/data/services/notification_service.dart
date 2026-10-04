import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Smart in-app reminder system.
///
/// Reminders are stored locally (SQLite) and mirrored to the OS notification
/// scheduler so they fire even when the app is closed. All pending reminders
/// are re-registered on every cold start, so scheduling survives reboots and
/// app updates.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'dispatch_reminders';
  static const String _channelName = 'Dispatch Reminders';
  static const String _channelDescription =
      'Reminders you set inside Dispatch Diary';

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Request notification permission (Android 13+ runtime permission and iOS
  /// alert/sound permissions). Safe to call repeatedly.
  static Future<bool> requestPermissions() async {
    await ensureInitialized();
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      if (granted == false) return false;

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
      >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return true;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Deterministic notification id for a reminder id string.
  static int _notificationId(Reminder r) =>
      (r.id.hashCode & 0x7FFFFFFF);

  /// Schedule (or replace) the OS notification for [reminder].
  static Future<void> scheduleReminder(Reminder reminder) async {
    await ensureInitialized();
    if (reminder.done) {
      await cancelReminder(reminder.id);
      return;
    }

    final when = DateTime.fromMillisecondsSinceEpoch(reminder.at);
    if (!when.isAfter(DateTime.now())) return; // expired — nothing to fire

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _notificationId(reminder),
      'Reminder',
      reminder.text,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Remove the OS notification for a reminder id.
  static Future<void> cancelReminder(String reminderId) async {
    await ensureInitialized();
    // Hash again through a synthetic reminder to reuse the id derivation.
    final id = (reminderId.hashCode & 0x7FFFFFFF);
    await _plugin.cancel(id);
  }

  /// Re-register every pending future reminder (call on app start).
  static Future<void> rescheduleAll(List<Reminder> reminders) async {
    await ensureInitialized();
    for (final r in reminders) {
      await scheduleReminder(r);
    }
  }
}
