import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../models.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'onboarding.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key, required this.store, required this.onDone});
  final AppStore store;
  final VoidCallback onDone;
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  // The plan screen edits a draft. Once a profile exists every change saves
  // straight away; on first run nothing is saved until "Save and start".
  late Profile draft = widget.store.d.profile?.copy() ?? Profile();
  late final own = TextEditingController(text: draft.override?.toString() ?? '');

  AppStore get store => widget.store;

  static String fmtQtyNum(double v) => v % 1 == 0 ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  void dispose() {
    own.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    if (store.d.profile != null && estimate(draft, moveCredit: store.c.moveCredit) != null) store.setProfile(draft.copy());
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final me = store.d.me;
    final e = estimate(draft, moveCredit: c.moveCredit);
    final limit = draft.override ?? e?.target ?? 0;
    final have = c.pantry.toList();
    final days = store.d.log.length;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
      // Profile card
      AppCard(
        gradient: heroGradient(p),
        child: Column(children: [
          Row(children: [
            GestureDetector(onTap: () => openSetup(context, store, SetupMode.profile), child: Avatar(me: me, size: 68, border: 3)),
            gap16,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.name.isEmpty ? 'Add your name' : me.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(me.since > 0 ? 'With Plate Check since ${monthYear(DateTime.fromMillisecondsSinceEpoch(me.since))}' : 'Make the app yours',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            AddChip(label: 'EDIT', onDark: true, onTap: () => openSetup(context, store, SetupMode.profile)),
          ]),
          gap12,
          Row(children: [
            Expanded(child: HeroStat('$days', 'days logged')),
            gap8,
            Expanded(child: HeroStat('${c.streak(store.today)}', 'day streak')),
            gap8,
            Expanded(child: HeroStat(store.d.profile == null ? '–' : fmtQtyNum(store.d.profile!.weight), 'kg')),
          ]),
        ]),
      ),

      // Choices, asked once
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('🍽️ Your choices'),
          const Muted('Set once. The app won’t ask again; change them here whenever you like.'),
          gap8,
          SettingRow(first: true, emoji: '🥗', title: 'I eat', note: '${dietPrefInfo(store.d.settings.dietPref).emoji} ${dietPrefInfo(store.d.settings.dietPref).short}',
              trailing: SoftButton('Change', slim: true, onPressed: () => openSetup(context, store, SetupMode.pref))),
          SettingRow(emoji: '🧺', title: 'My kitchen', note: '${have.length} items · ${have.take(8).map((i) => pantryInfo[i]?.emoji ?? '').join(' ')}',
              trailing: SoftButton('Change', slim: true, onPressed: () => openSetup(context, store, SetupMode.kitchen))),
          SettingRow(emoji: '🙂', title: 'Name and photo', note: me.name.isEmpty ? 'Not set' : me.name,
              trailing: SoftButton('Change', slim: true, onPressed: () => openSetup(context, store, SetupMode.profile))),
        ]),
      ),

      if (store.d.profile == null)
        AppCard(
          gradient: heroGradient(p),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('👋 Last step', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            gap4,
            Text('Pick a plan and set your numbers. Your daily calorie limit is worked out from them.', style: TextStyle(color: Colors.white70)),
          ]),
        ),

      // Plan
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('🎯 Your plan'),
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
          const SectionTitle('🧍 About you'),
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
          GoButton(store.d.profile == null ? 'Save and start tracking' : 'Done ✓', onPressed: () {
            if (e == null && draft.override == null) {
              toast(context, 'Fill in age, height and weight, or set a limit');
              return;
            }
            final first = store.d.profile == null;
            store.setProfile(draft.copy());
            toast(context, '${first ? 'All set! ' : ''}Daily limit: ${fmt(store.c.baseTarget)} kcal');
            widget.onDone();
          }),
        ]),
      ),

      _RemindersCard(store: store),
      _HabitsCard(store: store),
      _DataCard(store: store),
      const Muted(
          'Calorie values are typical home-style portions and can be off by 20% or more. Oil and ghee are the usual culprits, so log them separately when you can see them. Food labels: low is up to 100 kcal a portion, medium 101–250, high over 250.'),
    ]);
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

