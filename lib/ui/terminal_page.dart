import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend_manager.dart';

class _H {
  static const green = Color(0xFF00FF41);
  static const greenDim = Color(0xFF00A828);
  static const cyan = Color(0xFF00FFFF);
  static const amber = Color(0xFFFFB000);
  static const red = Color(0xFFFF3355);
  static const bg = Color(0xFF0A0E0A);
  static const panel = Color(0xFF0F1A0F);
}

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});
  @override
  State<TerminalPage> createState() => _T();
}

class _T extends State<TerminalPage> with TickerProviderStateMixin {
  final List<TermLine> _lines = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription? _logSub;
  StreamSubscription? _progSub;
  double _progress = 0;
  bool _busy = false;
  bool _installed = false;
  bool _running = false;
  bool _lastOk = false;
  String _currentTask = '';
  late final AnimationController _scanCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _clockCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _clockCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _logSub = BackendManager.logs.listen(_onLog);
    _progSub = BackendManager.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    _refresh();
  }

  Future<void> _refresh() async {
    final installed = await BackendManager.isInstalled();
    final running = await BackendManager.isRunning();
    if (mounted) {
      setState(() {
        _installed = installed;
        _running = running;
      });
    }
  }

  void _onLog(TermLine line) {
    if (!mounted) return;
    final isProgress = RegExp(r'(Node|Backend)\s+\d+%').hasMatch(line.text);
    if (isProgress && _lines.isNotEmpty &&
        RegExp(r'(Node|Backend)\s+\d+%').hasMatch(_lines.last.text)) {
      setState(() => _lines[_lines.length - 1] = line);
      return;
    }
    setState(() {
      _lines.add(line);
      if (_lines.length > 250) _lines.removeRange(0, _lines.length - 250);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _run(Future<bool> Function() task, String name) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastOk = false;
      _currentTask = name;
    });
    final ok = await task();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastOk = ok;
    });
    await _refresh();
    HapticFeedback.mediumImpact();
  }

  Future<void> _clear() async {
    await BackendManager.clear();
    if (!mounted) return;
    setState(() {
      _lines.clear();
      _progress = 0;
      _installed = false;
      _running = false;
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _progSub?.cancel();
    _scroll.dispose();
    _scanCtrl.dispose();
    _blinkCtrl.dispose();
    _clockCtrl.dispose();
    super.dispose();
  }

  Color _color(LogLevel lv) {
    switch (lv) {
      case LogLevel.ok: return _H.green;
      case LogLevel.warn: return _H.amber;
      case LogLevel.err: return _H.red;
      case LogLevel.info: return _H.cyan;
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
      backgroundColor: _H.bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _MatrixPainter())),
        Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
          animation: _scanCtrl,
          builder: (_, __) => CustomPaint(painter: _ScanLinePainter(_scanCtrl.value)),
        ))),
        SafeArea(child: Column(children: [
          _topBar(),
          _actionBar(),
          Expanded(child: _console()),
          _bottomBar(),
        ])),
      ]),
    );
  }

  Widget _topBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _H.panel.withOpacity(0.9),
        border: Border.all(color: _H.green.withOpacity(0.4), width: 0.8),
        boxShadow: [BoxShadow(color: _H.green.withOpacity(0.18), blurRadius: 14, spreadRadius: -2)]),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context, _lastOk),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: _H.green.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(4)),
            child: Icon(Icons.arrow_back_ios_new, size: 12, color: _H.green))),
        const SizedBox(width: 10),
        _dot(_H.red), const SizedBox(width: 5),
        _dot(_H.amber), const SizedBox(width: 5),
        _dot(_H.green),
        const SizedBox(width: 12),
        Expanded(child: Text('root@kugou:~/backend#',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12,
            color: _H.green, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
        AnimatedBuilder(animation: _clockCtrl, builder: (_, __) {
          final now = DateTime.now();
          final hh = now.hour.toString().padLeft(2, '0');
          final mm = now.minute.toString().padLeft(2, '0');
          final ss = now.second.toString().padLeft(2, '0');
          return Text('$hh:$mm:$ss', style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, color: _H.cyan,
            fontWeight: FontWeight.w700));
        }),
        const SizedBox(width: 8),
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final on = _busy || _running;
          final color = _running ? _H.green
            : (_busy ? _H.amber : (_installed ? _H.cyan : _H.greenDim));
          return Container(width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(on ? (0.5 + _blinkCtrl.value * 0.5) : 0.6),
              boxShadow: [BoxShadow(color: color, blurRadius: on ? 8 : 3)]));
        }),
      ]));
  }

  Widget _dot(Color c) {
    return Container(width: 10, height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c));
  }

  Widget _actionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _H.panel.withOpacity(0.7),
        border: Border.all(color: _H.green.withOpacity(0.28), width: 0.8)),
      child: _installed ? _installedActions() : _firstTimeActions());
  }

  Widget _firstTimeActions() {
    return Column(children: [
      Row(children: [
        Icon(Icons.download, size: 14, color: _H.cyan),
        const SizedBox(width: 8),
        Text('首次使用：下载运行环境', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: _H.cyan,
          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 10),
      Text('Node 运行时 + KuGouMusicApi',
        style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _H.greenDim)),
      const SizedBox(height: 14),
      _bigBtn(
        label: _busy ? '下载中…' : '> 下载运行环境',
        color: _H.cyan,
        enabled: !_busy,
        onTap: () => _run(BackendManager.downloadRuntime, '下载')),
      if (_busy) ...[
        const SizedBox(height: 12),
        _progressBar(),
      ],
    ]);
  }

  Widget _installedActions() {
    return Column(children: [
      Row(children: [
        Icon(Icons.check_circle, size: 14, color: _H.green),
        const SizedBox(width: 8),
        Text('运行环境已就绪', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: _H.green,
          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const Spacer(),
        if (_running)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _H.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4)),
            child: Text('RUNNING', style: TextStyle(
              fontFamily: 'monospace', fontSize: 9, color: _H.green,
              fontWeight: FontWeight.w800, letterSpacing: 1))),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _bigBtn(
          label: _busy && _currentTask == '更新' ? '更新中…' : '> 更新后端',
          color: _H.amber,
          enabled: !_busy,
          onTap: () => _run(BackendManager.updateBackendOnly, '更新'))),
        const SizedBox(width: 12),
        Expanded(child: _bigBtn(
          label: _busy && _currentTask == '执行' ? '启动中…' : '> 执行',
          color: _H.green,
          enabled: !_busy,
          onTap: () => _run(BackendManager.executeOnly, '执行'))),
      ]),
      const SizedBox(height: 10),
      Text('「更新」= 拉最新 KuGouMusicApi    「执行」= 启动后端',
        style: TextStyle(fontFamily: 'monospace', fontSize: 9.5,
          color: _H.greenDim, height: 1.4)),
      if (_busy) ...[
        const SizedBox(height: 12),
        _progressBar(),
      ],
      if (_lastOk && !_busy)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 12, color: _H.green),
            const SizedBox(width: 5),
            Text('$_currentTask 成功', style: TextStyle(
              fontFamily: 'monospace', fontSize: 10, color: _H.green)),
          ])),
    ]);
  }

  Widget _bigBtn({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(enabled ? 0.7 : 0.3), width: 1.2),
          borderRadius: BorderRadius.circular(6),
          boxShadow: enabled ? [BoxShadow(color: color.withOpacity(0.4),
            blurRadius: 12, spreadRadius: -2)] : null),
        child: Center(child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: 13,
          color: enabled ? color : Colors.grey,
          fontWeight: FontWeight.w900, letterSpacing: 1)))));
  }

  Widget _progressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(children: [
        Container(height: 6, color: _H.green.withOpacity(0.10)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: MediaQuery.of(context).size.width * _progress * 0.9,
          height: 6,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_H.greenDim, _H.green, _H.cyan]),
            boxShadow: [BoxShadow(color: _H.green.withOpacity(0.7),
              blurRadius: 8, spreadRadius: 1)])),
      ]));
  }

  Widget _console() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        border: Border.all(color: _H.green.withOpacity(0.35), width: 0.8),
        boxShadow: [BoxShadow(color: _H.green.withOpacity(0.12),
          blurRadius: 16, spreadRadius: -5)]),
      child: Stack(children: [
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _H.green.withOpacity(0.10),
              border: Border(bottom: BorderSide(color: _H.green.withOpacity(0.25)))),
            child: Row(children: [
              Icon(Icons.terminal, size: 11, color: _H.green),
              const SizedBox(width: 6),
              Text('STDOUT — LIVE FEED', style: TextStyle(
                fontFamily: 'monospace', fontSize: 9.5, color: _H.green,
                letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${_lines.length} lines', style: TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: _H.greenDim,
                fontWeight: FontWeight.w700)),
            ]))),
        Positioned.fill(top: 26,
          child: _lines.isEmpty ? _emptyConsole() : _consoleList()),
      ]));
  }

  Widget _emptyConsole() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.memory, size: 44, color: _H.greenDim.withOpacity(0.35)),
      const SizedBox(height: 10),
      Text('> 等待操作...', style: TextStyle(
        fontFamily: 'monospace', fontSize: 13, color: _H.greenDim)),
      const SizedBox(height: 6),
      AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) =>
        Container(width: 9, height: 15,
          color: _H.green.withOpacity(_blinkCtrl.value))),
    ]));
  }

  Widget _consoleList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _lines.length,
      itemBuilder: _logLine);
  }

  Widget _logLine(BuildContext ctx, int i) {
    final line = _lines[i];
    final color = _color(line.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 12, alignment: Alignment.center,
          child: Text(_prefix(line.level), style: TextStyle(
            fontFamily: 'monospace', fontSize: 11,
            color: color, fontWeight: FontWeight.w800))),
        const SizedBox(width: 6),
        Expanded(child: Text(line.text.isEmpty ? ' ' : line.text,
          style: TextStyle(fontFamily: 'monospace',
            fontSize: 11, height: 1.45, color: color))),
      ]));
  }

  Widget _bottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _H.panel.withOpacity(0.9),
        border: Border.all(color: _H.green.withOpacity(0.35), width: 0.8),
        boxShadow: [BoxShadow(color: _H.green.withOpacity(0.12),
          blurRadius: 14, spreadRadius: -3)]),
      child: Row(children: [
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final c = _running ? _H.green
            : (_busy ? _H.amber : (_installed ? _H.cyan : _H.greenDim));
          final label = _running ? '> BACKEND ONLINE'
            : (_busy ? '> $_currentTask 中'
            : (_installed ? '> READY' : '> NO RUNTIME'));
          return Row(children: [
            Container(width: 9, height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.6 + _blinkCtrl.value * 0.4),
                boxShadow: [BoxShadow(color: c, blurRadius: _busy || _running ? 10 : 4)])),
            const SizedBox(width: 9),
            Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 11.5,
              color: c, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]);
        }),
        const Spacer(),
        GestureDetector(
          onTap: _busy ? null : _clear,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _H.greenDim.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4)),
            child: Row(children: [
              Icon(Icons.cleaning_services_outlined, size: 12, color: _H.greenDim),
              const SizedBox(width: 4),
              Text('清除', style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: _H.greenDim, fontWeight: FontWeight.w700)),
            ]))),
      ]));
  }
}

class _MatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final r = math.Random(42);
    const chars = '01アイウエオカキクケコサシスセソタチツテトABCDEF!@#';
    for (double x = 0; x < size.width; x += 20) {
      final col = (r.nextInt(8) + 3);
      for (int y = 0; y < col; y++) {
        final opacity = (1 - y / col) * 0.05;
        tp.text = TextSpan(text: chars[r.nextInt(chars.length)],
          style: TextStyle(color: _H.green.withOpacity(opacity),
            fontSize: 10, fontFamily: 'monospace'));
        tp.layout();
        tp.paint(canvas, Offset(x, y * 16.0));
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ScanLinePainter extends CustomPainter {
  final double t;
  _ScanLinePainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          _H.green.withOpacity(0.0),
          _H.green.withOpacity(0.07),
          _H.green.withOpacity(0.0),
        ]).createShader(Rect.fromLTWH(0, y - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, y - 40, size.width, 80), p);
  }
  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.t != t;
}
