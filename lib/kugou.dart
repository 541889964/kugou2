import 'dart:convert';
import 'package:dio/dio.dart';
import 'net_music.dart';
import 'signature_manager.dart';

class Song {
  final String hash, name, singer, album, albumId;
  final int duration;
  final String? cover, audioId;
  final String? localPath;
  final bool isLocal;
  final String source;
  Song({required this.hash, required this.name, required this.singer,
    this.album = '', this.albumId = '', this.duration = 0,
    this.cover, this.audioId, this.localPath, this.isLocal = false,
    this.source = 'concept'});
  String get title => singer.isEmpty ? name : '$name - $singer';
  Map<String,dynamic> toJson() => {'hash':hash,'name':name,'singer':singer,
    'album':album,'albumId':albumId,'duration':duration,'cover':cover,'audioId':audioId,'source':source};
  factory Song.fromJson(Map j) => Song(
    hash: (j['hash'] ?? j['FileHash'] ?? '').toString(),
    name: (j['name'] ?? j['songname'] ?? j['SongName'] ?? '未知').toString(),
    singer: (j['singer'] ?? j['singername'] ?? j['SingerName'] ?? '').toString(),
    album: (j['album'] ?? j['AlbumName'] ?? '').toString(),
    albumId: (j['albumId'] ?? j['AlbumID'] ?? '').toString(),
    duration: int.tryParse('${j['duration'] ?? j['Duration'] ?? 0}') ?? 0,
    cover: (j['cover'] ?? j['Image'] ?? '').toString().isEmpty ? null : (j['cover'] ?? j['Image']).toString(),
    audioId: (j['audioId'] ?? j['MixSongID'] ?? j['EMixSongID'] ?? '').toString().isEmpty
      ? null : (j['audioId'] ?? j['MixSongID'] ?? j['EMixSongID']).toString(),
    source: (j['source'] ?? 'concept').toString());
}

class KuGouApi {
  static final KuGouApi I = KuGouApi._();
  KuGouApi._();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20)));
  String? lastError;
  String get _base => 'http://127.0.0.1:3000';
  String get _cookie {
    final u = SignatureManager.I.config?['user'] as Map? ?? {};
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

  Future<List<Song>> searchConcept(String kw, {int pagesize = 30}) async {
    lastError = null;
    try {
      final r = await _dio.get('$_base/search',
        queryParameters: {'keywords': kw, 'type': 'song', 'page': 1, 'pagesize': pagesize},
        options: Options(headers: {'Cookie': _cookie}));
      final d = r.data is String ? jsonDecode(r.data) : r.data;
      final lists = (d['data']?['lists'] ?? d['data']?['info'] ?? []) as List;
      return lists.whereType<Map>().map((e) {
        final s = Song.fromJson(Map<String,dynamic>.from(e));
        return Song(hash: s.hash, name: s.name, singer: s.singer, album: s.album,
          albumId: s.albumId, duration: s.duration, cover: s.cover,
          audioId: s.audioId, source: 'concept');
      }).where((s) => s.hash.isNotEmpty).toList();
    } catch (e) {
      lastError = '概念版未启动: $e';
      return [];
    }
  }

  Future<List<Song>> searchNetease(String kw, {int pagesize = 30}) async {
    lastError = null;
    final results = await NetMusic.search(kw, limit: pagesize);
    if (results.isEmpty) { lastError = '网易云未返回结果'; return []; }
    return results.map((m) => Song(
      hash: 'netease_${m['id']}',
      name: m['name'].toString(),
      singer: m['artist'].toString(),
      album: m['album'].toString(),
      duration: (m['duration'] as num?)?.toInt() ?? 0,
      source: 'netease',
    )).toList();
  }

  Future<List<Song>> search(String kw, {int page = 1, int? pagesize, String? source}) async {
    final size = pagesize ?? 30;
    if (source == 'netease') return searchNetease(kw, pagesize: size);
    return searchConcept(kw, pagesize: size);
  }

  Future<Song?> resolveNetease(Song s) async {
    final kw = s.singer.isEmpty ? s.name : '${s.name} ${s.singer}';
    final list = await searchConcept(kw, pagesize: 5);
    if (list.isEmpty) return null;
    for (final x in list) {
      if (x.name.contains(s.name) || s.name.contains(x.name)) return x;
    }
    return list.first;
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
        if (d['error_code'] == 20018) return {'error':'VIP_ONLY','message':'VIP 权限不足'};
      }
      return {'error':'NO_URL','message':'未返回 URL'};
    } catch (e) { return {'error':'BACKEND_ERR','message':'后端请求失败: $e'}; }
  }

  Future<String?> getLyric(String hash, {int duration = 0, String? songName, String? singer}) async {
    if (songName != null && songName.trim().isNotEmpty) {
      final nj = await NetMusic.lyric(songName, singer ?? '');
      if (nj != null && nj.trim().length > 10) return nj;
    }
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
        if (txt != null && txt.trim().length > 10) return txt;
      } catch (_) {}
    }
    return null;
  }

  dynamic _tryJson(String s) { try { return jsonDecode(s); } catch (_) { return s; } }
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
          if (r != null && r.trim().length > 10) return r;
        }
      }
      for (final k in const ['data','result','candidates','list','info']) {
        if (d.containsKey(k)) { final r = _pickLyric(d[k]); if (r != null) return r; }
      }
    }
    if (d is List) {
      for (final e in d) { final r = _pickLyric(e); if (r != null) return r; }
    }
    return null;
  }

  Future<bool> verifyCookie() async {
    final u = SignatureManager.I.config?['user'] as Map? ?? {};
    return (u['token'] ?? '').toString().length >= 20;
  }
}
