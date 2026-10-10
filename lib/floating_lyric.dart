import 'dart:async';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'player.dart';

class FloatingLyricService {
  static final FloatingLyricService I = FloatingLyricService._();
  FloatingLyricService._();
  bool _active = false;
  bool get active => _active;
  Timer? _timer;
  String lastError = '';

  Future<bool> show() async {
    lastError = '';
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        final ok = await FlutterOverlayWindow.requestPermission();
        if (ok != true) { lastError = '未授予悬浮窗权限'; return false; }
      }
      if (_active) return true;
      await FlutterOverlayWindow.showOverlay(
        height: 92, width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        enableDrag: true, positionGravity: PositionGravity.none,
        overlayTitle: 'KuGou 歌词', overlayContent: '歌词');
      _active = true; _start(); return true;
    } catch (e) { lastError = '$e'; return false; }
  }

  Future<void> hide() async {
    try { if (_active) await FlutterOverlayWindow.closeOverlay(); } catch (_) {}
    _timer?.cancel(); _active = false;
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (!_active) return;
      final p = PlayerService.I;
      final s = p.current;
      if (s == null) return;
      final lines = p.lyricLines;
      final ms = p.position.inMilliseconds;
      int idx = 0;
      if (lines.isNotEmpty) {
        for (int i = lines.length - 1; i >= 0; i--) {
          if (ms >= lines[i].time) { idx = i; break; }
        }
      }
      final cur = lines.isNotEmpty && idx < lines.length ? lines[idx].text : '';
      final next = lines.isNotEmpty && idx + 1 < lines.length ? lines[idx + 1].text : '';
      final dur = p.duration?.inMilliseconds ?? 0;
      final prog = dur > 0 ? (ms / dur).clamp(0.0, 1.0) : 0.0;
      try {
        await FlutterOverlayWindow.shareData({
          'cur': cur, 'next': next, 'title': s.name,
          'playing': p.playing, 'progress': prog});
      } catch (_) {}
    });
  }
}
