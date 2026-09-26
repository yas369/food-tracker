// Data kept on the phone. The JSON shape matches the earlier web version of
// the app exactly, so its save file and backups load unchanged.

double _d(Object? v, [double or = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? or;
  return or;
}

int _i(Object? v, [int or = 0]) => _d(v, or.toDouble()).round();

Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _l(Object? v) => v is List ? v : const [];

class Food {
  final String id;
  final String cat;
  final String name;
  final String unit;
  final int kcal;
  final List<String> tags;
  const Food(this.id, this.cat, this.name, this.unit, this.kcal, this.tags);

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        '${j['id']}',
        '${j['cat'] ?? 'My foods'}',
        '${j['name']}',
        '${j['unit'] ?? '1 portion'}',
        _i(j['kcal']),
        [for (final t in _l(j['tags'])) '$t'],
      );

  Map<String, dynamic> toJson() => {'id': id, 'cat': cat, 'name': name, 'unit': unit, 'kcal': kcal, 'tags': tags};
}

/// One logged food. `b` groups items added together; `hunger` is 1–5 or null.
class Entry {
  final String f;
  final String name;
  final String unit;
  final int kcal;
  final List<String> tags;
  final double qty;
  final String meal;
  final int? hunger;
  final String b;
  final int t;
  const Entry({
    required this.f,
    required this.name,
    required this.unit,
    required this.kcal,
    required this.tags,
    required this.qty,
    required this.meal,
    required this.hunger,
    required this.b,
    required this.t,
  });

  double get total => kcal * qty;

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        f: '${j['f']}',
        name: '${j['name']}',
        unit: '${j['unit'] ?? ''}',
        kcal: _i(j['kcal']),
        tags: [for (final t in _l(j['tags'])) '$t'],
        qty: _d(j['qty'], 1),
        meal: '${j['meal'] ?? 'snack'}',
        hunger: j['hunger'] == null ? null : _i(j['hunger']),
        b: '${j['b'] ?? ''}',
        t: _i(j['t']),
      );

  Map<String, dynamic> toJson() => {
        'f': f, 'name': name, 'unit': unit, 'kcal': kcal, 'tags': tags,
        'qty': qty, 'meal': meal, 'hunger': hunger, 'b': b, 't': t,
      };
}

class Profile {
  int age;
  String sex; // 'm' | 'f'
  int height; // cm
  double weight; // kg
  double activity; // 1.2 … 1.725
  String plan; // 'low' | 'medium' | 'high'
  int? override; // own daily limit
  Profile({
    this.age = 30,
    this.sex = 'm',
    this.height = 165,
    this.weight = 70,
    this.activity = 1.375,
    this.plan = 'low',
    this.override,
  });

  Profile copy() => Profile(age: age, sex: sex, height: height, weight: weight, activity: activity, plan: plan, override: override);

  factory Profile.fromJson(Map<String, dynamic> j) {
    // Older saves had goal: lose | maintain instead of plan.
    final plan = j['plan'] ?? (j['goal'] == 'maintain' ? 'medium' : 'low');
    final o = j['override'];
    return Profile(
      age: _i(j['age'], 30),
      sex: j['sex'] == 'f' ? 'f' : 'm',
      height: _i(j['height'], 165),
      weight: _d(j['weight'], 70),
      activity: _d(j['activity'], 1.375),
      plan: '$plan',
      override: (o == null || o == '' || _i(o) == 0) ? null : _i(o),
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age, 'sex': sex, 'height': height, 'weight': weight,
        'activity': activity, 'plan': plan, 'override': override ?? '',
      };
}

class Reminder {
  final String id;
  final String label;
  String time; // HH:MM
  bool on;
  final String? meal;
  Reminder(this.id, this.label, this.time, this.on, this.meal);

  factory Reminder.fromJson(Map<String, dynamic> j) =>
      Reminder('${j['id']}', '${j['label']}', '${j['time'] ?? '08:00'}', j['on'] != false, j['meal'] == null ? null : '${j['meal']}');

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'time': time, 'on': on, 'meal': meal};

  int get minutes {
    final p = time.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}

List<Reminder> defaultReminders() => [
      Reminder('breakfast', 'Breakfast', '08:00', true, 'breakfast'),
      Reminder('lunch', 'Lunch', '13:00', true, 'lunch'),
      Reminder('snack', 'Evening snack', '16:30', true, 'snack'),
      Reminder('dinner', 'Dinner', '20:00', true, 'dinner'),
      Reminder('checkin', 'Kitchen-closed check-in', '21:30', true, null),
    ];

class Settings {
  bool hungerCheck;
  String theme; // '' | 'light' | 'dark'
  String dietPref; // veg | egg | nonveg
  List<Reminder> reminders;
  Settings({this.hungerCheck = true, this.theme = '', this.dietPref = 'veg', List<Reminder>? reminders})
      : reminders = reminders ?? defaultReminders();

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        hungerCheck: j['hungerCheck'] != false,
        theme: '${j['theme'] ?? ''}',
        dietPref: '${j['dietPref'] ?? 'veg'}',
        reminders: j['reminders'] is List && (j['reminders'] as List).isNotEmpty
            ? [for (final r in j['reminders']) Reminder.fromJson(_m(r))]
            : null,
      );

