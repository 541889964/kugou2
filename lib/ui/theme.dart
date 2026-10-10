import 'package:flutter/material.dart';

class AppTheme {
  // 主色
  static const p = Color(0xFF8B5CF6);
  static const s = Color(0xFF22D3EE);
  static const accent = Color(0xFFF472B6);
  static const gold = Color(0xFFD4C57A);

  // 背景
  static const bg = Color(0xFF0A0A10);
  static const surface = Color(0xFF15151E);
  static const surfaceHigh = Color(0xFF1E1E2A);

  // 全局圆角（Material You 24px）
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
  static const r28 = BorderRadius.all(Radius.circular(28));

  static ThemeData dark() {
    final sc = ColorScheme.fromSeed(
      seedColor: p, brightness: Brightness.dark, surface: surface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: sc,
      scaffoldBackgroundColor: Colors.transparent,
      // iOS 风格页面切换
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900,
          color: Colors.white, letterSpacing: -0.5)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const RoundedRectangleBorder(borderRadius: r16))),
      sliderTheme: SliderThemeData(
        activeTrackColor: p, thumbColor: Colors.white,
        overlayColor: p.withOpacity(0.15), inactiveTrackColor: Colors.white.withOpacity(0.10),
        trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // 渐变
  static const grad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)]);
  static const grad3 = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFF472B6), Color(0xFF22D3EE)]);
  static const discGrad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFF472B6)]);
  static const playerGrad = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1530), Color(0xFF0A0A10)]);

  // 根据进度动态返回色
  static Color dynamicColor(double t) {
    if (t < 0.5) return Color.lerp(p, accent, t * 2)!;
    return Color.lerp(accent, s, (t - 0.5) * 2)!;
  }
}
