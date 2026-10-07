import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../mode_manager.dart';
import '../playlist.dart';
import '../signature_manager.dart';
import '../updater.dart';
import 'home.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _S();
}

class _S extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _logoScale, _logoFade, _textFade, _ring;
  String _st = '正在启动…';
  double _p = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _logoScale = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)));
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _textFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.7, curve: Curves.easeOut)));
    _ring = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.15, 1.0, curve: Curves.easeInOut)));
    _b();
  }

  Future<void> _b() async {
    setState(() { _st = '加载签名配置…'; _p = 0.20; });
    await SignatureManager.I.init();
    setState(() { _st = '检查 Cookie 健康…'; _p = 0.42; });
    try { await SignatureManager.I.checkHealth().timeout(const Duration(seconds: 5)); } catch (_) {}
    setState(() { _st = '恢复播放模式…'; _p = 0.58; });
    await ModeManager.I.init();
    setState(() { _st = '同步收藏数据…'; _p = 0.76; });
    await PlaylistService.I.init();
    setState(() { _st = '检查云端更新…'; _p = 0.92; });
    Updater.I.check();
    final elapsed = (_c.value * 1400).toInt();
    if (elapsed < 1250) await Future.delayed(Duration(milliseconds: 1250 - elapsed));
    setState(() { _st = '就绪'; _p = 1.0; });
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const RootPage(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 380)));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0D0D10), body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF1A1730), Color(0xFF0D0D10), Color(0xFF13202A)])),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(animation: _c, builder: (_, __) => Opacity(
          opacity: _logoFade.value,
          child: Transform.scale(scale: _logoScale.value, child: SizedBox(
            width: 180, height: 180,
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 180, height: 180, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF7C6CB0).withOpacity(0.48 * _logoFade.value),
                  Colors.transparent]))),
              CustomPaint(size: const Size(180, 180),
                painter: _RingPainter(progress: _ring.value, color: const Color(0xFF7C6CB0))),
              Container(width: 96, height: 96, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF7C6CB0), Color(0xFF5A5480)]),
                boxShadow: [BoxShadow(color: const Color(0xFF7C6CB0).withOpacity(0.55),
                  blurRadius: 32, spreadRadius: 2)]),
                child: const Icon(Icons.music_note, size: 50, color: Colors.white)),
            ]))))),
        const SizedBox(height: 46),
        AnimatedBuilder(animation: _textFade, builder: (_, __) => Opacity(
          opacity: _textFade.value,
          child: Column(children: [
            const Text('KuGou', style: TextStyle(color: Colors.white, fontSize: 44,
              fontWeight: FontWeight.w900, letterSpacing: 7,
              shadows: [Shadow(color: Color(0xFF7C6CB0), blurRadius: 22)])),
            const SizedBox(height: 12),
            Text('遇见更好的音乐', style: TextStyle(
              color: Colors.white.withOpacity(0.72), fontSize: 13, letterSpacing: 5)),
          ]))),
        const SizedBox(height: 68),
        AnimatedBuilder(animation: _c, builder: (_, __) => Column(children: [
          SizedBox(width: 220, child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: _p > 0 ? _p : null, minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7C6CB0))))),
          const SizedBox(height: 18),
          Text(_st, style: TextStyle(color: Colors.white.withOpacity(0.62),
            fontSize: 12, letterSpacing: 1.5)),
        ])),
      ]))));
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.06));
    final fg = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 3.2..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.05), color, const Color(0xFF8FA3B8)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, 2 * math.pi * progress, false, fg);
  }
  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
