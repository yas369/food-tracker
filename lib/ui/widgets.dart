// Shared building blocks: cards, the progress ring, charts, buttons.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import 'theme.dart';

const gap4 = SizedBox(height: 4, width: 4);
const gap8 = SizedBox(height: 8, width: 8);
const gap12 = SizedBox(height: 12, width: 12);
const gap16 = SizedBox(height: 16, width: 16);

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2600)));
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.gradient, this.margin = const EdgeInsets.only(bottom: 14)});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: p.dark && gradient == null && color == null ? BorderSide(color: p.line) : BorderSide.none,
    );
    // A Material (not a coloured box) so tap ripples inside cards stay visible.
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: p.dark || gradient != null ? null : const [BoxShadow(color: Color(0x0F3B0873), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Material(
        color: gradient == null ? (color ?? p.surface) : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: gradient == null
            ? Padding(padding: padding, child: child)
            : Ink(
                decoration: BoxDecoration(gradient: gradient),
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// Lay children out two to a row, each row as tall as its tallest child.
class Pairs extends StatelessWidget {
  const Pairs({super.key, required this.children, this.gap = 10});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                SizedBox(width: gap),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
              ],
            ),
          ),
        ),
    ],
  );
}

LinearGradient heroGradient(Pal p) => LinearGradient(colors: p.hero, begin: Alignment.topLeft, end: Alignment.bottomRight);

/// The purple block at the top of a screen, rounded at the bottom.
class HeroBox extends StatelessWidget {
  const HeroBox({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: heroGradient(p),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x5922C55E), Color(0x0022C55E)]),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), child: child),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                trailing!,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13, this.align});
  final String text;
  final double size;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: TextStyle(fontSize: size, color: Pal.of(context).muted, height: 1.4),
  );
}

class EmojiBox extends StatelessWidget {
  const EmojiBox(this.emoji, {super.key, this.size = 44, this.bg, this.radius = 14});
  final String emoji;
  final double size;
  final double radius;
  final Color? bg;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: bg ?? Pal.of(context).surface2, borderRadius: BorderRadius.circular(radius)),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
  );
}

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});
  final String level;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: p.levelSoft(level), borderRadius: BorderRadius.circular(99)),
      child: Text(
        levelNames[level]!.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: p.levelColor(level)),
      ),
    );
  }
}

/// Green gradient button with white text.
class GoButton extends StatelessWidget {
  const GoButton(this.label, {super.key, required this.onPressed, this.big = false, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final bool big;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : const LinearGradient(colors: Pal.go),
          color: onPressed == null ? Pal.of(context).surface2 : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            constraints: BoxConstraints(minHeight: big ? 54 : 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: onPressed == null ? Pal.of(context).muted : Colors.white, fontWeight: FontWeight.w800, fontSize: big ? 17 : 15),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, required this.onPressed, this.color, this.slim = false});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool slim;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.line, width: 1.5),
        minimumSize: Size(0, slim ? 38 : 46),
        padding: EdgeInsets.symmetric(horizontal: slim ? 12 : 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: slim ? 14 : 15),
      ),
      child: Text(label),
    );
  }
}

/// "+ ADD" in green outline, like a shop's add button.
class AddChip extends StatelessWidget {
  const AddChip({super.key, required this.onTap, this.label = '+ ADD', this.onDark = false});
  final VoidCallback onTap;
  final String label;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: onDark ? Colors.white.withValues(alpha: .16) : p.greenSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: onDark ? Colors.white54 : p.green, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(color: onDark ? Colors.white : p.green, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .4),
          ),
        ),
      ),
    );
  }
}

/// A selectable pill.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.selected, required this.onTap, this.color, this.dot});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final Color? dot;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = color ?? p.brand;
    return Material(
      color: selected ? c : p.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? c : p.line, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: selected ? Colors.white : dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : p.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White-on-purple number tile in the hero.
class HeroStat extends StatelessWidget {
  const HeroStat(this.value, this.label, {super.key, this.valueColor});
  final String value;
  final String label;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: valueColor ?? Colors.white),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    ),
  );
}

/// The progress ring: green, amber near the limit, pink past it.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.progress, required this.level, required this.big, required this.sub, this.size = 150});
  final double progress;
  final String level;
  final String big;
  final String sub;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = level == 'over'
        ? const [Color(0xFFFDA4C0), Color(0xFFF43F7E)]
        : level == 'warn'
        ? const [Color(0xFFFCD34D), Color(0xFFF59E0B)]
        : const [Color(0xFF4ADE80), Color(0xFFA3E635)];
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => CustomPaint(painter: _RingPainter(v, colors), child: child),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  big,
                  style: TextStyle(fontSize: size * .17, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: size * .075, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.colors);
  final double v;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .1;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (v <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..shader = LinearGradient(colors: colors).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.colors != colors;
}

