import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, ok, warn, err }

class TermLine {
  final String text;
  final LogLevel level;
  TermLine(this.text, this.level);
}

class BackendManager {
  static const _ch = MethodChannel('kugou/backend');
  static const _owner = '541889964';
  static const _repo = 'kugou2';
  static const _tag = 'backend-runtime-v1';

  static final _logCtrl = StreamController<TermLine>.broadcast();
  static Stream<TermLine> get logs => _logCtrl.stream;
  static final _progressCtrl = StreamController<double>.broadcast();
  static Stream<double> get progress => _progressCtrl.stream;

  static void log(String msg, [LogLevel lv = LogLevel.info]) {
    _logCtrl.add(TermLine(msg, lv));
  }
  static void _emit(double v) => _progressCtrl.add(v.clamp(0.0, 1.0));

  static const _mirrors = [
    'https://gh-proxy.com',
    'https://ghfast.top',
    'https://ghproxy.net',
    'https://gh.llkk.cc',
    '',
  ];

  // ============ 版本管理 ============
  static const _verKey = 'backend_ver';

  static Future<String> getLocalVersion() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_verKey) ?? '';
  }

  static Future<void> _setLocalVersion(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_verKey, v);
  }

  /// 检查远端最新版本 + 状态
  /// 返回 { hasUpdate: bool, remoteVer: String, localVer: String, installed: bool, error: String? }
  static Future<Map<String, dynamic>> checkUpdate() async {
    final installed = await isInstalled();
    final localVer = await getLocalVersion();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10)));
      // 走加速
      final api = 'https://api.github.com/repos/$_owner/$_repo/releases/tags/$_tag';
      final r = await dio.get(api,
        options: Options(validateStatus: (_) => true,
          headers: {'User-Agent': 'KuGou-App'}));
      if (r.statusCode != 200) {
        return {'hasUpdate': false, 'remoteVer': '', 'localVer': localVer,
          'installed': installed, 'error': 'GitHub API ${r.statusCode}'};
      }
      final d = r.data is Map ? r.data as Map : {};
      final remoteVer = (d['published_at'] ?? d['created_at'] ?? '').toString();
      final hasUpdate = !installed || localVer.isEmpty || localVer != remoteVer;
      return {
        'hasUpdate': hasUpdate,
        'remoteVer': remoteVer,
        'localVer': localVer,
        'installed': installed,
        'error': null,
      };
    } catch (e) {
      return {'hasUpdate': false, 'remoteVer': '', 'localVer': localVer,
        'installed': installed, 'error': '$e'};
    }
  }

  // ============ 测速 ============
  static Future<String> _fastestMirror() async {
    log('开始测速（5 个源）…');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3)));
    final testUrl = 'https://github.com/$_owner/$_repo/releases/download/$_tag/node-arm64.tar.gz';

    final results = await Future.wait(_mirrors.map((m) async {
      final url = m.isEmpty ? testUrl : '$m/$testUrl';
      final sw = Stopwatch()..start();
      try {
        await dio.head(url, options: Options(validateStatus: (_) => true));
        sw.stop();
        log('  ${m.isEmpty ? "GitHub 直连" : m.padRight(24)}  ${sw.elapsedMilliseconds}ms');
        return MapEntry(m, sw.elapsedMilliseconds);
      } catch (_) {
        sw.stop();
        log('  ${m.isEmpty ? "GitHub 直连" : m.padRight(24)}  超时', LogLevel.warn);
        return MapEntry(m, 999999);
      }
    }));

    results.sort((a, b) => a.value.compareTo(b.value));
    final best = results.first;
    log('选择: ${best.key.isEmpty ? "GitHub 直连" : best.key}  (${best.value}ms)', LogLevel.ok);
    return best.key;
  }

  static Future<File> _download(String fileName, String destPath, String mirror, String label) async {
    final file = File(destPath);
    if (await file.exists()) await file.delete();

    final url = mirror.isEmpty
      ? 'https://github.com/$_owner/$_repo/releases/download/$_tag/$fileName'
      : '$mirror/https://github.com/$_owner/$_repo/releases/download/$_tag/$fileName';
    log('下载: $fileName');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5)));
    await dio.download(url, destPath, onReceiveProgress: (r, t) {
      if (t > 0) {
        final pct = (r / t * 100).toStringAsFixed(1);
        final mb = (r / 1024 / 1024).toStringAsFixed(2);
        final tmb = (t / 1024 / 1024).toStringAsFixed(2);
        log('$label  $pct%  $mb / $tmb MB');
        _emit(r / t * 0.8);
      }
    });
    final size = await File(destPath).length();
    if (size < 1024) throw Exception('$fileName 太小');
    log('$label 完成 (${(size / 1024 / 1024).toStringAsFixed(2)} MB)', LogLevel.ok);
    return File(destPath);
  }

  // ============ 主流程 ============
  static Future<bool> setupAndStart({bool forceUpdate = false}) async {
    try {
      _emit(0.0);
      log('═══ 初始化后端 ═══');
      log('');

      log('【0/4】检查版本');
      final upd = await checkUpdate();
      if (upd['error'] != null) {
        log('检查失败: ${upd['error']}（继续用本地）', LogLevel.warn);
      } else if (upd['hasUpdate'] == true) {
        log('远端版本: ${upd['remoteVer']}', LogLevel.ok);
        log('本地版本: ${upd['localVer'].isEmpty ? "未安装" : upd['localVer']}');
      } else {
        log('已是最新版本', LogLevel.ok);
      }
      log('');

      final installed = upd['installed'] == true;
      final needDownload = forceUpdate || !installed || upd['hasUpdate'] == true;

      // 已装 + 无需更新 → 直接启动
      if (installed && !needDownload) {
        log('【1/4】本地已有后端，跳过下载');
        log('');
        log('【4/4】启动 Node 进程…');
        return await _startAndWait();
      }

      // 需要下载
      if (installed && forceUpdate) {
        log('【1/4】强制更新：清空旧文件', LogLevel.warn);
        try { await _ch.invokeMethod<bool>('clear'); } catch (_) {}
      }

      log('【1/4】选择最快镜像');
      final mirror = await _fastestMirror();
      log('');
      final temp = await getTemporaryDirectory();

      log('【2/4】并发下载 Node + Backend');
      final results = await Future.wait([
        _download('node-arm64.tar.gz', '${temp.path}/node-arm64.tar.gz', mirror, 'Node')
          .then((f) => {'ok': true, 'file': f})
          .catchError((e) => {'ok': false, 'err': e.toString()}),
        _download('backend.tar.gz', '${temp.path}/backend.tar.gz', mirror, 'Backend')
          .then((f) => {'ok': true, 'file': f})
          .catchError((e) => {'ok': false, 'err': e.toString()}),
      ]);
      if (results[0]['ok'] != true) { log('Node 下载失败: ${results[0]['err']}', LogLevel.err); return false; }
      if (results[1]['ok'] != true) { log('Backend 下载失败: ${results[1]['err']}', LogLevel.err); return false; }
      final nodeTgz = results[0]['file'] as File;
      final backendTgz = results[1]['file'] as File;
      _emit(0.70);

      log('');
      log('【3/4】解压');
      final okN = await _ch.invokeMethod<bool>('unpackNode', {'src': nodeTgz.path});
      if (okN != true) {
        log('Node 解压失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }
      log('Node 解压完成', LogLevel.ok);
      final okB = await _ch.invokeMethod<bool>('unpackBackend', {'src': backendTgz.path});
      if (okB != true) {
        log('Backend 解压失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }
      log('Backend 解压完成', LogLevel.ok);

      try { await nodeTgz.delete(); await backendTgz.delete(); } catch (_) {}
      _emit(0.95);

      // 记录版本
      if (upd['remoteVer'] != null && (upd['remoteVer'] as String).isNotEmpty) {
        await _setLocalVersion(upd['remoteVer'] as String);
      }

      log('');
      log('【4/4】启动 Node 进程…');
      return await _startAndWait();
    } catch (e) {
      log('失败: $e', LogLevel.err);
      return false;
    }
  }

  static Future<bool> _startAndWait() async {
    final started = await _ch.invokeMethod<bool>('start');
    if (started != true) {
      log('启动失败', LogLevel.err);
      await _dumpCrash();
      return false;
    }
    log('等待后端响应 (最多 30 秒)…');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2)));
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final r = await dio.get('http://127.0.0.1:3000/',
          options: Options(validateStatus: (_) => true));
        if (r.statusCode != null && r.statusCode! < 500) {
          _emit(1.0);
          log('');
          log('✓✓✓ 后端启动成功 :3000', LogLevel.ok);
          return true;
        }
      } catch (_) {}
      log('等待中… ${i + 1}s');
    }
    _emit(1.0);
    log('后端未在 30 秒内响应', LogLevel.warn);
    return false;
  }

  static Future<void> _dumpCrash() async {
    final crash = await getCrashLog();
    if (crash.isNotEmpty) {
      log('--- 崩溃日志 ---', LogLevel.err);
      for (final line in crash.split('\n').take(30)) log(line, LogLevel.err);
    }
  }

  // ============ 基础 API ============
  static Future<bool> isInstalled() async {
    try { return await _ch.invokeMethod<bool>('unpacked') ?? false; }
    catch (_) { return false; }
  }

  static Future<bool> isRunning() async {
    try { return await _ch.invokeMethod<bool>('running') ?? false; }
    catch (_) { return false; }
  }

  static Future<bool> start() async {
    try { return await _ch.invokeMethod<bool>('start') ?? false; }
    catch (_) { return false; }
  }

  static Future<bool> stop() async {
    try { return await _ch.invokeMethod<bool>('stop') ?? false; }
    catch (_) { return false; }
  }

  static Future<bool> clear() async {
    try { return await _ch.invokeMethod<bool>('clear') ?? false; }
    catch (_) { return false; }
  }

  static Future<String> getCrashLog() async {
    try { return await _ch.invokeMethod<String>('crashLog') ?? ''; }
    catch (_) { return ''; }
  }

  static Future<bool> isOnline(int port) async {
    try {
      final r = await Dio().get('http://127.0.0.1:$port/',
        options: Options(receiveTimeout: const Duration(seconds: 2)));
      return r.statusCode == 200 || r.statusCode == 404;
    } catch (_) { return false; }
  }
  static Future<bool> isLiteOnline() => isOnline(3000);
  static Future<bool> isStandardOnline() => isOnline(3001);
}
