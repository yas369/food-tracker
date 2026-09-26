// The app's state: the saved data plus everything that changes it. Every
// change saves to the phone; changes that affect reminders re-plan them.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'logic.dart';
import 'models.dart';
import 'reminders.dart';
import 'services/notifications.dart';
import 'services/steps.dart';
import 'services/storage.dart';

class AppStore extends ChangeNotifier {
  AppStore({Storage? storage, Notifications? notifications, StepSensor? steps, DateTime Function()? clock})
      : storage = storage ?? Storage(),
        notifications = notifications ?? Notifications(),
        steps = steps ?? StepSensor(),
        _clock = clock ?? DateTime.now;

  final Storage storage;
  final Notifications notifications;
  final StepSensor steps;
  final DateTime Function() _clock;

  AppData d = AppData();
  late Calc c = Calc(d);
  bool loaded = false;

  // Reminder status, for the Me screen.
  bool notifAllowed = false;
  bool exactAllowed = true;
  int reminderCount = 0;

  DateTime get now => _clock();
  String get today => keyOf(now);

  ThemeMode get themeMode => d.settings.theme == 'light'
      ? ThemeMode.light
      : d.settings.theme == 'dark'
          ? ThemeMode.dark
          : ThemeMode.system;

  Future<void> init() async {
    d = await storage.load();
    c = Calc(d);
    loaded = true;
    notifyListeners();
    try {
      await notifications.init();
      await refreshPermissions();
      await reschedule();
    } catch (_) {}
    await steps.checkPermission();
    if (d.move.on) steps.start(_onSteps);
    notifyListeners();
  }

  // ---------- Saving ----------

  Future<void> _saving = Future.value();
  Timer? _plan;

  /// Save now; re-plan reminders shortly after (several quick changes → one re-plan).
  void save({bool reminders = true}) {
    d.savedAt = DateTime.now().millisecondsSinceEpoch;
    final snapshot = AppData.fromJson(jsonDecode(jsonEncode(d.toJson())));
    _saving = _saving.then((_) => storage.save(snapshot)).catchError((_) {});
    if (reminders) {
      _plan?.cancel();
      _plan = Timer(const Duration(milliseconds: 800), reschedule);
    }
    notifyListeners();
  }

  Future<void> flush() => _saving;

  Future<void> refreshPermissions() async {
    notifAllowed = await notifications.allowed;
    exactAllowed = await notifications.exactAllowed;
  }

  Future<void> reschedule() async {
    try {
      await refreshPermissions();
      reminderCount = await notifications.replaceAll(planReminders(c, now));
    } catch (_) {
      reminderCount = 0;
    }
    notifyListeners();
  }

  Future<void> requestNotifications() async {
    await notifications.request();
    await reschedule();
  }

  Future<void> requestExact() async {
    await notifications.requestExact();
    await reschedule();
  }

  // ---------- Food log ----------

  void addEntries(String day, List<Entry> list) {
    d.log.putIfAbsent(day, () => []).addAll(list);
    save();
  }

  Entry removeEntry(String day, int i) {
    final list = d.log[day]!;
    final e = list.removeAt(i);
    if (list.isEmpty) d.log.remove(day);
    save();
    return e;
  }

  String newBatch() => DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  int? logPlan(String meal) {
    final plan = c.planFor(today, meal);
    if (plan == null) return null;
    final b = newBatch();
    final t = now.millisecondsSinceEpoch;
    addEntries(today, [
      for (final x in plan.items)
        Entry(f: x.f.id, name: x.name, unit: x.f.unit, kcal: x.f.kcal, tags: x.f.tags, qty: x.qty, meal: meal, hunger: null, b: b, t: t),
    ]);
    return plan.kcal;
  }

  void nextOption(String day, String meal) {
    c.nextOption(day, meal, today);
    save(reminders: false);
  }

  void addCustomFood(Food f) {
    d.customFoods.insert(0, f);
    save(reminders: false);
  }

  Future<void> waitTenMinutes() => notifications.scheduleOnce(idWait, '10 minutes are up',
      'Still hungry? Then eat, and log it. If the craving has passed, you just skipped a snack.', now.add(const Duration(minutes: 10)),
      payload: 'snack');

  // ---------- Profile and choices ----------

  void setProfile(Profile p) {
    d.profile = p;
    save();
  }

  void finishOnboarding({required String name, required String photo, required String pref, required List<String> pantry}) {
    d.me
      ..name = name
      ..photo = photo
      ..onboarded = true
      ..since = d.me.since == 0 ? now.millisecondsSinceEpoch : d.me.since;
    d.settings.dietPref = pref;
    d.pantry = pantry;
    save();
  }

  void setNamePhoto(String name, String photo) {
    d.me
      ..name = name
      ..photo = photo;
    save(reminders: false);
  }

  void setDietPref(String pref) {
    d.settings.dietPref = pref;
    save(reminders: false);
  }

  void setPantry(List<String> items) {
    d.pantry = items;
    save(reminders: false);
  }

  void setReminder(int i, {bool? on, String? time}) {
    final r = d.settings.reminders[i];
    if (on != null) r.on = on;
    if (time != null) r.time = time;
    save();
  }

  void setHungerCheck(bool v) {
    d.settings.hungerCheck = v;
    save(reminders: false);
  }

  void setTheme(String t) {
    d.settings.theme = t;
    save(reminders: false);
  }

  // ---------- Move ----------

  void _onSteps(double count, int boot, int at) {
    final before = c.stepsOn(today).round();
    recordSteps(d.move, count, boot, at, today);
    save(reminders: false);
    if (c.stepsOn(today).round() != before) notifyListeners();
  }

  Future<void> startMove() async {
    await steps.requestPermission();
    d.move
      ..on = true
      ..credit = true;
    save();
    steps.start(_onSteps);
  }

  void setCredit(bool v) {
    d.move.credit = v;
    save();
  }

  void setStepGoal(int g) {
    d.move.goal = g.clamp(1000, 30000);
    save(reminders: false);
  }

  void setManualSteps(int? v) {
    if (v == null) {
      d.move.manual.remove(today);
    } else {
      d.move.manual[today] = v.clamp(0, 100000);
      if (!d.move.on) {
        d.move
          ..on = true
          ..credit = true;
      }
    }
    save();
  }

  void addWorkout(String id, int minutes) {
    d.move.workouts.putIfAbsent(today, () => []).add(Workout(id, minutes, now.millisecondsSinceEpoch));
    save();
  }

  void removeWorkout(int i) {
    d.move.workouts[today]?.removeAt(i);
    save();
  }

  // ---------- Data ----------

  /// Replace everything with a backup. Returns false if it isn't one.
  bool importBackup(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['log'] is! Map) return false;
      d = AppData.fromJson(Map<String, dynamic>.from(j));
      c = Calc(d);
      save();
      return true;
    } catch (_) {
      return false;
    }
  }

  void eraseAll() {
    d = AppData();
    c = Calc(d);
    save();
  }

  // ---------- Setup-time helpers used by tests ----------

  @visibleForTesting
  void replaceData(AppData data) {
    d = data;
    c = Calc(d);
    loaded = true;
    notifyListeners();
  }
}
