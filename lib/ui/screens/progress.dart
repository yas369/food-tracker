import 'package:flutter/material.dart';

import '../../data/catalog.dart';
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
    const mealColors = {
      'breakfast': [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      'lunch': [Color(0xFF0FA548), Color(0xFF4ADE80)],
      'snack': [Color(0xFFE0245E), Color(0xFFFB7185)],
      'dinner': [Color(0xFF5B1BAA), Color(0xFF8B2CF5)],
    };

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
      Pairs(
        children: [
          _Stat('🔥', '$streak', 'day streak within limit', const [Color(0xFF5B1BAA), Color(0xFF8B2CF5)]),
          _Stat('✅', '$within/${week.length}', 'logged days within limit', const [Color(0xFF0A8F3E), Color(0xFF22C55E)]),
          _Stat('⚡', week.isEmpty ? '–' : fmt(avg), 'average kcal a day', const [Color(0xFFC2410C), Color(0xFFF59E0B)]),
          _Stat('📅', '${week.length}/7', 'days logged this week', const [Color(0xFFBE123C), Color(0xFFF43F7E)]),
        ],
      ),
      gap16,
      AppCard(
        child: Column(children: [
          const SectionTitle('📊 Last 14 days'),
          DayBars(
            values: [for (final d in days) totals[d]!],
            labels: [for (final d in days) weekdayLetter(d)],
            colors: [for (final d in days) barColors(d)],
            line: c.baseTarget.toDouble(),
            lineLabel: 'limit ${fmt(c.baseTarget)}',
            highlight: 13,
          ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('🍩 Where calories came from', trailing: '7 days'),
          if (weekKcal == 0)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: Muted('🍩  Log a few meals to see this.')))
          else
            Row(children: [
              Donut(parts: [for (final k in ['l', 'm', 'h']) (mix[k]!, p.levelColor(k))], center: '${(mix['l']! / weekKcal * 100).round()}%', caption: 'from low-cal'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(children: [
                  for (final k in ['l', 'm', 'h'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: p.levelColor(k), borderRadius: BorderRadius.circular(4))),
                        gap8,
                        Expanded(child: Text(levelNames[k]!)),
                        Text('${(mix[k]! / weekKcal * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
            ]),
        ]),
      ),
      AppCard(
        child: Column(children: [
          const SectionTitle('🍽️ By meal', trailing: '7 days'),
          for (final m in meals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('${m.emoji} ${m.label}')),
                  Flexible(
                    child: Text('${weekKcal == 0 ? 0 : ((byMeal[m.id] ?? 0) / weekKcal * 100).round()}% · ${fmt(byMeal[m.id] ?? 0)} kcal',
                        textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 10,
                    color: p.surface2,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: weekKcal == 0 ? 0 : (byMeal[m.id] ?? 0) / weekKcal,
                      child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: mealColors[m.id]!))),
                    ),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('🔍 What the pattern says'),
          for (final (e, t) in _insights(c, days, weekEntries, byMeal, weekKcal, week.length, mix))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e, style: const TextStyle(fontSize: 18)), const SizedBox(width: 10), Expanded(child: Text(t))]),
            ),
        ]),
      ),
    ]);
  }

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

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.value, this.label, this.colors);
  final String emoji, value, label;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20)),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -38, bottom: -38, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), shape: BoxShape.circle))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            FittedBox(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
            Text(label, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
        ]),
      );
}
