import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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
  const TerminalPage({super.key, this.autoStart = true});
  final bool autoStart;
  @override
  State<TerminalPage> createState() => _T();
}

class _T extends State<TerminalPage> with TickerProviderStateMixin {
  final List<TermLine> _lines = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription? _logSub;
  StreamSubscription? _progSub;

  double _progress = 0;
  bool _running = false;
  bool _done = false;
  bool _success = false;
  int _phase = 0;

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
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
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

    final t = line.text;
    if (t.contains('测速')) {
      _phase = 1;
    } else if (t.contains('并发下载') || t.contains('下载 Node')) {
      _phase = 2;
    } else if (t.contains('解压')) {
      _phase = 3;
    } else if (t.contains('启动 Node')) {
      _phase = 4;
    } else if (t.contains('启动成功')) {
      _phase = 5;
      _success = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true; _done = false; _success = false; _phase = 1;
    });
    final ok = await BackendManager.setupAndStart();
    if (!mounted) return;
    setState(() {
      _running = false; _done = true; _success = ok; _phase = ok ? 5 : 0;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _clear() async {
    await BackendManager.clear();
    if (!mounted) return;
    setState(() {
      _lines.clear(); _progress = 0; _done = false; _success = false; _phase = 0;
    });
    BackendManager.log('CLEARED', LogLevel.warn);
  }

  Future<void> _showCrashLog() async {
    final log = await BackendManager.getCrashLog();
    if (!mounted) return;
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: _H.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _H.red.withOpacity(0.5))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _H.red.withOpacity(0.3)))),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: _H.red, size: 18),
              const SizedBox(width: 8),
              Text('SYSTEM CRASH LOG', style: TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: _H.red,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
            ])),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              log.isEmpty ? '> (no data)' : log,
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: _H.greenDim, height: 1.5)))),
          Padding(padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11, color: _H.green))),
            ])),
        ]))));
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
          _phaseStrip(),
          Expanded(child: _console()),
          _bottomBar(),
        ])),
      ]),
    );
  }

  Widget _topBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _H.panel.withOpacity(0.85),
        border: Border.all(color: _H.green.withOpacity(0.35), width: 0.8),
        boxShadow: [BoxShadow(color: _H.green.withOpacity(0.15),
          blurRadius: 12, spreadRadius: -2)]),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: _H.green),
          splashRadius: 16,
          onPressed: () => Navigator.pop(context, _success)),
        const SizedBox(width: 4),
        _blinkDot(_H.red),
        const SizedBox(width: 5),
        _blinkDot(_H.amber),
        const SizedBox(width: 5),
        _blinkDot(_H.green),
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
            fontFamily: 'monospace', fontSize: 11, color: _H.cyan));
        }),
        const SizedBox(width: 8),
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final on = _running;
          final color = on ? _H.green : (_done ? (_success ? _H.green : _H.red) : _H.greenDim);
          return Container(width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(on ? (0.5 + _blinkCtrl.value * 0.5) : 0.6),
              boxShadow: [BoxShadow(color: color, blurRadius: on ? 8 : 3)]));
        }),
      ]));
  }

  Widget _blinkDot(Color c) => Container(width: 10, height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _phaseStrip() {
    const phases = ['SCAN', 'DL', 'UNZIP', 'EXEC', 'DONE'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _H.panel.withOpacity(0.6),
        border: Border.all(color: _H.green.withOpacity(0.25), width: 0.8)),
      child: Column(children: [
        SizedBox(height: 40, child: Row(children: List.generate(phases.length, (i) {
          final active = _phase == i + 1;
          final passed = _phase > i + 1;
          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: passed ? _H.green.withOpacity(0.25)
                    : (active ? _H.green.withOpacity(0.15) : Colors.transparent),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: passed ? _H.green : (active ? _H.cyan : _H.greenDim.withOpacity(0.4)),
                    width: 1.5),
                  boxShadow: active ? [BoxShadow(
                    color: _H.cyan.withOpacity(0.6),
                    blurRadius: 10, spreadRadius: 1)] : null),
                child: Center(child: Text(
                  passed ? '✓' : '${i + 1}',
                  style: TextStyle(
                    fontFamily: 'monospace', fontSize: 10,
                    color: passed ? _H.green : (active ? _H.cyan : _H.greenDim),
                    fontWeight: FontWeight.w800)))),
              const SizedBox(height: 4),
              Text(phases[i], style: TextStyle(
                fontFamily: 'monospace', fontSize: 9,
                color: active ? _H.cyan : (passed ? _H.green : _H.greenDim.withOpacity(0.5)),
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ])),
            if (i < phases.length - 1)
              Expanded(child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    (passed ? _H.green : _H.greenDim).withOpacity(0.5),
                    (passed ? _H.green : _H.greenDim).withOpacity(0.2),
                  ])))),
          ]));
        }))),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(height: 6, child: Stack(children: [
            Container(color: _H.green.withOpacity(0.08)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * _progress * 0.92,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_H.greenDim, _H.green, _H.cyan]),
                boxShadow: [BoxShadow(color: _H.green.withOpacity(0.7),
                  blurRadius: 8, spreadRadius: 1)])),
            if (_running)
              Positioned.fill(child: AnimatedBuilder(
                animation: _scanCtrl,
                builder: (_, __) => Align(
                  alignment: Alignment(-1 + _scanCtrl.value * 2, 0),
                  child: Container(width: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.7),
                        Colors.transparent])))))),
          ]))),
        const SizedBox(height: 4),
        Row(children: [
          Text('>> ${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10,
              color: _H.green, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(_statusText(), style: TextStyle(
            fontFamily: 'monospace', fontSize: 10,
            color: _running ? _H.cyan : (_success ? _H.green : (_done ? _H.red : _H.greenDim)),
            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
      ]));
  }

  String _statusText() {
    if (_running) return '[RUNNING]';
    if (_done) return _success ? '[SUCCESS]' : '[FAILED]';
    return '[IDLE]';
  }

  Widget _console() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        border: Border.all(color: _H.green.withOpacity(0.3), width: 0.8),
        boxShadow: [BoxShadow(color: _H.green.withOpacity(0.1),
          blurRadius: 15, spreadRadius: -5)]),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Stack(children: [
            Positioned(top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _H.green.withOpacity(0.08),
                  border: Border(bottom: BorderSide(color: _H.green.withOpacity(0.2)))),
                child: Row(children: [
                  Icon(Icons.terminal, size: 10, color: _H.green),
                  const SizedBox(width: 6),
                  Text('STDOUT — LIVE FEED', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 9, color: _H.green,
                    letterSpacing: 1, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${_lines.length} lines', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 9, color: _H.greenDim)),
                ]))),
            Positioned.fill(top: 22,
              child: _lines.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.memory, size: 40, color: _H.greenDim.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text('> 等待输入...', style: TextStyle(
                      fontFamily: 'monospace', fontSize: 12, color: _H.greenDim)),
                    const SizedBox(height: 4),
                    AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) =>
                      Container(width: 8, height: 14,
                        color: _H.green.withOpacity(_blinkCtrl.value))),
                  ]))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    itemCount: _lines.length,
                    itemBuilder: _logLine)),
          ])),
      ),
    );
  }

  Widget _logLine(BuildContext ctx, int i) {
    final line = _lines[i];
    final color = _color(line.level);
    final ts = DateTime.now();
    final tsStr = '${ts.hour.toString().padLeft(2, '0')}:'
      '${ts.minute.toString().padLeft(2, '0')}:'
      '${ts.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('[$tsStr]', style: TextStyle(
          fontFamily: 'monospace', fontSize: 10,
          color: _H.greenDim.withOpacity(0.5))),
        const SizedBox(width: 6),
        Text(_prefix(line.level), style: TextStyle(
          fontFamily: 'monospace', fontSize: 11,
          color: color, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Expanded(child: Text(line.text.isEmpty ? ' ' : line.text,
          style: TextStyle(fontFamily: 'monospace',
            fontSize: 11, height: 1.4, color: color))),
      ]),
    );
  }

  Widget _bottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _H.panel.withOpacity(0.85),
        border: Border.all(color: _H.green.withOpacity(0.3), width: 0.8),
        boxShadow: [BoxShadow(color: _H.green.withOpacity(0.1),
          blurRadius: 12, spreadRadius: -3)]),
      child: Row(children: [
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final c = _running ? _H.amber
            : (_success ? _H.green : (_done ? _H.red : _H.greenDim));
          return Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.6 + _blinkCtrl.value * 0.4),
                boxShadow: [BoxShadow(color: c, blurRadius: _running ? 8 : 3)])),
            const SizedBox(width: 8),
            Text(_running ? '> PROCESSING'
              : (_done ? (_success ? '> OK' : '> ERR') : '> STANDBY'),
              style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                color: c, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ]);
        }),
        const Spacer(),
        if (_done && !_success)
          TextButton(
            onPressed: _showCrashLog,
            style: TextButton.styleFrom(
              foregroundColor: _H.amber,
              padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text('>> LOG', style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700))),
        if (_done && _success)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _H.green, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('> DONE', style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w800))),
        if (_done && !_success)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _H.amber, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            onPressed: _start,
            child: Text('> RETRY', style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w800))),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.cleaning_services_outlined, size: 16, color: _H.greenDim),
          splashRadius: 16,
          tooltip: 'CLEAR',
          onPressed: _running ? null : _clear),
      ]));
  }
}

class _MatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final r = math.Random(42);
    const chars = '01アイウエオカキクケコサシスセソタチツテトABCDEF!@#';
    for (double x = 0; x < size.width; x += 18) {
      final col = (r.nextInt(10) + 3);
      for (int y = 0; y < col; y++) {
        final opacity = (1 - y / col) * 0.06;
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
          _H.green.withOpacity(0.08),
          _H.green.withOpacity(0.0),
        ]).createShader(Rect.fromLTWH(0, y - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, y - 40, size.width, 80), p);
  }
  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.t != t;
}
