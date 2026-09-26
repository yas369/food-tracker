// Move shows steps and calories burnt; adding a workout opens a sheet, and the
// details and settings fold away.

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../store.dart';
import '../feedback.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets.dart';

class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  final manual = TextEditingController();

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final v = store.d.move.manual[store.today];
    manual.text = v == null ? '' : '$v';
  }

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> _addWorkout() async {
    final c = store.c;
    final picked = await showModalBottomSheet<(String, int)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _WorkoutSheet(kg: c.bodyKg, stepsCount: store.d.move.on && store.steps.granted),
    );
    if (picked == null || !mounted) return;
    store.addWorkout(picked.$1, picked.$2);
    final w = workoutInfo(picked.$1)!;
    toast(context, '${w.title} added · ${fmt((w.met - 1) * c.bodyKg * picked.$2 / 60)} kcal');
  }

  @override
  Widget build(BuildContext context) {
    final c = store.c;
    final mv = store.d.move;
    final p = Pal.of(context);
    final k = store.today;
    final steps = c.stepsOn(k);
    final goal = mv.goal;
    final burnt = c.burntOn(k);
    final sensor = store.steps;
    final list = c.workoutsOn(k);
    final days = [for (var i = 6; i >= 0; i--) addDays(k, -i)];
    final sk = c.stepKcal(k).round();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
      AppCard(
        gradient: heroGradient(p),
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Ring(progress: steps / goal, level: 'ok', big: fmt(steps), sub: 'of ${fmt(goal)} steps', size: 120),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmt(burnt)} kcal', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const Text('burnt today', style: TextStyle(color: Colors.white70)),
              gap8,
              Text('${c.kmOf(steps).toStringAsFixed(1)} km · ${list.fold(0, (a, w) => a + w.min)} workout min', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      if (!mv.on)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Track your movement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            gap4,
            Muted(sensor.supported
                ? 'Your phone counts your steps. Steps and workouts become calories burnt, added to your food limit.'
                : 'Log workouts here, or type in steps from a watch. Automatic step counting works in the Android app.'),
            gap12,
            GoButton('Start tracking', icon: Icons.directions_walk, onPressed: () async {
              await store.startMove();
              if (context.mounted) toast(context, 'Movement tracking on');
            }),
          ]),
        )
      else if (sensor.supported && (!sensor.available || !sensor.granted))
        AppCard(
          color: p.medSoft,
          child: Row(children: [
            Icon(Icons.info_outline, color: p.med),
            gap12,
            Expanded(
              child: Text(!sensor.available
                  ? 'This phone has no step sensor. Log workouts instead, or type in steps from a watch in Settings below.'
                  : sensor.blocked
                      ? 'Step counting is blocked. In Android settings, open Permissions, then Physical activity, and choose Allow.'
                      : 'Step counting needs the “Physical activity” permission.'),
            ),
            if (sensor.available)
              TextButton(
                onPressed: () async {
                  if (sensor.blocked) {
                    await sensor.openSettings(); // checked again when you come back
                  } else {
                    await store.startMove();
                  }
                },
                child: Text(sensor.blocked ? 'Open settings' : 'Allow'),
              ),
          ]),
        )
      else if (sensor.supported && sensor.lastReading == null)
        _status(p, Icons.hourglass_empty, 'Waiting for your phone’s step sensor. Walk a few steps and the count will move.'),
      if (mv.on && (mv.manual[k] ?? -1) >= (mv.days[k] ?? 0))
        _status(p, Icons.watch_outlined,
            'Showing the ${fmt(mv.manual[k]!)} steps you typed in from a watch; the phone has counted ${fmt(mv.days[k] ?? 0)}. Clear the watch steps in Settings to use the phone’s count.'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Workouts today'),
          if (list.isEmpty) const Muted('None yet.'),
          for (var i = 0; i < list.length; i++)
            Row(children: [
              IconTile(workoutIcon(list[i].id), size: 36, radius: 11),
              gap12,
              Expanded(child: Text('${workoutInfo(list[i].id)?.title ?? list[i].id} · ${list[i].min} min')),
              Text('${fmt(c.workoutKcal(list[i]))} kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.close, size: 18, color: p.muted),
                onPressed: () {
                  final w = store.removeWorkout(i);
                  if (w != null) showUndo(context, 'Removed ${workoutInfo(w.id)?.title ?? 'workout'}', () => store.restoreWorkout(i, w));
                },
              ),
            ]),
          gap12,
          SoftButton('Add a workout', icon: Icons.add, onPressed: _addWorkout),
        ]),
      ),
      AppCard(
        child: Column(children: [
          SectionTitle('Steps this week', trailing: '${fmt(days.fold(0, (a, d) => a + c.stepsOn(d)))} steps'),
          DayBars(
            values: [for (final d in days) c.stepsOn(d)],
            labels: [for (final d in days) weekdayLetter(d)],
            colors: [
              for (final d in days) c.stepsOn(d) >= goal ? const [Color(0xFF4ADE80), Color(0xFF0FA548)] : [p.brand2, p.brand],
            ],
            line: goal.toDouble(),
            lineLabel: 'goal ${fmt(goal)}',
            highlight: 6,
            height: 140,
          ),
        ]),
      ),
      Fold(
        title: 'How calories burnt are counted',
        children: [
          _row(p, 'Steps above ${fmt(Calc.baseSteps)}', '${fmt(sk)} kcal'),
          _row(p, 'Workouts', '${fmt(burnt - sk)} kcal'),
          gap8,
          Muted(c.moveCredit
              ? 'Added to today’s food limit: ${fmt(c.baseTarget)} + ${fmt(burnt)} = ${fmt(c.dailyTarget(k))} kcal. Estimates from your weight (${fmtQty(c.bodyKg)} kg). The first ${fmt(Calc.baseSteps)} steps are everyday moving about, already in your limit.'
              : 'Not added to your food limit (switch it on in Settings below). Estimates from your weight (${fmtQty(c.bodyKg)} kg).'),
          if (sensor.supported && mv.on) ...[
            gap8,
            const Muted('Steps come from your phone’s step sensor. On some phones it only counts reliably if you open Plate Check about once a day.'),
          ],
        ],
      ),
      Fold(
        title: 'Settings',
        children: [
          Row(children: [
            const Expanded(child: Text('Daily step goal')),
            SizedBox(width: 150, child: NumberStepper(value: goal.toDouble(), step: 500, min: 1000, max: 30000, label: 'step goal', onChanged: (v) => store.setStepGoal(v.round()))),
          ]),
          gap8,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add calories I burn to my food limit'),
            subtitle: const Text('Your limit starts from a desk-job baseline and grows as you move.'),
            value: c.moveCredit,
            onChanged: mv.on ? store.setCredit : null,
          ),
          Row(children: [
            const Expanded(child: Text('Steps from a watch today')),
            SizedBox(
              width: 100,
              child: TextField(
                controller: manual,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '0'),
                onSubmitted: (v) => store.setManualSteps(v.trim().isEmpty ? null : int.tryParse(v.trim())),
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  final v = manual.text.trim();
                  final cur = mv.manual[k];
                  if ((v.isEmpty && cur != null) || (v.isNotEmpty && int.tryParse(v) != cur)) store.setManualSteps(v.isEmpty ? null : int.tryParse(v));
                },
              ),
            ),
          ]),
        ],
      ),
    ]);
  }

  Widget _status(Pal p, IconData icon, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: p.muted),
          const SizedBox(width: 10),
          Expanded(child: Muted(text)),
        ]),
      );

  Widget _row(Pal p, String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(a)), Text(b, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

/// Pick a workout, then how long.
class _WorkoutSheet extends StatefulWidget {
  const _WorkoutSheet({required this.kg, required this.stepsCount});
  final double kg;
  final bool stepsCount;
  @override
  State<_WorkoutSheet> createState() => _WorkoutSheetState();
}

class _WorkoutSheetState extends State<_WorkoutSheet> {
  WorkoutInfo? picked;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final w = picked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (w != null) ...[IconTile(workoutIcon(w.id), size: 36, radius: 11), gap12],
            Expanded(child: Text(w == null ? 'What did you do?' : '${w.title}: how long?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          gap12,
          if (w == null)
            LayoutBuilder(builder: (context, box) {
              final size = (box.maxWidth - 3 * 8) / 4;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in workouts)
                  SizedBox(
                    width: size,
                    child: Material(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => picked = x),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                          child: Column(children: [
                            Icon(workoutIcon(x.id), size: 28, color: p.brand),
                            gap4,
                            Text(x.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]);
            })
          else ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in [10, 15, 20, 30, 45, 60, 90])
                ActionChip(label: Text('$m min · ${fmt((w.met - 1) * widget.kg * m / 60)} kcal'), onPressed: () => Navigator.pop(context, (w.id, m))),
            ]),
            if (w.id == 'walk' && widget.stepsCount) const Padding(padding: EdgeInsets.only(top: 10), child: Muted('Your steps already count walks. Add one only if your phone wasn’t with you.')),
            gap8,
            TextButton.icon(onPressed: () => setState(() => picked = null), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Pick another')),
          ],
        ]),
      ),
    );
  }
}
