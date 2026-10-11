import 'dart:async';
import 'package:flutter/material.dart';
import '../backend_manager.dart';
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
  String _st = '正在唤醒…';
  double _p = 0;
  double _dlProgress = 0;
  bool _dlActive = false;
  StreamSubscription? _progSub;

  @override
  void initState() {
    super.initState();
    _progSub = BackendManager.progress.listen((v) {
      if (mounted) setState(() => _dlProgress = v);
    });
    _boot();
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    try {
      // ========== 0.0 - 1.2s 基础配置 ==========
      setState(() { _st = '加载签名配置…'; _p = 0.08; });
      try { await SignatureManager.I.init(); } catch (_) {}
      await _tick(start, 400);

      setState(() { _st = '恢复播放模式…'; _p = 0.15; });
      try { await ModeManager.I.init(); } catch (_) {}
      await _tick(start, 800);

      setState(() { _st = '同步收藏数据…'; _p = 0.22; });
      try { await PlaylistService.I.init(); } catch (_) {}
      await _tick(start, 1200);

      // ========== 1.2 - 2.5s 服务器 + 配置 ==========
      setState(() { _st = '加载服务器配置…'; _p = 0.28; });
      try { await ServerManager.I.init(); } catch (_) {}
      try { await SearchSettings.I.init(); } catch (_) {}
      try { await SourceManager.I.init(); } catch (_) {}
      try { await WallpaperManager.I.init(); } catch (_) {}
      await _tick(start, 2500);

      // ========== 2.5 - 4.0s 预热图标 + 壁纸 ==========
      setState(() { _st = '预加载资源…'; _p = 0.40; });
      final icons = IconPicker.all;
      for (int i = 0; i < icons.length; i++) {
        try { await precacheImage(AssetImage(icons[i]), context); } catch (_) {}
        if (i % 8 == 0) setState(() => _p = 0.40 + 0.15 * (i / icons.length));
      }
      final walls = WallpaperManager.all;
      for (int i = 0; i < walls.length; i++) {
        try { await precacheImage(AssetImage(walls[i]), context); } catch (_) {}
        if (i % 3 == 0) setState(() => _p = 0.55 + 0.08 * (i / walls.length));
      }
      await _tick(start, 4000);

      // ========== 4.0 - 4.5s 触发后端下载（如果未安装）==========
      setState(() { _st = '检查后端运行时…'; _p = 0.65; });
      try {
        final installed = await BackendManager.isInstalled();
        if (!installed) {
          setState(() { _st = '下载后端运行时 (62MB)…'; _dlActive = true; });
          // 异步启动，不阻塞
          unawaited(BackendManager.downloadRuntime());
        } else {
          setState(() => _st = '启动后端服务…');
          unawaited(BackendManager.executeOnly());
        }
      } catch (_) {}
      await _tick(start, 4500);

      // ========== 4.5 - 6.0s 健康检查 ==========
      setState(() { _st = '检查账号状态…'; _p = 0.75; });
      try {
        await SignatureManager.I.checkHealth().timeout(const Duration(seconds: 2));
      } catch (_) {}
      await _tick(start, 6000);

      // ========== 6.0 - 7.0s 云端更新 ==========
      setState(() { _st = '检查云端更新…'; _p = 0.85; });
      Updater.I.check();
      await _tick(start, 7000);

      // ========== 7.0 - 8.0s 收尾 ==========
      setState(() { _st = '即将就绪…'; _p = 0.95; });
      await _tick(start, 8000);

      setState(() { _st = '就绪'; _p = 1.0; });
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RootPage(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic), child: c),
        transitionDuration: const Duration(milliseconds: 400)));
    } catch (e) {
      debugPrint('BOOT ERROR: $e');
      setState(() { _st = '启动失败: $e'; _p = 1.0; });
    }
  }

  Future<void> _tick(DateTime start, int targetMs) async {
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (targetMs - elapsed > 0) {
      await Future.delayed(Duration(milliseconds: targetMs - elapsed));
    }
  }

  @override
  void dispose() {
    _progSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        Positioned(top: -100, left: -60, right: -60,
          child: Container(height: 400, decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppTheme.p.withOpacity(0.28), Colors.transparent])))),
        Positioned(bottom: -120, left: -80, right: -80,
          child: Container(height: 340, decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppTheme.s.withOpacity(0.16), Colors.transparent])))),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 110, height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: AppTheme.grad3,
              boxShadow: [
                BoxShadow(color: AppTheme.p.withOpacity(0.55),
                  blurRadius: 60, spreadRadius: -8),
                BoxShadow(color: AppTheme.accent.withOpacity(0.35),
                  blurRadius: 80, spreadRadius: -10)]),
            child: const Icon(Icons.graphic_eq, size: 56, color: Colors.white)),
          const SizedBox(height: 36),
          const Text('KuGou', style: TextStyle(color: Colors.white, fontSize: 40,
            fontWeight: FontWeight.w900, letterSpacing: 6,
            shadows: [Shadow(color: Color(0xFF8B5CF6), blurRadius: 20)])),
          const SizedBox(height: 10),
          Text('遇见更好的音乐', style: TextStyle(
            color: Colors.white.withOpacity(0.55), fontSize: 12, letterSpacing: 5)),
          const SizedBox(height: 60),
          SizedBox(width: 220, child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 4, color: Colors.white.withOpacity(0.08)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 220 * _p, height: 4,
                decoration: BoxDecoration(
                  gradient: AppTheme.grad,
                  boxShadow: [BoxShadow(
                    color: AppTheme.p.withOpacity(0.6), blurRadius: 8)])),
            ]))),
          const SizedBox(height: 16),
          Text(_st, style: TextStyle(color: Colors.white.withOpacity(0.65),
            fontSize: 11.5, letterSpacing: 1.5)),
          if (_dlActive && _dlProgress > 0) ...[
            const SizedBox(height: 12),
            SizedBox(width: 220, child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 2.5, color: Colors.white.withOpacity(0.06)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 220 * _dlProgress, height: 2.5,
                  color: AppTheme.s),
              ]))),
            const SizedBox(height: 6),
            Text('${(_dlProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10,
                color: AppTheme.s.withOpacity(0.8))),
          ],
        ])),
      ]));
  }
}
