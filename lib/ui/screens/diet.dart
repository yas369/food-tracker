import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../store.dart';
import '../feedback.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key, required this.store, required this.goMe});
  final AppStore store;
  final VoidCallback goMe;
  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  int offset = 0; // 0 today, 1 tomorrow, 2 the day after

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final c = store.c;
    final p = Pal.of(context);
    final today = store.today;
    final day = addDays(today, offset);
    final target = c.baseTarget;
    final plans = [for (final m in meals) (m, c.planFor(day, m.id))];
    final dayTotal = plans.fold(0, (a, x) => a + (x.$2?.kcal ?? 0));
    final pref = dietPrefInfo(store.d.settings.dietPref);
    final have = c.pantry.toList();
    final logged = {for (final e in c.entriesOn(day)) e.meal};
    final burnt = offset == 0 && c.moveCredit ? c.burntOn(day) : 0;
    // Today, meals already eaten shrink to one line at the bottom.
    final order = offset == 0 ? [...plans.where((x) => !logged.contains(x.$1.id)), ...plans.where((x) => logged.contains(x.$1.id))] : plans;
    final times = {for (final r in store.d.settings.reminders) if (r.meal != null) r.meal!: r.time};

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          for (var n = 0; n < 3; n++)
            ButtonSegment(value: n, label: Text(n == 0 ? 'Today' : n == 1 ? 'Tomorrow' : weekdayShort(addDays(today, n)))),
        ],
        selected: {offset},
        onSelectionChanged: (s) => setState(() => offset = s.first),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
        child: Text.rich(TextSpan(style: TextStyle(color: p.muted, fontSize: 14), children: [
          TextSpan(text: target > 0 ? '${fmt(dayTotal)} kcal planned' : 'Set up your goal first', style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
          if (target > 0) TextSpan(text: ' · fits your ${fmt(target)} limit · ${pref.short}'),
          if (target > 0 && burnt > 0) TextSpan(text: ' · +${fmt(burnt)} from moving'),
        ])),
      ),
      for (final (m, plan) in order)
        if (offset == 0 && logged.contains(m.id))
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconTile(mealIcon(m.id), size: 32, radius: 10, bg: p.soft(m.tint), fg: p.strong(m.tint)),
              gap12,
              Expanded(child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              gap8,
              Icon(Icons.check_circle, size: 18, color: p.green),
              gap4,
              Flexible(
                child: Text('Logged · ${fmt(sumKcal(c.entriesOn(day).where((e) => e.meal == m.id).toList()))} kcal',
                    textAlign: TextAlign.end, style: TextStyle(color: p.green, fontWeight: FontWeight.w700)),
              ),
            ]),
          )
        else if (plan != null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconTile(mealIcon(m.id), size: 32, radius: 10, bg: p.soft(m.tint), fg: p.strong(m.tint)),
                gap8,
                Expanded(
                  child: Text('${m.label.toUpperCase()}${times[m.id] != null ? ' · ${clock12(times[m.id]!)}' : ''}',
                      style: TextStyle(fontSize: 12, letterSpacing: .8, fontWeight: FontWeight.w700, color: p.muted)),
                ),
                Text('${fmt(plan.kcal)} kcal', style: TextStyle(fontWeight: FontWeight.w700, color: p.brand)),
              ]),
              gap8,
              Text(plan.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              gap4,
              for (final x in plan.items)
                Padding(padding: const EdgeInsets.only(top: 2), child: Muted('${qtyUnit(x.qty, x.f.unit)} ${x.name.toLowerCase()}', size: 14)),
              gap12,
              Row(children: [
                if (c.dietOptions(m.id).length > 1) Expanded(child: SoftButton('Another option', slim: true, onPressed: () => store.nextOption(day, m.id))),
                if (offset == 0) ...[
                  gap8,
                  Expanded(
                    child: GoButton('I ate this', icon: Icons.check, onPressed: () {
                      final k = store.logPlan(m.id);
                      final b = store.lastBatch;
                      if (k != null && b != null) showUndo(context, '${m.label} logged · ${fmt(k)} kcal', () => store.removeBatch(day, b), buzz: true);
                    }),
                  ),
                ],
              ]),
            ]),
          )
        else if (target > 0)
          AppCard(
            child: Row(children: [
              IconTile(mealIcon(m.id), size: 32, radius: 10, bg: p.soft(m.tint), fg: p.strong(m.tint)),
              gap12,
              Expanded(child: Text('${m.label}: nothing in your kitchen fits.', style: const TextStyle(fontSize: 15))),
              TextButton(onPressed: widget.goMe, child: const Text('Update kitchen')),
            ]),
          ),
      Fold(
        title: 'How plans are made',
        subtitle: 'From your kitchen · ${have.length} items',
        children: [
          const Muted('Amounts are sized so the day fits your limit, using only what you have at home. The limit is a ceiling, not a target: if you’re full on less, stop.', size: 14),
          gap12,
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in have)
              if (pantryInfo[id] != null) Chip(label: Text(pantryInfo[id]!.label), visualDensity: VisualDensity.compact),
          ]),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: widget.goMe, child: const Text('Change in Me'))),
          const _PlateGuide(),
          const Muted('This is general guidance, not medical advice. If you have diabetes, kidney or heart disease, are pregnant, or take medicines that interact with food, check with a doctor or dietitian first.'),
        ],
      ),
    ]);
  }
}

class _PlateGuide extends StatelessWidget {
  const _PlateGuide();
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget row(Color c, IconData icon, String t, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(icon, size: 28, radius: 8, bg: c.withValues(alpha: .16), fg: c),
            gap8,
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), Muted(s, size: 12)])),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('How to fill your plate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        gap12,
        Row(children: [
          SizedBox(width: 116, height: 116, child: CustomPaint(painter: _PlatePainter(p.surface2))),
          gap16,
          Expanded(
            child: Column(children: [
              row(const Color(0xFF22C55E), Icons.eco_outlined, 'Half: vegetables and fruit', 'Poriyal, kootu, salad, fruit'),
              row(const Color(0xFFF59E0B), Icons.rice_bowl_outlined, 'Quarter: grains', 'Rice, idli, dosa, chapati'),
              row(const Color(0xFF8B2CF5), Icons.egg_outlined, 'Quarter: protein', 'Dal, sambar, curd, eggs, fish'),
            ]),
          ),
        ]),
        const Muted('Based on the "My Plate for the Day" idea in India’s ICMR-NIN dietary guidelines. Drink water with meals, and tea or coffee without sugar.'),
      ]),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.rim);
  final Color rim;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2, Paint()..color = rim);
    final r = Rect.fromCircle(center: c, radius: size.width / 2 - 6);
    canvas.drawArc(r, -math.pi / 2, math.pi, true, Paint()..color = const Color(0xFF22C55E));
    canvas.drawArc(r, math.pi / 2, math.pi / 2, true, Paint()..color = const Color(0xFFF59E0B));
    canvas.drawArc(r, math.pi, math.pi / 2, true, Paint()..color = const Color(0xFF8B2CF5));
    // Thin lines between the sections, like a divided plate.
    final gap = Paint()
      ..color = rim
      ..strokeWidth = 3;
    canvas.drawLine(c + Offset(0, -r.height / 2), c + Offset(0, r.height / 2), gap);
    canvas.drawLine(c, c + Offset(-r.width / 2, 0), gap);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.rim != rim;
}
