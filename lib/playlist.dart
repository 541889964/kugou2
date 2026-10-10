import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kugou.dart';

class PlaylistService extends ChangeNotifier {
  static final PlaylistService I = PlaylistService._();
  PlaylistService._();
  final _songs = <Song>[];
  final _set = <String>{};
  static const _extFile = '/storage/emulated/0/Music/KuGou/favorites.json';

  List<Song> get songs => List.unmodifiable(_songs);
  bool contains(Song s) => _set.contains(s.hash);

  Future<void> init() async {
    List<Song> a = [];
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('playlist');
      if (raw != null) {
        final l = jsonDecode(raw) as List;
        a = l.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    List<Song> b = [];
    try {
      final f = File(_extFile);
      if (await f.exists()) {
        final l = jsonDecode(await f.readAsString()) as List;
        b = l.whereType<Map>().map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    final merged = <String, Song>{};
    for (final s in b) merged[s.hash] = s;
    for (final s in a) merged[s.hash] = s;
    _songs.clear(); _songs.addAll(merged.values);
    _set.clear(); _set.addAll(_songs.map((s) => s.hash));
    await _saveBoth(); notifyListeners();
  }

  Future<void> _saveBoth() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('playlist',
        jsonEncode(_songs.map((s) => s.toJson()).toList()));
    } catch (_) {}
    try {
      final dir = Directory('/storage/emulated/0/Music/KuGou');
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(_extFile).writeAsString(
        jsonEncode(_songs.map((s) => s.toJson()).toList()), flush: true);
    } catch (_) {}
  }

  Future<bool> toggle(Song s) async {
    if (_set.contains(s.hash)) {
      _songs.removeWhere((x) => x.hash == s.hash);
      _set.remove(s.hash);
      await _saveBoth(); notifyListeners(); return false;
    }
    _songs.insert(0, s);
    _set.add(s.hash);
    await _saveBoth(); notifyListeners(); return true;
  }

  Future<void> clear() async {
    _songs.clear(); _set.clear();
    await _saveBoth(); notifyListeners();
  }
}
