// Me is a short settings list. Each row opens its own page, so nothing here
// needs reading unless you're looking for it.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../store.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'goal.dart';
import 'onboarding.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final c = store.c;
    final me = store.d.me;
    final prof = store.d.profile;
    final rsOn = store.d.settings.reminders.where((r) => r.on).length;
    const themes = {'': 'Follow phone', 'light': 'Light', 'dark': 'Dark'};

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
      AppCard(
        child: Row(children: [
          GestureDetector(onTap: () => openSetup(context, store, SetupMode.profile), child: Avatar(me: me, size: 60, border: 0)),
          gap16,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me.name.isEmpty ? 'Add your name' : me.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Muted('${store.d.log.length} days logged · ${c.streak(store.today)}-day streak'),
            ]),
          ),
          TextButton(onPressed: () => openSetup(context, store, SetupMode.profile), child: const Text('Edit')),
        ]),
      ),
      Group(title: 'Your goal', children: [
        NavRow(
          icon: Icons.flag_outlined,
          title: 'Plan and body',
          value: prof == null ? 'Not set yet' : '${prof.override != null ? 'Own limit' : planInfo(prof.plan).name} · ${fmt(c.baseTarget)} kcal a day',
          onTap: () => openGoal(context, store),
        ),
      ]),
      Group(title: 'Food', children: [
        NavRow(icon: Icons.restaurant_outlined, title: 'I eat', value: dietPrefInfo(store.d.settings.dietPref).title, onTap: () => openSetup(context, store, SetupMode.pref)),
        NavRow(icon: Icons.kitchen_outlined, title: 'My kitchen', value: '${c.pantry.length} items at home', onTap: () => openSetup(context, store, SetupMode.kitchen)),
      ]),
      Group(title: 'Reminders and habits', children: [
        NavRow(
          icon: Icons.notifications_none,
          title: 'Meal reminders',
          value: kIsWeb ? '$rsOn on' : !store.notifAllowed ? 'Off: tap to turn on' : '$rsOn on',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RemindersScreen(store: store))),
        ),
        NavRow(
          icon: Icons.psychology_outlined,
          title: 'Ask how hungry I am',
          value: 'Before snacks and off-time meals',
          trailing: Switch(value: store.d.settings.hungerCheck, onChanged: store.setHungerCheck),
        ),
        NavRow(
          icon: Icons.contrast,
          title: 'Theme',
          value: themes[store.d.settings.theme],
          onTap: () async {
            final t = await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(title: const Text('Theme'), children: [
                for (final e in themes.entries) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value)),
              ]),
            );
            if (t != null) store.setTheme(t);
          },
        ),
      ]),
      Group(title: 'Your data', children: [
        NavRow(icon: Icons.file_upload_outlined, title: 'Export backup', value: 'Save a copy of everything', onTap: () async {
          final f = await store.storage.writeBackup(store.d, 'plate-check-backup-${store.today}.json');
          await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/json')], title: 'Plate Check backup'));
        }),
        NavRow(icon: Icons.file_download_outlined, title: 'Import backup', onTap: () async {
          final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
          if (files.isEmpty || !context.mounted) return;
          final raw = await files.first.xFile.readAsString();
          if (!context.mounted || !await _confirm(context, 'Replace everything on this phone with this backup?')) return;
          final done = store.importBackup(raw);
          if (context.mounted) toast(context, done ? 'Backup restored' : 'That file isn’t a Plate Check backup');
        }),
        NavRow(icon: Icons.delete_outline, title: 'Erase everything', danger: true, onTap: () async {
          if (await _confirm(context, 'Erase all your logs, foods and settings from this phone? This can’t be undone.')) store.eraseAll();
        }),
      ]),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Muted('Everything stays on this phone. Calorie values are typical home portions and can be off by 20% or more; oil and ghee are the usual culprits.'),
      ),
    ]);
  }

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

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(backgroundColor: p.bg, title: const Text('Meal reminders', style: TextStyle(fontWeight: FontWeight.w700))),
        body: ListView(padding: const EdgeInsets.all(16), children: [RemindersCard(store: store)]),
      ),
    );
  }
}

class RemindersCard extends StatelessWidget {
  const RemindersCard({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final rs = store.d.settings.reminders;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Muted('A reminder is skipped if you’ve already logged that meal. They arrive with the app closed and after a restart.'),
        gap8,
        for (var i = 0; i < rs.length; i++)
          SettingRow(
            first: i == 0,
            icon: mealIcon(rs[i].id),
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
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(store.notifAllowed ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, size: 20, color: store.notifAllowed ? p.green : p.high),
            gap8,
            Expanded(
              child: Text(
                  store.notifAllowed
                      ? (store.reminderCount > 0 ? 'On: ${store.reminderCount} reminders scheduled for the next 14 days' : 'On. Switch a reminder on above.')
                      : 'Off: notifications aren’t allowed yet',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
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

