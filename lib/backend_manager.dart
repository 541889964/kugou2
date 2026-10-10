import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

enum LogLevel { info, ok, warn, err }

class TermLine {
  final String text;
  final LogLevel level;
  final DateTime time;
  TermLine(this.text, this.level) : time = DateTime.now();
}

class BackendManager {
  static const _ch = MethodChannel('kugou/backend');
  static const _owner = '541889964';
  static const _repo = 'kugou2';

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
    '',
  ];

  static Future<File> _download(String fileName, String destPath, {required String label}) async {
    final file = File(destPath);
    if (await file.exists()) await file.delete();

    Object? lastErr;
    for (final m in _mirrors) {
      final url = m.isEmpty
        ? 'https://github.com/$_owner/$_repo/releases/latest/download/$fileName'
        : '$m/https://github.com/$_owner/$_repo/releases/latest/download/$fileName';
      log('尝试源: ${m.isEmpty ? "GitHub 直连" : m}', LogLevel.info);
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: true));
        await dio.download(url, destPath, onReceiveProgress: (r, t) {
          if (t > 0) {
            final pct = (r / t * 100).toStringAsFixed(1);
            final mb = (r / 1024 / 1024).toStringAsFixed(2);
            final tmb = (t / 1024 / 1024).toStringAsFixed(2);
            log('$label  $pct%  $mb MB / $tmb MB');
            _emit(r / t * 0.8);
          }
        });
        final size = await File(destPath).length();
        if (size < 1024) throw Exception('文件太小');
        log('$label 下载完成 (${(size / 1024 / 1024).toStringAsFixed(2)} MB)', LogLevel.ok);
        return File(destPath);
      } catch (e) {
        lastErr = e;
        log('源失败: $e', LogLevel.warn);
        if (await file.exists()) await file.delete();
      }
    }
    throw Exception('所有源均失败: $lastErr');
  }

  static Future<bool> setupAndStart() async {
    try {
      _emit(0.0);
      log('═══ 初始化后端 ═══');
      final temp = await getTemporaryDirectory();

      log('');
      log('【1/3】下载 Node 运行时 (arm64)');
      final nodeTgz = await _download('node-arm64.tar.gz',
        '${temp.path}/node-arm64.tar.gz', label: 'Node');

      log('');
      log('【2/3】解压 Node');
      final okNode = await _ch.invokeMethod<bool>('unpackNode', {'src': nodeTgz.path});
      if (okNode != true) { log('Node 解压失败', LogLevel.err); return false; }
      log('Node 解压完成', LogLevel.ok);
      _emit(0.85);

      log('');
      log('【3/3】下载 KuGouMusicApi 后端');
      final backendTgz = await _download('backend.tar.gz',
        '${temp.path}/backend.tar.gz', label: 'Backend');

      log('解压后端…');
      final okBk = await _ch.invokeMethod<bool>('unpackBackend', {'src': backendTgz.path});
      if (okBk != true) { log('后端解压失败', LogLevel.err); return false; }
      log('后端解压完成', LogLevel.ok);

      try { await nodeTgz.delete(); await backendTgz.delete(); } catch (_) {}
      _emit(0.95);

      log('');
      log('启动 Node 进程…');
      final started = await _ch.invokeMethod<bool>('start');
      if (started != true) { log('启动失败', LogLevel.err); return false; }

      log('等待后端响应 (最多 30 秒)…');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2)));
      bool online = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final r = await dio.get('http://127.0.0.1:3000/',
            options: Options(validateStatus: (_) => true));
          if (r.statusCode != null && r.statusCode! < 500) {
            online = true;
            log('后端响应正常 (HTTP ${r.statusCode})', LogLevel.ok);
            break;
          }
        } catch (_) {}
        log('等待中… ${i + 1}s');
      }
      _emit(1.0);
      if (online) {
        log('');
        log('✓✓✓ 后端启动成功 :3000', LogLevel.ok);
        return true;
      }
      log('后端未在 30 秒内响应', LogLevel.warn);
      return false;
    } catch (e) {
      log('失败: $e', LogLevel.err);
      return false;
    }
  }

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

  static Future<bool> isOnline(int port) async {
    try {
      final r = await Dio().get('http://127.0.0.1:$port/',
        options: Options(receiveTimeout: const Duration(seconds: 2)));
      return r.statusCode == 200 || r.statusCode == 404;
    } catch (_) { return false; }
  }
  static Future<bool> isLiteOnline() => isOnline(3000);
  static Future<bool> isStandardOnline() => isOnline(3001);

  static const startScriptPath = '/storage/emulated/0/Download/kugou-backend-start.sh';
  static const stopScriptPath = '/storage/emulated/0/Download/kugou-backend-stop.sh';
  static const startCmd = 'bash /storage/emulated/0/Download/kugou-backend-start.sh';
  static const stopCmd = 'bash /storage/emulated/0/Download/kugou-backend-stop.sh';

  static Future<bool> launchTermux() async {
    if (!Platform.isAndroid) return false;
    try {
      final intent = AndroidIntent(
        action: 'com.termux.RUN_COMMAND', package: 'com.termux',
        arguments: {
          'com.termux.RUN_COMMAND_PATH': '/data/data/com.termux/files/usr/bin/bash',
          'com.termux.RUN_COMMAND_ARGUMENTS': [startScriptPath],
          'com.termux.RUN_COMMAND_WORKDIR': '/data/data/com.termux/files/home',
          'com.termux.RUN_COMMAND_BACKGROUND': 'false',
        },
        flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION]);
      await intent.launch();
      return true;
    } catch (_) { return false; }
  }
  static Future<bool> stopTermux() async {
    if (!Platform.isAndroid) return false;
    try {
      final intent = AndroidIntent(
        action: 'com.termux.RUN_COMMAND', package: 'com.termux',
        arguments: {
          'com.termux.RUN_COMMAND_PATH': '/data/data/com.termux/files/usr/bin/bash',
          'com.termux.RUN_COMMAND_ARGUMENTS': [stopScriptPath],
          'com.termux.RUN_COMMAND_WORKDIR': '/data/data/com.termux/files/home',
          'com.termux.RUN_COMMAND_BACKGROUND': 'false',
        },
        flags: [Flag.FLAG_GRANT_READ_URI_PERMISSION]);
      await intent.launch();
      return true;
    } catch (_) { return false; }
  }

  static Future<(bool, String)> generateScripts() async => (false, '使用内嵌后端');
  static Future<bool> startScriptExists() async => false;
  static Future<String?> getGithubUrl() async => null;
  static Future<void> setGithubUrl(String _) async {}
}
