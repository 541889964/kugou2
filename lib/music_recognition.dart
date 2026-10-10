import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum RecogState { idle, recording, uploading, done, failed }

class RecogResult {
  final String title, artist;
  final String? source;
  RecogResult({required this.title, required this.artist, this.source});
}

class MusicRecognition extends ChangeNotifier {
  static final MusicRecognition I = MusicRecognition._();
  MusicRecognition._();
  static const _ch = MethodChannel('kugou/recorder');

  RecogState _state = RecogState.idle;
  RecogState get state => _state;
  double _progress = 0;
  double get progress => _progress;
  List<double> _waveform = [];
  List<double> get waveform => List.unmodifiable(_waveform);
  RecogResult? _result;
  RecogResult? get result => _result;
  String? _error;
  String? get error => _error;

  String? _currentPath;
  int _elapsedMs = 0;
  Timer? _timer;
  int durationMs = 8000;

  Future<void> start() async {
    try {
      final s = await Permission.microphone.request();
      if (!s.isGranted) { _fail('未授予麦克风权限'); return; }
      final dir = await getTemporaryDirectory();
      _currentPath = '${dir.path}/recog_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ok = await _ch.invokeMethod<bool>('start', {'path': _currentPath});
      if (ok != true) { _fail('启动录音失败（原生通道未就绪）'); return; }
      _state = RecogState.recording;
      _progress = 0; _waveform = []; _elapsedMs = 0;
      _result = null; _error = null;
      notifyListeners();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
        _elapsedMs += 60;
        _progress = (_elapsedMs / durationMs).clamp(0.0, 1.0);
        _waveform.add(0.4 + 0.6 * Random().nextDouble());
        if (_waveform.length > 60) _waveform.removeAt(0);
        notifyListeners();
        if (_elapsedMs >= durationMs) { t.cancel(); _stopAndRecognize(); }
      });
    } catch (e) { _fail('启动录音失败：$e'); }
  }

  Future<void> stop() async {
    if (_state != RecogState.recording) return;
    _timer?.cancel();
    await _stopAndRecognize();
  }

  Future<void> _stopAndRecognize() async {
    try { await _ch.invokeMethod('stop'); } catch (_) {}
    if (_currentPath == null) { _fail('录音文件丢失'); return; }
    _state = RecogState.uploading; _progress = 1.0;
    notifyListeners();
    try {
      final r = await _recognizeByNetease(_currentPath!);
      if (r != null) {
        _result = r; _state = RecogState.done; notifyListeners(); return;
      }
      _fail('识别失败，未匹配到歌曲');
    } catch (e) { _fail('识别失败：$e'); }
  }

  Future<RecogResult?> _recognizeByNetease(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length < 1024) return null;
    final sessionId = _randomHex(16);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
        'Referer': 'https://music.163.com/'}));
    final url = 'https://interface.music.163.com/api/music/audio/match'
        '?sessionId=$sessionId&algorithmCode=shazam_v2&duration=8';
    try {
      final r = await dio.post(url, data: bytes,
        options: Options(contentType: 'application/octet-stream', validateStatus: (_) => true));
      if (r.statusCode != 200) return null;
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is! Map || d['code'] != 200) return null;
      final list = d['data']?['result'] as List?;
      if (list == null || list.isEmpty) return null;
      final first = list[0] as Map;
      return RecogResult(
        title: (first['songName'] ?? first['name'] ?? '未知').toString(),
        artist: (first['artistName'] ?? '').toString(),
        source: '网易云');
    } catch (_) { return null; }
  }

  String _randomHex(int n) {
    const c = '0123456789ABCDEF';
    final r = Random();
    return List.generate(n, (_) => c[r.nextInt(c.length)]).join();
  }

  void _fail(String msg) {
    _state = RecogState.failed; _error = msg; notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _state = RecogState.idle; _progress = 0; _waveform = [];
    _result = null; _error = null;
    notifyListeners();
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}