  Map<String, dynamic> toJson() => {
        'hungerCheck': hungerCheck, 'theme': theme, 'dietPref': dietPref,
        'reminders': [for (final r in reminders) r.toJson()],
      };
}

class Me {
  String name;
  String photo; // data URL, empty when none
  bool onboarded;
  int since;
  Me({this.name = '', this.photo = '', this.onboarded = false, this.since = 0});

  factory Me.fromJson(Map<String, dynamic> j) =>
      Me(name: '${j['name'] ?? ''}', photo: '${j['photo'] ?? ''}', onboarded: j['onboarded'] == true, since: _i(j['since']));

  Map<String, dynamic> toJson() => {'name': name, 'photo': photo, 'onboarded': onboarded, 'since': since};
}

class Workout {
  final String id;
  final int min;
  final int t;
  const Workout(this.id, this.min, this.t);
  factory Workout.fromJson(Map<String, dynamic> j) => Workout('${j['id']}', _i(j['min']), _i(j['t']));
  Map<String, dynamic> toJson() => {'id': id, 'min': min, 't': t};
}

/// The last step-counter reading: total since the phone started (c), and when.
class StepReading {
  final double c;
  final int boot;
  final int t;
  const StepReading(this.c, this.boot, this.t);
  factory StepReading.fromJson(Map<String, dynamic> j) => StepReading(_d(j['c']), _i(j['boot']), _i(j['t']));
  Map<String, dynamic> toJson() => {'c': c, 'boot': boot, 't': t};
}

class Move {
  bool on;
  bool credit;
  int goal;
  StepReading? last;
  Map<String, double> days; // steps counted by the phone, per day
  Map<String, int> manual; // steps typed in from a watch
  Map<String, List<Workout>> workouts;
  double? stride; // cm per step, measured by walking a known distance; null: estimated from height
  Move({this.on = false, this.credit = true, this.goal = 7000, this.last, Map<String, double>? days, Map<String, int>? manual, Map<String, List<Workout>>? workouts, this.stride})
      : days = days ?? {},
        manual = manual ?? {},
        workouts = workouts ?? {};

  factory Move.fromJson(Map<String, dynamic> j) => Move(
        on: j['on'] == true,
        credit: j['credit'] != false,
        goal: _i(j['goal'], 7000),
        last: j['last'] is Map ? StepReading.fromJson(_m(j['last'])) : null,
        days: {for (final e in _m(j['days']).entries) e.key: _d(e.value)},
        manual: {for (final e in _m(j['manual']).entries) e.key: _i(e.value)},
        workouts: {for (final e in _m(j['workouts']).entries) e.key: [for (final w in _l(e.value)) Workout.fromJson(_m(w))]},
        stride: j['stride'] == null ? null : _d(j['stride']),
      );

  Map<String, dynamic> toJson() => {
        'on': on, 'credit': credit, 'goal': goal, 'last': last?.toJson(),
        'days': days, 'manual': manual,
        'workouts': {for (final e in workouts.entries) e.key: [for (final w in e.value) w.toJson()]},
        'stride': stride,
      };
}

class AppData {
  Profile? profile;
  Settings settings;
  List<Food> customFoods;
  Map<String, List<Entry>> log;
  Map<String, bool> fired;
  Me me;
  List<String>? pantry; // null means the typical kitchen
  Move move;
  int savedAt;
  Map<String, Map<String, int>> planPicks;

  AppData({
    this.profile,
    Settings? settings,
    List<Food>? customFoods,
    Map<String, List<Entry>>? log,
    Map<String, bool>? fired,
    Me? me,
    this.pantry,
    Move? move,
    this.savedAt = 0,
    Map<String, Map<String, int>>? planPicks,
  })  : settings = settings ?? Settings(),
        customFoods = customFoods ?? [],
        log = log ?? {},
        fired = fired ?? {},
        me = me ?? Me(),
        move = move ?? Move(),
        planPicks = planPicks ?? {};

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        profile: j['profile'] is Map ? Profile.fromJson(_m(j['profile'])) : null,
        settings: Settings.fromJson(_m(j['settings'])),
        customFoods: [for (final f in _l(j['customFoods'])) Food.fromJson(_m(f))],
        log: {for (final e in _m(j['log']).entries) e.key: [for (final x in _l(e.value)) Entry.fromJson(_m(x))]},
        fired: {for (final e in _m(j['fired']).entries) e.key: e.value == true},
        me: Me.fromJson(_m(j['me'])),
        pantry: j['pantry'] is List ? [for (final p in j['pantry']) '$p'] : null,
        move: Move.fromJson(_m(j['move'])),
        savedAt: _i(j['savedAt']),
        planPicks: {for (final e in _m(j['planPicks']).entries) e.key: {for (final p in _m(e.value).entries) p.key: _i(p.value)}},
      );

  Map<String, dynamic> toJson() => {
        'profile': profile?.toJson(),
        'settings': settings.toJson(),
        'customFoods': [for (final f in customFoods) f.toJson()],
        'log': {for (final e in log.entries) e.key: [for (final x in e.value) x.toJson()]},
        'fired': fired,
        'me': me.toJson(),
        'pantry': pantry,
        'move': move.toJson(),
        'savedAt': savedAt,
        'planPicks': planPicks,
      };
}
