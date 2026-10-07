import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wallpaper_manager.dart';

class AppBackground extends StatelessWidget {
  final Widget? child;
  const AppBackground({super.key, this.child});
  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WallpaperManager>().current;
    return Stack(children: [
      Positioned.fill(child: RepaintBoundary(child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: Image.asset(
          wp, key: ValueKey(wp), fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0D0D10)),
        ),
      ))),
      Positioned.fill(child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.42), Colors.black.withOpacity(0.62), Colors.black.withOpacity(0.76)])))),
      if (child != null) child!,
    ]);
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin, padding;
  final double radius;
  final VoidCallback? onTap;
  final bool heavy;
  const GlassCard({super.key, required this.child, this.margin, this.padding,
    this.radius = 20, this.onTap, this.heavy = false});
  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white.withOpacity(heavy ? 0.10 : 0.08);
    Widget inner = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.14), width: 0.9),
        boxShadow: heavy ? [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 4))] : null),
      padding: padding, child: child);
    if (heavy) {
      inner = ClipRRect(borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: inner));
    }
    if (onTap != null) {
      inner = Material(color: Colors.transparent, child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        splashColor: Colors.white10, highlightColor: Colors.white10,
        onTap: onTap, child: inner));
    }
    return Container(margin: margin, child: inner);
  }
}
