import 'package:flutter/material.dart';

class AppTheme {
  static const p = Color(0xFF7C6CB0);
  static const s = Color(0xFF8FA3B8);
  static const bg = Color(0xFF0D0D10);
  static const surface = Color(0xFF17171B);
  static const surfaceHigh = Color(0xFF1F1F24);
  static const accent = Color(0xFFB85C7A);

  static ThemeData dark() {
    final sc = ColorScheme.fromSeed(
      seedColor: p, brightness: Brightness.dark, surface: surface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: sc,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600,
          color: Colors.white, letterSpacing: 0.3)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withOpacity(0.6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.32), fontSize: 13.5)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: p.withOpacity(0.18),
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85)))),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.06), thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70, textColor: Colors.white),
      sliderTheme: SliderThemeData(
        activeTrackColor: p, thumbColor: p,
        overlayColor: p.withOpacity(0.12),
        inactiveTrackColor: Colors.white.withOpacity(0.10)),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(letterSpacing: 0.15)),
    );
  }

  static const grad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C6CB0), Color(0xFF5A5480)]);
  static const playerGrad = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF17162A), bg]);
  static const discGrad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C6CB0), Color(0xFF5A5480)]);
}
