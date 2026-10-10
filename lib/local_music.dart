import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'kugou.dart';

class LocalMusicScanner extends ChangeNotifier {
  static final LocalMusicScanner I = LocalMusicScanner._();
  LocalMusicScanner._();
  List<Song> _songs = [];
  bool scanning = false;
  String status = '';
  final Set<String> _scannedDirs = {};
  List<Song> get songs => List.unmodifiable(_songs);
  static const _audioExts = ['.mp3', '.flac', '.m4a', '.ogg', '.wav', '.ape', '.aac'];
  static const _defaultDirs = [
    '/storage/emulated/0/Music', '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents', '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Android/media', '/storage/emulated/0/kuGou',
    '/storage/emulated/0/kgmusic/download',
  ];

  Future<bool> _perm() async {
    var s = await Permission.storage.status; if (s.isGranted) return true;
    s = await Permission.storage.request(); if (s.isGranted) return true;
    var m = await Permission.manageExternalStorage.status; if (m.isGranted) return true;
    m = await Permission.manageExternalStorage.request(); return m.isGranted;
  }

  Future<void> scan({List<String>? dirs}) async {
    if (scanning) return;
    if (!await _perm()) { status = '需要存储权限'; notifyListeners(); return; }
    scanning = true; status = '扫描中…';
    _songs.clear(); _scannedDirs.clear();
    notifyListeners();
    final scanDirs = dirs ?? _defaultDirs;
    int count = 0;
    for (final d in scanDirs) {
      final dir = Directory(d);
      if (!await dir.exists()) continue;
      await _scanDir(dir, (s) {
        _songs.add(s); count++;
        if (count % 20 == 0) { status = '已找到 $count 首…'; notifyListeners(); }
      });
    }
    _songs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    scanning = false; status = '共 ${_songs.length} 首';
    notifyListeners();
  }

  Future<void> _scanDir(Directory dir, Function(Song) onFound) async {
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (_scannedDirs.contains(path)) continue;
        final ext = path.toLowerCase();
        if (!_audioExts.any((e) => ext.endsWith(e))) continue;
        _scannedDirs.add(path);
        final name = path.split('/').last;
        final dot = name.lastIndexOf('.');
        final title = dot > 0 ? name.substring(0, dot) : name;
        String singer = '未知';
        String songName = title;
        if (title.contains(' - ')) {
          final parts = title.split(' - ');
          if (parts.length >= 2) {
            songName = parts[0].trim();
            singer = parts.sublist(1).join(' - ').trim();
          }
        }
        onFound(Song(hash: path.hashCode.toString(), name: songName,
          singer: singer, localPath: path, isLocal: true));
      }
    } catch (_) {}
  }

  Future<bool> deleteFile(String path) async {
    try {
      await File(path).delete();
      _songs.removeWhere((s) => s.localPath == path);
      notifyListeners(); return true;
    } catch (_) { return false; }
  }
}
