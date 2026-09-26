// Scheduled reminders, using the phone's alarm system so they arrive with the
// app closed and survive a restart.

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../reminders.dart';

class Notifications {
  final _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called with the meal when a reminder is tapped ('' for "just open").
  void Function(String payload)? onTap;
  String? launchPayload;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('meals', 'Meal reminders',
        channelDescription: 'Meal-time and kitchen-closed reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_plate',
        color: Color(0xFF5B1BAA)),
  );

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    await _p.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_plate')),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload ?? ''),
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel('meals', 'Meal reminders',
        description: 'Meal-time and kitchen-closed reminders', importance: Importance.high));
    final launch = await _p.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) launchPayload = launch!.notificationResponse?.payload ?? '';
    _ready = true;
  }

  Future<bool> get allowed async => kIsWeb ? false : (await _android?.areNotificationsEnabled()) ?? false;
  Future<bool> get exactAllowed async => kIsWeb ? false : (await _android?.canScheduleExactNotifications()) ?? true;
  Future<bool> request() async => kIsWeb ? false : (await _android?.requestNotificationsPermission()) ?? false;
  Future<void> requestExact() async => _android?.requestExactAlarmsPermission();

  /// Replace every scheduled reminder with [list]. Without the exact-alarm
  /// permission they're scheduled inexact rather than prompting every time.
  Future<int> replaceAll(List<PlannedReminder> list) async {
    if (!_ready) return 0;
    for (final p in await _p.pendingNotificationRequests()) {
      if (p.id != idWait && p.id != idTest) await _p.cancel(id: p.id);
    }
    if (!await allowed) return 0;
    final exact = await exactAllowed;
    var n = 0;
    for (final r in list) {
      await _p.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('meals', 'Meal reminders',
              channelDescription: 'Meal-time and kitchen-closed reminders',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_plate',
              color: const Color(0xFF5B1BAA),
              styleInformation: BigTextStyleInformation(r.body)),
        ),
        androidScheduleMode: exact && r.exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.meal ?? '',
      );
      if (r.id != idStale) n++;
    }
    return n;
  }

  Future<void> showNow(int id, String title, String body, {String payload = ''}) async {
    if (!_ready) return;
    await _p.show(id: id, title: title, body: body, notificationDetails: _details, payload: payload);
  }

  Future<void> scheduleOnce(int id, String title, String body, DateTime at, {String payload = ''}) async {
    if (!_ready || !await allowed) return;
    await _p.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: await exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }
}
