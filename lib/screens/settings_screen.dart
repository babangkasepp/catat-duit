import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _reminderOn = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  int _versionTaps = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _reminderOn = p.getBool('reminder_on') ?? false;
      final h = p.getInt('reminder_hour') ?? 21;
      final m = p.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: h, minute: m);
    });
  }

  Future<void> _saveReminder() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('reminder_on', _reminderOn);
    await p.setInt('reminder_hour', _reminderTime.hour);
    await p.setInt('reminder_minute', _reminderTime.minute);

    if (_reminderOn) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted && mounted) {
        _showPermissionSheet();
        setState(() => _reminderOn = false);
        await p.setBool('reminder_on', false);
        return;
      }
      await NotificationService.instance.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Reminder aktif tiap ${_reminderTime.format(context)}'),
          ),
        );
      }
    } else {
      await NotificationService.instance.cancelAll();
    }
  }

  void _showPermissionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Notif belum di-allow',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Buka pengaturan notifikasi HP buat enable.\n\nUntuk Xiaomi/MIUI: aktifkan juga "Autostart" dan set "Battery saver" jadi "No restrictions".',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              AppSettings.openAppSettings(type: AppSettingsType.notification);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.settings),
            label: const Text('Buka Setting Notif'),
          ),
        ]),
      ),
    );
  }

  // Hidden debug menu — 7-tap on version row.
  Future<void> _onVersionTap() async {
    _versionTaps++;
    if (_versionTaps < 7) return;
    _versionTaps = 0;
    final info = await NotificationService.instance.diagnostics();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Diagnostic'),
        content: SingleChildScrollView(
          child: Text(
            info.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await NotificationService.instance.showInstantTest();
            },
            child: const Text('Test notif'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Setelan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        children: [
          _section(theme, 'Pengingat'),
          SwitchListTile(
            title: const Text('Reminder catat harian'),
            subtitle: Text('Tiap ${_reminderTime.format(context)}'),
            value: _reminderOn,
            onChanged: (v) async {
              setState(() => _reminderOn = v);
              await _saveReminder();
            },
          ),
          ListTile(
            title: const Text('Jam pengingat'),
            trailing: Text(_reminderTime.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                  context: context, initialTime: _reminderTime);
              if (picked != null) {
                setState(() => _reminderTime = picked);
                await _saveReminder();
              }
            },
          ),
          const Divider(height: 32),
          _section(theme, 'Tentang'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('CatatDuit'),
            subtitle: const Text('v0.2.1 — Offline-first finance tracker'),
            onTap: _onVersionTap,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notifikasi gak muncul?'),
            subtitle: const Text(
                'Buka setelan HP & enable. Khusus MIUI: Autostart ON + Battery saver "No restrictions".'),
            onTap: () => AppSettings.openAppSettings(
                type: AppSettingsType.notification),
          ),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Privasi'),
            subtitle: Text(
                'Data lu cuma disimpan di HP. Gak ada cloud, gak ada login.'),
          ),
          const ListTile(
            leading: Icon(Icons.handshake_outlined),
            title: Text('Buat Indonesia 🇮🇩'),
            subtitle: Text('Kategori & bahasa lokal first-class.'),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1),
      ),
    );
  }
}
