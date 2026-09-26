// The phone's step counter: steps since the phone last started. The app keeps
// the last reading and works out steps per day from the differences.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get listening => _sub != null;

  @protected
  Future<PermissionStatus> permissionStatus() => Permission.activityRecognition.status;
  @protected
  Future<PermissionStatus> askPermission() => Permission.activityRecognition.request();
  @protected
  Stream<int> readings() => Pedometer.stepCountStream.map((s) => s.steps);

  Future<void> openSettings() => openAppSettings();

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

  /// When the phone last started, from /proc/uptime, so a restart (which
  /// resets the counter) can be told apart from a normal reading.
  Future<int> bootTime() async {
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
        lastReading = DateTime.now();
        onReading(steps.toDouble(), await bootTime(), DateTime.now().millisecondsSinceEpoch);
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
