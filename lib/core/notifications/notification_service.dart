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

  static const String _dailyChannelId = 'daily_reminder';
  static const String _dailyChannelName = 'Pengingat Harian';
  static const String _dailyChannelDesc =
      'Reminder buat catat keuangan tiap hari';
  static const String _budgetChannelId = 'budget_alert';
  static const String _budgetChannelName = 'Peringatan Budget';
  static const String _budgetChannelDesc =
      'Alert kalau pengeluaran mendekati/lewat budget';

  /// Drawable monochrome alpha icon (Android 5+ requires this for status bar).
  /// Full-color mipmap akan di-silently-drop sama banyak OEM (Xiaomi/MIUI).
  static const String _androidIconRes = '@drawable/ic_notification';

  final _plugin = FlutterLocalNotificationsPlugin();
  String _detectedTz = 'UTC';
  bool _ready = false;

  String get detectedTimezone => _detectedTz;

  Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
      _detectedTz = localName;
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
        _detectedTz = 'Asia/Jakarta (fallback)';
      } catch (_) {}
      debugPrint('NotificationService: timezone fallback - $e');
    }

    const android = AndroidInitializationSettings(_androidIconRes.substring(1));
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));

    // Create channels eksplisit (jangan tunggu auto-create di first show())
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
        _dailyChannelId,
        _dailyChannelName,
        description: _dailyChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await androidImpl.createNotificationChannel(const AndroidNotificationChannel(
        _budgetChannelId,
        _budgetChannelName,
        description: _budgetChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
    }

    _ready = true;
  }

  /// Request permissions runtime. Return true kalau notif granted.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ butuh POST_NOTIFICATIONS, < 13 granted by default.
      final notifStatus = await Permission.notification.request();
      try {
        await Permission.scheduleExactAlarm.request();
      } catch (_) {}
      // Android < 13: Permission.notification balikin granted otomatis,
      // tapi user mungkin disable lewat settings. Cek juga via plugin.
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidImpl?.areNotificationsEnabled() ?? true;
      return notifStatus.isGranted && enabled;
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

  /// Cek status notif + alarm. Return map debug info.
  Future<Map<String, dynamic>> diagnostics() async {
    final info = <String, dynamic>{
      'timezone': _detectedTz,
      'now_local': tz.TZDateTime.now(tz.local).toString(),
    };
    final pending = await _plugin.pendingNotificationRequests();
    info['pending_count'] = pending.length;
    info['pending_ids'] = pending.map((p) => p.id).toList();

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      info['notifications_enabled'] =
          await androidImpl?.areNotificationsEnabled() ?? false;
      info['exact_alarm'] =
          (await Permission.scheduleExactAlarm.status).isGranted;
      info['post_notification'] =
          (await Permission.notification.status).isGranted;
    }
    return info;
  }

  /// Instant notif (no scheduling). Kalau ini gak muncul = channel diblock OEM.
  Future<void> showInstantTest() async {
    await _plugin.show(
      8888,
      '🔔 Notif Instan',
      'Kalau lu liat ini, notif sistem & channel jalan.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          _dailyChannelName,
          channelDescription: _dailyChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Scheduled test setelah `seconds` detik.
  Future<void> scheduleTestNotification({int seconds = 5}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      9999,
      '🔔 Test Scheduled',
      'Notif ini di-schedule $seconds detik lalu via tz.${_detectedTz}.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          _dailyChannelName,
          channelDescription: _dailyChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
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
          _dailyChannelId,
          _dailyChannelName,
          channelDescription: _dailyChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

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
          _budgetChannelId,
          _budgetChannelName,
          channelDescription: _budgetChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
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
