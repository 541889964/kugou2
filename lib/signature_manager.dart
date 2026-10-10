import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'mode_manager.dart';

enum CookieStatus { unknown, ok, expired, missing }

class SignatureManager {
  static final SignatureManager I = SignatureManager._();
  SignatureManager._();
  Map<String, dynamic>? _config;
  String _source = 'assets';
  CookieStatus _health = CookieStatus.unknown;
  String _healthMsg = '';
  Map<String, dynamic>? get config => _config;
  String get source => _source;
  int get version => (_config?['version'] as num?)?.toInt() ?? 0;
  CookieStatus get health => _health;
  String get healthMsg => _healthMsg;
  static const importPath = '/storage/emulated/0/Download/kugou-signature.json';
  static const extPath = '/storage/emulated/0/Music/KuGou/cookie.json';

  Future<File> _pf() async {
    final d = await getApplicationSupportDirectory();
    return File('${d.path}/signature.json');
  }

  Future<void> init() async {
    if (await _loadFrom(extPath, 'external')) return;
    try {
      final f = await _pf();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString());
        if (m is Map<String, dynamic> && m['version'] != null) {
          _config = m; _source = 'private';
          await _save(); await tryImport(); return;
        }
      }
    } catch (_) {}
    if (await tryImport()) return;
    try {
      final raw = await rootBundle.loadString('assets/signature.json');
      _config = jsonDecode(raw) as Map<String, dynamic>;
      _source = 'assets'; await _save();
    } catch (_) {}
  }

  Future<bool> _loadFrom(String path, String src) async {
    try {
      final f = File(path);
      if (!await f.exists()) return false;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map<String, dynamic>) return false;
      _config = m; _source = src;
      await _save(); return true;
    } catch (_) { return false; }
  }

  Future<bool> tryImport() async {
    try {
      final f = File(importPath);
      if (!await f.exists()) return false;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map<String, dynamic>) return false;
      final nv = (m['version'] as num?)?.toInt() ?? 0;
      if (nv <= version && source != 'assets') return false;
      _config = m; _source = 'imported';
      await _save(); return true;
    } catch (_) { return false; }
  }

  Future<void> _save() async {
    try { await (await _pf()).writeAsString(jsonEncode(_config)); } catch (_) {}
    try {
      final f = File(extPath);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await f.writeAsString(jsonEncode(_config), flush: true);
    } catch (_) {}
  }

  Future<void> updateUser(Map<String, String> u) async {
    if (_config == null) return;
    final cur = Map<String, dynamic>.from((_config!['user'] as Map?) ?? {});
    u.forEach((k, v) { if (v.isNotEmpty) cur[k] = v; });
    if ((cur['kg_fake'] ?? '').toString().isEmpty) cur['kg_fake'] = cur['userid'] ?? '';
    _config!['user'] = cur;
    _health = CookieStatus.unknown;
    await _save();
  }

  Future<bool> reload() async {
    if (await _loadFrom(extPath, 'external')) return true;
    if (await tryImport()) return true;
    try {
      final f = await _pf();
      if (await f.exists()) {
        _config = jsonDecode(await f.readAsString());
        _source = 'private'; return true;
      }
    } catch (_) {}
    return false;
  }

  Future<CookieStatus> checkHealth() async {
    final u = (_config?['user'] as Map?) ?? {};
    final token = (u['token'] ?? '').toString();
    if (token.isEmpty || token.length < 20) {
      _health = CookieStatus.missing;
      _healthMsg = 'Cookie 未导入';
      return _health;
    }
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 5)));
      final r = await dio.get('${ModeManager.I.backendUrl}/search',
        queryParameters: {'keywords': 'test', 'type': 'song', 'page': 1, 'pagesize': 1},
        options: Options(headers: {'Cookie': _cookieHeader()}, validateStatus: (_) => true));
      final code = r.statusCode ?? 0;
      if (code == 401 || code == 403) {
        _health = CookieStatus.expired;
        _healthMsg = 'Cookie 已过期，请重新导入 HAR';
        return _health;
      }
      final data = r.data is String ? jsonDecode(r.data) : r.data;
      if (data is Map) {
        final ec = data['error_code'] ?? data['errcode'];
        if (ec == 20018 || ec == 11001 || ec == 40001) {
          _health = CookieStatus.expired;
          _healthMsg = 'Cookie 已过期 (错误码 $ec)';
          return _health;
        }
      }
      _health = CookieStatus.ok;
      _healthMsg = 'Cookie 正常';
      return _health;
    } catch (_) {
      _health = CookieStatus.unknown;
      _healthMsg = '无法验证（后端离线）';
      return _health;
    }
  }

  String _cookieHeader() {
    final u = (_config?['user'] as Map?) ?? {};
    return [
      if ((u['token'] ?? '').toString().isNotEmpty) 'token=${u['token']}',
      if ((u['userid'] ?? '').toString().isNotEmpty) 'userid=${u['userid']}',
      if ((u['dfid'] ?? '').toString().isNotEmpty) 'dfid=${u['dfid']}',
      if ((u['mid'] ?? '').toString().isNotEmpty) 'mid=${u['mid']}',
      'appid=${u['appid'] ?? "3116"}',
      'clientver=${u['clientver'] ?? "11590"}',
      'KG-FAKE=${u['kg_fake'] ?? u['userid'] ?? ""}',
    ].join('; ');
  }
}
