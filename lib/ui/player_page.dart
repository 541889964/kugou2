import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../floating_lyric.dart';
import '../icon_picker.dart';
import 'theme.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    final s = p.current;
    if (s == null) return const Scaffold(body: Center(child: Text('无曲目')));
    final dur = p.duration ?? Duration.zero;
    final max = dur.inMilliseconds.toDouble();
    final cur = p.position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    final pl = context.watch<PlaylistService>();
    final fav = pl.contains(s);
    final dl = context.watch<Downloader>();
    final t = dl.tasks[s.hash];

    return Scaffold(body: Stack(children: [
      // 壁纸
      Positioned.fill(child: Image.asset('assets/wallpaper.jpg',
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.bg))),
      // 封面再叠一层模糊
      if (s.cover != null)
        Positioned.fill(child: Opacity(opacity: 0.35, child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: CachedNetworkImage(imageUrl: s.cover!, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox())))),
      // 暗化渐变
      Positioned.fill(child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.35),
            Colors.black.withOpacity(0.72),
            Colors.black.withOpacity(0.92),
          ])))),

      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 30),
              color: Colors.white, onPressed: () => Navigator.pop(context)),
            const Spacer(),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('正在播放', style: TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 2)),
              const SizedBox(height: 2),
              SizedBox(width: 160, child: Text(s.album.isEmpty ? '未知专辑' : s.album,
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white54))),
            ]),
            const Spacer(),
            IconButton(icon: Icon(
                FloatingLyricService.I.active
                  ? Icons.picture_in_picture_alt
                  : Icons.picture_in_picture_alt_outlined, size: 24, color: Colors.white),
              tooltip: '悬浮歌词',
              onPressed: () async {
                if (FloatingLyricService.I.active) {
                  await FloatingLyricService.I.hide();
                } else {
                  final ok = await FloatingLyricService.I.show();
                  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('需要悬浮窗权限')));
                }
              }),
          ])),
        const Spacer(flex: 2),
        _RotatingDisc(song: s, playing: p.playing),
        const SizedBox(height: 36),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            Text(s.name, maxLines: 2, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                letterSpacing: 0.5, color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 20)])),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (s.isLocal)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.s.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('本地', style: TextStyle(fontSize: 10, color: AppTheme.s, fontWeight: FontWeight.w600))),
              if (s.isLocal) const SizedBox(width: 8),
              Flexible(child: Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.white70))),
            ]),
          ])),
        if (p.errorMsg != null)
          Padding(padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
            child: Text(p.errorMsg!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const Spacer(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
            child: Slider(value: cur, max: max > 0 ? max : 1,
              onChanged: max > 0 ? (v) => p.seek(Duration(milliseconds: v.toInt())) : null))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_f(p.position), style: const TextStyle(fontSize: 11, color: Colors.white60)),
            Text(_f(dur), style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ])),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(iconSize: 30, icon: Icon(_mi(p.mode), color: Colors.white70),
            onPressed: () { p.cycleMode(); _toast(context, _mt(p.mode)); }),
          const SizedBox(width: 16),
          IconButton(iconSize: 46, icon: const Icon(Icons.skip_previous),
            color: Colors.white, onPressed: p.prev),
          const SizedBox(width: 12),
          Container(width: 78, height: 78,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.grad,
              boxShadow: [
                BoxShadow(color: AppTheme.p.withOpacity(0.55), blurRadius: 32, spreadRadius: 2),
                BoxShadow(color: AppTheme.s.withOpacity(0.35), blurRadius: 60, spreadRadius: -8, offset: const Offset(0, 8)),
              ]),
            child: IconButton(iconSize: 46, color: Colors.white,
              icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44),
              onPressed: p.toggle)),
          const SizedBox(width: 12),
          IconButton(iconSize: 46, icon: const Icon(Icons.skip_next),
            color: Colors.white, onPressed: p.next),
          const SizedBox(width: 16),
          if (s.isLocal)
            const SizedBox(width: 30)
          else if (t == null)
            IconButton(iconSize: 30, icon: Icon(Icons.download_outlined, color: Colors.white70),
              onPressed: () async {
                final ok = await dl.download(s);
                if (context.mounted) _toast(context, ok ? '已开始下载' : '已存在或失败');
              })
          else if (t.status == 'done')
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 30)
          else if (t.status == 'failed')
            IconButton(iconSize: 30, icon: const Icon(Icons.refresh, color: Colors.redAccent),
              onPressed: () => dl.download(s))
          else Padding(padding: const EdgeInsets.all(4),
            child: SizedBox(width: 26, height: 26,
              child: CircularProgressIndicator(value: t.progress > 0 ? t.progress : null, strokeWidth: 3))),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _pill(context, icon: Icons.lyrics_outlined, label: '歌词', onTap: () => _showLyric(context, p)),
          const SizedBox(width: 12),
          _pill(context,
            icon: fav ? Icons.favorite : Icons.favorite_border,
            label: fav ? '已收藏' : '收藏',
            color: fav ? Colors.redAccent : null,
            onTap: () async {
              final a = await pl.toggle(s);
              if (context.mounted) _toast(context, a ? '已收藏' : '已取消');
            }),
          if (!s.isLocal) ...[
            const SizedBox(width: 12),
            _pill(context, icon: Icons.file_download_outlined, label: '下歌词',
              onTap: () async {
                final ok = await dl.downloadLyric(s);
                if (context.mounted) _toast(context, ok ? '歌词已保存' : '歌词下载失败');
              }),
          ],
        ]),
        const Spacer(),
      ])),
    ]));
  }
  Widget _pill(BuildContext c, {required IconData icon, required String label,
      Color? color, required VoidCallback onTap}) {
    return Material(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color ?? Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color ?? Colors.white70, fontWeight: FontWeight.w500)),
          ]))));
  }
  IconData _mi(PlayMode m) { switch (m) {
    case PlayMode.order: return Icons.repeat;
    case PlayMode.shuffle: return Icons.shuffle;
    case PlayMode.single: return Icons.repeat_one; } }
  String _mt(PlayMode m) { switch (m) {
    case PlayMode.order: return '列表循环';
    case PlayMode.shuffle: return '随机播放';
    case PlayMode.single: return '单曲循环'; } }
  void _toast(BuildContext c, String s) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s),
      duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
  }
  void _showLyric(BuildContext context, PlayerService p) {
    if (p.lyricLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无歌词')));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(expand: false,
        initialChildSize: 0.8, maxChildSize: 0.95,
        builder: (_, c) => _LyricSheet(player: p, scroll: c)));
  }
  static String _f(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _RotatingDisc extends StatefulWidget {
  final Song song;
  final bool playing;
  const _RotatingDisc({required this.song, required this.playing});
  @override
  State<_RotatingDisc> createState() => _RotatingDiscState();
}
class _RotatingDiscState extends State<_RotatingDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));
    if (widget.playing) _c.repeat();
  }
  @override
  void didUpdateWidget(covariant _RotatingDisc old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    else if (!widget.playing && _c.isAnimating) _c.stop();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290, height: 290,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: AppTheme.p.withOpacity(0.5), blurRadius: 70, spreadRadius: 2),
        const BoxShadow(color: Colors.black54, blurRadius: 22, offset: Offset(0, 12)),
      ]),
      child: RotationTransition(turns: _c,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [
              Color(0xFF181820), Color(0xFF2A2A38), Color(0xFF181820),
              Color(0xFF2A2A38), Color(0xFF181820),
            ]),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 8)),
          padding: const EdgeInsets.all(30),
          child: ClipOval(child: _img()))));
  }
  Widget _img() {
    if (widget.song.cover != null && widget.song.cover!.isNotEmpty) {
      return CachedNetworkImage(imageUrl: widget.song.cover!, fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _ph());
    }
    return _ph();
  }
  Widget _ph() {
    final p = IconPicker.forHash(widget.song.hash);
    if (p.isEmpty) {
      return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, size: 100, color: Colors.white70));
    }
    return Image.asset(p, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, size: 100, color: Colors.white70)));
  }
}

class _LyricSheet extends StatefulWidget {
  final PlayerService player;
  final ScrollController scroll;
  const _LyricSheet({required this.player, required this.scroll});
  @override
  State<_LyricSheet> createState() => _LyricSheetState();
}
class _LyricSheetState extends State<_LyricSheet> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: widget.player, builder: (_, __) {
      final lines = widget.player.lyricLines;
      final cur = widget.player.currentLyricIndex;
      return ListView.builder(
        controller: widget.scroll,
        padding: const EdgeInsets.symmetric(vertical: 60),
        itemCount: lines.length,
        itemBuilder: (_, i) {
          final isCur = i == cur;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: isCur ? 18 : 14,
                fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                color: isCur ? AppTheme.p : Colors.white.withOpacity(0.5),
                height: 1.5),
              child: Text(lines[i].text, textAlign: TextAlign.center)));
        });
    });
  }
}
