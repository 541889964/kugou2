import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _logSub = BackendManager.logs.listen((line) {
      if (!mounted) return;
      setState(() => _lines.add(line));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
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
    setState(() { _running = true; _done = false; });
    final ok = await BackendManager.setupAndStart();
    if (!mounted) return;
    setState(() { _running = false; _done = true; });
    if (ok) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _stop() async {
    await BackendManager.stop();
    BackendManager.log('已发送停止信号', LogLevel.warn);
  }

  Future<void> _clear() async {
    await BackendManager.clear();
    if (!mounted) return;
    setState(() { _lines.clear(); _progress = 0; _done = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090C),
      appBar: AppBar(
        title: const Text('后端终端', style: TextStyle(fontFamily: 'monospace',
          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
        backgroundColor: const Color(0xFF0B0F14),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            tooltip: '清空重装', onPressed: _running ? null : _clear),
          IconButton(
            icon: Icon(_running ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 20),
            tooltip: _running ? '停止' : '开始',
            onPressed: _running ? _stop : _start),
        ],
      ),
      body: Column(children: [
        // 进度条
        if (_running || _progress > 0)
          Container(
            height: 3,
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: const Color(0xFF111820),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)))),
        // 终端输出
        Expanded(child: Container(
          color: const Color(0xFF07090C),
          child: _lines.isEmpty
            ? const Center(child: Text('等待初始化…', style: TextStyle(
                fontFamily: 'monospace', color: Color(0xFF4ADE80), fontSize: 13)))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _lines.length,
                itemBuilder: (_, i) {
                  final line = _lines[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      line.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: _color(line.level))));
                }))),
        // 底部状态
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF0B0F14),
          child: Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _done ? (_progress >= 1 ? const Color(0xFF4ADE80) : const Color(0xFFF87171))
                             : const Color(0xFFFBBF24))),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _running ? '运行中…' : (_done ? (_progress >= 1 ? '成功' : '失败') : '待机'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12,
                color: Color(0xFFB0BEC5)))),
            if (_done && _progress >= 1)
              TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('完成', style: TextStyle(color: Color(0xFF4ADE80)))),
          ])),
      ]),
    );
  }
}
