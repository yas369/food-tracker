// The app's arithmetic: dates, limits, calories, diet sizing and steps.
// Nothing here touches the screen or the phone, so it is all unit-tested.

import 'dart:math' as math;

import 'data/catalog.dart';
import 'data/foods.dart';
import 'models.dart';

// ---------- Dates ----------

String keyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addDays(String k, int n) {
  final d = parseKey(k);
  return keyOf(DateTime(d.year, d.month, d.day + n));
}

int dayNum(String k) => parseKey(k).difference(DateTime(2000)).inDays;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String weekdayShort(String k) => _weekdays[parseKey(k).weekday - 1];
String weekdayLetter(String k) => weekdayShort(k).substring(0, 1);
String monthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

String dayLabel(String k, String today) {
  if (k == today) return 'Today';
  if (k == addDays(today, -1)) return 'Yesterday';
  final d = parseKey(k);
  return '${weekdayShort(k)}, ${d.day} ${_months[d.month - 1]}';
}

String mealForTime(DateTime now) {
  final h = now.hour + now.minute / 60;
  if (h < 11) return 'breakfast';
  if (h < 15.5) return 'lunch';
  if (h < 18.5) return 'snack';
  return 'dinner';
}

String clock12(String hhmm) {
  final p = hhmm.split(':').map(int.parse).toList();
  final h = p[0] % 12 == 0 ? 12 : p[0] % 12;
  return '$h:${p[1].toString().padLeft(2, '0')} ${p[0] < 12 ? 'am' : 'pm'}';
}

// ---------- Numbers ----------

/// Indian digit grouping: 1,890 · 12,345 · 1,23,456.
String fmt(num n) {
  final v = n.round();
  final neg = v < 0;
  var s = v.abs().toString();
  if (s.length > 3) {
    final last = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last';
  }
  return neg ? '-$s' : s;
}

/// 1.5 → "1½", 0.5 → "½", 3 → "3".
String fmtQty(num q) {
  final w = q.floor();
  final half = q - w >= 0.5;
  return (w > 0 || !half ? '$w' : '') + (half ? '½' : '');
}

/// "1 cup" × 1.5 → "1½ cup"; "1 dosa" × 3 → "3 dosa"; "2 tbsp" × 2 → "2 × 2 tbsp".
String qtyUnit(num qty, String unit) {
  final m = RegExp(r'^1 (.+)$').firstMatch(unit);
  if (m != null) return '${fmtQty(qty)} ${m.group(1)}';
  return qty == 1 ? unit : '${fmtQty(qty)} × $unit';
}

/// Calorie level of one portion: low ≤ 100, medium 101–250, high > 250.
String levelOf(num kcal) => kcal <= 100 ? 'l' : kcal <= 250 ? 'm' : 'h';
const levelNames = {'l': 'Low', 'm': 'Medium', 'h': 'High'};

/// How a day is going against its limit: ok, warn (80%+) or over.
String levelFor(num total, num target) {
  if (target <= 0) return 'ok';
  final p = total / target;
  return p > 1 ? 'over' : p >= 0.8 ? 'warn' : 'ok';
}

double sumKcal(Iterable<Entry> entries) => entries.fold(0.0, (a, e) => a + e.total);

/// Half steps for things you'd reasonably eat half of; whole pieces otherwise.
double stepFor(Food f) =>
    RegExp(r'cup|plate|bowl|glass|100 g|handful|tumbler|scoop|ml', caseSensitive: false).hasMatch(f.unit) ? 0.5 : 1;

String emojiFor(String id, String cat) => foodEmoji[id] ?? catEmoji[cat] ?? '🍽️';

// ---------- Limits ----------

class Estimate {
  final int bmr;
  final int tdee;
  final Map<String, int> targets;
  final int target;
  final bool floored;
  const Estimate(this.bmr, this.tdee, this.targets, this.target, this.floored);
}

