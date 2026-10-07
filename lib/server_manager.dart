import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServerManager extends ChangeNotifier {
  static final ServerManager I = ServerManager._();
  ServerManager._();

  String _address = '';
  String _username = '';
  String _password = '';
  String _shareId = '';

  String get address => _address;
  String get username => _username;
  String get password => _password;
  String get shareId => _shareId;
  bool get configured => _address.isNotEmpty && _username.isNotEmpty;

  static const _path = '/storage/emulated/0/Music/KuGou/server.json';
  static const _blobApi = 'https://jsonblob.com/api/jsonBlob';

  Future<void> init() async {
    try {
      final f = File(_path);
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map;
        _address = (m['address'] ?? '').toString();
        _username = (m['username'] ?? '').toString();
        _password = (m['password'] ?? '').toString();
        _shareId = (m['shareId'] ?? '').toString();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save({required String address, required String username, required String password}) async {
    _address = address.trim();
    _username = username.trim();
    _password = password;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final f = File(_path);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'address': _address, 'username': _username,
        'password': _password, 'shareId': _shareId,
      }), flush: true);
    } catch (_) {}
  }

  Future<String> uploadShare() async {
    if (_address.isEmpty || _username.isEmpty) throw Exception('请先填写地址和用户名');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10)));
    final r = await dio.post(_blobApi,
      data: {
        'address': _address, 'username': _username,
        'password': _password,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
      options: Options(
        contentType: Headers.jsonContentType,
        validateStatus: (_) => true,
        followRedirects: false));
    final loc = r.headers.value('location') ?? r.headers.value('Location') ?? '';
    final id = loc.split('/').last;
    if (id.isEmpty) throw Exception('上传失败：未获取到 ID');
    _shareId = id;
    await _persist();
    notifyListeners();
    return id;
  }

  Future<void> importShare(String id) async {
    final clean = id.trim().split('/').last;
    if (clean.isEmpty) throw Exception('ID 为空');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10)));
    final r = await dio.get('$_blobApi/$clean',
      options: Options(validateStatus: (_) => true));
    if (r.statusCode != 200) throw Exception('ID 无效或已过期（${r.statusCode}）');
    final m = r.data is String ? jsonDecode(r.data) : r.data;
    if (m is! Map) throw Exception('数据格式错误');
    _address = (m['address'] ?? '').toString();
    _username = (m['username'] ?? '').toString();
    _password = (m['password'] ?? '').toString();
    _shareId = clean;
    await _persist();
    notifyListeners();
  }
}
