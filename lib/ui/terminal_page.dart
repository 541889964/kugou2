import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend_manager.dart';
import 'theme.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key, this.autoStart = true});
  final bool autoStart;
  @override
  State<TerminalPage> createState() => _T();
}

class _T extends State<TerminalPage> {
  final List<TermLine> _lines = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription? _logSub;
  StreamSubscription? _progSub;
  double _progress = 0;
  bool _running = false;
  bool _done = false;
  bool _success = false;
  int _phase = 0; // 0=待机 1=测速 2=下载 3=解压 4=启动 5=完成

  @override
  void initState() {
    super.initState();
    _logSub = BackendManager.logs.listen((line) {
      if (!mounted) return;
      setState(() => _lines.add(line));
      // 从日志中识别当前阶段
      final t = line.text;
      if (t.contains('测速')) _phase = 1;
      else if (t.contains('下载 Node') || t.contains('下载 KuGou')) _phase = 2;
      else if (t.contains('解压')) _phase = 3;
      else if (t.contains('启动 Node')) _phase = 4;
      else if (t.contains('启动成功')) { _phase = 5; _success = true; }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
        }
      });
    });
    _progSub = BackendManager.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() { _running = true; _done = false; _success = false; _phase = 1; });
    final ok = await BackendManager.setupAndStart();
    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
      _success = ok;
      _phase = ok ? 5 : 0;
    });
    if (ok) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _stop() async {
    await BackendManager.stop();
    BackendManager.log('已发送停止信号', LogLevel.warn);
    setState(() { _running = false; _done = true; _success = false; });
  }

  Future<void> _clear() async {
    await BackendManager.clear();
    if (!mounted) return;
    setState(() {
      _lines.clear();
      _progress = 0;
      _done = false;
      _success = false;
      _phase = 0;
    });
    BackendManager.log('已清空已解压文件', LogLevel.warn);
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _progSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Color _color(LogLevel lv) {
    switch (lv) {
      case LogLevel.ok: return const Color(0xFF4ADE80);
      case LogLevel.warn: return const Color(0xFFFBBF24);
      case LogLevel.err: return const Color(0xFFF87171);
      case LogLevel.info: return const Color(0xFF7DD3FC);
    }
  }

  String _prefix(LogLevel lv) {
    switch (lv) {
      case LogLevel.ok: return '✓';
      case LogLevel.warn: return '⚠';
      case LogLevel.err: return '✗';
      case LogLevel.info: return '›';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Stack(children: [
        // 背景网格 + 光晕
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        Positioned(top: -80, right: -60,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.p.withOpacity(_running ? 0.28 : 0.12),
                Colors.transparent])))),
        Positioned(bottom: -100, left: -80,
          child: Container(width: 260, height: 260,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.s.withOpacity(_running ? 0.20 : 0.08),
                Colors.transparent])))),

        SafeArea(child: Column(children: [
          _header(),
          _phaseIndicator(),
          Expanded(child: _terminal()),
          _bottomBar(),
        ])),
      ]),
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 26, color: Colors.white),
          splashRadius: 20,
          onPressed: () => Navigator.pop(context, _success)),
        const SizedBox(width: 4),
        // 三色点（仿 macOS）
        Row(children: [
          _dot(const Color(0xFFFF5F56)),
          const SizedBox(width: 6),
          _dot(const Color(0xFFFFBD2E)),
          const SizedBox(width: 6),
          _dot(const Color(0xFF27C93F)),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KuGou Backend Terminal',
            style: TextStyle(fontFamily: 'monospace', fontSize: 13,
              fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text('v30.0 · Node arm64 runtime',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10,
              color: Colors.white.withOpacity(0.4))),
        ])),
        if (_running)
          const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Color(0xFF4ADE80)))),
      ]),
    );
  }

  Widget _dot(Color c) => Container(width: 11, height: 11,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _phaseIndicator() {
    final phases = ['测速', '下载', '解压', '启动', '完成'];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(children: [
        Row(children: List.generate(phases.length, (i) {
          final active = _phase == i + 1;
          final passed = _phase > i + 1;
          return Expanded(child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: passed || active ? AppTheme.grad : null,
                color: passed || active ? null : Colors.white.withOpacity(0.06),
                boxShadow: active ? [
                  BoxShadow(color: AppTheme.p.withOpacity(0.6),
                    blurRadius: 16, spreadRadius: 2)] : null),
              child: Icon(
                passed ? Icons.check : _phaseIcon(i),
                size: 14,
                color: passed || active ? Colors.white : Colors.white.withOpacity(0.3))),
            const SizedBox(height: 6),
            Text(phases[i], style: TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? Colors.white : (passed ? AppTheme.s : Colors.white.withOpacity(0.3)))),
          ]));
        })),
        const SizedBox(height: 12),
        // 细进度
        ClipRRect(borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(height: 4, color: Colors.white.withOpacity(0.05)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 4,
              width: MediaQuery.of(context).size.width * _progress * 0.92,
              decoration: BoxDecoration(
                gradient: AppTheme.grad,
                boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.6),
                  blurRadius: 8, spreadRadius: 1)])),
          ])),
        const SizedBox(height: 6),
        Row(children: [
          Text('进度 ${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10,
              color: Colors.white.withOpacity(0.5))),
          const Spacer(),
          if (_running)
            Text('运行中…', style: const TextStyle(fontFamily: 'monospace',
              fontSize: 10, color: Color(0xFF4ADE80)))
          else if (_done)
            Text(_success ? '成功' : '失败',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10,
                color: _success ? const Color(0xFF4ADE80) : const Color(0xFFF87171))),
        ]),
      ]),
    );
  }

  IconData _phaseIcon(int i) {
    switch (i) {
      case 0: return Icons.speed;
      case 1: return Icons.download;
      case 2: return Icons.folder_zip_outlined;
      case 3: return Icons.play_arrow;
      case 4: return Icons.check;
    }
    return Icons.circle;
  }

  Widget _terminal() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.55),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: ClipRRect(borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: _lines.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.terminal, size: 48, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 12),
                Text('等待初始化…', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 13,
                  color: Colors.white.withOpacity(0.3))),
              ]))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(14),
                itemCount: _lines.length,
                itemBuilder: (_, i) {
                  final line = _lines[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_prefix(line.level),
                        style: TextStyle(fontFamily: 'monospace',
                          fontSize: 12, color: _color(line.level),
                          fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        line.text.isEmpty ? ' ' : line.text,
                        style: TextStyle(fontFamily: 'monospace',
                          fontSize: 12, height: 1.5, color: _color(line.level)))),
                    ]));
                })))),
    );
  }

  Widget _bottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 9, height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _running ? const Color(0xFFFBBF24)
              : (_success ? const Color(0xFF4ADE80)
              : (_done ? const Color(0xFFF87171)
              : Colors.white.withOpacity(0.3))),
            boxShadow: _running ? [
              BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.6),
                blurRadius: 8, spreadRadius: 1)] : null)),
        const SizedBox(width: 10),
        Expanded(child: Text(
          _running ? '正在处理…'
            : (_success ? '✓ 后端已就绪'
            : (_done ? '✗ 处理失败'
            : '待机中')),
          style: TextStyle(fontFamily: 'monospace', fontSize: 12,
            color: Colors.white.withOpacity(0.8)))),
        if (_done && _success)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('完成', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700))),
        if (_done && !_success)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _start,
            child: const Text('重试', style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700))),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.white54),
          splashRadius: 18,
          tooltip: '清空重装',
          onPressed: _running ? null : _clear),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.015)..strokeWidth = 1;
    const gap = 32.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