/// Bars for a run of days, with a dashed limit or goal line.
class DayBars extends StatelessWidget {
  const DayBars({super.key, required this.values, required this.labels, required this.colors, this.line, this.lineLabel, this.highlight, this.height = 180});
  final List<double> values;
  final List<String> labels;
  final List<List<Color>?> colors; // null = empty day
  final double? line;
  final String? lineLabel;
  final int? highlight;
  final double height;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final max = [...values, (line ?? 0) * 1.25, 1.0].reduce(math.max);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.5),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: colors[i] == null ? 3 : math.max(3, values[i] / max * box.maxHeight)),
                                duration: const Duration(milliseconds: 500),
                                builder: (_, h, _) => Container(
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: colors[i] == null ? p.surface2 : null,
                                    gradient: colors[i] == null ? null : LinearGradient(colors: colors[i]!, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
                                    border: i == highlight ? Border.all(color: p.green, width: 2) : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (line != null && line! > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: line! / max * box.maxHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(size: Size(box.maxWidth, 2), painter: _DashPainter(p.green)),
                          if (lineLabel != null)
                            Positioned(
                              right: 0,
                              top: -22,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  lineLabel!,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.green),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        gap4,
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: i == highlight ? FontWeight.w800 : FontWeight.w600, color: i == highlight ? p.green : p.muted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 6, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A donut of shares, with a big number in the middle.
class Donut extends StatelessWidget {
  const Donut({super.key, required this.parts, required this.center, required this.caption, this.size = 130});
  final List<(double, Color)> parts;
  final String center;
  final String caption;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(parts, p.surface2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(caption, style: TextStyle(fontSize: 10, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.track);
  final List<(double, Color)> parts;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final r = (Offset.zero & size).deflate(stroke / 2 + 4);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final total = parts.fold(0.0, (a, x) => a + x.$1);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final (v, c) in parts) {
      final sweep = v / total * math.pi * 2;
      canvas.drawArc(
        r,
        start,
        sweep,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

/// − value + for whole numbers or halves.
class NumberStepper extends StatelessWidget {
  const NumberStepper({super.key, required this.value, required this.onChanged, this.step = 1, this.min = 0, this.max = 999, this.label});
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget btn(String t, double d, String hint) => Semantics(
      button: true,
      label: hint,
      child: Material(
        color: p.surface,
        elevation: p.dark ? 0 : 1,
        shadowColor: const Color(0x223B0873),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged((value + d).clamp(min, max)),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Text(
                t,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.brand),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        btn('−', -step, 'Less ${label ?? ''}'),
        Expanded(
          child: Text(
            value % 1 == 0 ? '${value.round()}' : value.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        btn('+', step, 'More ${label ?? ''}'),
      ],
    );
  }
}

/// A toggle row with an emoji, a title and a note.
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.emoji, required this.title, this.note, required this.trailing, this.first = false});
  final String emoji;
  final String title;
  final String? note;
  final Widget trailing;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          EmojiBox(emoji, size: 36, bg: p.brandSoft, radius: 12),
          gap12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (note != null) Muted(note!),
              ],
            ),
          ),
          gap8,
          trailing,
        ],
      ),
    );
  }
}

/// Your photo, or your initials, or a smile.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.me, this.size = 38, this.border = 2});
  final Me me;
  final double size;
  final double border;
  @override
  Widget build(BuildContext context) {
    Widget inner;
    final photo = me.photo;
    if (photo.startsWith('data:image')) {
      inner = Image.memory(base64Decode(photo.substring(photo.indexOf(',') + 1)), fit: BoxFit.cover, width: size, height: size, gaplessPlayback: true);
    } else {
      final n = me.name.trim();
      final initials = n.isEmpty ? '🙂' : n.split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
      inner = Center(
        child: Text(
          initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .36),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .2),
        gradient: photo.isEmpty ? const LinearGradient(colors: [Color(0xFF5B1BAA), Color(0xFF8B2CF5)]) : null,
        border: Border.all(color: Colors.white70, width: border),
      ),
      child: inner,
    );
  }
}

/// A settings-style row: optional emoji, a title, a quiet value, a chevron.
class NavRow extends StatelessWidget {
  const NavRow({super.key, this.emoji, required this.title, this.value, this.onTap, this.trailing, this.danger = false});
  final String? emoji;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 20)), const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: danger ? p.high : null),
                  ),
                  if (value != null) Padding(padding: const EdgeInsets.only(top: 2), child: Muted(value!)),
                ],
              ),
            ),
            if (trailing != null) trailing! else if (onTap != null) Icon(Icons.chevron_right, color: p.muted),
          ],
        ),
      ),
    );
  }
}

/// A titled group of rows in one card, separated by thin lines.
class Group extends StatelessWidget {
  const Group({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: .8, fontWeight: FontWeight.w700, color: p.muted),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: p.line), children[i]],
            ],
          ),
        ),
      ],
    );
  }
}

/// A card that shows only its title until tapped.
class Fold extends StatelessWidget {
  const Fold({super.key, required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 13, color: p.muted)),
          children: children,
        ),
      ),
    );
  }
}
