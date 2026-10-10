import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../mode_manager.dart';
import '../playlist.dart';
import '../signature_manager.dart';
import '../updater.dart';
import 'home.dart';
import 'theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _S();
}

class _S extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _c1, _c2;
  String _st = '正在唤醒…';
  double _p = 0;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
    _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _boot();
  }

  Future<void> _boot() async {
    setState(() { _st = '加载签名…'; _p = 0.20; });
    await SignatureManager.I.init();
    setState(() { _st = '检查 Cookie…'; _p = 0.42; });
    try { await SignatureManager.I.checkHealth().timeout(const Duration(seconds: 5)); } catch (_) {}
    setState(() { _st = '恢复模式…'; _p = 0.60; });
    await ModeManager.I.init();
    setState(() { _st = '同步收藏…'; _p = 0.78; });
    await PlaylistService.I.init();
    setState(() { _st = '检查更新…'; _p = 0.94; });
    Updater.I.check();
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() { _st = '就绪'; _p = 1.0; });
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const RootPage(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
        child: c),
      transitionDuration: const Duration(milliseconds: 500)));
  }

  @override
  void dispose() { _c1.dispose(); _c2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        // 顶部光晕
        AnimatedBuilder(animation: _c2, builder: (_, __) => Positioned(
          top: -100 + 40 * _c2.value, left: -60, right: -60,
          child: Container(height: 460,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.p.withOpacity(0.35),
                Colors.transparent])))),
        ),
        // 底部光晕
        Positioned(bottom: -140, left: -100, right: -100,
          child: Container(height: 380,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.s.withOpacity(0.20),
                Colors.transparent])))),
        // 内容
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedBuilder(animation: _c1, builder: (_, __) {
            final t = Curves.easeOutCubic.transform(
              _c1.value.clamp(0.0, 1.0));
            return Opacity(opacity: t, child: Transform.scale(
              scale: 0.7 + 0.3 * t,
              child: Container(width: 120, height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: AppTheme.grad3,
                  boxShadow: [
                    BoxShadow(color: AppTheme.p.withOpacity(0.55),
                      blurRadius: 60, spreadRadius: -8),
                    BoxShadow(color: AppTheme.accent.withOpacity(0.35),
                      blurRadius: 80, spreadRadius: -10)]),
                child: const Icon(Icons.graphic_eq, size: 60, color: Colors.white))))),
          }),
          const SizedBox(height: 40),
          // 逐字上浮
          AnimatedBuilder(animation: _c1, builder: (_, __) {
            const letters = ['K','u','G','o','u'];
            return Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(letters.length, (i) {
                final start = 0.25 + i * 0.08;
                final t = ((_c1.value - start) / 0.35).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - Curves.easeOutCubic.transform(t))),
                  child: Opacity(opacity: t, child: Text(letters[i],
                    style: const TextStyle(color: Colors.white,
                      fontSize: 42, fontWeight: FontWeight.w900,
                      letterSpacing: -1))));
              }));
          }),
          const SizedBox(height: 8),
          AnimatedBuilder(animation: _c1, builder: (_, __) {
            final t = ((_c1.value - 0.65) / 0.35).clamp(0.0, 1.0);
            return Opacity(opacity: t, child: Text('遇见更好的音乐',
              style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 12, letterSpacing: 6)));
          }),
          const SizedBox(height: 80),
          AnimatedBuilder(animation: _c1, builder: (_, __) {
            final t = ((_c1.value - 0.7) / 0.3).clamp(0.0, 1.0);
            return Opacity(opacity: t, child: Column(children: [
              SizedBox(width: 180, child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _p, minHeight: 3,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.p)))),
              const SizedBox(height: 16),
              Text(_st, style: TextStyle(color: Colors.white.withOpacity(0.5),
                fontSize: 11, letterSpacing: 2)),
            ]));
          }),
        ])),
      ]));
  }
}
