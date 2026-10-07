import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'local_music.dart';
import 'mode_manager.dart';
import 'server_manager.dart';
import 'search_settings.dart';
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
  String _cur = '', _next = '', _title = '';
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) setState(() {
        _cur = event['cur']?.toString() ?? '';
        _next = event['next']?.toString() ?? '';
        _title = event['title']?.toString() ?? '';
        _playing = event['playing'] == true;
      });
    });
  }
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent,
    child: GestureDetector(
      onTap: () => FlutterOverlayWindow.shareData('open_player'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12))),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500))),
            Icon(_playing ? Icons.play_arrow : Icons.pause, color: Colors.white38, size: 12),
          ]),
          const SizedBox(height: 6),
          Text(_cur, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          if (_next.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
            child: Text(_next, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12))),
        ]))));
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
    ChangeNotifierProvider.value(value: MusicRecognition.I),
    ChangeNotifierProvider.value(value: LocalMusicScanner.I),
  ], child: MaterialApp(title: 'KuGou', debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    builder: (context, child) => AppBackground(child: child),
    home: const SplashPage()));
}
