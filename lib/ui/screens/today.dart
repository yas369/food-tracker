import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../data/foods.dart';
import '../../logic.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_food.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.store, required this.day, required this.onDay, required this.goMe});
  final AppStore store;
  final String day;
  final ValueChanged<String> onDay;
  final VoidCallback goMe;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final today = store.today;
    final isToday = day == today;
    final entries = c.entriesOn(day);
    final total = sumKcal(entries);
    final target = c.dailyTarget(day);
    final level = levelFor(total, target);
    final left = target - total;
    final burnt = c.moveCredit ? c.burntOn(day) : 0;

    String status, sub;
    if (target <= 0) {
      status = 'Set your goal';
      sub = 'Tap Me below. It takes 20 seconds.';
    } else if (entries.isEmpty) {
      status = isToday ? 'Fresh start! 🌱' : 'Nothing logged';
      sub = '${fmt(target)} kcal to spend ${isToday ? 'today' : 'that day'}.';
    } else if (level == 'over') {
      status = '${fmt(-left)} kcal over';
      sub = isToday ? 'Stop here for today. Tomorrow starts fresh.' : 'Went past the limit that day.';
    } else if (level == 'warn') {
      status = 'Nearly there';
      sub = isToday ? 'Past 80%. Keep the next meal light.' : 'Close to the limit.';
    } else {
      status = 'On track 💪';
      sub = '${fmt(left)} kcal still to go.';
    }

    final profile = store.d.profile;
    final planLabel = profile == null
        ? 'limit'
        : burnt > 0
            ? 'limit + moves'
            : profile.override != null
                ? 'own limit'
                : '${planInfo(profile.plan).name.split(' ').first.toLowerCase()} plan';

    return ListView(
      padding: const EdgeInsets.only(bottom: 160),
      children: [
        HeroBox(
          child: Column(children: [
            Row(children: [
              _NavBtn('‹', 'Previous day', () => onDay(addDays(day, -1))),
              Expanded(child: Text(dayLabel(day, today), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              _NavBtn('›', 'Next day', isToday ? null : () => onDay(addDays(day, 1))),
            ]),
            gap8,
            Row(children: [
              Ring(progress: target > 0 ? total / target : 0, level: level, big: fmt(total), sub: target > 0 ? '${(total / target * 100).round()}% of limit' : 'kcal eaten'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(status, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                  gap4,
                  Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
            ]),
            gap16,
            Row(children: [
              Expanded(child: HeroStat(fmt(total), 'eaten')),
              gap8,
              Expanded(child: HeroStat(target > 0 ? fmt(left.abs()) : '–', left < 0 ? 'over' : 'left', valueColor: left < 0 ? const Color(0xFFFDA4C0) : const Color(0xFF86EFAC))),
              gap8,
              Expanded(child: HeroStat(target > 0 ? fmt(target) : '–', planLabel)),
            ]),
            if (burnt > 0) ...[
              gap12,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0x3822C55E), borderRadius: BorderRadius.circular(12)),
                child: Text('🔥 +${fmt(burnt)} kcal earned by moving · ${fmt(c.stepsOn(day))} steps',
                    style: const TextStyle(color: Color(0xFFD9FBE5), fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            if (isToday && target > 0 && level != 'ok') _Banner(level: level, left: left),
            _MixCard(store: store, day: day),
            for (final m in meals) _MealCard(store: store, day: day, meal: m, target: target),
            AppCard(
              gradient: LinearGradient(colors: [p.greenSoft, p.brandSoft]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('💡 Why it matters'),
                Text(tips[dayNum(day) % tips.length], style: const TextStyle(fontSize: 15, height: 1.45)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn(this.t, this.label, this.onTap);
  final String t;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Opacity(
          opacity: onTap == null ? .3 : 1,
          child: Material(
            color: Colors.white.withValues(alpha: .14),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 38, height: 38, child: Center(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 22)))),
            ),
          ),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.level, required this.left});
  final String level;
  final double left;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final over = level == 'over';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: over ? p.highSoft : p.medSoft, borderRadius: BorderRadius.circular(18)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(over ? '🛑' : '⚠️', style: const TextStyle(fontSize: 24)),
        gap12,
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: over ? 'You’ve passed today’s limit.\n' : '${fmt(left)} kcal left for today.\n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            TextSpan(
                text: over
                    ? 'Still hungry? Have water, buttermilk, cucumber or a fruit, and close the kitchen for today.'
                    : 'Plan what you’ll eat next before you get hungry.',
                style: const TextStyle(fontSize: 14)),
          ])),
        ),
      ]),
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({required this.store, required this.day});
  final AppStore store;
  final String day;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final entries = c.entriesOn(day);
    final mix = c.mixOf(entries);
    final mt = mix.values.fold(0.0, (a, b) => a + b);
    final isToday = day == store.today;
    final hour = store.now.hour;

    // Quality nudges
    double count(String tag) => entries.where((e) => e.tags.contains(tag)).fold(0.0, (a, e) => a + e.qty);
    final fried = count('fried'), sweet = count('sweet'), plant = count('plant'), protein = count('protein');
    final nudges = <(String, String)>[];
    if (fried >= 3) {
      nudges.add(('🍳', '${fmtQty(fried)} fried items so far. Fried food is the fastest way to use up a day’s calories.'));
    } else if (fried == 2) {
      nudges.add(('🍳', 'Two fried items already. Make the rest of today’s food non-fried.'));
    }
    if (sweet >= 3) nudges.add(('🍬', '${fmtQty(sweet)} sweet items today, including sweet tea and coffee. Try one without sugar next time.'));
    if (entries.isNotEmpty && plant == 0 && (!isToday || hour >= 14)) {
      nudges.add(('🥦', 'No vegetables or fruit logged ${isToday ? 'yet' : 'that day'}. Aim for about half your plate.'));
    }
    if (entries.length >= 3 && protein == 0) nudges.add(('🥚', 'No protein yet. Dal, sundal, curd or eggs will keep you fuller.'));
    final unhungry = {for (final e in entries) if (e.hunger != null && e.hunger! <= 2) e.b}.length;
    if (unhungry >= 2) nudges.add(('🧭', 'You ate $unhungry times ${isToday ? 'today' : 'that day'} without being hungry. That’s where overeating usually starts.'));
    if (isToday && hour >= 22 && entries.any((e) => DateTime.fromMillisecondsSinceEpoch(e.t).hour >= 22)) {
      nudges.add(('🌙', 'Late-night eating tends to be habit rather than hunger. Try brushing your teeth after dinner to close the kitchen.'));
    }

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('🎯 Calorie mix', trailing: mt == 0 ? null : mix['h']! / mt > .5 ? 'Mostly high-calorie' : mix['l']! / mt >= .3 ? 'Nice balance' : 'Add more green'),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 14,
            child: mt == 0
                ? Container(color: p.surface2)
                : Row(children: [
                    for (final k in ['l', 'm', 'h'])
                      if (mix[k]! > 0) Expanded(flex: (mix[k]! / mt * 1000).round(), child: Container(color: p.levelColor(k))),
                  ]),
          ),
        ),
        gap8,
        if (mt == 0)
          const Muted('Log food to see how much comes from low, medium and high calorie foods.')
        else
          Wrap(spacing: 14, children: [
            for (final k in ['l', 'm', 'h'])
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: p.levelColor(k), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Muted('${levelNames[k]} ${(mix[k]! / mt * 100).round()}%'),
              ]),
          ]),
        for (final (e, t) in nudges)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
            ]),
          ),
      ]),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.store, required this.day, required this.meal, required this.target});
  final AppStore store;
  final String day;
  final MealInfo meal;
  final int target;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final all = c.entriesOn(day);
    final idx = [for (var i = 0; i < all.length; i++) if (all[i].meal == meal.id) i];
    final sub = idx.fold(0.0, (a, i) => a + all[i].total);
    final budget = ((target * meal.share) / 10).round() * 10;
    final plan = idx.isEmpty && day == store.today && target > 0 ? c.planFor(store.today, meal.id) : null;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          EmojiBox(meal.emoji, bg: p.soft(meal.tint)),
          gap12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meal.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Muted('${fmt(sub)}${budget > 0 ? ' / ~${fmt(budget)}' : ''} kcal'),
              if (budget > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (sub / budget).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: p.surface2,
                    color: sub > budget ? p.high : p.brand,
                  ),
                ),
              ],
            ]),
          ),
          gap12,
          AddChip(onTap: () => openAddFood(context, store, day, meal: meal.id)),
        ]),
        if (plan != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Text('📋', style: TextStyle(fontSize: 22)),
              gap8,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plan: ${plan.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Muted('${plan.items.map((x) => (x.qty == 1 ? '' : '${fmtQty(x.qty)} ') + x.f.name.toLowerCase()).join(' + ')} · ${fmt(plan.kcal)} kcal', size: 12),
                ]),
              ),
              gap8,
              GoButton('I ate this', expand: false, onPressed: () {
                final k = store.logPlan(meal.id);
                if (k != null) toast(context, '${meal.label} logged ✅ ${fmt(k)} kcal');
              }),
            ]),
          ),
        for (final i in idx) _EntryRow(store: store, day: day, index: i),
      ]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.store, required this.day, required this.index});
  final AppStore store;
  final String day;
  final int index;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final e = store.c.entriesOn(day)[index];
    final lv = levelOf(e.kcal);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Row(children: [
        EmojiBox(emojiFor(e.f, store.c.food(e.f)?.cat ?? ''), size: 34, bg: p.levelSoft(lv), radius: 10),
        gap12,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: const TextStyle(fontSize: 15)),
            Muted('${qtyUnit(e.qty, e.unit)}${e.hunger != null ? ' · hunger ${e.hunger}/5' : ''}', size: 12),
          ]),
        ),
        Text(fmt(e.total), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Remove ${e.name}',
          style: IconButton.styleFrom(backgroundColor: p.surface2, minimumSize: const Size(30, 30), padding: EdgeInsets.zero),
          icon: Icon(Icons.close, size: 16, color: p.muted),
          onPressed: () {
            final removed = store.removeEntry(day, index);
            toast(context, 'Removed ${removed.name}');
          },
        ),
      ]),
    );
  }
}
