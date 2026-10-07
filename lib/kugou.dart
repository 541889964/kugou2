import 'dart:convert';
import 'package:dio/dio.dart';
import 'mode_manager.dart';
import 'signature_manager.dart';
import 'server_manager.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover, audioId;
  final String? localPath;
  final bool isLocal;
  Song({required this.hash, required this.name, required this.singer,
    this.album = '', this.albumId = '', this.duration = 0,
    this.cover, this.audioId, this.localPath, this.isLocal = false});
  String get title => singer.isEmpty ? name : '$name - $singer';
  Map<String,dynamic> toJson() => {'hash':hash,'name':name,'singer':singer,
    'album':album,'albumId':albumId,'duration':duration,'cover':cover,'audioId':audioId};
  factory Song.fromJson(Map j) => Song(
    hash: (j['hash'] ?? j['FileHash'] ?? '').toString(),
    name: (j['name'] ?? j['songname'] ?? j['SongName'] ?? '未知').toString(),
    singer: (j['singer'] ?? j['singername'] ?? j['SingerName'] ?? '').toString(),
    album: (j['album'] ?? j['AlbumName'] ?? '').toString(),
    albumId: (j['albumId'] ?? j['AlbumID'] ?? '').toString(),
    duration: int.tryParse('${j['duration'] ?? j['Duration'] ?? 0}') ?? 0,
    cover: (j['cover'] ?? j['Image'] ?? '').toString().isEmpty ? null : (j['cover'] ?? j['Image']).toString(),
    audioId: (j['audioId'] ?? j['MixSongID'] ?? j['EMixSongID'] ?? '').toString().isEmpty
      ? null : (j['audioId'] ?? j['MixSongID'] ?? j['EMixSongID']).toString());
}

/// 网易云歌词 API（无需登录）
class NeteaseApi {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
      'Referer': 'https://music.163.com/',
    },
  ));

  static Future<String?> getLyric(String songName, String singer) async {
    try {
      final kw = '$songName ${singer.isEmpty ? "" : singer}'.trim();
      // 1. 搜索
      final sr = await _dio.get('https://music.163.com/api/search/get/web',
        queryParameters: {'s': kw, 'type': 1, 'offset': 0, 'total': 'true', 'limit': 8});
      final sd = sr.data is String ? jsonDecode(sr.data) : sr.data;
      final songs = sd?['result']?['songs'] as List?;
      if (songs == null || songs.isEmpty) return null;

      // 2. 逐个尝试拿歌词（第一个可能没歌词）
      for (int i = 0; i < songs.length && i < 3; i++) {
        final id = songs[i]['id'];
        if (id == null) continue;
        final lr = await _dio.get('https://music.163.com/api/song/lyric',
          queryParameters: {'id': id, 'lv': -1, 'kv': -1, 'tv': -1});
        final ld = lr.data is String ? jsonDecode(lr.data) : lr.data;
        final lrc = ld?['lrc']?['lyric'] as String?;
        if (lrc != null && lrc.trim().isNotEmpty) return lrc;
      }
      return null;
    } catch (_) { return null; }
  }
}

