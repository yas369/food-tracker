import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:platecheck/data/catalog.dart';
import 'package:platecheck/logic.dart';
import 'package:platecheck/models.dart';

AppData withProfile({String plan = 'low', String sex = 'm', double weight = 82, int height = 172, int age = 32, double activity = 1.375}) =>
    AppData(profile: Profile(age: age, sex: sex, height: height, weight: weight, activity: activity, plan: plan));

void main() {
  group('numbers', () {
    test('Indian grouping', () {
      expect(fmt(1890), '1,890');
      expect(fmt(123456), '1,23,456');
      expect(fmt(-300), '-300');
      expect(fmt(99), '99');
    });
    test('portions read naturally', () {
      expect(qtyUnit(1.5, '1 cup'), '1½ cup');
      expect(qtyUnit(3, '1 dosa'), '3 dosa');
      expect(qtyUnit(0.5, '1 cup cooked'), '½ cup cooked');
      expect(qtyUnit(1, '2 tbsp'), '2 tbsp');
      expect(qtyUnit(2, '2 tbsp'), '2 × 2 tbsp');
      expect(qtyUnit(2.5, '100 g'), '2½ × 100 g');
    });
    test('levels', () {
      expect(levelOf(100), 'l');
      expect(levelOf(101), 'm');
      expect(levelOf(251), 'h');
      expect(levelFor(1520, 1890), 'warn');
      expect(levelFor(1500, 1890), 'ok');
      expect(levelFor(2000, 1890), 'over');
    });
  });

  group('limits (same numbers as the web app)', () {
    test('plans for 32 y, 172 cm, 82 kg, light activity', () {
      final e = estimate(withProfile().profile, moveCredit: false)!;
      expect(e.tdee, 2393);
      expect(e.targets, {'low': 1890, 'medium': 2390, 'high': 2690});
    });
    test('movement on: desk baseline plus what you burn', () {
      final d = withProfile()..move.on = true;
      final c = Calc(d);
      expect(c.baseTarget, 1590);
      final k = '2026-09-26';
      d.move.manual[k] = 9000;
      d.move.workouts[k] = [const Workout('yoga', 45, 0), const Workout('surya', 15, 0)];
      expect(c.stepKcal(k).round(), 213);
      expect(c.burntOn(k), 353);
      expect(c.dailyTarget(k), 1943);
      d.move.credit = false;
      expect(c.dailyTarget(k), 1890);
    });
    test('old saves with goal: maintain become the medium plan', () {
      final p = Profile.fromJson({'age': 32, 'sex': 'm', 'height': 172, 'weight': 82, 'activity': 1.375, 'goal': 'maintain', 'override': ''});
      expect(p.plan, 'medium');
      expect(p.override, isNull);
    });
  });

  group('diet plan', () {
    test('never plans a meal more than a few percent past its share, at any limit', () {
      for (final prof in [
        withProfile(sex: 'f', weight: 50, height: 152, age: 45, activity: 1.2),
        withProfile(),
        withProfile(weight: 95, height: 180, age: 25, activity: 1.725),
      ]) {
        for (final plan in ['low', 'medium', 'high']) {
          prof.profile!.plan = plan;
          prof.settings.dietPref = 'nonveg';
          final c = Calc(prof);
          for (final m in meals) {
            for (final o in diet[m.id]!) {
              final budget = c.baseTarget * m.share;
              final p = c.sizeOption(o, budget);
              expect(p.kcal, lessThanOrEqualTo(budget * 1.05), reason: '${o.name} at ${c.baseTarget}');
              for (final x in p.items.where((x) => x.flex)) {
                expect(x.qty, lessThanOrEqualTo(x.base * 2), reason: 'staple capped at double');
              }
            }
          }
        }
      }
    });
    test('only uses what is in the kitchen', () {
      final d = withProfile()..pantry = ['rice', 'atta', 'dal', 'beans', 'carrot', 'apple', 'curd'];
      final c = Calc(d);
      for (final m in meals) {
        for (final o in c.dietOptions(m.id)) {
          for (final i in o.items) {
            expect(['idli', 'dosa', 'upma', 'ragidosa', 'pesarattu'].contains(i.id), isFalse);
          }
        }
      }
      final lunch = c.planFor('2026-09-26', 'lunch')!;
      expect(lunch.items.any((x) => x.name.contains('beans') || x.name.contains('carrot') || x.f.id == 'rice'), isTrue);
    });
    test('empty kitchen gives no plan rather than food you do not have', () {
      final d = withProfile()..pantry = [];
      expect(Calc(d).planFor('2026-09-26', 'lunch'), isNull);
    });
    test('veg never sees egg or meat options', () {
      final c = Calc(withProfile());
      for (final m in meals) {
        expect(c.dietOptions(m.id).every((o) => o.pref == 'veg'), isTrue);
      }
    });
  });

  group('steps', () {
    int ms(String s) => DateTime.parse(s).millisecondsSinceEpoch;
    test('first reading counts only if the phone restarted today', () {
      final mv = Move();
      recordSteps(mv, 5000, ms('2026-09-25T06:00:00'), ms('2026-09-26T09:00:00'), '2026-09-26');
      expect(mv.days['2026-09-26'] ?? 0, 0);
      recordSteps(mv, 8000, ms('2026-09-25T06:00:00'), ms('2026-09-26T10:00:00'), '2026-09-26');
      expect(mv.days['2026-09-26']!.round(), 3000);
    });
    test('steps across midnight are split by time', () {
      final mv = Move(last: StepReading(8000, ms('2026-09-25T06:00:00'), ms('2026-09-26T09:00:00')));
      recordSteps(mv, 9000, ms('2026-09-25T06:00:00'), ms('2026-09-27T01:00:00'), '2026-09-27');
      expect(mv.days['2026-09-26']!.round(), 938);
      expect(mv.days['2026-09-27']!.round(), 63);
    });
    test('a restart is handled and a backwards restart time is ignored', () {
      final mv = Move(last: StepReading(9000, ms('2026-09-25T06:00:00'), ms('2026-09-27T01:00:00')));
      recordSteps(mv, 400, ms('2026-09-27T06:00:00'), ms('2026-09-27T07:00:00'), '2026-09-27');
      expect(mv.days['2026-09-27']!.round(), 400);
      recordSteps(mv, 5000, ms('2026-09-25T06:00:00'), ms('2026-09-27T08:00:00'), '2026-09-27');
      expect(mv.days['2026-09-27']!.round(), 400);
    });
  });

  test('a save from the web app loads and saves back unchanged', () {
    const web = '{"profile":{"age":32,"sex":"m","height":172,"weight":82,"activity":1.375,"plan":"low","override":""},'
        '"settings":{"hungerCheck":true,"theme":"","dietPref":"egg","reminders":[{"id":"breakfast","label":"Breakfast","time":"08:00","on":true,"meal":"breakfast"}]},'
        '"customFoods":[{"id":"c_1","cat":"My foods","name":"Kambu koozh","unit":"1 portion","kcal":150,"tags":[]}],'
        '"log":{"2026-09-26":[{"f":"idli","name":"Idli","unit":"1 piece","kcal":60,"tags":[],"qty":3,"meal":"breakfast","hunger":4,"b":"x","t":1}]},'
        '"fired":{},"me":{"name":"Yas","photo":"","onboarded":true,"since":1},"pantry":["rice"],'
        '"move":{"on":true,"credit":true,"goal":7000,"last":{"c":400,"boot":5,"t":6},"days":{"2026-09-26":123.5},"manual":{},"workouts":{"2026-09-26":[{"id":"yoga","min":45,"t":1}]}},'
        '"savedAt":10,"planPicks":{"2026-09-26":{"lunch":3}}}';
    final d = AppData.fromJson(jsonDecode(web));
    expect(d.me.name, 'Yas');
    expect(d.log['2026-09-26']!.first.total, 180);
    expect(d.customFoods.single.name, 'Kambu koozh');
    expect(d.move.workouts['2026-09-26']!.single.min, 45);
    final again = AppData.fromJson(jsonDecode(jsonEncode(d.toJson())));
    expect(jsonEncode(again.toJson()), jsonEncode(d.toJson()));
  });

  group('stride', () {
    test('distance uses your measured stride, or 41.5% of height', () {
      final c = Calc(withProfile(height: 172));
      expect(c.strideCm, closeTo(71.38, .01));
      expect(c.kmOf(10000), closeTo(7.138, .001));
      c.d.move.stride = 80;
      expect(c.strideMeasured, isTrue);
      expect(c.kmOf(10000), closeTo(8.0, .001));
    });
    test('a walk too short, or a stride no one walks, is refused', () {
      expect(strideFrom(100, 140), closeTo(71.43, .01));
      expect(strideFrom(400, 520), closeTo(76.92, .01));
      expect(strideFrom(10, 14), isNull, reason: 'too short to trust');
      expect(strideFrom(100, 20), isNull, reason: 'fewer than 30 steps');
      expect(strideFrom(100, 400), isNull, reason: '25 cm a step');
      expect(strideFrom(1000, 500), isNull, reason: '2 m a step');
    });
    test('saved with the rest, and older saves load without one', () {
      final d = withProfile()..move.stride = 74.5;
      expect(AppData.fromJson(jsonDecode(jsonEncode(d.toJson()))).move.stride, 74.5);
      final old = withProfile().toJson();
      (old['move'] as Map).remove('stride');
      expect(AppData.fromJson(jsonDecode(jsonEncode(old))).move.stride, isNull);
    });
  });
}
