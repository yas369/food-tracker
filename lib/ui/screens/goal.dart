// Your goal: the plan, your body numbers and activity. Opened from Me, and
// once after first-run setup.

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../models.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> openGoal(BuildContext context, AppStore store) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoalScreen(store: store)));

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  // Edits a draft. Once a profile exists every change saves straight away; on
  // first run nothing is saved until "Save and start tracking".
  late Profile draft = widget.store.d.profile?.copy() ?? Profile();
  late final own = TextEditingController(text: draft.override?.toString() ?? '');
  late final bool first = widget.store.d.profile == null;

  AppStore get store => widget.store;

  @override
  void dispose() {
    own.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    if (!first && estimate(draft, moveCredit: store.c.moveCredit) != null) store.setProfile(draft.copy());
  }

  void _save() {
    final e = estimate(draft, moveCredit: store.c.moveCredit);
    if (e == null && draft.override == null) {
      toast(context, 'Fill in age, height and weight, or set a limit');
      return;
    }
    store.setProfile(draft.copy());
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('${first ? 'All set! ' : ''}Daily limit: ${fmt(store.c.baseTarget)} kcal')));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final e = estimate(draft, moveCredit: c.moveCredit);
    final limit = draft.override ?? e?.target ?? 0;
    return PopScope(
      canPop: !first,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.bg,
          automaticallyImplyLeading: !first,
          title: Text(first ? 'Last step: your goal' : 'Your goal', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          if (first) const Padding(padding: EdgeInsets.only(bottom: 12), child: Muted('Pick a plan and set your numbers. Your daily calorie limit is worked out from them.', size: 15)),
      // Plan
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Your plan'),
          for (final pl in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: draft.plan == pl.id && draft.override == null ? p.brandSoft : p.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18), side: BorderSide(color: draft.plan == pl.id && draft.override == null ? p.brand : p.line, width: 2)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    draft
                      ..plan = pl.id
                      ..override = null;
                    own.clear();
                    _changed();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      EmojiBox(pl.emoji, size: 50, bg: p.soft(pl.tint), radius: 16),
                      gap12,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pl.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          Muted(pl.desc),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(e == null ? '–' : fmt(e.targets[pl.id]!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const Muted('kcal/day', size: 11),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            ShaderMask(
              shaderCallback: (r) => LinearGradient(colors: [p.brand, p.brand2]).createShader(r),
              child: Text(limit > 0 ? fmt(limit) : '–', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            gap8,
            const Flexible(child: Muted('kcal a day', size: 15)),
          ]),
          Muted(e == null
              ? 'Fill in your age, height and weight.'
              : 'You burn about ${fmt(e.tdee)} kcal a day.${draft.override != null ? ' You’ve set your own limit.' : ''}'
                  '${e.floored && draft.override == null ? ' The low plan is held at a safe minimum, so don’t go lower without a doctor.' : ''}'
                  '${draft.plan == 'high' && draft.override == null ? ' The high plan is for very active days or building muscle. If you want to stop overeating, choose low or medium.' : ''}'
                  ' It’s an estimate: if your weight doesn’t move after 3–4 weeks, adjust.'),
        ]),
      ),

      // About you
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('About you'),
          Pairs(
            children: [
              _tile(p, 'AGE', NumberStepper(value: draft.age.toDouble(), min: 15, max: 90, label: 'age', onChanged: (v) {
                draft.age = v.round();
                _changed();
              })),
              _tile(p, 'SEX', Row(children: [
                for (final (id, label) in [('m', '♂ Male'), ('f', '♀ Female')])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: draft.sex == id ? p.brand : p.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            draft.sex = id;
                            _changed();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: draft.sex == id ? Colors.white : p.muted)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ])),
              _tile(p, 'HEIGHT · CM', NumberStepper(value: draft.height.toDouble(), min: 120, max: 220, label: 'height', onChanged: (v) {
                draft.height = v.round();
                _changed();
              })),
              _tile(p, 'WEIGHT · KG', NumberStepper(value: draft.weight, step: .5, min: 30, max: 250, label: 'weight', onChanged: (v) {
                draft.weight = v;
                _changed();
              })),
            ],
          ),
          if (c.moveCredit) const Padding(padding: EdgeInsets.only(top: 12), child: Muted('🏃 Movement tracking is on, so your activity comes from steps and workouts in the Move tab.')),
          gap12,
          Opacity(
            opacity: c.moveCredit ? .45 : 1,
            child: IgnorePointer(
              ignoring: c.moveCredit,
              child: Pairs(
                gap: 8,
                children: [
                  for (final a in activities)
                    Material(
                      color: draft.activity == a.v ? p.brandSoft : p.surface2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: draft.activity == a.v ? p.brand : Colors.transparent, width: 2)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          draft.activity = a.v;
                          _changed();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.emoji, style: const TextStyle(fontSize: 22)),
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Muted(a.desc, size: 12),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: draft.override != null,
              title: Text('Set my own daily limit', style: TextStyle(color: p.brand, fontWeight: FontWeight.w700, fontSize: 14)),
              children: [
                TextField(
                  controller: own,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Daily limit (kcal). Leave blank to use your plan'),
                  onChanged: (v) {
                    final n = int.tryParse(v.trim());
                    if (v.trim().isEmpty) {
                      draft.override = null;
                    } else if (n != null && n >= 1000 && n <= 5000) {
                      draft.override = n;
                    } else {
                      return;
                    }
                    _changed();
                  },
                ),
              ],
            ),
          ),
          gap8,
        ]),
      ),

        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: GoButton(first ? 'Save and start tracking' : 'Done', big: true, onPressed: _save),
          ),
        ),
      ),
    );
  }

  Widget _tile(Pal p, String label, Widget child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.muted, letterSpacing: .5)),
          gap8,
          child,
        ]),
      );
}
