// Today answers one question first: how much can I still eat, and what's
// next? Everything else is one tap away.

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../logic.dart';
import '../../models.dart';
import '../../store.dart';
import '../feedback.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_food.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store, required this.day, required this.onDay, required this.goMe});
  final AppStore store;
  final String day;
  final ValueChanged<String> onDay;
  final VoidCallback goMe;
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String? open; // the meal whose items are showing

  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final c = store.c;
    final day = widget.day;
    final isToday = day == store.today;
    final entries = c.entriesOn(day);
    final target = c.dailyTarget(day);
    final nudge = isToday ? _topNudge(entries) : null;
    final list = ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
      _Summary(store: store, day: day, onDay: widget.onDay),
      if (isToday && target > 0 && store.now.hour < 12) _Yesterday(store: store),
      if (target <= 0)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Set your goal to begin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            gap8,
            GoButton('Set my goal', onPressed: widget.goMe),
          ]),
        ),
      if (isToday && target > 0) _NextUp(store: store),
      if (nudge != null) _Nudge(emoji: nudge.$1, text: nudge.$2),
      _MealList(store: store, day: day, open: open, onToggle: (m) => setState(() => open = open == m ? null : m)),
    ]);
    // Swipe right for the day before, left for the day after.
    return GestureDetector(
      onHorizontalDragEnd: (e) {
        final v = e.primaryVelocity ?? 0;
        if (v > 300) widget.onDay(addDays(day, -1));
        if (v < -300 && !isToday) widget.onDay(addDays(day, 1));
      },
      child: list,
    );
  }

  /// At most one nudge: the one that matters most right now.
  (String, String)? _topNudge(List<Entry> entries) {
    double count(String tag) => entries.where((e) => e.tags.contains(tag)).fold(0.0, (a, e) => a + e.qty);
    final unhungry = {for (final e in entries) if (e.hunger != null && e.hunger! <= 2) e.b}.length;
    if (unhungry >= 2) return ('🧭', 'You ate $unhungry times today without being hungry. That’s where overeating usually starts.');
    if (count('fried') >= 2) return ('🍳', 'Two or more fried items today. Keep the rest non-fried.');
    if (count('sweet') >= 3) return ('🍬', 'Three sweet items today, counting tea and coffee. Try the next one without sugar.');
    if (entries.isNotEmpty && count('plant') == 0 && store.now.hour >= 14) return ('🥦', 'No vegetables or fruit yet. Aim for half your plate.');
    if (entries.length >= 3 && count('protein') == 0) return ('🥚', 'No protein yet. Dal, curd or eggs will keep you fuller.');
    return null;
  }
}

/// The one big number: what's left today.
class _Summary extends StatelessWidget {
  const _Summary({required this.store, required this.day, required this.onDay});
  final AppStore store;
  final String day;
  final ValueChanged<String> onDay;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final isToday = day == store.today;
    final total = sumKcal(c.entriesOn(day));
    final target = c.dailyTarget(day);
    final left = target - total;
    final level = levelFor(total, target);
    final burnt = c.moveCredit ? c.burntOn(day) : 0;
    final barColor = level == 'over' ? const Color(0xFFFDA4C0) : level == 'warn' ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC);
    return AppCard(
      gradient: heroGradient(p),
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(dayLabel(day, store.today), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
          IconButton(tooltip: 'Previous day', onPressed: () => onDay(addDays(day, -1)), icon: const Icon(Icons.chevron_left, color: Colors.white)),
          IconButton(
            tooltip: 'Next day',
            onPressed: isToday ? null : () => onDay(addDays(day, 1)),
            icon: Icon(Icons.chevron_right, color: isToday ? Colors.white24 : Colors.white),
          ),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(target > 0 ? fmt(left.abs()) : fmt(total), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(target <= 0 ? 'kcal eaten' : left < 0 ? 'kcal over' : 'kcal left',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (target > 0) ...[
          gap12,
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: (total / target).clamp(0, 1), minHeight: 8, backgroundColor: Colors.white24, color: barColor),
            ),
          ),
          gap8,
          Text('${fmt(total)} eaten of ${fmt(target)}${burnt > 0 ? ' · ${fmt(c.baseTarget)} + ${fmt(burnt)} from moving' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ]),
    );
  }
}

/// The next meal to eat, from the diet plan, with one tap to log it.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.c;
    final logged = {for (final e in c.entriesOn(store.today)) e.meal};
    final now = store.now.hour * 60 + store.now.minute;
    final times = {for (final r in store.d.settings.reminders) if (r.meal != null) r.meal!: r.minutes};
    // The first meal not yet logged whose time hasn't long passed.
    MealInfo? next;
    for (final m in meals) {
      if (logged.contains(m.id)) continue;
      if (m.id != 'dinner' && (times[m.id] ?? 0) + 150 < now) continue;
      next = m;
      break;
    }
    if (next == null) {
      return AppCard(
        child: Row(children: [
          const Text('🌙', style: TextStyle(fontSize: 26)),
          gap12,
          const Expanded(child: Text('All meals logged. The kitchen can close for today.', style: TextStyle(fontSize: 15))),
        ]),
      );
    }
    final meal = next;
    final plan = c.planFor(store.today, meal.id);
    final time = store.d.settings.reminders.where((r) => r.meal == meal.id).map((r) => clock12(r.time)).firstOrNull;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEXT UP · ${meal.label.toUpperCase()}${time == null ? '' : ' · $time'}',
            style: TextStyle(fontSize: 12, letterSpacing: .8, fontWeight: FontWeight.w700, color: p.muted)),
        gap8,
        if (plan == null)
          const Text('Nothing from your kitchen fits this meal. Log what you eat.', style: TextStyle(fontSize: 15))
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(plan.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            gap8,
            Text('${fmt(plan.kcal)} kcal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.brand)),
          ]),
          gap4,
          Muted(plan.items.map((x) => '${qtyUnit(x.qty, x.f.unit)} ${x.name.toLowerCase()}').join(' · ')),
        ],
        gap12,
        Row(children: [
          if (plan != null) ...[
            Expanded(
              child: GoButton('I ate this', onPressed: () {
                final k = store.logPlan(meal.id);
                final b = store.lastBatch;
                if (k != null && b != null) showUndo(context, '${meal.label} logged · ${fmt(k)} kcal', () => store.removeBatch(store.today, b), buzz: true);
              }),
            ),
            gap8,
          ],
          Expanded(child: SoftButton(plan == null ? 'Log a meal' : 'Something else', onPressed: () => openAddFood(context, store, store.today, meal: meal.id))),
        ]),
      ]),
    );
  }
}

