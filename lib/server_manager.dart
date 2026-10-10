import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServerField {
  final String key, label, hint;
  final bool obscure;
  const ServerField({required this.key, required this.label, this.hint = '', this.obscure = false});
}

class ServerProvider {
  final String id, name, desc, signupUrl, signupLabel;
  final List<ServerField> fields;
  const ServerProvider({required this.id, required this.name, required this.desc,
    this.signupUrl = '', this.signupLabel = '', this.fields = const []});
}

const kProviders = <ServerProvider>[
  ServerProvider(id: 'jsonblob', name: 'JsonBlob', desc: '匿名上传，无需注册。30 天。'),
  ServerProvider(id: 'dpaste', name: 'DPaste', desc: '匿名粘贴，无需注册。365 天。'),
  ServerProvider(id: 'npoint', name: 'npoint.io', desc: '匿名 JSON，无需注册。'),
  ServerProvider(id: 'jsonbin', name: 'JSONBin.io', desc: '免费账号，永久保存。',
    signupUrl: 'https://jsonbin.io/login', signupLabel: 'JSONBin.io',
    fields: [ServerField(key: 'masterKey', label: 'X-Master-Key', hint: r'$2b$10$...', obscure: true)]),
  ServerProvider(id: 'pastebin', name: 'Pastebin', desc: '免费账号，可设过期。',
    signupUrl: 'https://pastebin.com/signup', signupLabel: 'Pastebin',
    fields: [ServerField(key: 'apiKey', label: 'API Dev Key', obscure: true)]),
];

class ShareCrypto {
  static const _key = 'KuGou-Secure-2025-v1';
  static String encrypt(String plain) {
    final data = utf8.encode(plain);
    final out = List<int>.generate(data.length, (i) => data[i] ^ _key.codeUnitAt(i % _key.length));
    return 'KGv1:${base64.encode(out)}';
  }
  static String decrypt(String cipher) {
    final s = cipher.trim();
    if (!s.startsWith('KGv1:')) return s;
    final bytes = base64.decode(s.substring(5));
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ _key.codeUnitAt(i % _key.length));
    return utf8.decode(out);
  }
  static bool isEncrypted(String s) => s.trim().startsWith('KGv1:');
}

class ServerManager extends ChangeNotifier {
  static final ServerManager I = ServerManager._();
  ServerManager._();
  String _address = '';
  String _username = '';
  String _password = '';
  String _shareId = '';
  String _providerId = 'jsonblob';
  String _serverMode = 'local';
  final Map<String, String> _extraFields = {};
  String get address => _address;
  String get username => _username;
  String get password => _password;
  String get shareId => _shareId;
  String get providerId => _providerId;
  String get serverMode => _serverMode;
  Map<String, String> get extraFields => Map.unmodifiable(_extraFields);
  bool get hasRemote => _address.isNotEmpty;
  ServerProvider get provider =>
    kProviders.firstWhere((p) => p.id == _providerId, orElse: () => kProviders[0]);

  static const _path = '/storage/emulated/0/Music/KuGou/server.json';

