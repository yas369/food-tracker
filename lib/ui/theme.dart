// Colours: purple like Zepto, green for "go", amber and pink for warnings.

import 'package:flutter/material.dart';

import '../data/catalog.dart';

class Pal {
  final bool dark;
  final Color bg, surface, surface2, text, muted, line;
  final Color brand, brand2, brandDeep, brandSoft;
  final Color green, greenSoft;
  final Color low, lowSoft, med, medSoft, high, highSoft;
  final List<Color> hero;

  const Pal._({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.line,
    required this.brand,
    required this.brand2,
    required this.brandDeep,
    required this.brandSoft,
    required this.green,
    required this.greenSoft,
    required this.low,
    required this.lowSoft,
    required this.med,
    required this.medSoft,
    required this.high,
    required this.highSoft,
    required this.hero,
  });

  static const light = Pal._(
    dark: false,
    bg: Color(0xFFF5F0FC), surface: Color(0xFFFFFFFF), surface2: Color(0xFFF1E9FC),
    text: Color(0xFF1D0F33), muted: Color(0xFF6D5F86), line: Color(0xFFE8DDF6),
    brand: Color(0xFF5B1BAA), brand2: Color(0xFF8B2CF5), brandDeep: Color(0xFF3A0873), brandSoft: Color(0xFFEFE4FF),
    green: Color(0xFF0FA548), greenSoft: Color(0xFFE3F8EA),
    low: Color(0xFF0FA548), lowSoft: Color(0xFFE3F8EA), med: Color(0xFFE08A00), medSoft: Color(0xFFFFF2D6),
    high: Color(0xFFE0245E), highSoft: Color(0xFFFFE3EC),
    hero: [Color(0xFF34066A), Color(0xFF5B1BAA), Color(0xFF8B2CF5)],
  );

  static const darkPal = Pal._(
    dark: true,
    bg: Color(0xFF110820), surface: Color(0xFF1B1030), surface2: Color(0xFF26173F),
    text: Color(0xFFF3EDFC), muted: Color(0xFFB6A8CE), line: Color(0xFF33244D),
    brand: Color(0xFFA56BFF), brand2: Color(0xFFC18CFF), brandDeep: Color(0xFF2A0757), brandSoft: Color(0xFF2C1A4A),
    green: Color(0xFF2FD06B), greenSoft: Color(0xFF133626),
    low: Color(0xFF3FD67A), lowSoft: Color(0xFF143424), med: Color(0xFFF5B642), medSoft: Color(0xFF3A2B10),
    high: Color(0xFFFF6B96), highSoft: Color(0xFF40172A),
    hero: [Color(0xFF22044A), Color(0xFF43108A), Color(0xFF6A22C9)],
  );

  static Pal of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkPal : light;

  /// Buttons with white text keep the deeper green in both themes.
  static const go = [Color(0xFF0B9442), Color(0xFF16B455)];
  static const goSolid = Color(0xFF0B9442);

  Color soft(Tint t) => switch (t) { Tint.med => medSoft, Tint.green => greenSoft, Tint.high => highSoft, Tint.brand => brandSoft };
  Color levelColor(String l) => l == 'l' ? low : l == 'm' ? med : high;
  Color levelSoft(String l) => l == 'l' ? lowSoft : l == 'm' ? medSoft : highSoft;
  Color statusColor(String level) => level == 'over' ? high : level == 'warn' ? med : green;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.darkPal : Pal.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B1BAA), brightness: b, primary: p.brand, surface: p.surface),
    scaffoldBackgroundColor: p.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.brandDeep,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Pal.goSolid : p.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.brand, width: 1.5)),
    ),
  );
}
