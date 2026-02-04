import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications helper.
///
/// Design goals:
/// - Safe to reference anywhere (no side effects until you call initialize)
/// - Best-effort: failures are caught to avoid crashing the app
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  int _idForKey(String key) {
    // Stable positive int.
    return key.hashCode & 0x7fffffff;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const init = InitializationSettings(android: androidInit);

      await _plugin.initialize(init);
      _initialized = true;
    } catch (e) {
      // Keep best-effort; don't crash.
      if (kDebugMode) {
        // ignore: avoid_print
        print('Notification init failed: $e');
      }
    }
  }

  Future<void> requestPermissions() async {
    try {
      await ensureInitialized();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {
      // ignore
    }
  }

  Future<void> schedulePausedMissionReminder({
    required String sessionId,
    required String title,
    required Duration after,
  }) async {
    try {
      await ensureInitialized();
      if (!_initialized) return;

      final id = _idForKey('paused:$sessionId');
      final when = tz.TZDateTime.now(tz.local).add(after);

      final androidDetails = AndroidNotificationDetails(
        'paused_mission',
        'Paused mission reminders',
        channelDescription: 'Reminders to resume a paused mission',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      await _plugin.zonedSchedule(
        id,
        'Mission paused',
        'Resume: $title',
        when,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancelPausedMissionReminder(String sessionId) async {
    try {
      await ensureInitialized();
      if (!_initialized) return;
      await _plugin.cancel(_idForKey('paused:$sessionId'));
    } catch (_) {
      // ignore
    }
  }

  Future<void> scheduleDueDateReminder({
    required String questId,
    required String title,
    required DateTime dueDate,
    required int hour,
  }) async {
    try {
      await ensureInitialized();
      if (!_initialized) return;

      final safeHour = hour.clamp(0, 23);
      final scheduleAt = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day,
        safeHour,
        0,
      );

      // If the scheduled time is already in the past, don't schedule.
      if (scheduleAt.isBefore(tz.TZDateTime.now(tz.local))) return;

      final id = _idForKey('due:$questId');

      final androidDetails = AndroidNotificationDetails(
        'due_date',
        'Due date reminders',
        channelDescription: 'Reminders for mission due dates',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      await _plugin.zonedSchedule(
        id,
        'Mission due',
        title,
        scheduleAt,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancelDueDateReminder(String questId) async {
    try {
      await ensureInitialized();
      if (!_initialized) return;
      await _plugin.cancel(_idForKey('due:$questId'));
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancelAll() async {
    try {
      await ensureInitialized();
      if (!_initialized) return;
      await _plugin.cancelAll();
    } catch (_) {
      // ignore
    }
  }

  Future<void> scheduleEventReminder({
    required String eventId,
    required String title,
    required DateTime startAt,
    required bool allDay,
    required int hourIfAllDay,
    required int minutesBefore,
  }) async {
    try {
      await ensureInitialized();
      if (!_initialized) return;

      final id = _idForKey('event:$eventId');

      tz.TZDateTime when;
      if (allDay) {
        when = tz.TZDateTime(
          tz.local,
          startAt.year,
          startAt.month,
          startAt.day,
          hourIfAllDay.clamp(0, 23),
          0,
        );
      } else {
        when = tz.TZDateTime.from(startAt, tz.local);
      }

      final before = Duration(minutes: minutesBefore.clamp(0, 24 * 60));
      when = when.subtract(before);

      if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

      final androidDetails = AndroidNotificationDetails(
        'calendar_events',
        'Calendar event reminders',
        channelDescription: 'Reminders for your calendar events',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      await _plugin.zonedSchedule(
        id,
        'Event reminder',
        title,
        when,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    try {
      await ensureInitialized();
      if (!_initialized) return;
      await _plugin.cancel(_idForKey('event:$eventId'));
    } catch (_) {
      // ignore
    }
  }

  /// Helper used by UI to create consistent durations.
  Duration pausedReminderDelayMinutes(int minutes) {
    return Duration(minutes: max(1, minutes));
  }
}
