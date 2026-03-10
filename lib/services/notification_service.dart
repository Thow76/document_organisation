import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/document.dart';
import '../models/reminder.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'docsafe_reminders';
  static const String _channelName = 'Document Reminders';
  static const String _channelDescription =
      'Reminders for actionable dates in your documents';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  /// Initialises the notifications plugin, timezone database, and requests
  /// notification permissions on Android 13+.
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await Permission.notification.request();
  }

  /// Schedules a local notification for [reminder] at 9:00 AM on
  /// (actionableDate − notifyDaysBefore). Skips silently if that date is in
  /// the past.
  Future<void> scheduleReminder(Reminder reminder, String documentTitle) async {
    final notifyDate = reminder.actionableDate.subtract(
      Duration(days: reminder.notifyDaysBefore),
    );

    final now = DateTime.now();
    if (notifyDate.isBefore(now)) return;

    final scheduledDate = tz.TZDateTime(
      tz.local,
      notifyDate.year,
      notifyDate.month,
      notifyDate.day,
      9, // 9:00 AM
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      _reminderNotificationId(reminder.id),
      'DocSafe Reminder',
      '$documentTitle — ${reminder.contextReason}',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancels the scheduled notification for [reminderId].
  Future<void> cancelReminder(String reminderId) async {
    await _plugin.cancel(_reminderNotificationId(reminderId));
  }

  /// Cancels the existing notification for [reminder] then schedules a new one.
  Future<void> rescheduleReminder(
    Reminder reminder,
    String documentTitle,
  ) async {
    await cancelReminder(reminder.id);
    await scheduleReminder(reminder, documentTitle);
  }

  /// Cancels all existing notifications and re-schedules every active
  /// (non-completed) reminder. Call this on app startup.
  Future<void> rescheduleAllReminders(
    List<Reminder> reminders,
    List<Document> documents,
  ) async {
    await _plugin.cancelAll();

    final docMap = {for (final d in documents) d.id: d};

    for (final reminder in reminders) {
      if (reminder.isCompleted) continue;
      final doc = docMap[reminder.documentId];
      if (doc == null) continue;
      await scheduleReminder(reminder, doc.title);
    }
  }

  /// Converts a reminder UUID string to a stable non-negative int suitable
  /// for use as a notification ID.
  int _reminderNotificationId(String reminderId) =>
      reminderId.hashCode.abs() % 2147483647;
}
