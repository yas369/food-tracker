import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platecheck/main.dart';
import 'package:platecheck/models.dart';
import 'package:platecheck/services/steps.dart';
import 'package:platecheck/store.dart';

import 'fakes.dart';

/// A phone's step sensor we can drive: permission answers, readings, restarts.
class DrivenSteps extends StepSensor {
  PermissionStatus status = PermissionStatus.denied;
  StreamController<int>? stream;
  int starts = 0;
  int settingsOpened = 0;

  @override
  bool get supported => true;
  @override
  Future<PermissionStatus> permissionStatus() async => status;
  @override
  Future<PermissionStatus> askPermission() async => status;
  @override
  Stream<int> readings() {
    starts++;
    stream = StreamController<int>();
    return stream!.stream;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
  @override
  Future<int> bootTime() async => DateTime(2026, 9, 20).millisecondsSinceEpoch; // phone started days ago
}

Future<(AppStore, DrivenSteps)> open(WidgetTester tester, PermissionStatus status) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final d = AppData(profile: Profile(age: 32, sex: 'm', height: 172, weight: 82, activity: 1.375, plan: 'low'));
  d.me
    ..name = 'Yaswanth C'
    ..onboarded = true;
  d.move
    ..on = true
    ..credit = true;
  final steps = DrivenSteps()..status = status;
  final store = AppStore(storage: MemoryStorage(jsonEncode(d.toJson())), notifications: FakeNotifications(), steps: steps, clock: () => DateTime(2026, 9, 26, 13, 10));
  await tester.pumpWidget(PlateCheckApp(store: store));
  await store.init();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Move'));
  await tester.pumpAndSettle();
  return (store, steps);
}

Future<void> reading(WidgetTester tester, DrivenSteps s, int count) async {
  s.stream!.add(count);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> comeBack(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('allowing the permission in Android settings starts counting when you come back', (tester) async {
    final (store, s) = await open(tester, PermissionStatus.denied);
    expect(find.textContaining('needs the “Physical activity” permission'), findsOneWidget);
    expect(s.starts, 0);

    s.status = PermissionStatus.granted; // allowed in Android settings
    await comeBack(tester);
    expect(s.starts, 1, reason: 'listening starts without restarting the app');
    expect(find.textContaining('Waiting for your phone’s step sensor'), findsOneWidget);

    await reading(tester, s, 5000); // first reading: the starting point
    await reading(tester, s, 5250);
    expect(store.c.stepsOn('2026-09-26'), 250);
    expect(find.text('250'), findsOneWidget, reason: 'the ring shows the new count');
    expect(find.textContaining('Waiting for'), findsNothing);
  });

  testWidgets('if the sensor stream stops, coming back starts it again', (tester) async {
    final (store, s) = await open(tester, PermissionStatus.granted);
    await reading(tester, s, 100);
    await reading(tester, s, 160);
    await s.stream!.close();
    await tester.pumpAndSettle();
    expect(s.listening, isFalse);

    await comeBack(tester);
    expect(s.starts, 2);
    await reading(tester, s, 400); // steps taken while it was stopped still count
    expect(store.c.stepsOn('2026-09-26'), 300);
  });

  testWidgets('a blocked permission sends you to Android settings', (tester) async {
    final (_, s) = await open(tester, PermissionStatus.permanentlyDenied);
    expect(find.textContaining('Step counting is blocked'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(s.settingsOpened, 1);
  });

  testWidgets('a phone without a step sensor says so', (tester) async {
    final (_, s) = await open(tester, PermissionStatus.granted);
    s.stream!.addError(Exception('StepCount not available'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This phone has no step sensor'), findsOneWidget);
  });
}
