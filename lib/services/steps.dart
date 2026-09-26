// The phone's step counter: steps since the phone last started. The app keeps
// the last reading and works out steps per day from the differences.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepSensor {
  StreamSubscription<StepCount>? _sub;
  bool available = true;
  bool granted = false;
  String error = '';

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> checkPermission() async {
    if (!supported) return;
    granted = await Permission.activityRecognition.isGranted;
  }

  Future<void> requestPermission() async {
    if (!supported) return;
    granted = (await Permission.activityRecognition.request()).isGranted;
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
  /// keeps counting while someone listens.
  void start(void Function(double steps, int boot, int at) onReading) {
    if (!supported || !granted || _sub != null) return;
    _sub = Pedometer.stepCountStream.listen((s) async {
      error = '';
      available = true;
      onReading(s.steps.toDouble(), await bootTime(), s.timeStamp.millisecondsSinceEpoch);
    }, onError: (Object e) {
      error = '$e';
      if (error.toLowerCase().contains('not available')) available = false;
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
