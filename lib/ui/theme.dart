import 'package:flutter/material.dart';
class AppTheme {
  static const p = Color(0xFF8B5CF6);
  static const s = Color(0xFF22D3EE);
  static const bg = Color(0xFF0A0812);
  static const surface = Color(0xFF1A1726);
  static const surfaceHigh = Color(0xFF24203A);
  static const accent = Color(0xFFFF4081);
  static ThemeData dark() {
    final sc = ColorScheme.fromSeed(seedColor: p, brightness: Brightness.dark, surface: surface);
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
      colorScheme: sc,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface, indicatorColor: p.withOpacity(0.22), height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08), thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70, textColor: Colors.white),
      sliderTheme: SliderThemeData(
        activeTrackColor: p, thumbColor: p, overlayColor: p.withOpacity(0.15),
        inactiveTrackColor: Colors.white.withOpacity(0.1)),
    );
  }
  static const grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, s]);
  static const playerGrad = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1B4A), bg]);
  static const discGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, accent, s]);
}
