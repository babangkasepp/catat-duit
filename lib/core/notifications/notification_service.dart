import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    // Init timezone db + set local zone (default tz.local = UTC, harus di-set manual)
    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      // Fallback: pake Asia/Jakarta kalau gagal detect
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {}
      debugPrint('NotificationService: timezone fallback - $e');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));
    _ready = true;
  }

  /// Request runtime permissions: POST_NOTIFICATIONS (Android 13+) + exact alarm (Android 12+).
  /// Return true kalau notif permission granted.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.request();
      // Exact alarm (Android 12+ / API 31+) — best effort, jangan block kalau gagal
      try {
        await Permission.scheduleExactAlarm.request();
      } catch (_) {}
      return notifStatus.isGranted;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  Future<void> scheduleDailyReminder({int hour = 21, int minute = 0}) async {
    await _plugin.cancel(1001);
    await _plugin.zonedSchedule(
      1001,
      'Catat keuangan hari ini yuk',
      'Jangan lupa input pengeluaran biar gak lupa 💰',
      _nextInstanceOf(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Pengingat Harian',
          channelDescription: 'Reminder buat catat keuangan tiap malam',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Test notif setelah `seconds` detik — buat verify notif system jalan
  Future<void> scheduleTestNotification({int seconds = 5}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      9999,
      '🔔 Test Notif CatatDuit',
      'Kalau lu liat ini, notif sistem jalan 🎉',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Pengingat Harian',
          channelDescription: 'Reminder buat catat keuangan tiap malam',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cek list notif yang udah di-schedule (debug)
  Future<List<PendingNotificationRequest>> pendingNotifications() {
    return _plugin.pendingNotificationRequests();
  }

  Future<void> showBudgetAlert(String categoryName, int percent) async {
    await _plugin.show(
      2000 + categoryName.hashCode % 1000,
      'Budget $categoryName udah $percent%',
      percent >= 100
          ? 'Lewat budget bulan ini. Cek laporan buat detailnya.'
          : 'Hampir tembus budget. Hati-hati 👀',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alert',
          'Peringatan Budget',
          channelDescription: 'Alert kalau pengeluaran mendekati/lewat budget',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
