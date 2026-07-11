// Native side of task reminders, used only by the APK shell (main_shell.dart).
// The web app posts JSON messages to the `Notifier` JavaScript channel; here we
// turn them into scheduled OS notifications via flutter_local_notifications.
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ShellNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _channelId = 'task_reminders';
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // fall back to UTC if the platform timezone can't be resolved
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Task reminders',
          description: 'Reminders for your tasks',
          importance: Importance.high,
        ));
    _ready = true;
  }

  /// Handle one JSON message from the web app's `Notifier` channel.
  static Future<void> handleMessage(String raw) async {
    await init();
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['action']) {
      case 'requestPermission':
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        break;
      case 'cancelAll':
        await _plugin.cancelAll();
        break;
      case 'cancel':
        await _plugin.cancel(id: (msg['id'] as num).toInt());
        break;
      case 'schedule':
        await _schedule(msg);
        break;
    }
  }

  static Future<void> _schedule(Map<String, dynamic> msg) async {
    final id = (msg['id'] as num).toInt();
    final epochMs = (msg['epochMs'] as num).toInt();
    final when = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, epochMs);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return; // don't schedule past
    await _plugin.zonedSchedule(
      id: id,
      title: (msg['title'] as String?) ?? 'Reminder',
      body: (msg['body'] as String?) ?? '',
      scheduledDate: when,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Task reminders',
          channelDescription: 'Reminders for your tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
