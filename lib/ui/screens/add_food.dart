import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../models.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Open the add-food screen. The hunger check only appears for snacks and for
/// meals well away from their usual time, and only when adding for today.
Future<void> openAddFood(BuildContext context, AppStore store, String day, {String? meal}) {
  if (store.c.baseTarget <= 0) {
    toast(context, 'Set up your goal first');
    return Future.value();
  }
  final m = meal ?? mealForTime(store.now);
  final ask = store.d.settings.hungerCheck && day == store.today && store.c.offSchedule(m, store.now);
  return Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AddFoodScreen(store: store, day: day, meal: m, askHunger: ask)));
}

enum _Step { hunger, pause, pick }

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key, required this.store, required this.day, required this.meal, required this.askHunger});
  final AppStore store;
  final String day;
  final String meal;
  final bool askHunger;
  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  late _Step step = widget.askHunger ? _Step.hunger : _Step.pick;
  late String meal = widget.meal;
  int? hunger;
  final tray = <String, double>{};
  String q = '', cat = '', lv = '';
  String? last;

  AppStore get store => widget.store;
  Calc get c => store.c;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        _header(p),
        Expanded(child: step == _Step.hunger ? _hungerBody(p) : step == _Step.pause ? _pauseBody(p) : _pickBody(p)),
        if (step == _Step.pick) _footer(p),
      ]),
    );
  }

  Widget _header(Pal p) {
    final title = step == _Step.hunger ? 'Before you eat' : step == _Step.pause ? 'Pause for a moment' : 'Add to ${mealInfo(meal).label}';
    return Container(
      decoration: BoxDecoration(gradient: heroGradient(p)),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Material(
            color: Colors.white.withValues(alpha: .16),
            shape: const CircleBorder(),
            child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
          ),
          gap12,
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        ]),
        if (step == _Step.hunger) ...[gap8, const Text('How hungry are you right now?', style: TextStyle(color: Colors.white70))],
        if (step == _Step.pick) ...[
          gap12,
          TextField(
            onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            style: const TextStyle(color: Color(0xFF1D0F33), fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search idli, rice, tea…',
              prefixIcon: const Padding(padding: EdgeInsets.only(left: 12, right: 8), child: Text('🔍', style: TextStyle(fontSize: 17))),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          gap8,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final m in meals)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: m.id == meal ? Colors.white : Colors.white.withValues(alpha: .14),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => meal = m.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text('${m.emoji} ${m.label}', style: TextStyle(fontWeight: FontWeight.w700, color: m.id == meal ? p.brandDeep : Colors.white)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ---------- Hunger check ----------

  Widget _hungerBody(Pal p) => ListView(padding: const EdgeInsets.all(16), children: [
        for (final h in hungerLevels)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  hunger = h.v;
                  step = h.v <= 2 ? _Step.pause : _Step.pick;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    EmojiBox(h.emoji, size: 48, bg: p.soft(h.tint)),
                    gap12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Muted(h.desc),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        SoftButton('I already ate. Just log it', onPressed: () => setState(() => step = _Step.pick)),
      ]);

  Widget _pauseBody(Pal p) => ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
        const Center(child: Text('⏳', style: TextStyle(fontSize: 72))),
        gap12,
        Text(hunger == 1 ? 'You’re not really hungry' : 'You’re only a little hungry', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        gap8,
        const Muted('Boredom, stress, tiredness and food just being there all feel like hunger. Drink a glass of water, wait 10 minutes, then decide.', size: 15, align: TextAlign.center),
        const SizedBox(height: 20),
        GoButton('💧 Wait 10 minutes', onPressed: () async {
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          await store.waitTenMinutes();
          nav.pop();
          messenger.showSnackBar(const SnackBar(content: Text('Good call. I’ll check back in 10 minutes.')));
        }),
        gap8,
        SoftButton('Log it anyway', onPressed: () => setState(() => step = _Step.pick)),
      ]);

  // ---------- Food grid ----------

  Widget _pickBody(Pal p) {
    final all = c.allFoods;
    final cats = {for (final f in all) f.cat}.toList();
    final recent = c.recentFoods();
    final list = all.where((f) =>
        (cat.isEmpty || f.cat == cat) && (lv.isEmpty || levelOf(f.kcal) == lv) && (q.isEmpty || f.name.toLowerCase().contains(q) || f.cat.toLowerCase().contains(q)));
    final byCat = <String, List<Food>>{};
    for (final f in list) {
      byCat.putIfAbsent(f.cat, () => []).add(f);
    }
    Widget pills(List<Widget> xs) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [for (final x in xs) Padding(padding: const EdgeInsets.only(right: 8), child: x)]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
      pills([
        Pill('All levels', selected: lv.isEmpty, onTap: () => setState(() => lv = '')),
        for (final k in ['l', 'm', 'h'])
          Pill(levelNames[k]!, selected: lv == k, color: p.levelColor(k), dot: p.levelColor(k), onTap: () => setState(() => lv = k)),
      ]),
      pills([
        Pill('🍽️ All', selected: cat.isEmpty, onTap: () => setState(() => cat = '')),
        for (final ct in cats) Pill('${catEmoji[ct] ?? '🍽️'} $ct', selected: cat == ct, onTap: () => setState(() => cat = ct)),
      ]),
      if (q.isEmpty && cat.isEmpty && lv.isEmpty && recent.isNotEmpty) ...[
        const _CatTitle('🕘 Recent'),
        SizedBox(
          height: 230,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in recent)
              Padding(padding: const EdgeInsets.only(right: 10), child: Align(alignment: Alignment.topCenter, child: SizedBox(width: 158, child: _foodCard(p, f)))),
          ]),
        ),
      ],
      if (byCat.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Muted('🤷 No match. Add it as a custom food below.', align: TextAlign.center)),
      for (final e in byCat.entries) ...[
        _CatTitle('${catEmoji[e.key] ?? '🍽️'} ${e.key}'),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 400 ? 3 : 2;
          final w = (box.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final f in e.value) SizedBox(width: w, child: _foodCard(p, f))]);
        }),
      ],
      gap16,
      _CustomFood(onSave: (f) {
        store.addCustomFood(f);
        setState(() {
          tray[f.id] = 1;
          last = f.id;
          q = '';
          cat = '';
          lv = '';
        });
      }),
    ]);
  }

  void _set(String id, double qty) => setState(() {
        if (qty <= 0) {
          tray.remove(id);
          if (last == id) last = null;
        } else {
          tray[id] = qty;
          last = id;
        }
      });

  Widget _foodCard(Pal p, Food f) {
    final qty = tray[f.id] ?? 0;
    final lvl = levelOf(f.kcal);
    final s = stepFor(f);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qty > 0 ? p.green : p.line, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 76,
          decoration: BoxDecoration(color: p.levelSoft(lvl), borderRadius: BorderRadius.circular(14)),
          child: Stack(children: [
            Center(child: Text(emojiFor(f.id, f.cat), style: const TextStyle(fontSize: 38))),
            Positioned(left: 6, top: 6, child: LevelBadge(lvl)),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 36, child: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.25))),
        Muted(f.unit, size: 12),
        gap8,
        Row(children: [
          Expanded(child: Text.rich(TextSpan(children: [
            TextSpan(text: '${f.kcal}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            TextSpan(text: ' kcal', style: TextStyle(fontSize: 11, color: p.muted)),
          ]))),
          if (qty == 0)
            OutlinedButton(
              onPressed: () => _set(f.id, 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.green,
                side: BorderSide(color: p.green, width: 1.5),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              child: Semantics(label: 'Add ${f.name}', child: const Text('ADD')),
            )
          else
            Container(
              decoration: BoxDecoration(color: Pal.goSolid, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _qtyBtn('−', 'Less ${f.name}', () => _set(f.id, qty - s)),
                Text(fmtQty(qty), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                _qtyBtn('+', 'More ${f.name}', () => _set(f.id, qty + s)),
              ]),
            ),
        ]),
      ]),
    );
  }

  Widget _qtyBtn(String t, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: InkWell(onTap: onTap, child: SizedBox(width: 28, height: 32, child: Center(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))))),
      );

  // ---------- Cart ----------

  Widget _footer(Pal p) {
    final items = [for (final e in tray.entries) if (c.food(e.key) != null) (c.food(e.key)!, e.value)];
    final addKcal = items.fold(0.0, (a, x) => a + x.$1.kcal * x.$2);
    final target = c.dailyTarget(widget.day);
    final after = sumKcal(c.entriesOn(widget.day)) + addKcal;
    final lvl = levelFor(after, target);

    Widget? swap;
    final lastFood = last == null ? null : c.food(last!);
    final lowPlan = store.d.profile?.plan == 'low' && store.d.profile?.override == null;
    if (lastFood != null && levelOf(lastFood.kcal) == 'h' && (lowPlan || after > target)) {
      final qty = tray[lastFood.id] ?? 0;
      final sw = swaps[lastFood.id] == null ? null : c.food(swaps[lastFood.id]!);
      if (sw != null && sw.kcal <= lastFood.kcal * 0.8) {
        swap = _swapBox(p, emojiFor(sw.id, sw.cat), 'Lighter swap: ${sw.name} · ${sw.kcal} kcal', 'saves ${fmt((lastFood.kcal - sw.kcal) * qty)} kcal against ${lastFood.name}', 'Swap', () {
          setState(() {
            tray.remove(lastFood.id);
            tray[sw.id] = (tray[sw.id] ?? 0) + qty;
            last = null;
          });
          toast(context, 'Swapped for ${sw.name} 🌿');
        });
      } else if (qty >= 1) {
        swap = _swapBox(p, '✂️', 'High-calorie pick.', 'Half a portion saves ${fmt(lastFood.kcal * qty / 2)} kcal.', 'Make it ½', () {
          setState(() {
            tray[lastFood.id] = qty / 2;
            last = null;
          });
        });
      }
    }

    final colors = lvl == 'over'
        ? const [Color(0xFFBE123C), Color(0xFFE0245E)]
        : lvl == 'warn'
            ? const [Color(0xFFD97706), Color(0xFFF59E0B)]
            : Pal.go;
    return Container(
      color: p.bg,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ?swap,
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: items.isEmpty ? null : LinearGradient(colors: colors),
              color: items.isEmpty ? p.surface2 : null,
              borderRadius: BorderRadius.circular(18),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: items.isEmpty ? null : () => _confirm(items),
              child: Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(items.isEmpty ? 'Tap ADD on a food' : '${items.length} ${items.length == 1 ? 'item' : 'items'} · ${fmt(addKcal)} kcal',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: items.isEmpty ? p.muted : Colors.white)),
                      Text(
                          items.isEmpty
                              ? '${fmt((target - after).clamp(0, 99999))} kcal left today'
                              : lvl == 'over'
                                  ? '${fmt(after - target)} kcal over your limit. Could you eat less?'
                                  : 'After this: ${fmt(target - after)} kcal left',
                          style: TextStyle(fontSize: 13, color: items.isEmpty ? p.muted : Colors.white.withValues(alpha: .92))),
                    ]),
                  ),
                  if (items.isNotEmpty)
                    Text('${lvl == 'over' ? 'Add anyway' : 'Add to ${mealInfo(meal).label}'} ›', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _swapBox(Pal p, String emoji, String title, String note, String action, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          gap8,
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Muted(note, size: 12),
            ]),
          ),
          gap8,
          GoButton(action, expand: false, onPressed: onTap),
        ]),
      );

  void _confirm(List<(Food, double)> items) {
    final b = store.newBatch();
    final t = widget.day == store.today ? store.now.millisecondsSinceEpoch : parseKey(widget.day).add(const Duration(hours: 12)).millisecondsSinceEpoch;
    store.addEntries(widget.day, [
      for (final (f, qty) in items)
        Entry(f: f.id, name: f.name, unit: f.unit, kcal: f.kcal, tags: f.tags, qty: qty, meal: meal, hunger: hunger, b: b, t: t),
    ]);
    final target = c.dailyTarget(widget.day);
    final total = sumKcal(c.entriesOn(widget.day));
    final msg = target > 0 && total > target
        ? 'Over today’s limit. Close the kitchen for today.'
        : target > 0 && total >= target * .8
            ? '${fmt(target - total)} kcal left. Keep the next meal light.'
            : 'Logged ✅';
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _CatTitle extends StatelessWidget {
  const _CatTitle(this.t);
  final String t;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 16, bottom: 10), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)));
}