class KuGouApi {
  static final KuGouApi I = KuGouApi._();
  KuGouApi._();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20)));
  String? lastError;
  String get _base {
    final local = ModeManager.I.backendUrl;
    return ServerManager.I.effectiveBaseUrl(localUrl: local);
  }
  String get _cookie {
    final u = SignatureManager.I.config!['user'] as Map;
    return <String>[
      if ((u['token'] ?? '').toString().isNotEmpty) 'token=${u['token']}',
      if ((u['userid'] ?? '').toString().isNotEmpty) 'userid=${u['userid']}',
      if ((u['dfid'] ?? '').toString().isNotEmpty) 'dfid=${u['dfid']}',
      if ((u['mid'] ?? '').toString().isNotEmpty) 'mid=${u['mid']}',
      'appid=${u['appid'] ?? "3116"}',
      'clientver=${u['clientver'] ?? "11590"}',
      'KG-FAKE=${u['kg_fake'] ?? u['userid'] ?? ""}',
    ].join('; ');
  }

  Future<List<Song>> search(String kw, {int page = 1, int pagesize = 30}) async {
    lastError = null;
    try {
      final r = await _dio.get('$_base/search',
        queryParameters: {'keywords': kw, 'type': 'song', 'page': page, 'pagesize': pagesize},
        options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final lists = (d['data']?['lists'] ?? d['data']?['info'] ?? []) as List;
      return lists.whereType<Map>()
        .map((e) => Song.fromJson(Map<String,dynamic>.from(e)))
        .where((s) => s.hash.isNotEmpty).toList();
    } catch (e) { lastError = '后端未启动: $e'; return []; }
  }

  Future<Map?> getSongUrl(String hash, {String albumId = '', String? audioId}) async {
    try {
      final params = <String,dynamic>{'id': hash};
      if (audioId != null && audioId.isNotEmpty) params['album_audio_id'] = audioId;
      final r = await _dio.get('$_base/song/url',
        queryParameters: params,
        options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      if (d is Map) {
        final u = d['data']?['url'] ?? d['url'];
        if (u is String && u.isNotEmpty) return {'url': u};
        if (u is List && u.isNotEmpty) return {'url': u[0].toString()};
        final bu = d['backupUrl'] ?? d['data']?['backupUrl'];
        if (bu is List && bu.isNotEmpty) return {'url': bu[0].toString()};
        if (d['error_code'] == 20018) return {'error':'VIP_ONLY','message':'切到概念版试试'};
      }
      return {'error':'NO_URL','message':'未返回 URL'};
    } catch (e) { return {'error':'BACKEND_ERR','message':'后端请求失败: $e'}; }
  }

  /// 歌词：网易云优先 → 酷狗后端兜底
  Future<String?> getLyric(String hash, {int duration = 0, String? songName, String? singer}) async {
    // 1. 网易云
    if (songName != null && songName.trim().isNotEmpty) {
      final nj = await NeteaseApi.getLyric(songName, singer ?? '');
      if (nj != null && nj.trim().isNotEmpty) return nj;
    }
    // 2. 酷狗后端
    final tries = <Map<String, dynamic>>[
      {'p': '/lyric', 'q': {'hash': hash, 'id': hash, 'duration': duration, 'decode': 'true', 'fmt': 'lrc'}},
      {'p': '/lyric', 'q': {'hash': hash, 'id': hash}},
      {'p': '/search/lyric', 'q': {'hash': hash, 'id': hash, 'duration': duration}},
    ];
    for (final t in tries) {
      try {
        final r = await _dio.get('$_base${t['p']}',
          queryParameters: (t['q'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          options: Options(headers: {'Cookie': _cookie}));
        final data = r.data is String ? _tryJson(r.data as String) : r.data;
        final txt = _pickLyric(data);
        if (txt != null && txt.trim().isNotEmpty) return txt;
      } catch (_) {}
    }
    return null;
  }

  dynamic _tryJson(String s) {
    try { return jsonDecode(s); } catch (_) { return s; }
  }
  String? _pickLyric(dynamic d) {
    if (d == null) return null;
    if (d is String) {
      final t = d.trim();
      if (t.isEmpty) return null;
      if (t.contains('[') && t.contains(']')) return t;
      try {
        final dec = utf8.decode(base64.decode(t), allowMalformed: true);
        if (dec.contains('[') || dec.contains('\n')) return dec;
      } catch (_) {}
      if (t.contains('\n') && t.length > 20) return t;
      return null;
    }
    if (d is Map) {
      for (final k in const ['lyric','lrc','decodeContent','content','krc','lyrics','txt']) {
        final v = d[k];
        if (v is String && v.trim().isNotEmpty) {
          final r = _pickLyric(v);
          if (r != null && r.trim().isNotEmpty) return r;
        }
      }
      for (final k in const ['data','result','candidates','list','info']) {
        if (d.containsKey(k)) {
          final r = _pickLyric(d[k]);
          if (r != null && r.trim().isNotEmpty) return r;
        }
      }
    }
    if (d is List) {
      for (final e in d) {
        final r = _pickLyric(e);
        if (r != null && r.trim().isNotEmpty) return r;
      }
    }
    return null;
  }

  Future<bool> verifyCookie() async {
    final u = SignatureManager.I.config!['user'] as Map;
    return (u['token'] ?? '').toString().length >= 20;
  }
}
