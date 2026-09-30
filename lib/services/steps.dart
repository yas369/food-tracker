// The phone's step counter: steps since the phone last started. The app keeps
// the last reading and works out steps per day from the differences.
//
// While the app is open it listens directly. While it's closed, an Android
// foreground service (StepService.kt) keeps listening and queues readings,
// which the app takes in when it opens again.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepSensor {
  StreamSubscription<int>? _sub;
  bool available = true;
  bool granted = false;

  /// Android stops showing the permission dialog after it's been refused
  /// twice; then only the app's page in Android settings can allow it.
  bool blocked = false;

  /// When the sensor last reported, this session. Null: nothing yet.
  DateTime? lastReading;
  String error = '';

  /// Told when something the screen shows changes outside a reading (an
  /// error, the stream ending).
  VoidCallback? onChange;

  /// Whether Android's battery saving leaves the app alone. If not, some
  /// phones stop background counting anyway.
  bool batteryExempt = true;

  static const _channel = MethodChannel('platecheck/steps');

  /// The time readings are stamped with (the app's clock, so tests can fix it).
  DateTime Function() clock = DateTime.now;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get listening => _sub != null;

  @protected
  Future<PermissionStatus> permissionStatus() => Permission.activityRecognition.status;
  @protected
  Future<PermissionStatus> askPermission() => Permission.activityRecognition.request();
  @protected
  Stream<int> readings() => Pedometer.stepCountStream.map((s) => s.steps);

  Future<void> openSettings() => openAppSettings();

  /// Calls into the Android side (MainActivity.kt). Null if it isn't there.
  @protected
  Future<Object?> native(String method) async {
    try {
      return await _channel.invokeMethod<Object?>(method);
    } catch (_) {
      return null;
    }
  }

  /// Keep counting with the app closed (shows a small notification).
  Future<void> startBackground() async {
    if (supported && granted) await native('start');
  }

  Future<void> stopBackground() async {
    if (supported) await native('stop');
  }

  /// Readings taken while the app was closed, oldest first: (count, boot, at).
  Future<List<(double, int, int)>> takeBackgroundReadings() async {
    if (!supported) return const [];
    final raw = await native('drain');
    return [
      if (raw is List)
        for (final r in raw)
          if (r is List && r.length == 3 && r.every((x) => x is num)) ((r[0] as num).toDouble(), (r[1] as num).toInt(), (r[2] as num).toInt()),
    ];
  }

  Future<void> checkBattery() async {
    if (!supported) return;
    batteryExempt = await native('batteryExempt') != false;
  }

  Future<void> askBatteryExempt() => native('askBatteryExempt');

  Future<void> checkPermission() async {
    if (!supported) return;
    _status(await permissionStatus());
  }

  /// Ask for the permission. If Android won't ask any more, open the app's
  /// settings page instead; coming back to the app checks again.
  Future<void> requestPermission() async {
    if (!supported) return;
    _status(await askPermission());
    if (!granted && blocked) await openSettings();
  }

  void _status(PermissionStatus s) {
    granted = s.isGranted;
    blocked = s.isPermanentlyDenied;
  }

  /// When the phone last started, so a restart (which resets the counter) can
  /// be told apart from a normal reading. Android's clock first; /proc/uptime
  /// if that isn't available.
  Future<int> bootTime() async {
    final b = await native('bootTime');
    if (b is int && b > 0) return b;
    try {
      final up = double.parse((await File('/proc/uptime').readAsString()).split(' ').first);
      return DateTime.now().millisecondsSinceEpoch - (up * 1000).round();
    } catch (_) {
      return 0;
    }
  }

  /// Keep listening while the app is alive: on some phones the counter only
  /// keeps counting while someone listens. Safe to call again: it does nothing
  /// while listening, and starts over if the stream ended.
  void start(void Function(double steps, int boot, int at) onReading) {
    if (!supported || !granted || _sub != null) return;
    _sub = readings().listen(
      (steps) async {
        error = '';
        available = true;
        lastReading = clock();
        onReading(steps.toDouble(), await bootTime(), clock().millisecondsSinceEpoch);
      },
      onError: (Object e) {
        error = '$e';
        if (error.toLowerCase().contains('not available')) {
          available = false;
          stop();
        }
        onChange?.call();
      },
      onDone: () {
        _sub = null;
        onChange?.call();
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
