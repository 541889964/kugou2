import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_recognition.dart';
import '../kugou.dart';
import '../player.dart';
import 'theme.dart';
import 'glass.dart';
import 'player_page.dart';

class RecognizePage extends StatefulWidget {
  const RecognizePage({super.key});
  @override
  State<RecognizePage> createState() => _S();
}
class _S extends State<RecognizePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MusicRecognition.I.reset(); MusicRecognition.I.start();
    });
  }
  @override
  Widget build(BuildContext context) {
    final r = context.watch<MusicRecognition>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('听歌识曲')),
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 20),
        _ring(r), const SizedBox(height: 28),
        _status(r), const SizedBox(height: 16),
        _wave(r), const SizedBox(height: 20),
        if (r.result != null) _result(r),
        if (r.state == RecogState.failed) Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(r.error ?? '', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Colors.redAccent, height: 1.7))),
        const Spacer(),
        _actions(r),
        const SizedBox(height: 32),
      ])),
    );
  }
  Widget _ring(MusicRecognition r) => SizedBox(width: 220, height: 220,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(220, 220), painter: _CP(progress: r.progress)),
      Container(width: r.state == RecogState.recording ? 132 : 120,
        height: r.state == RecogState.recording ? 132 : 120,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.grad,
          boxShadow: [BoxShadow(
            color: AppTheme.p.withOpacity(r.state == RecogState.recording ? 0.6 : 0.35),
            blurRadius: r.state == RecogState.recording ? 55 : 38,
            spreadRadius: r.state == RecogState.recording ? 6 : 3)]),
        child: Icon(r.state == RecogState.recording ? Icons.graphic_eq
          : r.state == RecogState.done ? Icons.check
          : r.state == RecogState.failed ? Icons.close : Icons.mic_none,
          size: 54, color: Colors.white)),
    ]));
  Widget _status(MusicRecognition r) {
    String t;
    switch (r.state) {
      case RecogState.idle: t = '准备中…'; break;
      case RecogState.recording: t = '正在聆听…'; break;
      case RecogState.uploading: t = '识别中…'; break;
      case RecogState.done: t = '识别成功'; break;
      case RecogState.failed: t = '识别失败'; break;
    }
    return Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
      color: r.state == RecogState.failed ? Colors.redAccent : Colors.white.withOpacity(0.92)));
  }
  Widget _wave(MusicRecognition r) {
    final wf = r.waveform;
    if (wf.isEmpty) return const SizedBox(height: 60);
    return SizedBox(height: 60, child: Row(mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(wf.length, (i) {
        final h = 8 + wf[i] * 52;
        return Container(width: 3, height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: AppTheme.p.withOpacity(0.4 + 0.6 * wf[i]),
            borderRadius: BorderRadius.circular(2)));
      })));
  }
  Widget _result(MusicRecognition r) {
    final res = r.result!;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(radius: 16, padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          const Icon(Icons.music_note, color: Color(0xFF9C8FD0), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(res.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(res.artist.isEmpty ? '未知歌手' : res.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
          ])),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.p),
          onPressed: () async {
            final kw = res.artist.isEmpty ? res.title : '${res.title} ${res.artist}';
            final songs = await KuGouApi.I.search(kw);
            if (songs.isEmpty) return;
            if (!mounted) return;
            PlayerService.I.playSong(songs.first, list: songs);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
          },
          icon: const Icon(Icons.search, size: 18),
          label: const Text('在酷狗搜索并播放'))),
      ])));
  }
  Widget _actions(MusicRecognition r) {
    final busy = r.state == RecogState.recording || r.state == RecogState.uploading;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.white.withOpacity(0.18))),
          onPressed: busy ? null : () { MusicRecognition.I.reset(); MusicRecognition.I.start(); },
          icon: const Icon(Icons.refresh, size: 18), label: const Text('重录'))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: r.state == RecogState.recording ? Colors.redAccent : AppTheme.p),
          onPressed: busy ? (r.state == RecogState.recording ? () => MusicRecognition.I.stop() : null)
            : () => MusicRecognition.I.start(),
          icon: Icon(r.state == RecogState.recording ? Icons.stop : Icons.mic, size: 18),
          label: Text(r.state == RecogState.recording ? '停止识别' : '开始识别'))),
      ]));
  }
}
class _CP extends CustomPainter {
  final double progress;
  _CP({required this.progress});
  @override
  void paint(Canvas c, Size s) {
    final ce = s.center(Offset.zero);
    final r = s.width / 2 - 6;
    c.drawCircle(ce, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.08));
    final fg = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [AppTheme.p.withOpacity(0.1), AppTheme.p, AppTheme.s])
        .createShader(Rect.fromCircle(center: ce, radius: r));
    c.drawArc(Rect.fromCircle(center: ce, radius: r), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }
  @override
  bool shouldRepaint(covariant _CP o) => o.progress != progress;
}
