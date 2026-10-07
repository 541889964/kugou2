import 'dart:ui';
import 'package:flutter/material.dart';

/// 全局壁纸背景（MaterialApp.builder 包一层即可覆盖所有页面）
class AppBackground extends StatelessWidget {
  final Widget? child;
  const AppBackground({super.key, this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: Image.asset(
        'assets/wallpaper.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0812)),
      )),
      Positioned.fill(child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.40),
            Colors.black.withOpacity(0.62),
            Colors.black.withOpacity(0.75),
          ],
        )),
      )),
      if (child != null) child!,
    ]);
  }
}

/// 液态玻璃卡片
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double blur;
  final double opacity;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;
  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.blur = 22,
    this.opacity = 0.10,
    this.radius = 20,
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.0),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      content = Material(color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: content));
    }
    return Container(margin: margin, child: content);
  }
}

/// 玻璃质感的 scaffold
class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  const GlassScaffold({super.key, this.appBar, this.body, this.floatingActionButton, this.bottomNavigationBar});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: appBar,
    body: body,
    floatingActionButton: floatingActionButton,
    bottomNavigationBar: bottomNavigationBar,
  );
}
