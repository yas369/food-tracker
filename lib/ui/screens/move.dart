import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  String? picked;
  final manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    final v = widget.store.d.move.manual[widget.store.today];
    manual.text = v == null ? '' : '$v';
  }

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final c = store.c;
    final mv = store.d.move;
    final p = Pal.of(context);
    final k = store.today;
    final steps = c.stepsOn(k);
    final goal = mv.goal;
    final burnt = c.burntOn(k);
    final sensor = store.steps;

    Widget? setup;
    if (!mv.on) {
      setup = AppCard(
        gradient: heroGradient(p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🏃 Track your movement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          gap8,
          Text(
              sensor.supported
                  ? 'Your phone counts your steps. Plate Check turns them, and any workouts you add, into calories burnt and adds those to your food limit.'
                  : 'Log workouts here, or type in steps from a watch. Automatic step counting works in the Android app.',
              style: const TextStyle(color: Colors.white70)),
          gap12,
          GoButton('Start tracking', onPressed: () async {
            await store.startMove();
            if (context.mounted) toast(context, 'Movement tracking on 🏃');
          }),
          gap8,
          const Text('Your limit then starts from a desk-job baseline and grows as you move, so nothing is counted twice.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );
    } else if (sensor.supported && !sensor.available) {
      setup = _banner(p, '📵', 'This phone has no step sensor.', 'You can still log workouts, or type in steps from a watch below.');
    } else if (sensor.supported && !sensor.granted) {
      setup = _banner(p, '🔒', 'Step counting needs permission.', 'Allow “Physical activity” for Plate Check.',
          action: SoftButton('Allow', slim: true, onPressed: () async {
            await store.startMove();
            setState(() {});
          }));
    } else if (sensor.supported) {
      setup = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Muted('Steps come from your phone’s step sensor. On some phones it only counts reliably if you open Plate Check about once a day.'
            '${sensor.error.isEmpty ? '' : ' (Last reading: ${sensor.error})'}'),
      );
    }

    final sk = c.stepKcal(k).round();
    final list = c.workoutsOn(k);
    final pw = picked == null ? null : workoutInfo(picked!);
    final days = [for (var i = 6; i >= 0; i--) addDays(k, -i)];

    return ListView(padding: const EdgeInsets.only(bottom: 120), children: [
      HeroBox(
        child: Column(children: [
          gap12,
          Row(children: [
            Ring(progress: steps / goal, level: 'ok', big: fmt(steps), sub: 'of ${fmt(goal)} steps'),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps >= goal ? 'Goal reached! 🎉' : steps > 0 ? '${fmt(goal - steps)} steps to go' : 'Let’s get moving',
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                gap4,
                const Text('Every step counts toward today’s limit.', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
          gap16,
          Row(children: [
            Expanded(child: HeroStat(c.kmOf(steps).toStringAsFixed(1), 'km')),
            gap8,
            Expanded(child: HeroStat(fmt(burnt), 'kcal burnt', valueColor: const Color(0xFF86EFAC))),
            gap8,
            Expanded(child: HeroStat('${list.fold(0, (a, w) => a + w.min)}', 'workout min')),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ?setup,
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('🔥 Calories burnt today'),
              _row(p, '👟 Steps above ${fmt(Calc.baseSteps)}', '${fmt(sk)} kcal'),
              _row(p, '💪 Workouts', '${fmt(burnt - sk)} kcal'),
              _row(p, '🔥 Burnt today', '${fmt(burnt)} kcal', total: true),
              gap8,
              Muted(c.moveCredit
                  ? 'Added to today’s food limit: ${fmt(c.baseTarget)} + ${fmt(burnt)} = ${fmt(c.dailyTarget(k))} kcal. Estimates from your weight (${fmtQty(c.bodyKg)} kg).'
                  : 'Not added to your food limit. Switch it on below. Estimates from your weight (${fmtQty(c.bodyKg)} kg).'),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('➕ Add a workout'),
              LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 3 * 8) / 4;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final x in workouts)
                    SizedBox(
                      width: w,
                      child: Material(
                        color: picked == x.id ? p.brandSoft : p.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: picked == x.id ? p.brand : p.line, width: 1.5)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => picked = picked == x.id ? null : x.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                            child: Column(children: [
                              Text(x.emoji, style: const TextStyle(fontSize: 26)),
                              gap4,
                              Text(x.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
              if (pw != null) ...[
                gap12,
                Text('${pw.emoji} ${pw.title}: how long?', style: const TextStyle(fontWeight: FontWeight.w700)),
                gap8,
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in [10, 15, 20, 30, 45, 60, 90])
                    ActionChip(
                      label: Text('$m min · ${fmt((pw.met - 1) * c.bodyKg * m / 60)} kcal'),
                      onPressed: () {
                        store.addWorkout(pw.id, m);
                        setState(() => picked = null);
                        toast(context, '${pw.emoji} ${pw.title} added · ${fmt((pw.met - 1) * c.bodyKg * m / 60)} kcal');
                      },
                    ),
                ]),
                if (pw.id == 'walk' && mv.on && sensor.granted) const Padding(padding: EdgeInsets.only(top: 8), child: Muted('Your steps already count walks. Add one here only if your phone wasn’t with you.')),
              ],
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 10), child: Muted('No workouts yet today.'))
              else
                for (var i = 0; i < list.length; i++)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
                    child: Row(children: [
                      EmojiBox(workoutInfo(list[i].id)?.emoji ?? '💪', size: 34, radius: 10, bg: p.greenSoft),
                      gap12,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(workoutInfo(list[i].id)?.title ?? list[i].id),
                          Muted('${list[i].min} min', size: 12),
                        ]),
                      ),
                      Text(fmt(c.workoutKcal(list[i])), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(tooltip: 'Remove', icon: Icon(Icons.close, size: 16, color: p.muted), onPressed: () => store.removeWorkout(i)),
                    ]),
                  ),
            ]),
          ),
          AppCard(
            child: Column(children: [
              SectionTitle('👟 Last 7 days', trailing: '${fmt(days.fold(0, (a, d) => a + c.burntOn(d)))} kcal burnt this week'),
              DayBars(
                values: [for (final d in days) c.stepsOn(d)],
                labels: [for (final d in days) weekdayLetter(d)],
                colors: [
                  for (final d in days)
                    c.stepsOn(d) >= goal ? const [Color(0xFF4ADE80), Color(0xFF0FA548)] : [p.brand2, p.brand],
                ],
                line: goal.toDouble(),
                lineLabel: 'goal ${fmt(goal)}',
                highlight: 6,
              ),
            ]),
          ),
          AppCard(
            child: Column(children: [
              const SectionTitle('⚙️ Movement settings'),
              SettingRow(
                first: true,
                emoji: '🎯',
                title: 'Daily step goal',
                trailing: SizedBox(width: 150, child: NumberStepper(value: goal.toDouble(), step: 500, min: 1000, max: 30000, label: 'step goal', onChanged: (v) => store.setStepGoal(v.round()))),
              ),
              SettingRow(
                emoji: '🍽️',
                title: 'Add calories I burn to my food limit',
                note: 'Your limit starts from a desk-job baseline and grows as you move.',
                trailing: Switch(value: c.moveCredit, onChanged: mv.on ? store.setCredit : null),
              ),
              SettingRow(
                emoji: '⌚',
                title: 'Steps from a watch',
                note: 'Type today’s total if your phone didn’t count them. The higher number is used.',
                trailing: SizedBox(
                  width: 96,
                  child: TextField(
                    controller: manual,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '0'),
                    onSubmitted: (v) => store.setManualSteps(v.trim().isEmpty ? null : int.tryParse(v.trim())),
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      final v = manual.text.trim();
                      final cur = mv.manual[k];
                      if ((v.isEmpty && cur != null) || (v.isNotEmpty && int.tryParse(v) != cur)) {
                        store.setManualSteps(v.isEmpty ? null : int.tryParse(v));
                      }
                    },
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _row(Pal p, String a, String b, {bool total = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(fontSize: total ? 17 : 15, fontWeight: total ? FontWeight.w800 : FontWeight.w400, color: total ? p.green : null))),
          Text(b, style: TextStyle(fontSize: total ? 17 : 15, fontWeight: FontWeight.w800, color: total ? p.green : null)),
        ]),
      );

  Widget _banner(Pal p, String emoji, String title, String text, {Widget? action}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.medSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          gap12,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(text),
              if (action != null) ...[gap8, action],
            ]),
          ),
        ]),
      );
}