/// Mifflin–St Jeor. With movement tracking on, activity comes from steps and
/// workouts instead, so the base uses the desk-job factor.
Estimate? estimate(Profile? p, {required bool moveCredit}) {
  if (p == null || p.age <= 0 || p.height <= 0 || p.weight <= 0) return null;
  final bmr = 10 * p.weight + 6.25 * p.height - 5 * p.age + (p.sex == 'f' ? -161 : 5);
  final tdee = bmr * (moveCredit ? 1.2 : p.activity);
  final floor = p.sex == 'f' ? 1200 : 1500;
  int r10(num n) => (n / 10).round() * 10;
  final targets = {'low': r10(math.max(floor.toDouble(), tdee - 500)), 'medium': r10(tdee), 'high': r10(tdee + 300)};
  return Estimate(bmr.round(), tdee.round(), targets, targets[p.plan] ?? targets['low']!, p.plan == 'low' && tdee - 500 < floor);
}

// ---------- Diet planning ----------

class PlannedItem {
  final Food f;
  final String? label;
  double qty;
  final double base;
  final bool flex;
  PlannedItem(this.f, this.label, this.qty, this.flex) : base = qty;
  String get name => label ?? f.name;
  double get kcal => f.kcal * qty;
}

class MealPlan {
  final String name;
  final List<PlannedItem> items;
  const MealPlan(this.name, this.items);
  int get kcal => items.fold(0.0, (a, x) => a + x.kcal).round();
}

double _roundTo(double q, double step) => math.max(step, (q / step).round() * step);

/// Everything that needs the saved data.
class Calc {
  final AppData d;
  Calc(this.d);

