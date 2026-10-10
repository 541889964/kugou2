import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'signature_manager.dart';

class Updater extends ChangeNotifier {
  static final Updater I = Updater._();
  Updater._();
  bool checking = false;
  String status = '';
  bool hasUpdate = false;
  int remoteVersion = 0;
  static const _url = 'https://raw.githubusercontent.com/541889964/kugou2/main/cloud/signature.json';

  Future<void> check() async {
    checking = true; status = '检查中…'; notifyListeners();
    try {
      String? raw;
      for (final u in [_url, 'https://gh-proxy.com/$_url', 'https://ghfast.top/$_url']) {
        try {
          final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 15));
          if (r.statusCode == 200) { raw = r.body; break; }
        } catch (_) { continue; }
      }
      if (raw == null) { status = '检查失败'; checking = false; notifyListeners(); return; }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      remoteVersion = (m['version'] as num?)?.toInt() ?? 0;
      final lv = SignatureManager.I.version;
      hasUpdate = remoteVersion > lv;
      status = hasUpdate ? '有新版本 v$remoteVersion' : '已是最新 v$lv';
      checking = false; notifyListeners();
    } catch (e) { status = '失败: $e'; checking = false; notifyListeners(); }
  }

  Future<bool> reload() async {
    final ok = await SignatureManager.I.reload();
    if (ok) {
      hasUpdate = false;
      status = '已加载 v${SignatureManager.I.version}';
      notifyListeners();
    }
    return ok;
  }
}
