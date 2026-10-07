import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'kugou.dart';
import 'lyric_parser.dart';

enum PlayMode { order, shuffle, single }

class PlayerService extends ChangeNotifier {
  static final PlayerService I = PlayerService._();
  final player = AudioPlayer();
  final List<Song> queue = [];
  int idx = -1;
  PlayMode _mode = PlayMode.order;
  PlayMode get mode => _mode;
  bool loading = false;
  String? errorMsg;
  String? lyric;
  List<LyricLine> lyricLines = [];
  int currentLyricIndex = 0;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  Timer? _ticker;
  bool _handlingComplete = false;
  int _cooldownUntil = 0;

  Song? get current => (idx >= 0 && idx < queue.length) ? queue[idx] : null;
  Duration get position => _pos;
  Duration? get duration => _dur.inMilliseconds > 0 ? _dur : null;
  bool get playing => player.playing;

  PlayerService._() {
    // 关键修复：用 Timer 每 200ms 轮询，不依赖 stream，100% 能触发
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    // 流只用来快速响应 playing 变化
    player.playerStateStream.listen((_) => notifyListeners());
  }

  void _tick() {
    final newPos = player.position;
    final newDur = player.duration ?? Duration.zero;
    final posChanged = (newPos - _pos).abs() > const Duration(milliseconds: 90);
    final durChanged = newDur != _dur;
    if (!posChanged && !durChanged) return;
    _pos = newPos;
    _dur = newDur;
    _updateLyric();
    _checkComplete();
    notifyListeners();
  }

  void _checkComplete() {
    if (_handlingComplete) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _cooldownUntil) return;
    if (queue.isEmpty) return;
    final dur = player.duration;
    if (dur == null || dur.inMilliseconds == 0) return;

    final proc = player.processingState;
    final posMs = player.position.inMilliseconds;
    final durMs = dur.inMilliseconds;
    final completed = proc == ProcessingState.completed;
    final atEnd = posMs >= durMs - 400;

    if (completed || atEnd) {
      _cooldownUntil = now + 1500;
      _onComplete();
    }
  }

  Future<void> _onComplete() async {
    if (_handlingComplete) return;
    _handlingComplete = true;
    try {
      if (queue.isEmpty) return;
      switch (_mode) {
        case PlayMode.single:
          await player.seek(Duration.zero);
          await player.play();
          break;
        case PlayMode.shuffle:
          if (queue.length > 1) {
            final r = Random();
            int n;
            do { n = r.nextInt(queue.length); } while (n == idx);
            idx = n;
          } else { idx = 0; }
          await _load();
          break;
        case PlayMode.order:
          idx = (idx < queue.length - 1) ? idx + 1 : 0;
          await _load();
          break;
      }
    } catch (_) {
    } finally {
      _handlingComplete = false;
    }
  }

  void cycleMode() {
    _mode = PlayMode.values[(_mode.index + 1) % PlayMode.values.length];
    notifyListeners();
  }

  void _updateLyric() {
    if (lyricLines.isEmpty) return;
    final ms = _pos.inMilliseconds;
    int ni = 0;
    for (int i = lyricLines.length - 1; i >= 0; i--) {
      if (ms >= lyricLines[i].time) { ni = i; break; }
    }
    if (ni != currentLyricIndex) currentLyricIndex = ni;
  }

  bool _isCurrentPlaying(Song s) {
    if (current == null || current!.hash != s.hash) return false;
    if (player.processingState == ProcessingState.completed) return false;
    return true;
  }

  Future<void> playSong(Song s, {List<Song>? list}) async {
    if (_isCurrentPlaying(s)) {
      if (!player.playing) await player.play();
      return;
    }
    loading = true; errorMsg = null; lyric = null; lyricLines = [];
    currentLyricIndex = 0; notifyListeners();
    if (list != null) {
      queue.clear(); queue.addAll(list);
      idx = queue.indexWhere((x) => x.hash == s.hash);
      if (idx < 0) { queue.insert(0, s); idx = 0; }
    } else {
      final e = queue.indexWhere((x) => x.hash == s.hash);
      if (e >= 0) { idx = e; } else { queue.add(s); idx = queue.length - 1; }
    }
    await _load();
  }

  Future<void> playFromList(Song s, List<Song> list, {int? i}) async {
    if (_isCurrentPlaying(s)) {
      if (!player.playing) await player.play();
      return;
    }
    loading = true; errorMsg = null; lyric = null; lyricLines = [];
    currentLyricIndex = 0; notifyListeners();
    queue.clear(); queue.addAll(list);
    idx = i ?? queue.indexWhere((x) => x.hash == s.hash);
    if (idx < 0) idx = 0;
    await _load();
  }

  Future<void> _load() async {
    final s = current;
    if (s == null) return;
    try {
      if (s.isLocal && s.localPath != null) {
        if (!await File(s.localPath!).exists()) {
          errorMsg = '文件不存在'; loading = false; notifyListeners(); return;
        }
        await player.setFilePath(s.localPath!);
        await player.play();
        await _loadLocalLyric(s.localPath!);
        loading = false; notifyListeners(); return;
      }
      final r = await KuGouApi.I.getSongUrl(s.hash, albumId: s.albumId, audioId: s.audioId);
      if (r == null || r['error'] != null) {
        errorMsg = r?['message']?.toString() ?? '失败';
        loading = false; notifyListeners(); return;
      }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) { errorMsg = '空链接'; loading = false; notifyListeners(); return; }
      await player.setUrl(url);
      await player.play();
      // 歌词：网易云优先，酷狗兜底
      KuGouApi.I.getLyric(s.hash, duration: s.duration, songName: s.name, singer: s.singer).then((l) {
        lyric = l;
        lyricLines = (l == null || l.isEmpty) ? [] : LyricParser.parse(l);
        currentLyricIndex = 0;
        notifyListeners();
      });
    } catch (e) {
      errorMsg = '失败: $e';
    } finally {
      loading = false; notifyListeners();
    }
  }

  Future<void> _loadLocalLyric(String audioPath) async {
    try {
      final lrcPath = audioPath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
      final f = File(lrcPath);
      if (await f.exists()) {
        lyric = await f.readAsString();
        lyricLines = LyricParser.parse(lyric!);
        currentLyricIndex = 0;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    if (player.playing) await player.pause(); else await player.play();
  }
  Future<void> next() async {
    if (queue.isEmpty) return;
    if (_mode == PlayMode.shuffle && queue.length > 1) {
      final r = Random(); int n;
      do { n = r.nextInt(queue.length); } while (n == idx);
      idx = n;
    } else { idx = (idx + 1) % queue.length; }
    _cooldownUntil = DateTime.now().millisecondsSinceEpoch + 800;
    await _load();
  }
  Future<void> prev() async {
    if (queue.isEmpty) return;
    idx = (idx - 1 + queue.length) % queue.length;
    _cooldownUntil = DateTime.now().millisecondsSinceEpoch + 800;
    await _load();
  }
  Future<void> seek(Duration d) => player.seek(d);
}
