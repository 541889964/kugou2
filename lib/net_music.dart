import 'dart:convert';
import 'package:dio/dio.dart';

class NetMusic {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
      'Referer': 'https://music.163.com/',
      'Cookie': 'os=android; appver=9.0.0;',
    }));

  static const rankIds = {
    '热歌榜': 3778678,
    '飙升榜': 19723756,
    '新歌榜': 3779629,
    '原创榜': 2884035,
  };

  static Future<List<Map<String, dynamic>>> search(String kw, {int limit = 30, int offset = 0}) async {
    try {
      final r = await _dio.get('https://music.163.com/api/search/get/web',
        queryParameters: {'s': kw, 'type': 1, 'offset': offset, 'total': 'true', 'limit': limit});
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final songs = (d?['result']?['songs'] ?? []) as List;
      return songs.map<Map<String, dynamic>>((t) {
        final artists = t['artists'] as List?;
        final ar = artists != null && artists.isNotEmpty
          ? artists.map((a) => a['name']).join('/') : '';
        return {
          'id': t['id'] ?? 0,
          'name': (t['name'] ?? '').toString(),
          'artist': ar,
          'album': ((t['album'] ?? {})['name'] ?? '').toString(),
          'duration': t['duration'] ?? 0,
        };
      }).where((e) => (e['name'] as String).isNotEmpty).toList();
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> rankSongs(int id, {int limit = 50}) async {
    try {
      final r = await _dio.get('https://music.163.com/api/playlist/detail',
        queryParameters: {'id': id, 'n': limit, 's': 0});
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final tracks = (d?['result']?['tracks'] ?? []) as List;
      return tracks.take(limit).map<Map<String, dynamic>>((t) {
        final artists = t['artists'] as List?;
        final ar = artists != null && artists.isNotEmpty
          ? artists.map((a) => a['name']).join('/') : '';
        return {
          'id': t['id'] ?? 0,
          'name': (t['name'] ?? '').toString(),
          'artist': ar,
          'album': ((t['album'] ?? {})['name'] ?? '').toString(),
          'duration': t['duration'] ?? 0,
        };
      }).where((e) => (e['name'] as String).isNotEmpty).toList();
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> dailyRecommend() async {
    try {
      final r = await _dio.get('https://music.163.com/api/discovery/recommend/songs');
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final list = (d?['recommend'] ?? d?['data']?['dailySongs'] ?? []) as List;
      if (list.isNotEmpty) {
        return list.take(50).map<Map<String, dynamic>>((t) {
          final artists = t['artists'] as List?;
          final ar = artists != null && artists.isNotEmpty
            ? artists.map((a) => a['name']).join('/') : '';
          return {
            'id': t['id'] ?? 0,
            'name': (t['name'] ?? '').toString(),
            'artist': ar,
            'album': ((t['album'] ?? {})['name'] ?? '').toString(),
            'duration': t['duration'] ?? 0,
          };
        }).toList();
      }
    } catch (_) {}
    return rankSongs(3779629, limit: 50);
  }

  static Future<String?> lyric(String name, String artist) async {
    try {
      final kw = '$name ${artist.isEmpty ? "" : artist}'.trim();
      final sr = await _dio.get('https://music.163.com/api/search/get/web',
        queryParameters: {'s': kw, 'type': 1, 'offset': 0, 'total': 'true', 'limit': 10});
      final sd = sr.data is String ? jsonDecode(sr.data) : sr.data;
      final songs = sd?['result']?['songs'] as List?;
      if (songs == null || songs.isEmpty) return null;
      for (int i = 0; i < songs.length && i < 3; i++) {
        final id = songs[i]['id'];
        if (id == null) continue;
        final lr = await _dio.get('https://music.163.com/api/song/lyric',
          queryParameters: {'id': id, 'lv': -1, 'kv': -1, 'tv': -1});
        final ld = lr.data is String ? jsonDecode(lr.data) : lr.data;
        final lrc = ld?['lrc']?['lyric'] as String?;
        if (lrc != null && lrc.trim().length > 10) return lrc;
      }
      return null;
    } catch (_) { return null; }
  }
}
