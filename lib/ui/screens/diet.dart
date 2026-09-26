import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../store.dart';
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
    final times = {for (final r in store.d.settings.reminders) if (r.meal != null) r.meal!: r.time};

    return ListView(padding: const EdgeInsets.only(bottom: 120), children: [
      HeroBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          gap8,
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              for (var n = 0; n < 3; n++)
                Expanded(
                  child: Material(
                    color: n == offset ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => setState(() => offset = n),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Text(n == 0 ? 'Today' : n == 1 ? 'Tomorrow' : weekdayShort(addDays(today, n)),
                            textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: n == offset ? p.brandDeep : Colors.white70)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          gap16,
          Text(target > 0 ? fmt(dayTotal) : '–', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.1)),
          Text(target > 0 ? 'kcal planned of your ${fmt(target)} limit${c.moveCredit ? ' (plus what you burn moving)' : ''}' : 'Set up your goal first',
              style: const TextStyle(color: Colors.white70)),
          gap12,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
            child: Text('${pref.emoji} ${pref.short} · from your profile', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                EmojiBox('🧺', bg: p.greenSoft),
                gap12,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Your kitchen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Muted('${have.length} items at home'),
                  ]),
                ),
              ]),
              gap8,
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final id in have.take(14))
                  if (pantryInfo[id] != null) EmojiBox(pantryInfo[id]!.emoji, size: 38, radius: 12),
                if (have.length > 14) EmojiBox('+${have.length - 14}', size: 38, radius: 12),
              ]),
              gap8,
              Row(children: [
                const Expanded(child: Muted('Plans only use what you have at home.')),
                TextButton(onPressed: widget.goMe, child: const Text('Change in Me')),
              ]),
            ]),
          ),
          const _PlateGuide(),
          for (final (m, plan) in plans)
            if (plan == null)
              if (target > 0)
                AppCard(
                  child: Row(children: [
                    EmojiBox(m.emoji, bg: p.soft(m.tint)),
                    gap12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const Muted('Nothing in your kitchen fits this meal.'),
                      ]),
                    ),
                    TextButton(onPressed: widget.goMe, child: const Text('Update kitchen')),
                  ]),
                )
              else
                const SizedBox.shrink()
            else
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    EmojiBox(m.emoji, bg: p.soft(m.tint)),
                    gap12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: m.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if (times[m.id] != null) TextSpan(text: '  · ${clock12(times[m.id]!)}', style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
                        ])),
                        Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmt(plan.kcal), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.brand)),
                      const Muted('kcal', size: 11),
                    ]),
                  ]),
                  for (final x in plan.items)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
                      child: Row(children: [
                        EmojiBox(emojiFor(x.f.id, x.f.cat), size: 34, radius: 10, bg: p.levelSoft(levelOf(x.f.kcal))),
                        gap12,
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(x.name, style: const TextStyle(fontSize: 15)),
                            Muted(qtyUnit(x.qty, x.f.unit), size: 12),
                          ]),
                        ),
                        Text(fmt(x.kcal), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  gap12,
                  Row(children: [
                    if (c.dietOptions(m.id).length > 1)
                      Expanded(child: SoftButton('🔄 Another option', slim: true, onPressed: () => store.nextOption(day, m.id))),
                    if (offset == 0) ...[
                      gap8,
                      Expanded(
                        child: logged.contains(m.id)
                            ? const SoftButton('✓ Logged', slim: true, onPressed: null)
                            : GoButton('✓ I ate this', onPressed: () {
                                final k = store.logPlan(m.id);
                                if (k != null) toast(context, '${m.label} logged ✅ ${fmt(k)} kcal');
                              }),
                      ),
                    ],
                  ]),
                ]),
              ),
          const Muted(
              'Amounts are sized so the day fits your limit. The limit is a ceiling, not a target: if you’re full on less, stop. This is general guidance, not medical advice. If you have diabetes, kidney or heart disease, are pregnant, or take medicines that interact with food, check with a doctor or dietitian first.'),
        ]),
      ),
    ]);
  }
}

class _PlateGuide extends StatelessWidget {
  const _PlateGuide();
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget row(Color c, String t, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 4), width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            gap8,
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), Muted(s, size: 12)])),
          ]),
        );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('🍽️ How to fill your plate'),
        Row(children: [
          SizedBox(width: 116, height: 116, child: CustomPaint(painter: _PlatePainter(p.surface2))),
          gap16,
          Expanded(
            child: Column(children: [
              row(const Color(0xFF22C55E), 'Half: vegetables and fruit', 'Poriyal, kootu, salad, fruit'),
              row(const Color(0xFFF59E0B), 'Quarter: grains', 'Rice, idli, dosa, chapati'),
              row(const Color(0xFF8B2CF5), 'Quarter: protein', 'Dal, sambar, curd, eggs, fish'),
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
    void emoji(String e, Offset at, double s) {
      final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: s)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    emoji('🥦', c + Offset(size.width * .22, 0), 20);
    emoji('🍚', c + Offset(-size.width * .2, size.width * .2), 17);
    emoji('🫘', c + Offset(-size.width * .2, -size.width * .2), 17);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.rim != rim;
}
