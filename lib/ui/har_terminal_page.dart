import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../har_analyzer.dart';

class _C {
  static const green = Color(0xFF00FF41);
  static const greenDim = Color(0xFF00A828);
  static const cyan = Color(0xFF00FFFF);
  static const amber = Color(0xFFFFB000);
  static const red = Color(0xFFFF3355);
  static const purple = Color(0xFFB8A8FF);
  static const bg = Color(0xFF080C0A);
  static const panel = Color(0xFF0D150F);
  static const border = Color(0xFF1A2F1E);
}

class HarTerminalPage extends StatefulWidget {
  final File harFile;
  const HarTerminalPage({super.key, required this.harFile});
  @override
  State<HarTerminalPage> createState() => _S();
}

class _S extends State<HarTerminalPage> with TickerProviderStateMixin {
  final List<InsightLine> _lines = [];
  final ScrollController _scroll = ScrollController();
  bool _busy = true;
  HarAnalysisResult? _result;
  late final AnimationController _blinkCtrl;
  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _add(InsightLine('har-analyzer v1.0 — 深度凭证分析引擎', InsightLevel.header));
    _add(InsightLine('目标: ${widget.harFile.path.split("/").last}', InsightLevel.info));
    _add(InsightLine('', InsightLevel.plain));
    final r = await HarAnalyzer.analyze(widget.harFile, onLine: _add);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
    HapticFeedback.mediumImpact();
  }

  void _add(InsightLine line) {
    if (!mounted) return;
    setState(() {
      _lines.add(line);
      if (_lines.length > 500) _lines.removeRange(0, _lines.length - 500);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Color _color(InsightLevel lv) {
    switch (lv) {
      case InsightLevel.plain: return _C.greenDim;
      case InsightLevel.info: return _C.cyan;
      case InsightLevel.ok: return _C.green;
      case InsightLevel.warn: return _C.amber;
      case InsightLevel.err: return _C.red;
      case InsightLevel.header: return _C.purple;
      case InsightLevel.value: return _C.green;
    }
  }

  String _prefix(InsightLevel lv) {
    switch (lv) {
      case InsightLevel.ok: return '✓';
      case InsightLevel.warn: return '⚠';
      case InsightLevel.err: return '✗';
      case InsightLevel.info: return '›';
      case InsightLevel.header: return '';
      case InsightLevel.value: return '•';
      case InsightLevel.plain: return ' ';
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _blinkCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(child: Column(children: [
        _topBar(),
        if (_result != null) _summaryCard(_result!),
        Expanded(child: _console()),
        _bottomBar(),
      ])),
    );
  }

  Widget _topBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.panel,
        border: Border.all(color: _C.border, width: 0.8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: _C.purple.withOpacity(0.10),
          blurRadius: 20, spreadRadius: -4)]),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context, _result?.saved ?? false),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              border: Border.all(color: _C.green.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(5)),
            child: const Icon(Icons.arrow_back_ios_new, size: 13, color: _C.green))),
        const SizedBox(width: 12),
        Container(width: 10, height: 10,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.red)),
        const SizedBox(width: 6),
        Container(width: 10, height: 10,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.amber)),
        const SizedBox(width: 6),
        Container(width: 10, height: 10,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.green)),
        const SizedBox(width: 14),
        const Expanded(child: Text('root@kugou:~/har#',
          style: TextStyle(fontFamily: 'monospace', fontSize: 12,
            color: _C.purple, fontWeight: FontWeight.w700, letterSpacing: 0.4))),
        AnimatedBuilder(animation: _blinkCtrl, builder: (_, __) {
          final c = _busy ? _C.amber : _C.green;
          return Container(width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: c.withOpacity(0.6 + _blinkCtrl.value * 0.4),
              boxShadow: [BoxShadow(color: c.withOpacity(0.8),
                blurRadius: 10, spreadRadius: 1)]));
        }),
      ]));
  }

  Widget _summaryCard(HarAnalysisResult r) {
    final score = r.score;
    final c = score >= 90 ? _C.green
      : score >= 75 ? _C.cyan
      : score >= 60 ? _C.amber
      : _C.red;
    final grade = score >= 90 ? 'A+' : score >= 75 ? 'A'
      : score >= 60 ? 'B' : score >= 40 ? 'C' : 'D';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.panel,
        border: Border.all(color: c.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: c.withOpacity(0.18),
          blurRadius: 20, spreadRadius: -4)]),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: c.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: c.withOpacity(0.6), width: 2)),
          child: Center(child: Text(grade, style: TextStyle(
            fontFamily: 'monospace', fontSize: 20, color: c,
            fontWeight: FontWeight.w900)))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('凭证质量评分', style: TextStyle(
            fontFamily: 'monospace', fontSize: 10,
            color: _C.greenDim, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text('$score / 100', style: TextStyle(
            fontFamily: 'monospace', fontSize: 22, color: c,
            fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(r.saved ? '✓ 已写入本地配置' : '未保存',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10,
              color: r.saved ? _C.green : _C.amber)),
          if (r.insights.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.insights.join(' · '), style: const TextStyle(
              fontFamily: 'monospace', fontSize: 9.5, color: _C.amber)),
          ],
        ])),
      ]));
  }

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
          Positioned(top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _C.green.withOpacity(0.06),
                border: Border(bottom: BorderSide(
                  color: _C.green.withOpacity(0.15), width: 0.8))),
              child: Row(children: [
                Icon(Icons.psychology_outlined, size: 12,
                  color: _C.purple.withOpacity(0.9)),
                const SizedBox(width: 8),
                Text('ANALYZER OUTPUT', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9.5,
                  color: _C.purple.withOpacity(0.9),
                  letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${_lines.length}', style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: _C.greenDim, fontWeight: FontWeight.w700)),
              ]))),
          Positioned.fill(top: 30,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              itemCount: _lines.length,
              itemBuilder: (_, i) {
                final l = _lines[i];
                final c = _color(l.level);
                final isHeader = l.level == InsightLevel.header;
                return RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      if (!isHeader) SizedBox(
                        width: 12,
                        child: Text(_prefix(l.level), style: TextStyle(
                          fontFamily: 'monospace', fontSize: 11, color: c,
                          fontWeight: FontWeight.w800))),
                      if (!isHeader) const SizedBox(width: 6),
                      Expanded(child: Text(
                        l.text.isEmpty ? ' ' : l.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: isHeader ? 11.5 : 11,
                          height: 1.5,
                          color: c,
                          fontWeight: isHeader ? FontWeight.w800 : FontWeight.normal))),
                    ])),
                );
              })),
        ])),
    );
  }

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
          final c = _busy ? _C.amber : (_result?.saved == true ? _C.green : _C.cyan);
          final label = _busy ? 'ANALYZING...'
            : (_result?.saved == true ? 'READY · SAVED' : 'DONE');
          return Row(children: [
            Container(width: 9, height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: c.withOpacity(0.6 + _blinkCtrl.value * 0.4),
                boxShadow: [BoxShadow(color: c.withOpacity(0.8),
                  blurRadius: _busy ? 12 : 5,
                  spreadRadius: _busy ? 1 : 0)])),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 11, color: c,
              fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]);
        }),
        const Spacer(),
        if (!_busy) GestureDetector(
          onTap: () => Navigator.pop(context, _result?.saved ?? false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.green.withOpacity(0.12),
              border: Border.all(color: _C.green.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(5)),
            child: const Row(children: [
              Icon(Icons.check, size: 13, color: _C.green),
              SizedBox(width: 6),
              Text('完成', style: TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: _C.green,
                fontWeight: FontWeight.w800)),
            ]))),
      ]));
  }
}