class _CustomFood extends StatefulWidget {
  const _CustomFood({required this.onSave});
  final ValueChanged<Food> onSave;
  @override
  State<_CustomFood> createState() => _CustomFoodState();
}

class _CustomFoodState extends State<_CustomFood> {
  final name = TextEditingController(), unit = TextEditingController(), kcal = TextEditingController();
  final tags = <String>{};

  @override
  void dispose() {
    name.dispose();
    unit.dispose();
    kcal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.line, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('＋ Add a food that isn’t listed', style: TextStyle(fontWeight: FontWeight.w800, color: p.brand)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'Name', counterText: '')),
            gap8,
            Row(children: [
              Expanded(child: TextField(controller: unit, maxLength: 20, decoration: const InputDecoration(labelText: 'Portion', hintText: '1 cup', counterText: ''))),
              gap8,
              Expanded(child: TextField(controller: kcal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'kcal per portion'))),
            ]),
            gap8,
            Wrap(spacing: 6, children: [
              for (final (t, label) in [('fried', 'Fried'), ('sweet', 'Sweet'), ('protein', 'Protein'), ('plant', 'Veg / fruit')])
                FilterChip(label: Text(label), selected: tags.contains(t), onSelected: (v) => setState(() => v ? tags.add(t) : tags.remove(t))),
            ]),
            gap8,
            GoButton('Save and add', onPressed: () {
              final k = int.tryParse(kcal.text.trim());
              if (name.text.trim().isEmpty || k == null || k < 0 || k > 3000) {
                toast(context, 'Add a name and calories');
                return;
              }
              widget.onSave(Food('c_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}', 'My foods', name.text.trim(),
                  unit.text.trim().isEmpty ? '1 portion' : unit.text.trim(), k, tags.toList()));
              name.clear();
              unit.clear();
              kcal.clear();
              setState(tags.clear);
            }),
          ],
        ),
      ),
    );
  }
}
