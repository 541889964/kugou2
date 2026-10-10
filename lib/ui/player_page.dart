import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../floating_lyric.dart';
import '../icon_picker.dart';
import '../kugou.dart';
import 'theme.dart';
import 'glass.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(gradient: AppTheme.playerGrad))),
        Positioned(top: -100, left: -60, right: -60,
          child: Container(height: 380,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.p.withOpacity(0.35), Colors.transparent])))),
        SafeArea(child: Column(children: [
          // 顶栏
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 30, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
              const Spacer(),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('正在播放', style: TextStyle(fontSize: 10,
                  color: Colors.white70, letterSpacing: 3)),
                const SizedBox(height: 2),
                SizedBox(width: 160, child: Text(s.album.isEmpty ? '未知专辑' : s.album,
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)))),
              ]),
              const Spacer(),
              IconButton(
                icon: Icon(FloatingLyricService.I.active
                  ? Icons.picture_in_picture_alt : Icons.picture_in_picture_alt_outlined,
                  size: 24, color: Colors.white),
                onPressed: () async {
                  if (FloatingLyricService.I.active) {
                    await FloatingLyricService.I.hide();
                    if (context.mounted) _toast(context, '已关闭悬浮歌词');
                  } else {
                    final ok = await FloatingLyricService.I.show();
                    if (!context.mounted) return;
                    if (ok) { _toast(context, '悬浮歌词已开启'); }
                    else {
                      final err = FloatingLyricService.I.lastError;
                      _toast(context, err.isEmpty ? '开启失败，请检查悬浮窗权限' : err);
                    }
                  }
                }),
            ])),
          const Spacer(flex: 2),
          _disc(s, p.playing),
          const SizedBox(height: 32),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(children: [
              Text(s.name, maxLines: 2, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  letterSpacing: -0.3, color: Colors.white, height: 1.3)),
              const SizedBox(height: 8),
              Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
            ])),
          if (p.errorMsg != null) Padding(padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
            child: Text(p.errorMsg!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5))),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Slider(value: cur, max: max > 0 ? max : 1,
              onChanged: max > 0 ? (v) => p.seek(Duration(milliseconds: v.toInt())) : null)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_f(p.position), style: TextStyle(fontSize: 11,
                color: Colors.white.withOpacity(0.55))),
              Text(_f(dur), style: TextStyle(fontSize: 11,
                color: Colors.white.withOpacity(0.55))),
            ])),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(iconSize: 30, icon: Icon(_mi(p.mode), color: Colors.white70),
              onPressed: () { p.cycleMode(); _toast(context, _mt(p.mode)); }),
            const SizedBox(width: 14),
            IconButton(iconSize: 46, icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: p.prev),
            const SizedBox(width: 14),
            Container(width: 78, height: 78,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.grad,
                boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.55),
                  blurRadius: 36, spreadRadius: 2)]),
              child: IconButton(iconSize: 44, color: Colors.white,
                icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44),
                onPressed: p.toggle)),
            const SizedBox(width: 14),
            IconButton(iconSize: 46, icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: p.next),
            const SizedBox(width: 14),
            if (s.isLocal) const SizedBox(width: 30)
            else if (t == null) IconButton(iconSize: 28,
              icon: Icon(Icons.download_outlined, color: Colors.white.withOpacity(0.7)),
              onPressed: () async {
                final ok = await dl.download(s);
                if (context.mounted) _toast(context, ok ? '已开始下载' : '已存在或失败');
              })
            else if (t.status == 'done') const Icon(Icons.check_circle, color: AppTheme.s, size: 28)
            else if (t.status == 'failed') IconButton(iconSize: 28,
              icon: const Icon(Icons.refresh, color: Colors.redAccent),
              onPressed: () => dl.download(s))
            else Padding(padding: const EdgeInsets.all(6),
              child: SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(value: t.progress > 0 ? t.progress : null, strokeWidth: 3))),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pill(context, Icons.lyrics_outlined, '歌词', () => _showLyric(context, p)),
            const SizedBox(width: 12),
            _pill(context, fav ? Icons.favorite : Icons.favorite_border,
              fav ? '已收藏' : '收藏',
              () async {
                final a = await pl.toggle(s);
                if (context.mounted) _toast(context, a ? '已收藏' : '已取消');
              },
              color: fav ? AppTheme.accent : null),
            if (!s.isLocal) ...[
              const SizedBox(width: 12),
              _pill(context, Icons.file_download_outlined, '下歌词',
                () async {
                  final ok = await dl.downloadLyric(s);
                  if (context.mounted) _toast(context, ok ? '歌词已保存' : '歌词下载失败');
                }),
            ],
          ]),
          const Spacer(),
        ])),
      ]),
    );
  }

  Widget _pill(BuildContext c, IconData ic, String label, VoidCallback onTap, {Color? color}) {
    return Material(color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 17, color: color ?? Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5,
              color: color ?? Colors.white70, fontWeight: FontWeight.w600)),
          ]))));
  }

  Widget _disc(Song s, bool playing) => _RotatingDisc(song: s, playing: playing);

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
      duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.surface));
  }
  void _showLyric(BuildContext context, PlayerService p) {
    if (p.lyricLines.isEmpty) {
      _toast(context, '暂无歌词'); return;
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
  final Song song; final bool playing;
  const _RotatingDisc({required this.song, required this.playing});
  @override
  State<_RotatingDisc> createState() => _DS();
}
class _DS extends State<_RotatingDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 26));
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
    final ip = IconPicker.forHash(widget.song.hash);
    return Container(width: 280, height: 280,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: AppTheme.p.withOpacity(0.55), blurRadius: 70, spreadRadius: 2),
        BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 90, spreadRadius: -10),
        const BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 14))]),
      child: RotationTransition(turns: _c,
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [
              Color(0xFF181820), Color(0xFF2A2A38), Color(0xFF181820),
              Color(0xFF2A2A38), Color(0xFF181820)]),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 8)),
          padding: const EdgeInsets.all(28),
          child: ClipOval(child: ip.isEmpty ? _ph() : Image.asset(ip,
            fit: BoxFit.cover, filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => _ph())))));
  }
  Widget _ph() => Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
    child: const Icon(Icons.music_note, size: 100, color: Colors.white70));
}

class _LyricSheet extends StatefulWidget {
  final PlayerService player; final ScrollController scroll;
  const _LyricSheet({required this.player, required this.scroll});
  @override
  State<_LyricSheet> createState() => _LS();
}
class _LS extends State<_LyricSheet> {
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.player, builder: (_, __) {
    final lines = widget.player.lyricLines;
    final cur = widget.player.currentLyricIndex;
    return ListView.builder(controller: widget.scroll,
      padding: const EdgeInsets.symmetric(vertical: 60),
      itemCount: lines.length, itemBuilder: (_, i) {
      final isCur = i == cur;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 260),
          style: TextStyle(fontSize: isCur ? 18 : 14,
            fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
            color: isCur ? AppTheme.p : Colors.white.withOpacity(0.5), height: 1.5),
          child: Text(lines[i].text, textAlign: TextAlign.center)));
    });
  });
}