/// One calm line in the morning about how yesterday went.
class _Yesterday extends StatelessWidget {
  const _Yesterday({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final c = store.c;
    final y = addDays(store.today, -1);
    final entries = c.entriesOn(y);
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = sumKcal(entries);
    final target = c.dailyTarget(y);
    final over = total - target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(over > 0 ? '🌅' : '👏', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              over > 0
                  ? 'Yesterday: ${fmt(total)} of ${fmt(target)}, ${fmt(over)} over. Today is a fresh start.'
                  : 'Yesterday: ${fmt(total)} of ${fmt(target)}. Within your limit.',
              style: TextStyle(fontSize: 14, color: Pal.of(context).muted)),
        ),
      ]),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.emoji, required this.text});
  final String emoji;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Pal.of(context).medSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          gap12,
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ]),
      );
}

/// Four quiet rows; tap one to see or remove what's in it.
class _MealList extends StatelessWidget {
  const _MealList({required this.store, required this.day, required this.open, required this.onToggle});
  final AppStore store;
  final String day;
  final String? open;
  final ValueChanged<String> onToggle;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final all = store.c.entriesOn(day);
    return Group(
      title: day == store.today ? 'Today’s meals' : 'Meals',
      children: [
        for (final m in meals)
          Builder(builder: (context) {
            final idx = [for (var i = 0; i < all.length; i++) if (all[i].meal == m.id) i];
            final sub = idx.fold(0.0, (a, i) => a + all[i].total);
            final isOpen = open == m.id && idx.isNotEmpty;
            return Column(children: [
              InkWell(
                onTap: idx.isEmpty ? () => openAddFood(context, store, day, meal: m.id) : () => onToggle(m.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(children: [
                    Text(m.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Muted(idx.isEmpty ? 'Not logged yet' : '${idx.length} ${idx.length == 1 ? 'item' : 'items'} · ${fmt(sub)} kcal'),
                      ]),
                    ),
                    if (idx.isNotEmpty) Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: p.muted),
                    IconButton(
                      tooltip: 'Add to ${m.label}',
                      onPressed: () => openAddFood(context, store, day, meal: m.id),
                      icon: Icon(Icons.add_circle_outline, color: p.brand, size: 26),
                    ),
                  ]),
                ),
              ),
              if (isOpen)
                for (final i in idx) _EntryRow(store: store, day: day, index: i),
            ]);
          }),
      ],
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
    final e = store.c.entriesOn(day)[index];
    return InkWell(
      onTap: () => _editEntry(context, store, day, index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 0, 4, 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: const TextStyle(fontSize: 14)),
              Muted(qtyUnit(e.qty, e.unit), size: 12),
            ]),
          ),
          Text(fmt(e.total), style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'Remove ${e.name}',
            icon: Icon(Icons.close, size: 18, color: Pal.of(context).muted),
            onPressed: () => _remove(context, store, day, index),
          ),
        ]),
      ),
    );
  }
}

void _remove(BuildContext context, AppStore store, String day, int index) {
  final removed = store.removeEntry(day, index);
  showUndo(context, 'Removed ${removed.name}', () => store.restoreEntry(day, index, removed));
}

/// Change how much of a logged food was eaten, or remove it.
Future<void> _editEntry(BuildContext context, AppStore store, String day, int index) {
  final e = store.c.entriesOn(day)[index];
  final food = store.c.food(e.f);
  final step = food == null ? 0.5 : stepFor(food);
  var qty = e.qty;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Muted('${e.unit} · ${e.kcal} kcal each'),
            gap16,
            Row(children: [
              Expanded(child: Text('${fmt(e.kcal * qty)} kcal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              IconButton.filledTonal(tooltip: 'Less', onPressed: qty > step ? () => setSheet(() => qty -= step) : null, icon: const Icon(Icons.remove)),
              SizedBox(width: 56, child: Text(fmtQty(qty), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton.filledTonal(tooltip: 'More', onPressed: qty < 50 ? () => setSheet(() => qty += step) : null, icon: const Icon(Icons.add)),
            ]),
            gap16,
            Row(children: [
              Expanded(
                child: SoftButton('Remove', onPressed: () {
                  Navigator.pop(ctx);
                  _remove(context, store, day, index);
                }),
              ),
              gap8,
              Expanded(
                child: GoButton('Save', onPressed: () {
                  Navigator.pop(ctx);
                  if (qty == e.qty) return;
                  store.setEntryQty(day, index, qty);
                  showUndo(context, '${e.name}: ${qtyUnit(qty, e.unit)}', () => store.setEntryQty(day, index, e.qty));
                }),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
