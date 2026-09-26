import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../data/foods.dart';
import '../../logic.dart';
import '../../models.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final today = store.today;
    final days = [for (var i = 13; i >= 0; i--) addDays(today, -i)];
    final totals = {for (final d in days) d: sumKcal(c.entriesOn(d))};
    final week = days.sublist(7).where((d) => c.entriesOn(d).isNotEmpty).toList();
    final avg = week.isEmpty ? 0 : week.fold(0.0, (a, d) => a + totals[d]!) / week.length;
    final within = week.where((d) => totals[d]! <= c.dailyTarget(d)).length;
    final streak = c.streak(today);
    final weekEntries = [for (final d in days.sublist(7)) ...c.entriesOn(d)];
    final weekKcal = sumKcal(weekEntries);
    final mix = c.mixOf(weekEntries);

    List<Color>? barColors(String d) {
      if (c.entriesOn(d).isEmpty) return null;
      final l = levelFor(totals[d]!, c.dailyTarget(d));
      return l == 'over'
          ? [const Color(0xFFFB7185), p.high]
          : l == 'warn'
              ? [const Color(0xFFFBBF24), p.med]
              : [p.brand2, p.brand];
    }

    final byMeal = <String, double>{};
    for (final e in weekEntries) {
      byMeal[e.meal] = (byMeal[e.meal] ?? 0) + e.total;
    }

    final insights = _insights(c, days, weekEntries, byMeal, weekKcal, week.length, mix);
    Widget insight((String, String) x) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(x.$2, style: const TextStyle(fontSize: 14, height: 1.4))),
          ]),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('THIS WEEK', style: TextStyle(fontSize: 12, letterSpacing: .8, fontWeight: FontWeight.w700, color: p.muted)),
          gap8,
          Text(week.isEmpty ? 'Nothing logged yet' : '$within of ${week.length} logged days within your limit',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.25)),
          gap12,
          Row(children: [
            _mini(p, '🔥 $streak', 'day streak'),
            _mini(p, week.isEmpty ? '–' : fmt(avg), 'avg kcal'),
            _mini(p, '${week.length}/7', 'days logged'),
          ]),
        ]),
      ),
      AppCard(
        child: Column(children: [
          const SectionTitle('Last 14 days'),
          DayBars(
            values: [for (final d in days) totals[d]!],
            labels: [for (final d in days) weekdayLetter(d)],
            colors: [for (final d in days) barColors(d)],
            line: c.baseTarget.toDouble(),
            lineLabel: 'limit ${fmt(c.baseTarget)}',
            highlight: 13,
            height: 150,
          ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('What stands out'),
          for (final x in insights.take(2)) insight(x),
        ]),
      ),
      Fold(
        title: 'More details',
        subtitle: 'Where calories came from, by meal, and more',
        children: [
          if (weekKcal > 0) ...[
            const Text('Where calories came from', style: TextStyle(fontWeight: FontWeight.w700)),
            gap12,
            Row(children: [
              Donut(parts: [for (final k in ['l', 'm', 'h']) (mix[k]!, p.levelColor(k))], center: '${(mix['l']! / weekKcal * 100).round()}%', caption: 'from low-cal', size: 110),
              const SizedBox(width: 18),
              Expanded(
                child: Column(children: [
                  for (final k in ['l', 'm', 'h'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: p.levelColor(k), borderRadius: BorderRadius.circular(3))),
                        gap8,
                        Expanded(child: Text(levelNames[k]!)),
                        Text('${(mix[k]! / weekKcal * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
            ]),
            gap16,
            const Text('By meal', style: TextStyle(fontWeight: FontWeight.w700)),
            gap8,
            for (final m in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text('${m.emoji} ${m.label}')),
                    Text('${((byMeal[m.id] ?? 0) / weekKcal * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: (byMeal[m.id] ?? 0) / weekKcal, minHeight: 8, backgroundColor: p.surface2, color: p.brand),
                  ),
                ]),
              ),
          ],
          for (final x in insights.skip(2)) insight(x),
        ],
      ),
      AppCard(
        color: p.greenSoft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tip of the day', style: TextStyle(fontWeight: FontWeight.w700)),
          gap4,
          Text(tips[dayNum(today) % tips.length], style: const TextStyle(fontSize: 14, height: 1.45)),
        ]),
      ),
    ]);
  }

  Widget _mini(Pal p, String v, String label) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
        ]),
      );

  List<(String, String)> _insights(Calc c, List<String> days, List<Entry> weekEntries, Map<String, double> byMeal, double weekKcal, int logged, Map<String, double> mix) {
    final ins = <(String, String)>[];
    if (weekEntries.isEmpty) return [('🌱', 'Log for a few days and patterns will show up here.')];
    if (logged < 5) ins.add(('📅', 'You logged on $logged of the last 7 days. Missing days are usually the days you overate. Logging those matters most.'));
    final top = byMeal.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty) {
      final share = (top.first.value / weekKcal * 100).round();
      final label = mealInfo(top.first.key).label.toLowerCase();
      final tail = top.first.key == 'dinner' && share > 40
          ? 'A heavy dinner is often a sign of eating too little earlier in the day.'
          : top.first.key == 'snack' && share > 25
              ? 'Snacks are adding up. That’s usually the easiest place to cut.'
              : 'Keeping this meal steady will keep the whole day steady.';
      ins.add(('🍽️', 'Your biggest meal is $label, at $share% of your calories. $tail'));
    }
    if (weekKcal > 0 && mix['h']! / weekKcal > .5) ins.add(('🔴', 'More than half your calories came from high-calorie foods. Swapping one of them a day for a green one makes a real difference.'));
    final batches = <String, int>{for (final e in weekEntries) if (e.hunger != null) e.b: e.hunger!};
    if (batches.length >= 3) {
      final low = batches.values.where((h) => h <= 2).length;
      final pct = (low / batches.length * 100).round();
      ins.add(pct >= 30
          ? ('🧭', 'You weren’t really hungry for $low of ${batches.length} meals and snacks ($pct%). That’s the overeating to work on, more than portion size.')
          : ('👏', 'You ate when you were actually hungry most of the time (${100 - pct}%). Good.'));
    }
    final friedDays = days.sublist(7).where((d) => c.entriesOn(d).any((e) => e.tags.contains('fried'))).length;
    if (friedDays >= 5) ins.add(('🍳', 'You had fried food on $friedDays of 7 days. Cutting that to 2–3 days is probably the easiest single change you can make.'));
    final byFood = <String, double>{};
    for (final e in weekEntries) {
      byFood[e.name] = (byFood[e.name] ?? 0) + e.total;
    }
    final tf = byFood.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (tf.isNotEmpty) ins.add(('🏆', 'Most calories this week came from ${tf.first.key}: ${fmt(tf.first.value)} kcal.'));
    return ins;
  }
}
