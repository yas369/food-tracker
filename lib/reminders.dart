// Which reminders to schedule: one per meal per day for the next 14 days,
// re-planned after every change. That lets a logged meal cancel its own
// reminder, and today's text carry today's numbers.

import 'data/catalog.dart';
import 'data/foods.dart';
import 'logic.dart';

const daysAhead = 14;
const idTest = 1, idWait = 2, idStale = 3;

class PlannedReminder {
  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String? meal;
  final bool exact;
  const PlannedReminder(this.id, this.title, this.body, this.at, this.meal, {this.exact = true});
}

int reminderId(String dayKey, int idx) => int.parse(dayKey.replaceAll('-', '')) * 10 + idx;

String reminderMessage(Calc c, String today, String? meal) {
  final target = c.dailyTarget(today);
  final left = target - sumKcal(c.entriesOn(today));
  if (meal == null) {
    return left >= 0
        ? 'You have ${fmt(left)} kcal left, and that’s fine to leave unused. The kitchen is closed for today.'
        : 'You’re ${fmt(-left)} kcal over today. No more snacks tonight. Tomorrow resets.';
  }
  return '${left > 0 ? '${fmt(left)} kcal left today. ' : 'Already at your limit. Keep it light. '}Check how hungry you are, then eat slowly.';
}

List<PlannedReminder> planReminders(Calc c, DateTime now) {
  if (c.baseTarget <= 0) return const [];
  final today = keyOf(now);
  final out = <PlannedReminder>[];
  for (var d = 0; d < daysAhead; d++) {
    final k = addDays(today, d);
    final logged = {for (final e in c.entriesOn(k)) e.meal};
    final tip = tips[dayNum(k) % tips.length];
    final rs = c.d.settings.reminders;
    for (var idx = 0; idx < rs.length; idx++) {
      final r = rs[idx];
      if (!r.on) continue;
      final day = parseKey(k);
      final at = DateTime(day.year, day.month, day.day, r.minutes ~/ 60, r.minutes % 60);
      if (!at.isAfter(now.add(const Duration(seconds: 30)))) continue;
      if (r.meal != null && logged.contains(r.meal)) continue;
      out.add(PlannedReminder(
        reminderId(k, idx),
        r.meal != null ? '${r.label} time' : 'Kitchen closed?',
        d == 0
            ? '${reminderMessage(c, today, r.meal)}\n\n$tip'
            : r.meal != null
                ? 'Check how hungry you are, then eat slowly. $tip'
                : 'Close the kitchen for today. Open Plate Check to see what’s left.',
        at,
        r.meal,
      ));
    }
  }
  // Reminders run out if the app is never opened; say so on the last day.
  final last = parseKey(addDays(today, daysAhead - 1));
  out.add(PlannedReminder(idStale, 'Plate Check misses you',
      'You haven’t opened the app in two weeks, so reminders stop after today. Open it to keep them going.',
      DateTime(last.year, last.month, last.day, 10), null,
      exact: false));
  return out;
}

String mealName(String? meal) => meal == null ? '' : mealInfo(meal).label;
