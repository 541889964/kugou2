import 'package:flutter/material.dart';
class AppTheme {
  static const p = Color(0xFF7C6CB0);
  static const s = Color(0xFF8FA3B8);
  static const bg = Color(0xFF0D0D10);
  static ThemeData dark() {
    final sc = ColorScheme.fromSeed(seedColor: p, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: sc,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent, indicatorColor: p.withOpacity(0.18), height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85)))),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      sliderTheme: SliderThemeData(activeTrackColor: p, thumbColor: p,
        overlayColor: p.withOpacity(0.12), inactiveTrackColor: Colors.white.withOpacity(0.10)),
    );
  }
  static const grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C6CB0), Color(0xFF5A5480)]);
  static const discGrad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C6CB0), Color(0xFF5A5480)]);
}
