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
  Future<int> bootTime() async => boot;

  // The Android side: the background service's queue and battery settings.
  static final boot = DateTime(2026, 9, 20).millisecondsSinceEpoch; // phone started days ago
  final queue = <List<num>>[];
  bool backgroundOn = false;
  bool exempt = true;
  int askedExempt = 0;

  @override
  Future<Object?> native(String method) async {
    switch (method) {
      case 'start':
        backgroundOn = true;
      case 'stop':
        backgroundOn = false;
      case 'drain':
        final out = [...queue];
        queue.clear();
        return out;
      case 'batteryExempt':
        return exempt;
      case 'askBatteryExempt':
        askedExempt++;
    }
    return null;
  }

  /// A reading the background service took at [at] while the app was closed.
  void counted(double count, DateTime at) => queue.add([count, boot, at.millisecondsSinceEpoch]);
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

/// Close the app (to the background) the way Android does, step by step.
void leave(WidgetTester tester) {
  for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(st);
  }
}

void returnTo(WidgetTester tester) {
  for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(st);
  }
}

Future<void> comeBack(WidgetTester tester) async {
  leave(tester);
  returnTo(tester);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Scroll the screen's list until [f] is built and on screen.
Future<void> reach(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> openStridePage(WidgetTester tester) async {
  await reach(tester, find.text('Settings'));
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  await reach(tester, find.text('Measure'));
  await tester.tap(find.text('Measure'));
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

  testWidgets('measure your stride: the phone counts the steps of a known walk', (tester) async {
    final (store, s) = await open(tester, PermissionStatus.granted);
    await reading(tester, s, 1000);
    await openStridePage(tester);
    expect(find.text('Measure your stride'), findsOneWidget);

    await tester.tap(find.text('Start counting'));
    await tester.pumpAndSettle();
    await reading(tester, s, 1070);
    expect(find.text('70'), findsOneWidget, reason: 'the count moves as you walk');
    await reading(tester, s, 1140);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await reading(tester, s, 1150); // steps after Stop don't count
    await reach(tester, find.textContaining('Your stride: 71 cm a step'));

    await reach(tester, find.text('Save my stride'));
    await tester.tap(find.text('Save my stride'));
    await tester.pumpAndSettle();
    expect(store.d.move.stride, closeTo(71.43, .01));
    expect(store.c.strideMeasured, isTrue);
    await reach(tester, find.textContaining('71 cm · measured'));
  });

  testWidgets('measure your stride by typing in steps you counted', (tester) async {
    final (store, _) = await open(tester, PermissionStatus.denied);
    await openStridePage(tester);
    expect(find.text('Start counting'), findsNothing, reason: 'no sensor access, so counting is by hand');
    await tester.enterText(find.widgetWithText(TextField, 'Distance'), '400');
    await tester.enterText(find.widgetWithText(TextField, 'Steps'), '100');
    await tester.pumpAndSettle();
    await reach(tester, find.textContaining('doesn’t look right')); // 4 m a step
    await tester.enterText(find.widgetWithText(TextField, 'Steps'), '520');
    await tester.pumpAndSettle();
    await reach(tester, find.textContaining('Your stride: 77 cm a step'));
    await reach(tester, find.text('Save my stride'));
    await tester.tap(find.text('Save my stride'));
    await tester.pumpAndSettle();
    expect(store.d.move.stride, closeTo(76.92, .01));
  });

  testWidgets('a walk with the app closed is all counted when you open it again', (tester) async {
    final (store, s) = await open(tester, PermissionStatus.granted);
    expect(s.backgroundOn, isTrue, reason: 'counting carries on after the app closes');
    await reading(tester, s, 5000); // 13:10, the app is open

    // The app closes; the walk is 6 km, about 8,200 steps, counted by the service.
    leave(tester);
    for (var m = 1; m <= 60; m++) {
      s.counted(5000 + 8200 * m / 60, DateTime(2026, 9, 26, 13, 20).add(Duration(minutes: m)));
    }
    returnTo(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(store.c.stepsOn('2026-09-26'), closeTo(8200, 1));
    expect(find.text('8,200'), findsOneWidget);
    expect(s.queue, isEmpty, reason: 'taken in once');
  });

  testWidgets('background readings older than what the app already counted are not counted twice', (tester) async {
    final (store, s) = await open(tester, PermissionStatus.granted);
    await reading(tester, s, 5000); // 13:10 while open
    s.counted(4900, DateTime(2026, 9, 26, 13, 5)); // from before: already in the 5000
    s.counted(5600, DateTime(2026, 9, 26, 13, 40));
    await comeBack(tester);
    expect(store.c.stepsOn('2026-09-26'), 600);
  });

  testWidgets('counting with the app closed can be switched off', (tester) async {
    final (store, s) = await open(tester, PermissionStatus.granted);
    await reach(tester, find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await reach(tester, find.text('Count steps with the app closed'));
    await tester.tap(find.text('Count steps with the app closed'));
    await tester.pumpAndSettle();
    expect(store.d.move.background, isFalse);
    expect(s.backgroundOn, isFalse);
    await comeBack(tester);
    expect(s.backgroundOn, isFalse, reason: 'stays off when the app comes back');
  });

  testWidgets('if battery saving may stop counting, Move offers to allow it', (tester) async {
    final (_, s) = await open(tester, PermissionStatus.denied);
    s.exempt = false;
    s.status = PermissionStatus.granted;
    await comeBack(tester);
    expect(find.textContaining('Battery saving on this phone'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(s.askedExempt, 1);
    s.exempt = true; // allowed in the dialog
    await comeBack(tester);
    expect(find.textContaining('Battery saving on this phone'), findsNothing);
  });
}
