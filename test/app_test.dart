import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platecheck/main.dart';
import 'package:platecheck/models.dart';
import 'package:platecheck/store.dart';

import 'fakes.dart';

Future<AppStore> start(WidgetTester tester, {AppData? data, DateTime? at}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = at ?? DateTime(2026, 9, 26, 13, 10);
  final store = AppStore(
    storage: MemoryStorage(data == null ? null : jsonEncode(data.toJson())),
    notifications: FakeNotifications(),
    steps: FakeSteps(),
    clock: () => now,
  );
  await tester.pumpWidget(PlateCheckApp(store: store));
  await store.init();
  await tester.pumpAndSettle();
  return store;
}

AppData ready({bool withLog = false}) {
  final d = AppData(profile: Profile(age: 32, sex: 'm', height: 172, weight: 82, activity: 1.375, plan: 'low'));
  d.me
    ..name = 'Yaswanth C'
    ..onboarded = true
    ..since = DateTime(2026, 9, 1).millisecondsSinceEpoch;
  return d;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1)); // let the reminder re-plan run
  await tester.pumpAndSettle();
}

void main() {
  smallPhoneTests();
  testWidgets('first run: three setup screens, then the goal, then Today', (tester) async {
    final store = await start(tester);
    expect(find.text('Welcome! 👋'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome! 👋'), findsOneWidget, reason: 'a name is needed');
    await tester.enterText(find.byType(TextField), 'Yaswanth C');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What do you eat?'), findsOneWidget);
    await tester.tap(find.text('Eggetarian'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What’s in your kitchen?'), findsOneWidget);
    await tester.tap(find.text('Done, let’s go'));
    await tester.pumpAndSettle();
    expect(store.d.me.onboarded, isTrue);
    expect(store.d.settings.dietPref, 'egg');
    expect(find.text('Last step: your goal'), findsOneWidget, reason: 'the goal page follows setup');
    await tester.tap(find.text('Save and start tracking'));
    await settle(tester);
    // Defaults (30 y, 165 cm, 70 kg, light activity) on the low plan.
    expect(store.c.baseTarget, 1680);
    expect(find.text('Good afternoon, Yaswanth 👋'), findsOneWidget);
    // Never asked again
    expect(find.text('Welcome! 👋'), findsNothing);
  });

  testWidgets('lunch at lunchtime skips the hunger check; logging updates the day', (tester) async {
    final store = await start(tester, data: ready());
    expect(find.text('Welcome! 👋'), findsNothing);
    await tester.tap(find.text('Add food'));
    await tester.pumpAndSettle();
    expect(find.text('Add to Lunch'), findsOneWidget);
    expect(find.text('How hungry are you right now?'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'biryani');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Add Chicken biryani')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Make it ½'), findsOneWidget, reason: 'high-calorie pick on the low plan');
    await tester.tap(find.text('Make it ½'));
    await tester.pumpAndSettle();
    expect(find.text('1 item · 275 kcal'), findsOneWidget);
    await tester.tap(find.textContaining('Add to Lunch ›'));
    await settle(tester);
    expect(store.d.log['2026-09-26']!.single.qty, 0.5);
    expect(find.text('1 item · 275 kcal'), findsOneWidget);
  });

  testWidgets('a snack asks how hungry you are, and "not hungry" offers a wait', (tester) async {
    final store = await start(tester, data: ready());
    await tester.ensureVisible(find.byTooltip('Add to Snacks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to Snacks'));
    await tester.pumpAndSettle();
    expect(find.text('Before you eat'), findsOneWidget);
    await tester.tap(find.text('Not hungry'));
    await tester.pumpAndSettle();
    expect(find.text('You’re not really hungry'), findsOneWidget);
    await tester.tap(find.text('💧 Wait 10 minutes'));
    await settle(tester);
    final n = store.notifications as FakeNotifications;
    expect(n.once.single.$2, DateTime(2026, 9, 26, 13, 20));
  });

  testWidgets('parotta on the low plan offers chapati instead', (tester) async {
    final store = await start(tester, data: ready());
    await tester.tap(find.text('Add food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'parotta');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Add Parotta')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lighter swap: Chapati'), findsOneWidget);
    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add to Lunch ›'));
    await settle(tester);
    expect(store.d.log['2026-09-26']!.single.f, 'chapati');
  });

  testWidgets('diet plan: sized to the limit, one tap to log, choice shown from profile', (tester) async {
    final store = await start(tester, data: ready());
    await tester.tap(find.text('Diet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('fits your 1,890 limit · 🥦 Veg'), findsOneWidget);
    final planned = store.c.planFor('2026-09-26', 'breakfast')!;
    await tester.ensureVisible(find.text('✓ I ate this').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('✓ I ate this').first);
    await settle(tester);
    expect(store.d.log['2026-09-26']!.length, planned.items.length);
    expect(find.textContaining('✓ Logged'), findsOneWidget, reason: 'a logged meal shrinks to one line');
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(store.d.log['2026-09-26'], isNull, reason: 'undo removes the whole meal');
  });

  testWidgets('a logged food: tap to change the amount, remove with undo', (tester) async {
    final d = ready();
    d.log['2026-09-26'] = [const Entry(f: 'idli', name: 'Idli', unit: '1 piece', kcal: 60, tags: [], qty: 3, meal: 'breakfast', hunger: null, b: 'a', t: 0)];
    final store = await start(tester, data: d);
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idli'));
    await tester.pumpAndSettle();
    expect(find.text('180 kcal'), findsOneWidget);
    await tester.tap(find.byTooltip('Less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(store.d.log['2026-09-26']!.single.qty, 2);
    await tester.pump(const Duration(seconds: 6)); // the message closes by itself
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Idli'));
    await settle(tester);
    expect(store.d.log['2026-09-26'], isNull);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(store.d.log['2026-09-26']!.single.qty, 2);
  });

  testWidgets('mornings show how yesterday went; swipe to see a past day', (tester) async {
    final d = ready();
    d.log['2026-09-25'] = [const Entry(f: 'rice', name: 'White rice', unit: '1 cup', kcal: 200, tags: [], qty: 7, meal: 'lunch', hunger: null, b: 'a', t: 0)];
    await start(tester, data: d, at: DateTime(2026, 9, 26, 8, 0));
    expect(find.textContaining('Yesterday: 1,400 of 1,890. Within your limit.'), findsOneWidget);
    await tester.fling(find.text('kcal left'), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget, reason: 'swiped back a day');
    expect(find.text('1 item · 1,400 kcal'), findsOneWidget);
  });

  testWidgets('progress waits for 3 days of logging before showing charts', (tester) async {
    await start(tester, data: ready());
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Your patterns show up here after 3 days of logging'), findsOneWidget);
    expect(find.text('Last 14 days'), findsNothing);
  });

  testWidgets('move: workouts add to the day’s limit', (tester) async {
    final store = await start(tester, data: ready());
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start tracking'));
    await settle(tester);
    expect(store.c.baseTarget, 1590);
    await tester.ensureVisible(find.text('+ Add a workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add a workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yoga'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('45 min'));
    await settle(tester);
    expect(store.c.burntOn('2026-09-26'), 92);
    expect(store.c.dailyTarget('2026-09-26'), 1682);
    await tester.ensureVisible(find.text('How calories burnt are counted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How calories burnt are counted'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Added to today’s food limit: 1,590 + 92 = 1,682 kcal.'), findsOneWidget);
  });

  testWidgets('choices change only from Me, each on its own', (tester) async {
    final store = await start(tester, data: ready());
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I eat'));
    await tester.pumpAndSettle();
    expect(find.text('What do you eat?'), findsOneWidget);
    await tester.tap(find.text('Non-vegetarian'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(store.d.settings.dietPref, 'nonveg');
    expect(store.d.me.name, 'Yaswanth C');
    expect(store.d.pantry, isNull, reason: 'kitchen untouched');
  });

  testWidgets('reminders are planned for 14 days and a logged meal drops its own', (tester) async {
    final store = await start(tester, data: ready(), at: DateTime(2026, 9, 26, 9, 0));
    final n = store.notifications as FakeNotifications;
    expect(n.scheduled.where((r) => r.id == 202609261).length, 1);
    expect(store.logPlan('lunch'), isNotNull);
    await settle(tester);
    expect(n.scheduled.where((r) => r.id == 202609261), isEmpty);
    expect(n.scheduled.where((r) => r.id == 202609271).length, 1);
  });
}

void _smallPhoneTest(String theme, {double textScale = 1}) {
  testWidgets('every screen fits a small phone ($theme theme, text ×$textScale)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = ready()..settings.theme = theme;
    d.move
      ..on = true
      ..manual['2026-09-26'] = 9000;
    d.move.workouts['2026-09-26'] = [const Workout('yoga', 45, 0)];
    d.log['2026-09-26'] = [
      const Entry(f: 'idli', name: 'Idli', unit: '1 piece', kcal: 60, tags: [], qty: 3, meal: 'breakfast', hunger: 4, b: 'a', t: 0),
      const Entry(f: 'chkbiryani', name: 'Chicken biryani', unit: '1 plate', kcal: 550, tags: ['protein'], qty: 2, meal: 'lunch', hunger: 1, b: 'b', t: 0),
    ];
    for (final day in ['2026-09-24', '2026-09-25']) {
      d.log[day] = [const Entry(f: 'dosa', name: 'Plain dosa', unit: '1 dosa', kcal: 135, tags: [], qty: 3, meal: 'breakfast', hunger: 4, b: 'c', t: 0)];
    }
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3; // 360 × 740
    addTearDown(tester.view.reset);
    final store = AppStore(storage: MemoryStorage(jsonEncode(d.toJson())), notifications: FakeNotifications(), steps: FakeSteps(), clock: () => DateTime(2026, 9, 26, 16, 40));
    await tester.pumpWidget(PlateCheckApp(store: store));
    await store.init();
    await tester.pumpAndSettle();
    for (final tab in ['Diet', 'Move', 'Progress', 'Me', 'Today']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      // Open everything that folds, so it gets laid out too.
      for (final t in const ['How plans are made', 'How calories burnt are counted', 'Settings', 'More details']) {
        if (find.text(t).evaluate().isNotEmpty) {
          await tester.ensureVisible(find.text(t));
          await tester.pumpAndSettle();
          await tester.tap(find.text(t));
          await tester.pumpAndSettle();
        }
      }
      if (tab == 'Me') {
        for (final page in const ['Plan and body', 'Meal reminders']) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text(page), 200, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(page));
          await tester.pumpAndSettle();
          for (var i = 0; i < 6; i++) {
            await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }
      }
      // Scroll through the whole screen so every part gets laid out.
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Add food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Very hungry'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Add Idli')).first);
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).last;
    for (var i = 0; i < 10; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
  });
}

void smallPhoneTests() {
  _smallPhoneTest('light');
  _smallPhoneTest('dark');
  // Android's "Font size" setting at its larger steps.
  _smallPhoneTest('light', textScale: 1.3);
}
