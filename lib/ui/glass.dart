import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wallpaper_manager.dart';
import 'theme.dart';

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
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: Image.asset(wp, key: ValueKey(wp), fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => Container(color: AppTheme.bg))))),
      Positioned.fill(child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.bg.withOpacity(0.35), AppTheme.bg.withOpacity(0.70), AppTheme.bg.withOpacity(0.88)])))),
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
  final Color? tint;
  const GlassCard({super.key, required this.child, this.margin, this.padding,
    this.radius = 20, this.onTap, this.heavy = false, this.tint});
  @override
  Widget build(BuildContext context) {
    final base = (tint ?? Colors.white).withOpacity(heavy ? 0.10 : 0.06);
    Widget inner = Container(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
        boxShadow: heavy ? [BoxShadow(color: Colors.black.withOpacity(0.30),
          blurRadius: 18, offset: const Offset(0, 6))] : null),
      padding: padding, child: child);
    if (heavy) {
      inner = ClipRRect(borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: inner));
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

/// 弹簧点击卡片（iOS 动效）
class SpringCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? margin, padding;
  final double radius;
  const SpringCard({super.key, required this.child, this.onTap,
    this.margin, this.padding, this.radius = 20});
  @override
  State<SpringCard> createState() => _SC();
}
class _SC extends State<SpringCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 120), lowerBound: 0, upperBound: 1);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) { _c.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, c) {
          final scale = 1.0 - _c.value * 0.04;
          return Transform.scale(scale: scale, child: c);
        },
        child: Container(
          margin: widget.margin,
          child: GlassCard(
            radius: widget.radius, padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color c1, c2;
  final double size;
  const IconTile({super.key, required this.icon, required this.c1, required this.c2, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
      borderRadius: BorderRadius.circular(size * 0.30),
      boxShadow: [BoxShadow(color: c1.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))]),
    child: Icon(icon, color: Colors.white, size: size * 0.48));
}

/// 列表项淡入入场
class FadeInItem extends StatefulWidget {
  final Widget child;
  final int index;
  const FadeInItem({super.key, required this.child, required this.index});
  @override
  State<FadeInItem> createState() => _FI();
}
class _FI extends State<FadeInItem> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    final delay = (widget.index * 30).clamp(0, 300);
    Future.delayed(Duration(milliseconds: delay), () { if (mounted) _c.forward(); });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final e = Curves.easeOutCubic.transform(_c.value);
      return Opacity(opacity: e, child: Transform.translate(
        offset: Offset(0, 12 * (1 - e)), child: child));
    },
    child: widget.child);
}
