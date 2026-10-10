import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'kugou.dart';

class DownloadTask {
  final String hash, name, singer;
  double progress = 0;
  int received = 0, total = 0;
  String status = 'pending';
  String? error, filePath;
  DownloadTask({required this.hash, required this.name, required this.singer});
  String get display => singer.isEmpty ? name : '$name - $singer';
}

class Downloader extends ChangeNotifier {
  static final Downloader I = Downloader._();
  Downloader._();
  final _tasks = <String, DownloadTask>{};
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);
  final _dio = Dio();
  static const _dir = '/storage/emulated/0/Music/KuGou';

  Future<bool> _perm() async {
    var s = await Permission.storage.status; if (s.isGranted) return true;
    s = await Permission.storage.request(); if (s.isGranted) return true;
    var m = await Permission.manageExternalStorage.status; if (m.isGranted) return true;
    m = await Permission.manageExternalStorage.request(); return m.isGranted;
  }
  String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  Future<String?> _findExisting(Song song) async {
    try {
      final d = Directory(_dir);
      if (!await d.exists()) return null;
      final cands = <String>{
        _safe(song.title), _safe('${song.name} - ${song.singer}'),
        _safe('${song.singer} - ${song.name}'), _safe(song.name),
      }.where((x) => x.isNotEmpty).toList();
      for (final f in d.listSync()) {
        if (f is! File) continue;
        if (f.path.toLowerCase().endsWith('.lrc')) continue;
        final name = f.path.split('/').last;
        for (final c in cands) {
          if (name.startsWith(c) || name.contains(c)) return f.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> scanDownloaded(List<Song> songs) async {
    for (final s in songs) {
      if (_tasks.containsKey(s.hash)) continue;
      final p = await _findExisting(s);
      if (p != null) {
        final t = DownloadTask(hash: s.hash, name: s.name, singer: s.singer);
        t.status = 'done'; t.progress = 1.0; t.filePath = p;
        _tasks[s.hash] = t;
      }
    }
    notifyListeners();
  }

  bool isDownloaded(Song song) {
    final t = _tasks[song.hash];
    return t != null && t.status == 'done';
  }

  Future<bool> download(Song song) async {
    if (_tasks.containsKey(song.hash)) {
      final t = _tasks[song.hash]!;
      if (t.status == 'downloading' || t.status == 'done') return false;
    }
    final existing = await _findExisting(song);
    if (existing != null) {
      final t = DownloadTask(hash: song.hash, name: song.name, singer: song.singer);
      t.status = 'done'; t.progress = 1.0; t.filePath = existing;
      _tasks[song.hash] = t; notifyListeners(); return false;
    }
    final t = DownloadTask(hash: song.hash, name: song.name, singer: song.singer);
    _tasks[song.hash] = t; notifyListeners();
    try {
      if (!await _perm()) {
        t.status = 'failed'; t.error = '需要权限'; notifyListeners(); return false;
      }
      t.status = 'resolving'; notifyListeners();
      final r = await KuGouApi.I.getSongUrl(song.hash, albumId: song.albumId, audioId: song.audioId);
      if (r == null || r['error'] != null) {
        t.status = 'failed'; t.error = r?['message']?.toString() ?? '失败';
        notifyListeners(); return false;
      }
      final url = r['url'] as String?;
      if (url == null || url.isEmpty) {
        t.status = 'failed'; t.error = '空链接'; notifyListeners(); return false;
      }
      String ext = '.mp3';
      final low = url.toLowerCase();
      if (low.contains('.flac')) ext = '.flac';
      else if (low.contains('.m4a')) ext = '.m4a';
      final d = Directory(_dir);
      if (!await d.exists()) await d.create(recursive: true);
      final p = '$_dir/${_safe(t.display)}$ext';
      t.status = 'downloading'; notifyListeners();
      await _dio.download(url, p, onReceiveProgress: (r, tot) {
        t.received = r; t.total = tot;
        t.progress = tot > 0 ? r / tot : 0;
        notifyListeners();
      });
      t.status = 'done'; t.progress = 1.0; t.filePath = p;
      notifyListeners();
      await downloadLyric(song, audioPath: p);
      return true;
    } catch (e) {
      t.status = 'failed'; t.error = e.toString(); notifyListeners(); return false;
    }
  }

  Future<bool> downloadLyric(Song song, {String? audioPath}) async {
    try {
      if (!await _perm()) return false;
      final l = await KuGouApi.I.getLyric(song.hash, duration: song.duration,
        songName: song.name, singer: song.singer);
      if (l == null || l.trim().isEmpty) return false;
      String? audioFile = audioPath ?? _tasks[song.hash]?.filePath;
      if (audioFile == null) audioFile = await _findExisting(song);
      final String lrcPath;
      if (audioFile != null) {
        lrcPath = audioFile.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
      } else {
        final d = Directory(_dir);
        if (!await d.exists()) await d.create(recursive: true);
        lrcPath = '$_dir/${_safe(song.title)}.lrc';
      }
      await File(lrcPath).writeAsString(l, flush: true);
      return true;
    } catch (_) { return false; }
  }

  void clearTask(String h) { _tasks.remove(h); notifyListeners(); }
  void clearAllDone() {
    _tasks.removeWhere((_, t) => t.status == 'done' || t.status == 'failed');
    notifyListeners();
  }
}
