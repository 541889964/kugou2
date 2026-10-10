import 'package:flutter/material.dart';
class AppTheme {
  static const p = Color(0xFF8B5CF6);
  static const s = Color(0xFF22D3EE);
  static const accent = Color(0xFFF472B6);
  static const bg = Color(0xFF0A0A10);
  static const surface = Color(0xFF15151E);
  static const surfaceHigh = Color(0xFF1E1E2A);
  static ThemeData dark() {
    final sc = ColorScheme.fromSeed(seedColor: p, brightness: Brightness.dark, surface: surface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: sc,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      sliderTheme: SliderThemeData(
        activeTrackColor: p, thumbColor: Colors.white,
        overlayColor: p.withOpacity(0.15), inactiveTrackColor: Colors.white.withOpacity(0.10),
        trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
    );
  }
  static const grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)]);
  static const grad3 = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFF472B6), Color(0xFF22D3EE)]);
  static const discGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFF472B6)]);
  static const playerGrad = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1530), Color(0xFF0A0A10)]);
}
