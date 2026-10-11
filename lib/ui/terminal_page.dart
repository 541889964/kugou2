import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend_manager.dart';

class _C {
  static const green = Color(0xFF00FF41);
  static const greenDim = Color(0xFF00A828);
  static const cyan = Color(0xFF00FFFF);
  static const amber = Color(0xFFFFB000);
  static const red = Color(0xFFFF3355);
  static const bg = Color(0xFF080C0A);
  static const panel = Color(0xFF0D150F);
  static const border = Color(0xFF1A2F1E);
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
  DateTime? _taskStart;

  late final AnimationController _scanCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _progressAnimCtrl;

  Animation<double> _progressAnim = const AlwaysStoppedAnimation(0);

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _progressAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressAnimCtrl, curve: Curves.easeOutCubic));

    _logSub = BackendManager.logs.listen(_onLog);
    _progSub = BackendManager.progress.listen(_onProgress);
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

  void _onProgress(double p) {
    if (!mounted) return;
    final old = _progress;
    setState(() => _progress = p);
    // 平滑动画
    _progressAnim = Tween<double>(begin: old, end: p).animate(
      CurvedAnimation(parent: _progressAnimCtrl, curve: Curves.easeOutCubic));
    _progressAnimCtrl.forward(from: 0);
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
      if (_lines.length > 300) _lines.removeRange(0, _lines.length - 300);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _run(Future<bool> Function() task, String name) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastOk = false;
      _currentTask = name;
      _taskStart = DateTime.now();
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
    _entryCtrl.dispose();
    _progressAnimCtrl.dispose();
    super.dispose();
  }

  Color _color(LogLevel lv) {
    switch (lv) {
      case LogLevel.ok: return _C.green;
      case LogLevel.warn: return _C.amber;
      case LogLevel.err: return _C.red;
      case LogLevel.info: return _C.cyan;
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
      backgroundColor: _C.bg,
      body: Stack(children: [
        // 1. 背景：静态矩阵
        Positioned.fill(child: CustomPaint(painter: _MatrixPainter())),

        // 2. 扫描线（缓慢上下）
        Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
          animation: _scanCtrl,
          builder: (_, __) => CustomPaint(painter: _ScanPainter(_scanCtrl.value)),
        ))),

        // 3. 内容（带入场动画）
        SafeArea(child: AnimatedBuilder(
          animation: _entryCtrl,
          builder: (_, child) {
            final t = Curves.easeOutCubic.transform(_entryCtrl.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - t)),
                child: child),
            );
          },
          child: Column(children: [
            _topBar(),
            _actionPanel(),
            Expanded(child: _console()),
            _bottomBar(),
          ]),
        )),
      ]),
    );
  }

  // ============ 顶栏 ============
  Widget _topBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.panel,
        border: Border.all(color: _C.border, width: 0.8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: _C.green.withOpacity(0.10), blurRadius: 20, spreadRadius: -4)]),
      child: Row(children: [
        // 返回按钮
        _tapBtn(
          onTap: () => Navigator.pop(context, _lastOk),
          child: Icon(Icons.arrow_back_ios_new, size: 13, color: _C.green)),
        const SizedBox(width: 12),
        _dot(_C.red), const SizedBox(width: 6),
        _dot(_C.amber), const SizedBox(width: 6),
        _dot(_C.green),
        const SizedBox(width: 14),
        Expanded(child: Text('root@kugou:~/backend#',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12,
            color: _C.green, fontWeight: FontWeight.w700, letterSpacing: 0.4))),
        // 闪烁状态灯
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final on = _busy || _running;
          final color = _running ? _C.green
            : (_busy ? _C.amber : (_installed ? _C.cyan : _C.greenDim));
          return Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(on ? (0.6 + _blinkCtrl.value * 0.4) : 0.5),
              boxShadow: [BoxShadow(
                color: color.withOpacity(on ? 0.8 : 0.3),
                blurRadius: on ? 10 : 4,
                spreadRadius: on ? 1 : 0)]));
        }),
      ]));
  }

  Widget _dot(Color c) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _tapBtn({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          border: Border.all(color: _C.green.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(5)),
        child: child));
  }

  // ============ 动作面板 ============
  Widget _actionPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _C.panel,
        border: Border.all(
          color: _installed
            ? _C.green.withOpacity(0.35)
            : _C.cyan.withOpacity(0.35),
          width: 0.8),
        borderRadius: BorderRadius.circular(8)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim, axisAlignment: -1, child: child)),
        child: _installed
          ? _installedActions(key: const ValueKey('installed'))
          : _firstTimeActions(key: const ValueKey('first'))),
    );
  }

  Widget _firstTimeActions({Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _iconBadge(Icons.download, _C.cyan),
        const SizedBox(width: 10),
        Text('首次使用：下载运行环境', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12.5, color: _C.cyan,
          fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 12),
      Text('· Node 运行时 (约 62MB)\n· KuGouMusicApi (约 3MB)',
        style: TextStyle(fontFamily: 'monospace', fontSize: 10.5,
          color: _C.greenDim, height: 1.7)),
      const SizedBox(height: 16),
      _bigBtn(
        label: _busy ? '下载中…' : '下载运行环境',
        subtitle: _busy ? '正在下载，请稍候' : '首次使用，约 3-5 分钟',
        icon: Icons.cloud_download_outlined,
        color: _C.cyan,
        enabled: !_busy,
        onTap: () => _run(BackendManager.downloadRuntime, '下载')),
      if (_busy) ...[
        const SizedBox(height: 16),
        _progressIndicator(),
      ],
    ]);
  }

  Widget _installedActions({Key? key}) {
    return Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _iconBadge(Icons.check_circle, _C.green),
        const SizedBox(width: 10),
        Text('运行环境已就绪', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12.5, color: _C.green,
          fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        const Spacer(),
        if (_running)
          _statusChip('RUNNING', _C.green)
        else if (_installed)
          _statusChip('READY', _C.cyan),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _bigBtn(
          label: _busy && _currentTask == '更新' ? '更新中…' : '更新后端',
          subtitle: '拉取最新 KuGouMusicApi',
          icon: Icons.refresh,
          color: _C.amber,
          enabled: !_busy,
          onTap: () => _run(BackendManager.updateBackendOnly, '更新'))),
        const SizedBox(width: 12),
        Expanded(child: _bigBtn(
          label: _busy && _currentTask == '执行' ? '启动中…' : '执行',
          subtitle: '启动后端服务',
          icon: Icons.play_arrow_rounded,
          color: _C.green,
          enabled: !_busy,
          onTap: () => _run(BackendManager.executeOnly, '执行'))),
      ]),
      if (_busy) ...[
        const SizedBox(height: 16),
        _progressIndicator(),
      ],
      if (_lastOk && !_busy && _taskStart != null)
        Padding(padding: const EdgeInsets.only(top: 12),
          child: _successChip(_currentTask)),
    ]);
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 16, color: color));
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          return Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.6 + _blinkCtrl.value * 0.4)));
        }),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(
          fontFamily: 'monospace', fontSize: 9.5, color: color,
          fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ]));
  }

  Widget _successChip(String task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.green.withOpacity(0.08),
        border: Border.all(color: _C.green.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(Icons.check_circle_outline, size: 14, color: _C.green),
        const SizedBox(width: 8),
        Text('$task 成功', style: TextStyle(
          fontFamily: 'monospace', fontSize: 11, color: _C.green,
          fontWeight: FontWeight.w700)),
      ]));
  }

  Widget _bigBtn({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return _AnimatedPressBtn(
      enabled: enabled,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.10) : Colors.grey.withOpacity(0.06),
          border: Border.all(
            color: color.withOpacity(enabled ? 0.5 : 0.2), width: 1),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled ? [
            BoxShadow(color: color.withOpacity(0.20),
              blurRadius: 16, spreadRadius: -4),
          ] : null),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(enabled ? 0.20 : 0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18,
              color: enabled ? color : Colors.grey)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 13,
              color: enabled ? color : Colors.grey,
              fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(
              fontFamily: 'monospace', fontSize: 9.5,
              color: enabled ? color.withOpacity(0.55) : Colors.grey.withOpacity(0.5),
              letterSpacing: 0.3)),
          ])),
          if (enabled)
            Icon(Icons.chevron_right, size: 18, color: color.withOpacity(0.6)),
        ])));
  }

  Widget _progressIndicator() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${(_progress * 100).toStringAsFixed(0)}%', style: TextStyle(
          fontFamily: 'monospace', fontSize: 11, color: _C.green,
          fontWeight: FontWeight.w800)),
        const Spacer(),
        if (_taskStart != null)
          Text(_elapsed(), style: TextStyle(
            fontFamily: 'monospace', fontSize: 10, color: _C.greenDim)),
      ]),
      const SizedBox(height: 8),
      AnimatedBuilder(
        animation: _progressAnimCtrl,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(height: 5, color: _C.green.withOpacity(0.10)),
            FractionallySizedBox(
              widthFactor: _progressAnim.value.clamp(0.0, 1.0),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _C.greenDim, _C.green, _C.cyan, _C.green]),
                  boxShadow: [BoxShadow(color: _C.green.withOpacity(0.8),
                    blurRadius: 10, spreadRadius: 1)])),
            ),
          ]))),
    ]);
  }

  String _elapsed() {
    if (_taskStart == null) return '';
    final s = DateTime.now().difference(_taskStart!).inSeconds;
    return '${s}s';
  }

  // ============ 控制台 ============
  Widget _console() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        border: Border.all(color: _C.border, width: 0.8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: _C.green.withOpacity(0.08),
          blurRadius: 20, spreadRadius: -6)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          // 标题栏
          Positioned(top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _C.green.withOpacity(0.06),
                border: Border(bottom: BorderSide(
                  color: _C.green.withOpacity(0.15), width: 0.8))),
              child: Row(children: [
                Icon(Icons.terminal, size: 11, color: _C.green.withOpacity(0.8)),
                const SizedBox(width: 8),
                Text('STDOUT — LIVE FEED', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9.5,
                  color: _C.green.withOpacity(0.9),
                  letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${_lines.length}', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: _C.greenDim, fontWeight: FontWeight.w700)),
              ]))),
          // 内容
          Positioned.fill(top: 30,
            child: _lines.isEmpty ? _emptyConsole() : _consoleList()),
        ])),
    );
  }

  Widget _emptyConsole() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: _C.greenDim.withOpacity(0.08),
          shape: BoxShape.circle),
        child: Icon(Icons.memory, size: 28,
          color: _C.greenDim.withOpacity(0.4))),
      const SizedBox(height: 14),
      Text('等待操作…', style: TextStyle(
        fontFamily: 'monospace', fontSize: 12,
        color: _C.greenDim, letterSpacing: 1)),
      const SizedBox(height: 8),
      AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) =>
        Container(width: 10, height: 16,
          color: _C.green.withOpacity(0.3 + _blinkCtrl.value * 0.5))),
    ]));
  }

  Widget _consoleList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: _lines.length,
      itemBuilder: _logLine);
  }

  Widget _logLine(BuildContext ctx, int i) {
    final line = _lines[i];
    final color = _color(line.level);
    return _LogLineIn(
      key: ValueKey('line_$i'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 12, alignment: Alignment.center,
            child: Text(_prefix(line.level), style: TextStyle(
              fontFamily: 'monospace', fontSize: 11,
              color: color, fontWeight: FontWeight.w800))),
          const SizedBox(width: 6),
          Expanded(child: Text(line.text.isEmpty ? ' ' : line.text,
            style: TextStyle(fontFamily: 'monospace',
              fontSize: 11, height: 1.5, color: color))),
        ])),
    );
  }

  // ============ 底栏 ============
  Widget _bottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.panel,
        border: Border.all(color: _C.border, width: 0.8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: _C.green.withOpacity(0.08),
          blurRadius: 16, spreadRadius: -4)]),
      child: Row(children: [
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final c = _running ? _C.green
            : (_busy ? _C.amber : (_installed ? _C.cyan : _C.greenDim));
          final label = _running ? 'BACKEND ONLINE'
            : (_busy ? '$_currentTask 中…'
            : (_installed ? 'READY' : 'NO RUNTIME'));
          return Row(children: [
            Container(
              width: 9, height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.6 + _blinkCtrl.value * 0.4),
                boxShadow: [BoxShadow(
                  color: c.withOpacity(0.8),
                  blurRadius: _busy || _running ? 12 : 5,
                  spreadRadius: _busy || _running ? 1 : 0)])),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 11,
              color: c, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]);
        }),
        const Spacer(),
        _AnimatedPressBtn(
          enabled: !_busy,
          onTap: _clear,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: _C.greenDim.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(5)),
            child: Row(children: [
              Icon(Icons.cleaning_services_outlined, size: 12, color: _C.greenDim),
              const SizedBox(width: 5),
              Text('清除', style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: _C.greenDim, fontWeight: FontWeight.w700)),
            ]))),
      ]));
  }
}