  Future<void> init() async {
    try {
      final f = File(_path);
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map;
        _address = (m['address'] ?? '').toString();
        _username = (m['username'] ?? '').toString();
        _password = (m['password'] ?? '').toString();
        _shareId = (m['shareId'] ?? '').toString();
        _providerId = (m['providerId'] ?? 'jsonblob').toString();
        _serverMode = (m['serverMode'] ?? 'local').toString();
        final e = m['extraFields'];
        if (e is Map) e.forEach((k, v) => _extraFields[k.toString()] = v.toString());
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save({required String address, required String username, required String password,
      String? providerId, Map<String, String>? extra}) async {
    _address = address.trim();
    _username = username.trim();
    _password = password;
    if (providerId != null) _providerId = providerId;
    if (extra != null) { _extraFields.clear(); _extraFields.addAll(extra); }
    await _persist(); notifyListeners();
  }

  Future<void> setServerMode(String mode) async {
    _serverMode = mode; await _persist(); notifyListeners();
  }

  String effectiveBaseUrl({String localUrl = 'http://127.0.0.1:3000'}) {
    if (_serverMode == 'local') return localUrl;
    return _address.isEmpty ? localUrl : _address;
  }

  Future<bool> pingRemote() async {
    if (_address.isEmpty) return false;
    try {
      final r = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4)))
        .get(_address, options: Options(validateStatus: (_) => true));
      return r.statusCode != null && r.statusCode! < 500;
    } catch (_) { return false; }
  }

  Future<void> _persist() async {
    try {
      final f = File(_path);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'address': _address, 'username': _username, 'password': _password,
        'shareId': _shareId, 'providerId': _providerId,
        'serverMode': _serverMode, 'extraFields': _extraFields,
      }), flush: true);
    } catch (_) {}
  }

  Future<String> uploadShare() async {
    if (_address.isEmpty) throw Exception('请先填写地址');
    final p = provider;
    final plain = jsonEncode({'version': 1, 'address': _address,
      'username': _username, 'password': _password,
      'uploadedAt': DateTime.now().toIso8601String()});
    final encrypted = ShareCrypto.encrypt(plain);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12)));

    String id = '';
    switch (p.id) {
      case 'jsonblob':
        final r = await dio.post('https://jsonblob.com/api/jsonBlob',
          data: {'content': encrypted},
          options: Options(contentType: Headers.jsonContentType,
            validateStatus: (_) => true, followRedirects: false));
        id = (r.headers.value('location') ?? r.headers.value('Location') ?? '').split('/').last;
        break;
      case 'dpaste':
        final r = await dio.post('https://dpaste.com/api/v2/',
          data: {'content': encrypted, 'expiry_days': '365'},
          options: Options(contentType: Headers.formUrlEncodedContentType,
            validateStatus: (_) => true));
        id = r.data.toString().trim().replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
        if (id.length > 16) id = id.substring(id.length - 10);
        break;
      case 'npoint':
        final r = await dio.post('https://api.npoint.io/',
          data: {'content': encrypted},
          options: Options(contentType: Headers.jsonContentType,
            validateStatus: (_) => true));
        final m = r.data is String ? jsonDecode(r.data) : r.data;
        id = (m is Map ? (m['token'] ?? m['id'] ?? '') : '').toString();
        break;
      case 'jsonbin':
        final key = _extraFields['masterKey'] ?? '';
        if (key.isEmpty) throw Exception('请填写 X-Master-Key');
        final r = await dio.post('https://api.jsonbin.io/v3/b',
          data: {'content': encrypted},
          options: Options(contentType: Headers.jsonContentType,
            validateStatus: (_) => true,
            headers: {'X-Master-Key': key, 'X-Bin-Name': 'kugou-server'}));
        final m = r.data is String ? jsonDecode(r.data) : r.data;
        id = ((m is Map ? m['metadata'] : null)?['id'] ?? '').toString();
        break;
      case 'pastebin':
        final key = _extraFields['apiKey'] ?? '';
        if (key.isEmpty) throw Exception('请填写 API Dev Key');
        final r = await dio.post('https://pastebin.com/api/api_post.php',
          data: {'api_dev_key': key, 'api_option': 'paste', 'api_paste_code': encrypted,
            'api_paste_private': '1', 'api_paste_expire_date': 'N'},
          options: Options(contentType: Headers.formUrlEncodedContentType,
            validateStatus: (_) => true));
        final body = r.data.toString().trim();
        if (!body.startsWith('http')) throw Exception('上传失败：$body');
        id = body.split('/').last;
        break;
    }
    if (id.isEmpty) throw Exception('上传失败：${p.name} 未返回 ID');
    _shareId = id;
    await _persist(); notifyListeners();
    return id;
  }

  Future<void> importShare(String input) async {
    final s = input.trim();
    if (s.isEmpty) throw Exception('输入为空');
    if (ShareCrypto.isEncrypted(s)) {
      final m = jsonDecode(ShareCrypto.decrypt(s)) as Map;
      _address = (m['address'] ?? '').toString();
      _username = (m['username'] ?? '').toString();
      _password = (m['password'] ?? '').toString();
      _shareId = 'local-encrypted';
      await _persist(); notifyListeners();
      return;
    }
    String pid = _providerId;
    String id = s;
    if (s.contains(':')) {
      final parts = s.split(':');
      if (parts.length == 2 && kProviders.any((p) => p.id == parts[0])) {
        pid = parts[0]; id = parts[1];
      }
    }
    _providerId = pid;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12)));
    String? raw;
    switch (pid) {
      case 'jsonblob':
        final r = await dio.get('https://jsonblob.com/api/jsonBlob/$id',
          options: Options(validateStatus: (_) => true));
        if (r.statusCode != 200) throw Exception('ID 无效（${r.statusCode}）');
        raw = _extract(r.data); break;
      case 'dpaste':
        final r = await dio.get('https://dpaste.com/$id.txt',
          options: Options(validateStatus: (_) => true));
        if (r.statusCode != 200) throw Exception('ID 无效（${r.statusCode}）');
        raw = r.data.toString(); break;
      case 'npoint':
        final r = await dio.get('https://api.npoint.io/$id',
          options: Options(validateStatus: (_) => true));
        if (r.statusCode != 200) throw Exception('ID 无效（${r.statusCode}）');
        raw = _extract(r.data); break;
      case 'jsonbin':
        final key = _extraFields['masterKey'] ?? '';
        if (key.isEmpty) throw Exception('请先填写 X-Master-Key');
        final r = await dio.get('https://api.jsonbin.io/v3/b/$id/latest',
          options: Options(validateStatus: (_) => true,
            headers: {'X-Master-Key': key}));
        if (r.statusCode != 200) throw Exception('ID 无效（${r.statusCode}）');
        final m = r.data is String ? jsonDecode(r.data) : r.data;
        raw = _extract(m is Map ? m['record'] : null); break;
      case 'pastebin':
        final r = await dio.get('https://pastebin.com/raw/$id',
          options: Options(validateStatus: (_) => true));
        if (r.statusCode != 200) throw Exception('ID 无效（${r.statusCode}）');
        raw = r.data.toString(); break;
    }
    if (raw == null || raw.isEmpty) throw Exception('未获取到数据');
    final plain = ShareCrypto.isEncrypted(raw) ? ShareCrypto.decrypt(raw) : raw;
    final m = jsonDecode(plain) as Map;
    _address = (m['address'] ?? '').toString();
    _username = (m['username'] ?? '').toString();
    _password = (m['password'] ?? '').toString();
    _shareId = id;
    await _persist(); notifyListeners();
  }

  String? _extract(dynamic d) {
    if (d == null) return null;
    if (d is String) return d;
    if (d is Map) {
      if (d['content'] is String) return d['content'];
      for (final v in d.values) {
        final r = _extract(v);
        if (r != null) return r;
      }
    }
    return null;
  }

  String exportEncrypted() => ShareCrypto.encrypt(jsonEncode({
    'version': 1, 'address': _address, 'username': _username,
    'password': _password, 'uploadedAt': DateTime.now().toIso8601String()}));

  String exportShareToken() => _shareId.isEmpty ? '' : '$_providerId:$_shareId';

  Future<void> clearRemote() async {
    _address = ''; _username = ''; _password = ''; _shareId = '';
    _serverMode = 'local'; _extraFields.clear();
    await _persist(); notifyListeners();
  }
}
