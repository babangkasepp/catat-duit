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
      await NotificationService.instance.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
    } else {
      await NotificationService.instance.cancelAll();
    }
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
          const ListTile(
            title: Text('CatatDuit'),
            subtitle: Text('v0.1.0 — Offline-first finance tracker'),
            leading: Icon(Icons.info_outline),
          ),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Privasi'),
            subtitle: Text('Data lu cuma disimpan di HP. Gak ada cloud, gak ada login.'),
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
            color: theme.colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    );
  }
}
