import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'local_music.dart';
import 'mode_manager.dart';
import 'player.dart';
import 'playlist.dart';
import 'downloader.dart';
import 'updater.dart';
import 'server_manager.dart';
import 'search_settings.dart';
import 'source_manager.dart';
import 'wallpaper_manager.dart';
import 'music_recognition.dart';
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
  String _cur = '', _next = '', _title = '';
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
          _playing = event['playing'] == true;
          final pr = event['progress'];
          _progress = pr is num ? pr.toDouble().clamp(0.0, 1.0) : 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent,
      child: GestureDetector(
        onTap: () => FlutterOverlayWindow.shareData('open_player'),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5),
                  blurRadius: 20, offset: const Offset(0, 6))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Container(width: 5, height: 5,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _playing ? const Color(0xFF22D3EE) : Colors.white38)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_title, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5,
                          color: Colors.white.withOpacity(0.45)))),
                      Icon(_playing ? Icons.graphic_eq : Icons.pause,
                        size: 11, color: Colors.white.withOpacity(0.35)),
                    ]),
                    const SizedBox(height: 6),
                    Text(_cur.isEmpty ? '♪' : _cur, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600, letterSpacing: 0.4, height: 1.3)),
                    if (_next.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(_next, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.4),
                          fontSize: 11.5, height: 1.3))),
                  ])),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                  child: SizedBox(height: 2, child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7C6CB0))))),
              ]))))));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 400;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 << 20;
  bool isOverlay = false;
  try { isOverlay = await FlutterOverlayWindow.isActive(); } catch (_) {}
  if (isOverlay) { runApp(const _OverlayApp()); return; }
  await ServerManager.I.init();
  await SearchSettings.I.init();
  await SourceManager.I.init();
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
    ChangeNotifierProvider.value(value: LocalMusicScanner.I),
    ChangeNotifierProvider.value(value: ServerManager.I),
    ChangeNotifierProvider.value(value: SearchSettings.I),
    ChangeNotifierProvider.value(value: SourceManager.I),
    ChangeNotifierProvider.value(value: WallpaperManager.I),
    ChangeNotifierProvider.value(value: MusicRecognition.I),
  ], child: MaterialApp(title: 'KuGou', debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    builder: (context, child) => AppBackground(child: child),
    home: const SplashPage()));
}