// ============ 点击缩放按钮 ============
class _AnimatedPressBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;
  const _AnimatedPressBtn({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });
  @override
  State<_AnimatedPressBtn> createState() => _APBS();
}

class _APBS extends State<_AnimatedPressBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) {
        setState(() => _pressed = false);
        widget.onTap();
      } : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: widget.child),
      ));
  }
}

// ============ 日志行入场动画 ============
class _LogLineIn extends StatefulWidget {
  final Widget child;
  const _LogLineIn({super.key, required this.child});
  @override
  State<_LogLineIn> createState() => _LLIS();
}

class _LLIS extends State<_LogLineIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-8 * (1 - t), 0),
            child: child));
      },
      child: widget.child);
  }
}

// ============ 背景：静态矩阵 ============
class _MatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final r = math.Random(42);
    const chars = '01アイウエオカキクケコサシスセソタチツテトABCDEF!@#';
    for (double x = 0; x < size.width; x += 22) {
      final col = (r.nextInt(10) + 3);
      for (int y = 0; y < col; y++) {
        final opacity = (1 - y / col) * 0.04;
        tp.text = TextSpan(text: chars[r.nextInt(chars.length)],
          style: TextStyle(color: _C.green.withOpacity(opacity),
            fontSize: 10, fontFamily: 'monospace'));
        tp.layout();
        tp.paint(canvas, Offset(x, y * 16.0));
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============ 背景：缓慢扫描 ============
class _ScanPainter extends CustomPainter {
  final double t;
  _ScanPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          _C.green.withOpacity(0.0),
          _C.green.withOpacity(0.05),
          _C.green.withOpacity(0.0),
        ]).createShader(Rect.fromLTWH(0, y - 60, size.width, 120));
    canvas.drawRect(Rect.fromLTWH(0, y - 60, size.width, 120), p);
  }
  @override
  bool shouldRepaint(covariant _ScanPainter old) => old.t != t;
}
