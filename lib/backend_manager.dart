import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendManager {
  static const startScriptPath = '/storage/emulated/0/Download/kugou-backend-start.sh';
  static const stopScriptPath = '/storage/emulated/0/Download/kugou-backend-stop.sh';
  static const startCmd = 'bash /storage/emulated/0/Download/kugou-backend-start.sh';
  static const stopCmd = 'bash /storage/emulated/0/Download/kugou-backend-stop.sh';

  static Future<bool> isOnline(int port) async {
    try {
      final r = await Dio().get('http://127.0.0.1:$port/',
        options: Options(receiveTimeout: const Duration(seconds: 2)));
      return r.statusCode == 200 || r.statusCode == 404;
    } catch (_) { return false; }
  }
  static Future<bool> isLiteOnline() => isOnline(3000);
  static Future<bool> isStandardOnline() => isOnline(3001);

  static Future<String?> getGithubUrl() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('github_script_url');
  }
  static Future<void> setGithubUrl(String u) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('github_script_url', u);
  }

  static Future<bool> _perm() async {
    var s = await Permission.storage.status; if (s.isGranted) return true;
    s = await Permission.storage.request(); if (s.isGranted) return true;
    var m = await Permission.manageExternalStorage.status; if (m.isGranted) return true;
    m = await Permission.manageExternalStorage.request(); return m.isGranted;
  }

  static Future<(bool, String)> generateScripts() async {
    try {
      if (!await _perm()) return (false, '需要存储权限');
      await File(startScriptPath).writeAsString(_start);
      await File(stopScriptPath).writeAsString(_stop);
      return (true, startScriptPath);
    } catch (e) { return (false, '失败: $e'); }
  }

  static Future<bool> startScriptExists() async {
    try { return await File(startScriptPath).exists(); } catch (_) { return false; }
  }

  static Future<(bool, String)> uploadToGithub({required String owner,
      required String repo, required String token, required String path}) async {
    try {
      final content = await File(startScriptPath).readAsString();
      final b64 = base64.encode(utf8.encode(content));
      final api = 'https://api.github.com/repos/$owner/$repo/contents/$path';
      final dio = Dio(BaseOptions(headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'KuGouApp'}));
      String? sha;
      try { final r = await dio.get(api); sha = (r.data as Map)['sha']?.toString(); } catch (_) {}
      final r = await dio.put(api, data: {'message': 'update', 'content': b64, if (sha != null) 'sha': sha});
      if (r.statusCode == 200 || r.statusCode == 201) {
        final url = 'https://raw.githubusercontent.com/$owner/$repo/main/$path';
        await setGithubUrl(url);
        return (true, url);
      }
      return (false, 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      final c = e.response?.statusCode;
      if (c == 401) return (false, 'Token 无效或权限不足');
      if (c == 404) return (false, '仓库不存在');
      if (c == 422) return (false, '文件冲突');
      return (false, '失败: ${e.message}');
    } catch (e) { return (false, '失败: $e'); }
  }

  static const _start = r'''#!/data/data/com.termux/files/usr/bin/bash
set -e
G='\033[0;32m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'
ok(){ echo -e "${G}✓${N} $1"; }
say(){ echo -e "${C}▸${N} $1"; }
pkg install -y nodejs-lts curl unzip >/dev/null 2>&1 || true
pkill -f KuGouMusicApi 2>/dev/null || true
sleep 1
cd ~
[ -d KuGouMusicApi-src ] || {
  for u in "https://gh-proxy.com/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
    "https://ghfast.top/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip" \
    "https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip"; do
    curl -fL --retry 2 -o kugou.zip "$u" 2>/dev/null && unzip -tq kugou.zip >/dev/null 2>&1 && break
    rm -f kugou.zip
  done
  unzip -q kugou.zip
  mv KuGouMusicApi-main KuGouMusicApi-src
  rm -rf KuGouMusicApi-src/.git KuGouMusicApi-src/.github KuGouMusicApi-src/docs kugou.zip
}
cd ~/KuGouMusicApi-src
[ -d node_modules ] || { npm config set registry https://registry.npmmirror.com >/dev/null 2>&1; npm install --production --no-audit --no-fund 2>&1 | tail -1; }
printf 'platform=lite\nPORT=3000\n' > .env
nohup node app.js > ~/kugou.log 2>&1 &
L=0
for i in $(seq 1 30); do
  sleep 1
  [ "$L" = "0" ] && curl -sf http://127.0.0.1:3000/ >/dev/null 2>&1 && L=1
  [ "$L" = "1" ] && break
done
echo ""
[ "$L" = "1" ] && ok "后端已启动 :3000" || echo "后端启动失败"
echo "  停止: bash /storage/emulated/0/Download/kugou-backend-stop.sh"
''';

  static const _stop = r'''#!/data/data/com.termux/files/usr/bin/bash
G='\033[0;32m'; Y='\033[1;33m'; N='\033[0m'
pkill -f KuGouMusicApi && echo -e "${G}✓${N} 已停止" || echo -e "${Y}!${N} 未运行"
''';
}