  // Foods
  List<Food> get allFoods => [...d.customFoods, ...foods];
  Food? food(String id) {
    for (final f in d.customFoods) {
      if (f.id == id) return f;
    }
    for (final f in foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Entry> entriesOn(String k) => d.log[k] ?? const [];

  // Limits
  bool get moveCredit => d.move.on && d.move.credit;
  double get bodyKg => d.profile?.weight ?? 70;
  Estimate? get est => estimate(d.profile, moveCredit: moveCredit);

  /// The limit before movement.
  int get baseTarget {
    final p = d.profile;
    if (p == null) return 0;
    if (p.override != null) return p.override!;
    return est?.target ?? 0;
  }

  /// A day's limit: the base plus what you burnt moving that day, if that's on.
  int dailyTarget(String k) {
    final b = baseTarget;
    return b > 0 && moveCredit ? b + burntOn(k) : b;
  }

  // Movement. The first 2,500 steps a day are ordinary moving about, already
  // in the desk-job baseline, so they don't add calories. Workouts count
  // (MET − 1) × kg × hours: only what's on top of resting.
  static const baseSteps = 2500;
  double stepsOn(String k) => math.max(d.move.days[k] ?? 0, (d.move.manual[k] ?? 0).toDouble());
  double stepKcal(String k) => math.max(0, stepsOn(k) - baseSteps) * 0.0004 * bodyKg;
  double workoutKcal(Workout w) {
    final x = workoutInfo(w.id);
    return x == null ? 0 : (x.met - 1) * bodyKg * w.min / 60;
  }

  List<Workout> workoutsOn(String k) => d.move.workouts[k] ?? const [];
  int burntOn(String k) => (stepKcal(k) + workoutsOn(k).fold(0.0, (a, w) => a + workoutKcal(w))).round();
  double kmOf(double steps) => steps * (d.profile?.height ?? 165) * 0.00415 / 1000;

  // Kitchen and diet plan
  Set<String> get pantry => {...(d.pantry ?? defaultPantry)};
  bool canMake(String id, Set<String> have) => (needs[id] ?? const []).every((g) => g.any(have.contains));

  List<MealOption> dietOptions(String meal) {
    final pref = d.settings.dietPref;
    final ok = pref == 'nonveg' ? {'veg', 'egg', 'nonveg'} : pref == 'egg' ? {'veg', 'egg'} : {'veg'};
    final have = pantry;
    return [
      for (final o in diet[meal]!)
        if (ok.contains(o.pref) &&
            o.items.every((i) => i.id == 'FRUIT'
                ? fruitIds.any(have.contains)
                : i.id == 'NUT'
                    ? nutIds.any(have.contains)
                    : canMake(i.id, have)))
          o,
    ];
  }

  /// Turn FRUIT / NUT into a real food from the kitchen, and name the
  /// vegetables in poriyal, kootu and sambar, so the plan reads like your food.
  (Food, String?)? resolveItem(String id, int seed) {
    final have = pantry;
    String? pick(List<String> list) {
      final a = list.where(have.contains).toList();
      return a.isEmpty ? null : a[seed % a.length];
    }

    if (id == 'FRUIT') {
      final f = pick(fruitIds);
      final fd = f == null ? null : food(f);
      return fd == null ? null : (fd, null);
    }
    if (id == 'NUT') {
      final n = pick(nutIds);
      final fd = food('nuts');
      return n == null || fd == null ? null : (fd, pantryInfo[n]!.label);
    }
    final f = food(id);
    if (f == null) return null;
    if (const ['poriyal', 'kootu', 'avial', 'kurma', 'sambar'].contains(id)) {
      final order = id == 'poriyal' ? poriyalVeg : id == 'sambar' ? sambarVeg : vegIds;
      final vegs = order.where((v) => have.contains(v) && !const ['onion', 'tomato', 'cucumber'].contains(v)).toList();
      if (vegs.isNotEmpty) {
        final names = [vegs[seed % vegs.length], if (vegs.length > 2) vegs[(seed + 1) % vegs.length]]
            .map((v) => pantryInfo[v]!.label.split(' / ').first.toLowerCase());
        return (f, '${f.name.replaceAll(' (vegetable)', '')} (${names.join(', ')})');
      }
    }
    return (f, null);
  }

  /// Size one option to a calorie budget. Only the staple scales at first; on
  /// big budgets the sides grow too and the staple is capped at double, so it's
  /// more dal and vegetables rather than a tower of chapatis. Rounding up is
  /// trimmed back so a meal never goes more than 2% past its share.
  MealPlan sizeOption(MealOption opt, double budget, [int seed = 0]) {
    final items = <PlannedItem>[];
    for (final i in opt.items) {
      final r = resolveItem(i.id, seed);
      if (r != null) items.add(PlannedItem(r.$1, r.$2, i.qty, i.flex));
    }
    double sum(Iterable<PlannedItem> xs) => xs.fold(0.0, (a, x) => a + x.kcal);
    final fixedK = sum(items.where((x) => !x.flex));
    final flexK = sum(items.where((x) => x.flex));
    var factor = flexK > 0 ? (budget - fixedK) / flexK : 1.0;
    if (factor < 0.5) {
      // Small budget: shrink everything, not just the staple.
      final all = budget / (fixedK + flexK);
      for (final x in items) {
        x.qty = _roundTo(x.qty * all, 0.5);
      }
    } else {
      if (factor > 1.6) {
        for (final x in items) {
          if (!x.flex && x.f.kcal > 60) x.qty = _roundTo(x.qty * 1.5, stepFor(x.f));
        }
        factor = (budget - sum(items.where((x) => !x.flex))) / flexK;
      }
      factor = math.min(factor, 2);
      for (final x in items) {
        if (x.flex) x.qty = _roundTo(x.qty * factor, stepFor(x.f));
      }
    }
    for (var guard = 0; guard < 10 && sum(items) > budget * 1.02; guard++) {
      // First undo any enlarged sides, then shave the staple, then anything else.
      int rank(PlannedItem i) => (!i.flex && i.qty > i.base) ? 0 : i.flex ? 1 : 2;
      final cands = items.where((i) => i.qty > stepFor(i.f)).toList()
        ..sort((p, q) {
          final r = rank(p) - rank(q);
          return r != 0 ? r : q.kcal.compareTo(p.kcal);
        });
      if (cands.isEmpty) break;
      cands.first.qty -= stepFor(cands.first.f);
    }
    return MealPlan(opt.name, items);
  }

  int _pickIndex(String k, String meal) => d.planPicks[k]?[meal] ?? (dayNum(k) + mealOffset[meal]!);

  MealPlan? planFor(String k, String meal) {
    final opts = dietOptions(meal);
    if (opts.isEmpty || baseTarget <= 0) return null;
    final n = _pickIndex(k, meal);
    final i = ((n % opts.length) + opts.length) % opts.length;
    return sizeOption(opts[i], baseTarget * mealInfo(meal).share, n.abs());
  }

  void nextOption(String k, String meal, String today) {
    final picks = d.planPicks.putIfAbsent(k, () => {});
    picks[meal] = _pickIndex(k, meal) + 1;
    final cutoff = addDays(today, -7);
    d.planPicks.removeWhere((day, _) => day.compareTo(cutoff) < 0);
  }

  /// Eating a meal at its usual time needs no questions. Snacks, and meals well
  /// away from their reminder time, are where overeating tends to start.
  bool offSchedule(String meal, DateTime now) {
    if (meal == 'snack') return true;
    Reminder? r;
    for (final x in d.settings.reminders) {
      if (x.meal == meal) r = x;
    }
    if (r == null) return false;
    return ((now.hour * 60 + now.minute) - r.minutes).abs() > 90;
  }

  List<Food> recentFoods() {
    final seen = <String>{};
    final out = <Food>[];
    final days = d.log.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final day in days.take(14)) {
      for (final e in d.log[day]!.reversed) {
        if (seen.add(e.f)) {
          final f = food(e.f);
          if (f != null) out.add(f);
        }
        if (out.length >= 8) return out;
      }
    }
    return out;
  }

  Map<String, double> mixOf(Iterable<Entry> entries) {
    final m = {'l': 0.0, 'm': 0.0, 'h': 0.0};
    for (final e in entries) {
      m[levelOf(e.kcal)] = m[levelOf(e.kcal)]! + e.total;
    }
    return m;
  }

  int streak(String today) {
    var n = 0;
    for (var i = 0; i < 400; i++) {
      final k = addDays(today, -i);
      final list = entriesOn(k);
      if (i == 0 && list.isEmpty) continue;
      if (list.isNotEmpty && sumKcal(list) <= dailyTarget(k)) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }
}

// ---------- Steps ----------

/// Split steps counted between two readings across the days they span.
void addSteps(Move mv, double n, int from, int to) {
  if (!(n > 0) || n > 150000) return;
  if (to <= from) {
    final k = keyOf(DateTime.fromMillisecondsSinceEpoch(to));
    mv.days[k] = (mv.days[k] ?? 0) + n;
    return;
  }
  var t = from;
  while (t < to) {
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final next = DateTime(d.year, d.month, d.day + 1).millisecondsSinceEpoch;
    final end = math.min(next, to);
    final k = keyOf(d);
    mv.days[k] = (mv.days[k] ?? 0) + n * (end - t) / (to - from);
    t = end;
  }
}

/// Record a step-counter reading (steps since the phone started) and credit
/// the difference from the last one to the right days.
void recordSteps(Move mv, double c, int boot, int at, String today) {
  final prev = mv.last;
  mv.last = StepReading(c, boot, at);
  if (prev == null) {
    // First reading: we only know today's steps if the phone restarted today.
    if (boot > 0 && boot >= parseKey(today).millisecondsSinceEpoch) addSteps(mv, c, boot, at);
  } else if ((boot - prev.boot).abs() < 120000 && c >= prev.c) {
    addSteps(mv, c - prev.c, prev.t, at);
  } else if (boot > prev.boot) {
    // The phone restarted since the last reading.
    addSteps(mv, c, math.max(boot, prev.t), at);
  }
  // Anything else (a restart time going backwards) can't be trusted: take it
  // as a new starting point.
  final cutoff = addDays(today, -60);
  mv.days.removeWhere((k, _) => k.compareTo(cutoff) < 0);
}
