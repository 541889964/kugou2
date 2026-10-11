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
  static const _verKey = 'backend_ver';

  static final _logCtrl = StreamController<TermLine>.broadcast();
  static Stream<TermLine> get logs => _logCtrl.stream;
  static final _progressCtrl = StreamController<double>.broadcast();
  static Stream<double> get progress => _progressCtrl.stream;

  static int _lastDownloadPct = -1;

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

  // ============ 版本 ============
  static Future<String> getLocalVersion() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_verKey) ?? '';
  }

  static Future<void> _setLocalVersion(String v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_verKey, v);
  }

  static Future<Map<String, dynamic>> checkUpdate() async {
    final installed = await isInstalled();
    final localVer = await getLocalVersion();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final r = await dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/tags/$_tag',
        options: Options(
          validateStatus: (_) => true,
          headers: {'User-Agent': 'KuGou-App'},
        ),
      );
      if (r.statusCode != 200) {
        return {
          'hasUpdate': false, 'remoteVer': '', 'localVer': localVer,
          'installed': installed, 'error': 'API ${r.statusCode}'
        };
      }
      final d = r.data is Map ? r.data as Map : {};
      final remoteVer = (d['published_at'] ?? d['created_at'] ?? '').toString();
      final hasUpdate = !installed || localVer.isEmpty || localVer != remoteVer;
      return {
        'hasUpdate': hasUpdate, 'remoteVer': remoteVer,
        'localVer': localVer, 'installed': installed, 'error': null
      };
    } catch (e) {
      return {
        'hasUpdate': false, 'remoteVer': '', 'localVer': localVer,
        'installed': installed, 'error': '$e'
      };
    }
  }

  // ============ 测速 ============
  static Future<String> _fastestMirror() async {
    log('测速中…');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
    final testUrl =
        'https://github.com/$_owner/$_repo/releases/download/$_tag/node-arm64.tar.gz';

    final results = await Future.wait(_mirrors.map((m) async {
      final url = m.isEmpty ? testUrl : '$m/$testUrl';
      final sw = Stopwatch()..start();
      try {
        await dio.head(url, options: Options(validateStatus: (_) => true));
        sw.stop();
        return MapEntry(m, sw.elapsedMilliseconds);
      } catch (_) {
        sw.stop();
        return MapEntry(m, 999999);
      }
    }));

    results.sort((a, b) => a.value.compareTo(b.value));
    final best = results.first;
    log('选择: ${best.key.isEmpty ? "GitHub 直连" : best.key} (${best.value}ms)',
        LogLevel.ok);
    return best.key;
  }

  // ============ 下载 ============
  static Future<File> _download(
    String fileName,
    String destPath,
    String mirror,
    String label,
  ) async {
    final file = File(destPath);
    if (await file.exists()) await file.delete();

    final url = mirror.isEmpty
        ? 'https://github.com/$_owner/$_repo/releases/download/$_tag/$fileName'
        : '$mirror/https://github.com/$_owner/$_repo/releases/download/$_tag/$fileName';

    log('下载: $fileName');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
    ));

    await dio.download(url, destPath, onReceiveProgress: (r, t) {
      if (t > 0) {
        final pct = (r / t * 100).toInt();
        if (pct != _lastDownloadPct) {
          _lastDownloadPct = pct;
          final mb = (r / 1024 / 1024).toStringAsFixed(1);
          final tmb = (t / 1024 / 1024).toStringAsFixed(1);
          log('$label  $pct%  $mb / $tmb MB');
        }
        _emit(r / t * 0.8);
      }
    });

    final size = await File(destPath).length();
    if (size < 1024) throw Exception('$fileName 太小');
    log('$label 完成 (${(size / 1024 / 1024).toStringAsFixed(2)} MB)', LogLevel.ok);
    return File(destPath);
  }

  // ============ 【新】下载运行环境 ============
  static Future<bool> downloadRuntime() async {
    try {
      _emit(0.0);
      log('═══ 下载运行环境 ═══');
      log('');

      log('【1/3】选择最快镜像');
      final mirror = await _fastestMirror();
      log('');

      final temp = await getTemporaryDirectory();
      _lastDownloadPct = -1;

      log('【2/3】并发下载 Node + Backend');
      final results = await Future.wait([
        _download('node-arm64.tar.gz', '${temp.path}/node-arm64.tar.gz',
                mirror, 'Node')
            .then((f) => {'ok': true, 'file': f})
            .catchError((e) => {'ok': false, 'err': e.toString()}),
        _download('backend.tar.gz', '${temp.path}/backend.tar.gz',
                mirror, 'Backend')
            .then((f) => {'ok': true, 'file': f})
            .catchError((e) => {'ok': false, 'err': e.toString()}),
      ]);

      if (results[0]['ok'] != true) {
        log('Node 下载失败: ${results[0]['err']}', LogLevel.err);
        return false;
      }
      if (results[1]['ok'] != true) {
        log('Backend 下载失败: ${results[1]['err']}', LogLevel.err);
        return false;
      }

      final nodeTgz = results[0]['file'] as File;
      final backendTgz = results[1]['file'] as File;
      _emit(0.75);

      log('');
      log('【3/3】解压');
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

      final upd = await checkUpdate();
      if (upd['remoteVer'] != null && (upd['remoteVer'] as String).isNotEmpty) {
        await _setLocalVersion(upd['remoteVer'] as String);
      }

      _emit(1.0);
      log('');
      log('✓ 运行环境已就绪', LogLevel.ok);
      return true;
    } catch (e) {
      log('失败: $e', LogLevel.err);
      return false;
    }
  }

  // ============ 【新】只更新 Backend ============
  static Future<bool> updateBackendOnly() async {
    try {
      _emit(0.0);
      log('═══ 更新 KuGouMusicApi ═══');
      log('');

      log('【1/3】检查远端版本');
      final upd = await checkUpdate();
      final localVer = upd['localVer'] as String? ?? '';
      final remoteVer = upd['remoteVer'] as String? ?? '';
      log('本地: ${localVer.isEmpty ? "(未记录)" : localVer}');
      log('远端: ${remoteVer.isEmpty ? "(未知)" : remoteVer}');
      if (localVer.isNotEmpty && localVer == remoteVer) {
        log('已是最新', LogLevel.ok);
      }
      log('');

      log('【2/3】下载最新 Backend');
      final mirror = await _fastestMirror();
      final temp = await getTemporaryDirectory();
      _lastDownloadPct = -1;

      final backendTgz = await _download(
        'backend.tar.gz', '${temp.path}/backend.tar.gz', mirror, 'Backend');

      log('');
      log('【3/3】替换 Backend');
      log('清空旧 Backend…');
      try { await _ch.invokeMethod<bool>('clearBackend'); } catch (_) {}

      log('解压新 Backend…');
      final ok = await _ch.invokeMethod<bool>('unpackBackend', {'src': backendTgz.path});
      if (ok != true) {
        log('Backend 解压失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }
      log('Backend 解压完成', LogLevel.ok);

      try { await backendTgz.delete(); } catch (_) {}

      if (remoteVer.isNotEmpty) await _setLocalVersion(remoteVer);

      _emit(1.0);
      log('');
      log('✓ KuGouMusicApi 已更新', LogLevel.ok);
      return true;
    } catch (e) {
      log('更新失败: $e', LogLevel.err);
      return false;
    }
  }

  // ============ 【新】只执行（启动后端）============
  static Future<bool> executeOnly() async {
    try {
      _emit(0.0);
      log('═══ 启动后端 ═══');
      log('');

      final installed = await isInstalled();
      if (!installed) {
        log('未安装运行环境，请先下载', LogLevel.err);
        return false;
      }

      log('启动 Node 进程…');
      final started = await _ch.invokeMethod<bool>('start');
      if (started != true) {
        log('启动失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }

      log('等待响应 (最多 30 秒)…');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ));
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        _emit(0.3 + 0.7 * (i / 30));
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
      log('后端未响应', LogLevel.warn);
      return false;
    } catch (e) {
      log('失败: $e', LogLevel.err);
      return false;
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

  static Future<void> _dumpCrash() async {
    final crash = await getCrashLog();
    if (crash.isNotEmpty) {
      log('--- 崩溃日志 ---', LogLevel.err);
      for (final line in crash.split('\n').take(30)) log(line, LogLevel.err);
    }
  }
}
