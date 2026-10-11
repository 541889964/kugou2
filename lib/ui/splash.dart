import 'dart:async';
import 'package:flutter/material.dart';
import '../mode_manager.dart';
import '../playlist.dart';
import '../signature_manager.dart';
import '../server_manager.dart';
import '../search_settings.dart';
import '../source_manager.dart';
import '../wallpaper_manager.dart';
import '../icon_picker.dart';
import '../updater.dart';
import 'home.dart';
import 'theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _S();
}

class _S extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _c1;
  String _st = '正在唤醒…';
  double _p = 0;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1500))..forward();
    _boot();
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    try {
      setState(() { _st = '加载签名配置…'; _p = 0.08; });
      try { await SignatureManager.I.init(); } catch (_) {}
      await _tick(start, 400);

      setState(() { _st = '恢复播放模式…'; _p = 0.16; });
      try { await ModeManager.I.init(); } catch (_) {}
      await _tick(start, 800);

      setState(() { _st = '同步收藏数据…'; _p = 0.24; });
      try { await PlaylistService.I.init(); } catch (_) {}
      await _tick(start, 1200);

      setState(() { _st = '加载服务器配置…'; _p = 0.32; });
      try { await ServerManager.I.init(); } catch (_) {}
      try { await SearchSettings.I.init(); } catch (_) {}
      try { await SourceManager.I.init(); } catch (_) {}
      try { await WallpaperManager.I.init(); } catch (_) {}
      await _tick(start, 1600);

      setState(() { _st = '预加载图标…'; _p = 0.42; });
      final icons = IconPicker.all;
      for (int i = 0; i < icons.length; i++) {
        try { await precacheImage(AssetImage(icons[i]), context); } catch (_) {}
        if (i % 5 == 0) {
          setState(() => _p = 0.42 + 0.18 * (i / icons.length));
        }
      }
      await _tick(start, 2400);

      setState(() { _st = '预加载壁纸…'; _p = 0.62; });
      final walls = WallpaperManager.all;
      for (int i = 0; i < walls.length; i++) {
        try { await precacheImage(AssetImage(walls[i]), context); } catch (_) {}
        if (i % 3 == 0) {
          setState(() => _p = 0.62 + 0.18 * (i / walls.length));
        }
      }
      await _tick(start, 3200);

      setState(() { _st = '检查账号状态…'; _p = 0.82; });
      try {
        await SignatureManager.I.checkHealth().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await _tick(start, 3800);

      setState(() { _st = '检查云端更新…'; _p = 0.90; });
      Updater.I.check();
      await _tick(start, 4200);

      setState(() { _st = '即将就绪…'; _p = 0.95; });
      await _tick(start, 5000);

      setState(() { _st = '就绪'; _p = 1.0; });
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RootPage(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic), child: c),
        transitionDuration: const Duration(milliseconds: 500)));
    } catch (e, st) {
      debugPrint('BOOT ERROR: $e\n$st');
      setState(() { _err = e; _st = '启动失败'; _p = 1.0; });
    }
  }

  Future<void> _tick(DateTime start, int targetMs) async {
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    final remain = targetMs - elapsed;
    if (remain > 0) await Future.delayed(Duration(milliseconds: remain));
  }

  @override
  void dispose() { _c1.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        Positioned(top: -100, left: -60, right: -60,
          child: Container(height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.p.withOpacity(0.30), Colors.transparent])))),
        Positioned(bottom: -120, left: -80, right: -80,
          child: Container(height: 340,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.s.withOpacity(0.18), Colors.transparent])))),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedBuilder(animation: _c1, builder: (_, __) {
            final t = Curves.easeOutCubic.transform(_c1.value.clamp(0.0, 1.0));
            return Opacity(opacity: t, child: Transform.scale(
              scale: 0.6 + 0.4 * t,
              child: Container(width: 110, height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: AppTheme.grad3,
                  boxShadow: [
                    BoxShadow(color: AppTheme.p.withOpacity(0.55),
                      blurRadius: 60, spreadRadius: -8),
                    BoxShadow(color: AppTheme.accent.withOpacity(0.35),
                      blurRadius: 80, spreadRadius: -10)]),
                child: const Icon(Icons.graphic_eq, size: 56, color: Colors.white))));
          }),
          const SizedBox(height: 36),
          const Text('KuGou', style: TextStyle(color: Colors.white, fontSize: 40,
            fontWeight: FontWeight.w900, letterSpacing: 6,
            shadows: [Shadow(color: Color(0xFF8B5CF6), blurRadius: 20)])),
          const SizedBox(height: 10),
          Text('遇见更好的音乐', style: TextStyle(
            color: Colors.white.withOpacity(0.55), fontSize: 12, letterSpacing: 5)),
          const SizedBox(height: 60),
          SizedBox(width: 200, child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 4, color: Colors.white.withOpacity(0.08)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200 * _p,
                height: 4,
                decoration: BoxDecoration(
                  gradient: AppTheme.grad,
                  boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.6),
                    blurRadius: 8)])),
            ]))),
          const SizedBox(height: 16),
          Text(_st, style: TextStyle(color: Colors.white.withOpacity(0.6),
            fontSize: 11.5, letterSpacing: 1.5)),
          if (_err != null) Padding(padding: const EdgeInsets.all(20),
            child: Text('$_err', textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 10))),
        ])),
      ]));
  }
}
