import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'local_music.dart';
import 'mode_manager.dart';
import 'server_manager.dart';
import 'search_settings.dart';
import 'wallpaper_manager.dart';
import 'music_recognition.dart';
import 'player.dart';
import 'playlist.dart';
import 'downloader.dart';
import 'updater.dart';
import 'ui/theme.dart';
import 'ui/glass.dart';
import 'ui/splash.dart';

@pragma("vm:entry-point")
void overlayMain() => runApp(const _OverlayApp());

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();
  @override
  State<_OverlayApp> createState() => _OA();
}

class _OA extends State<_OverlayApp> {
  String _cur = '', _next = '', _title = '', _singer = '';
  bool _playing = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && mounted) {
        setState(() {
          _cur = event['cur']?.toString() ?? '';
          _next = event['next']?.toString() ?? '';
          _title = event['title']?.toString() ?? '';
          _singer = event['singer']?.toString() ?? '';
          _playing = event['playing'] == true;
          final pr = event['progress'];
          _progress = pr is num ? pr.toDouble().clamp(0.0, 1.0) : 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => FlutterOverlayWindow.shareData('open_player'),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xE6201E32), Color(0xE60D0D14)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6)),
                  BoxShadow(color: const Color(0xFF7C6CB0).withOpacity(0.25), blurRadius: 24, spreadRadius: -4)]),
              child: Stack(children: [
                Positioned(left: 0, top: 0, bottom: 0, width: 3,
                  child: Container(decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFF7C6CB0), Color(0xFF5A5480)]),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20), bottomLeft: Radius.circular(20))))),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _playing ? Colors.greenAccent : Colors.orangeAccent,
                          boxShadow: [BoxShadow(
                            color: (_playing ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.6),
                            blurRadius: 6, spreadRadius: 1)])),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_singer.isEmpty ? _title : '$_title · $_singer',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w500, letterSpacing: 0.3))),
                      Icon(_playing ? Icons.graphic_eq : Icons.pause, size: 12,
                        color: Colors.white.withOpacity(0.4)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_cur.isEmpty ? '♪ ♪ ♪' : _cur,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5, height: 1.3,
                        shadows: [Shadow(color: Color(0xFF7C6CB0), blurRadius: 10),
                          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))])),
                    if (_next.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(_next, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.45),
                          fontSize: 12.5, height: 1.3))),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(2),
                      child: SizedBox(height: 2.5, child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white.withOpacity(0.10),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF7C6CB0))))),
                  ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 加大图片缓存，避免每次重建都重新解码
  PaintingBinding.instance.imageCache.maximumSize = 400;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 << 20;
  bool isOverlay = false;
  try { isOverlay = await FlutterOverlayWindow.isActive(); } catch (_) {}
  if (isOverlay) {
    runApp(const _OverlayApp());
    return;
  }
  await ServerManager.I.init();
  await SearchSettings.I.init();
  await WallpaperManager.I.init();
  runApp(const KuGouApp());
}

class KuGouApp extends StatelessWidget {
  const KuGouApp({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(providers: [
    ChangeNotifierProvider.value(value: PlayerService.I),
    ChangeNotifierProvider.value(value: ModeManager.I),
    ChangeNotifierProvider.value(value: PlaylistService.I),
    ChangeNotifierProvider.value(value: Downloader.I),
    ChangeNotifierProvider.value(value: Updater.I),
    ChangeNotifierProvider.value(value: ServerManager.I),
    ChangeNotifierProvider.value(value: SearchSettings.I),
    ChangeNotifierProvider.value(value: WallpaperManager.I),
    ChangeNotifierProvider.value(value: MusicRecognition.I),
    ChangeNotifierProvider.value(value: LocalMusicScanner.I),
  ], child: MaterialApp(title: 'KuGou', debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    builder: (context, child) => AppBackground(child: child),
    home: const SplashPage()));
}
