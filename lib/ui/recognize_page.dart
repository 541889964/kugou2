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
      MusicRecognition.I.reset();
      MusicRecognition.I.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<MusicRecognition>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('听歌识曲'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            onPressed: () => _toast('识别历史即将上线'),
          ),
        ],
      ),
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 20),
        _ring(r),
        const SizedBox(height: 28),
        _statusText(r),
        const SizedBox(height: 16),
        _waveform(r),
        const SizedBox(height: 20),
        if (r.result != null) _resultBlock(r),
        if (r.state == RecogState.failed) _errorBlock(r),
        if (r.state == RecogState.idle ||
            r.state == RecogState.recording ||
            r.state == RecogState.uploading) _hint(),
        const Spacer(),
        _actions(r),
        const SizedBox(height: 32),
      ])),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2)));
  }

  Widget _ring(MusicRecognition r) {
    final p = r.progress;
    return SizedBox(width: 220, height: 220, child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(220, 220), painter: _CirclePainter(progress: p)),
      AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: r.state == RecogState.recording ? 132 : 120,
        height: r.state == RecogState.recording ? 132 : 120,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: AppTheme.grad,
          boxShadow: [
            BoxShadow(
              color: AppTheme.p.withOpacity(r.state == RecogState.recording ? 0.6 : 0.35),
              blurRadius: r.state == RecogState.recording ? 55 : 38,
              spreadRadius: r.state == RecogState.recording ? 6 : 3),
          ]),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Icon(
            r.state == RecogState.recording
              ? Icons.graphic_eq
              : r.state == RecogState.done ? Icons.check
              : r.state == RecogState.failed ? Icons.close
              : Icons.mic_none,
            key: ValueKey(r.state),
            size: 54, color: Colors.white)),
      ),
    ]));
  }

  Widget _statusText(MusicRecognition r) {
    String t;
    switch (r.state) {
      case RecogState.idle: t = '准备中…'; break;
      case RecogState.recording: t = '正在聆听…'; break;
      case RecogState.uploading: t = '识别中…'; break;
      case RecogState.done: t = '识别成功'; break;
      case RecogState.failed: t = '识别失败'; break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: Text(t, key: ValueKey(r.state),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
          color: r.state == RecogState.failed
            ? Colors.redAccent : Colors.white.withOpacity(0.92))));
  }

  Widget _waveform(MusicRecognition r) {
    final wf = r.waveform;
    if (wf.isEmpty) return const SizedBox(height: 60);
    return SizedBox(height: 60, child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(wf.length, (i) {
        final h = 8 + wf[i] * 52;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 3, height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: AppTheme.p.withOpacity(0.4 + 0.6 * wf[i]),
            borderRadius: BorderRadius.circular(2)));
      })));
  }

  Widget _hint() => Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Text('请将手机靠近音源，保持安静，识别过程约 8 秒',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), height: 1.7)));

  Widget _resultBlock(MusicRecognition r) {
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
            Text(res.artist.isEmpty ? '未知歌手' : res.artist,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
          ])),
          if (res.source != null)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.p.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6)),
              child: Text(res.source!, style: TextStyle(fontSize: 10, color: AppTheme.p))),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.p),
          onPressed: () async {
            final kw = res.artist.isEmpty ? res.title : '${res.title} ${res.artist}';
            _toast('搜索中：$kw');
            final songs = await KuGouApi.I.search(kw);
            if (songs.isEmpty) { _toast('未找到'); return; }
            if (!mounted) return;
            PlayerService.I.playSong(songs.first, list: songs);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
          },
          icon: const Icon(Icons.search, size: 18),
          label: const Text('在酷狗搜索并播放'))),
      ])));
  }

  Widget _errorBlock(MusicRecognition r) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Text(r.error ?? '',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12.5, color: Colors.redAccent, height: 1.7)));

  Widget _actions(MusicRecognition r) {
    final busy = r.state == RecogState.recording || r.state == RecogState.uploading;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.white.withOpacity(0.18))),
          onPressed: busy ? null : () {
            MusicRecognition.I.reset();
            MusicRecognition.I.start();
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重录'))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: r.state == RecogState.recording ? Colors.redAccent : AppTheme.p),
          onPressed: busy
            ? (r.state == RecogState.recording ? () => MusicRecognition.I.stop() : null)
            : () => MusicRecognition.I.start(),
          icon: Icon(r.state == RecogState.recording ? Icons.stop : Icons.mic, size: 18),
          label: Text(r.state == RecogState.recording ? '停止识别' : '开始识别'))),
      ]));
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  _CirclePainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.08));
    final fg = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [AppTheme.p.withOpacity(0.1), AppTheme.p, AppTheme.s],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, 2 * math.pi * progress, false, fg);
  }
  @override
  bool shouldRepaint(covariant _CirclePainter old) => old.progress != progress;
}