class _RemindersCard extends StatelessWidget {
  const _RemindersCard({required this.store});
  final AppStore store;
  static const emoji = {'breakfast': '🌅', 'lunch': '☀️', 'snack': '🍪', 'dinner': '🌙', 'checkin': '🔒'};
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final rs = store.d.settings.reminders;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('⏰ Reminders'),
        const Muted('A reminder is skipped if you’ve already logged that meal. They arrive with the app closed and after a restart.'),
        gap8,
        for (var i = 0; i < rs.length; i++)
          SettingRow(
            first: i == 0,
            emoji: emoji[rs[i].id] ?? '⏰',
            title: rs[i].label,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                style: TextButton.styleFrom(backgroundColor: p.surface2, foregroundColor: p.text),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: rs[i].minutes ~/ 60, minute: rs[i].minutes % 60));
                  if (t != null) store.setReminder(i, time: '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                },
                child: Text(clock12(rs[i].time), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              gap4,
              Switch(value: rs[i].on, onChanged: (v) => store.setReminder(i, on: v)),
            ]),
          ),
        const Divider(height: 24),
        if (kIsWeb)
          const Muted('Reminders work in the Android app.')
        else ...[
          Text(
              store.notifAllowed
                  ? (store.reminderCount > 0 ? '🔔 On: ${store.reminderCount} reminders scheduled for the next 14 days' : '🔔 On. Switch a reminder on above.')
                  : '🔕 Off: notifications aren’t allowed yet',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          gap8,
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!store.notifAllowed) GoButton('Turn on reminders', expand: false, onPressed: store.requestNotifications),
            if (store.notifAllowed)
              SoftButton('Send a test', slim: true, onPressed: () => store.notifications.showNow(1, 'Plate Check is working', 'This is what a meal reminder looks like.')),
          ]),
          if (store.notifAllowed && !store.exactAllowed) ...[
            gap8,
            const Muted('Android may delay reminders by several minutes to save battery. To have them arrive on time, allow “Alarms & reminders” for Plate Check.'),
            gap8,
            SoftButton('Allow on-time reminders', slim: true, onPressed: store.requestExact),
          ],
        ],
      ]),
    );
  }
}

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('🧘 Habits'),
          SettingRow(
            first: true,
            emoji: '🤔',
            title: 'Ask how hungry I am',
            note: 'A one-tap check before snacks and off-time meals. If you’re not really hungry, it suggests waiting 10 minutes. Meals at their usual time are never asked.',
            trailing: Switch(value: store.d.settings.hungerCheck, onChanged: store.setHungerCheck),
          ),
          SettingRow(
            emoji: '🎨',
            title: 'Theme',
            trailing: const SizedBox.shrink(),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [ButtonSegment(value: '', label: Text('Auto')), ButtonSegment(value: 'light', label: Text('Light')), ButtonSegment(value: 'dark', label: Text('Dark'))],
              selected: {store.d.settings.theme},
              onSelectionChanged: (s) => store.setTheme(s.first),
            ),
          ),
        ]),
      );
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('💾 Your data'),
          const Muted('Everything is stored only on this phone, and Android’s own backup covers it. Nothing is sent anywhere. Uninstalling or clearing the app’s data erases it, so export a backup now and then.'),
          gap12,
          Row(children: [
            Expanded(
              child: SoftButton('Export backup', onPressed: () async {
                final f = await store.storage.writeBackup(store.d, 'plate-check-backup-${store.today}.json');
                await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/json')], title: 'Plate Check backup'));
              }),
            ),
            gap8,
            Expanded(
              child: SoftButton('Import backup', onPressed: () async {
                final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
                if (files.isEmpty || !context.mounted) return;
                final raw = await files.first.xFile.readAsString();
                if (!context.mounted) return;
                final ok = await _confirm(context, 'Replace everything on this phone with this backup?');
                if (!ok) return;
                final done = store.importBackup(raw);
                if (context.mounted) toast(context, done ? 'Backup restored' : 'That file isn’t a Plate Check backup');
              }),
            ),
          ]),
          gap8,
          SoftButton('Erase everything', slim: true, color: Pal.of(context).high, onPressed: () async {
            if (await _confirm(context, 'Erase all your logs, foods and settings from this phone? This can’t be undone.')) store.eraseAll();
          }),
        ]),
      );

  Future<bool> _confirm(BuildContext context, String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(msg),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes'))],
        ),
      ) ??
      false;
}
