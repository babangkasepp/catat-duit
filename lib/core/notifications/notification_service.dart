import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));
    _ready = true;
  }

  Future<void> scheduleDailyReminder({int hour = 21, int minute = 0}) async {
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
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
