import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signature_manager.dart';

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
  static const _shaKey = 'backend_sha';

  /// 分片下载线程数（GitHub release 支持 Range，6~8 线程性价比最高）
  static const _threads = 8;

  static final _logCtrl = StreamController<TermLine>.broadcast();
  static Stream<TermLine> get logs => _logCtrl.stream;
  static final _progressCtrl = StreamController<double>.broadcast();
  static Stream<double> get progress => _progressCtrl.stream;

  // 并发下载各自独立进度（避免乱跳）
  static double _nodeDlPct = 0;
  static double _backendDlPct = 0;
  static int _lastNodeIntPct = -1;
  static int _lastBackendIntPct = -1;
  static double _lastEmittedPct = -1;

  static void log(String msg, [LogLevel lv = LogLevel.info]) {
    _logCtrl.add(TermLine(msg, lv));
  }

  static void _emit(double v) {
    final clamped = v.clamp(0.0, 1.0);
    // 变化小于 0.5% 且非端点值时不推送，避免高频抖动
    if ((clamped - _lastEmittedPct).abs() < 0.005 &&
        clamped != 0 && clamped != 1) {
      return;
    }
    _lastEmittedPct = clamped;
    _progressCtrl.add(clamped);
  }

  // 镜像列表：全部支持 Range 透传（GitHub release 直连反代）
  static const _mirrors = [
    'https://ghfast.top',
    'https://gh-proxy.com',
    'https://ghproxy.net',
    'https://gh.llkk.cc',
    'https://github.moeyy.xyz',
    'https://ghproxy.cc',
    'https://mirror.ghproxy.com',
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
  static Future<String> getBackendSha() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_shaKey) ?? '';
  }
  static Future<void> _setBackendSha(String sha) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_shaKey, sha);
  }

  static Future<Map<String, dynamic>> checkUpdate() async {
    final installed = await isInstalled();
    final localVer = await getLocalVersion();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10)));
      final r = await dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/tags/$_tag',
        options: Options(validateStatus: (_) => true,
          headers: {'User-Agent': 'KuGou-App'}));
      if (r.statusCode != 200) {
        return {'hasUpdate': false, 'installed': installed, 'error': 'API ${r.statusCode}'};
      }
      final d = r.data is Map ? r.data as Map : {};
      final remoteVer = (d['published_at'] ?? '').toString();
      return {
        'hasUpdate': !installed || localVer != remoteVer,
        'remoteVer': remoteVer,
        'localVer': localVer,
        'installed': installed,
      };
    } catch (e) {
      return {'hasUpdate': false, 'installed': installed, 'error': '$e'};
    }
  }

  static Future<Map<String, dynamic>> checkLatestSource() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10)));
      final r = await dio.get(
        'https://api.github.com/repos/MakcRe/KuGouMusicApi/commits/main',
        options: Options(validateStatus: (_) => true,
          headers: {'User-Agent': 'KuGou-App'}));
      if (r.statusCode != 200) return {'error': 'API ${r.statusCode}'};
      final d = r.data is Map ? r.data as Map : {};
      final sha = (d['sha'] ?? '').toString();
      final msg = ((d['commit'] as Map?)?['message'] ?? '').toString();
      final date = ((d['commit'] as Map?)?['author'] as Map?)?['date'] ?? '';
      return {'sha': sha, 'msg': msg, 'date': date};
    } catch (e) {
      return {'error': '$e'};
    }
  }

  // ============ 测速（并发 HEAD，同时验证是否支持 Range） ============
  static Future<String> _fastestMirror() async {
    log('测速中…（并发探测 ${_mirrors.length} 个镜像）');
    final testUrl = 'https://github.com/$_owner/$_repo/releases/download/$_tag/node-arm64.tar.gz';
    final results = await Future.wait(_mirrors.map((m) async {
      final url = m.isEmpty ? testUrl : '$m/$testUrl';
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        followRedirects: true));
      final sw = Stopwatch()..start();
      try {
        final r = await dio.head(url,
          options: Options(validateStatus: (_) => true));
        sw.stop();
        final ok = r.statusCode != null && r.statusCode! < 400;
        return MapEntry(m, ok ? sw.elapsedMilliseconds : 999999);
      } catch (_) {
        sw.stop();
        return MapEntry(m, 999999);
      }
    }));
    results.sort((a, b) => a.value.compareTo(b.value));
    final best = results.first;
    log('选择: ${best.key.isEmpty ? "GitHub 直连" : best.key} (${best.value}ms)', LogLevel.ok);
    return best.key;
  }

  // ============ 多线程 Range 分片下载 ============
  static Future<void> _multiThreadDownload(
    String url,
    String destPath,
    void Function(int received, int total) onProgress, {
    int threads = _threads,
  }) async {
    final file = File(destPath);
    if (await file.exists()) await file.delete();

    // 1) 探测文件大小 / 是否支持 Range
    int len = 0;
    bool acceptRanges = false;
    try {
      final probe = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        followRedirects: true));
      final head = await probe.head(url,
        options: Options(validateStatus: (_) => true));
      len = int.tryParse(head.headers.value('content-length') ?? '0') ?? 0;
      final ar = (head.headers.value('accept-ranges') ?? '').toLowerCase();
      acceptRanges = ar.contains('bytes');
    } catch (_) {}

    // 2) 回退单线程
    if (len <= 0 || !acceptRanges || threads <= 1) {
      log('  服务器不支持 Range，回退单线程', LogLevel.warn);
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 15),
        followRedirects: true));
      await dio.download(url, destPath, onReceiveProgress: onProgress);
      return;
    }

    log('  文件大小 ${(len / 1024 / 1024).toStringAsFixed(1)} MB，启用 $threads 线程分片下载');

    // 3) 预分配文件
    final raf0 = await file.open(mode: FileMode.write);
    await raf0.setLength(len);
    await raf0.close();

    final chunkSize = (len / threads).ceil();
    final received = List<int>.filled(threads, 0);

    await Future.wait(List.generate(threads, (i) async {
      final start = i * chunkSize;
      final end = math.min(start + chunkSize, len) - 1;
      if (start > end || start >= len) return;

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 15),
        followRedirects: true));

      final resp = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=$start-$end'},
          validateStatus: (_) => true),
        onReceiveProgress: (r, t) {
          received[i] = r;
          final sum = received.fold<int>(0, (a, b) => a + b);
          onProgress(sum, len);
        },
      );

      final bytes = resp.data ?? const <int>[];
      final raf = await file.open(mode: FileMode.write);
      await raf.setPosition(start);
      await raf.writeFrom(bytes);
      await raf.close();
    }));
  }

  // ============ 下载单文件（进度独立） ============
  static Future<File> _download(
    String fileName, String destPath, String mirror, String label) async {
    final file = File(destPath);
    if (await file.exists()) await file.delete();

    final url = mirror.isEmpty
        ? 'https://github.com/$_owner/$_repo/releases/download/$_tag/$fileName'
        : '$mirror/https://github.com/$_owner/$_repo/releases/download/$_tag/$fileName';

    log('开始下载 $label');

    await _multiThreadDownload(url, destPath, (r, t) {
      if (t <= 0) return;
      final pct = r / t;
      final intPct = (pct * 100).toInt();

      if (label == 'Node') {
        _nodeDlPct = pct;
        if (intPct != _lastNodeIntPct) {
          _lastNodeIntPct = intPct;
          final mb = (r / 1024 / 1024).toStringAsFixed(1);
          final tmb = (t / 1024 / 1024).toStringAsFixed(1);
          log('[Node]    $intPct%   $mb / $tmb MB');
        }
      } else {
        _backendDlPct = pct;
        if (intPct != _lastBackendIntPct) {
          _lastBackendIntPct = intPct;
          final mb = (r / 1024 / 1024).toStringAsFixed(1);
          final tmb = (t / 1024 / 1024).toStringAsFixed(1);
          log('[Backend] $intPct%   $mb / $tmb MB');
        }
      }

      // 综合进度：Node 占 45%，Backend 占 20%，其余 35% 留给解压
      _emit(0.10 + _nodeDlPct * 0.45 + _backendDlPct * 0.20);
    });

    final size = await File(destPath).length();
    if (size < 1024) throw Exception('$fileName 太小');
    log('$label 完成 (${(size / 1024 / 1024).toStringAsFixed(2)} MB)', LogLevel.ok);
    return File(destPath);
  }

  // ============ 下载运行环境 ============
  static Future<bool> downloadRuntime() async {
    try {
      _resetProgress();
      log('═══ 下载运行环境 ═══');
      log('');

      log('【1/3】选择最快镜像');
      final mirror = await _fastestMirror();
      log('');

      final temp = await getTemporaryDirectory();

      log('【2/3】并发下载 Node + Backend（每文件 $_threads 线程）');
      final results = await Future.wait([
        _download('node-arm64.tar.gz', '${temp.path}/node-arm64.tar.gz', mirror, 'Node')
            .then((f) => {'ok': true, 'file': f})
            .catchError((e) => {'ok': false, 'err': e.toString()}),
        _download('backend.tar.gz', '${temp.path}/backend.tar.gz', mirror, 'Backend')
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
      _emit(0.78);

      log('');
      log('【3/3】解压');
      log('解压 Node…');
      final okN = await _ch.invokeMethod<bool>('unpackNode', {'src': nodeTgz.path});
      if (okN != true) {
        log('Node 解压失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }
      log('Node 解压完成', LogLevel.ok);

      log('解压 Backend…');
      final okB = await _ch.invokeMethod<bool>('unpackBackend', {'src': backendTgz.path});
      if (okB != true) {
        log('Backend 解压失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }
      log('Backend 解压完成', LogLevel.ok);

      try { await nodeTgz.delete(); await backendTgz.delete(); } catch (_) {}

      final upd = await checkUpdate();
      if (upd['remoteVer'] != null) {
        await _setLocalVersion(upd['remoteVer'].toString());
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

  // ============ 从源头更新（GitHub 源码 + App 内 npm install）============
  static Future<bool> updateFromSource() async {
    try {
      _resetProgress();
      log('═══ 从源头更新 ═══');
      log('');

      log('【1/4】检查远端版本');
      final latest = await checkLatestSource();
      if (latest['error'] != null) {
        log('检查失败: ${latest['error']}', LogLevel.err);
        return false;
      }
      final remoteSha = (latest['sha'] ?? '').toString();
      final remoteMsg = (latest['msg'] ?? '').toString();
      final localSha = await getBackendSha();
      final rShort = remoteSha.length > 8 ? remoteSha.substring(0, 8) : remoteSha;
      final lShort = localSha.length > 8 ? localSha.substring(0, 8) : localSha;
      log('远端: $rShort');
      log('本地: ${lShort.isEmpty ? "(未记录)" : lShort}');
      if (remoteMsg.isNotEmpty) {
        log('最新提交: ${remoteMsg.split("\n").first}');
      }
      if (localSha == remoteSha && remoteSha.isNotEmpty) {
        log('已是最新', LogLevel.ok);
        _emit(1.0);
        return true;
      }
      log('');

      log('【2/4】下载源码（多线程分片）');
      final temp = await getTemporaryDirectory();
      final zipPath = '${temp.path}/kg-source.zip';
      bool dlOk = false;
      for (final m in _mirrors) {
        try {
          final url = m.isEmpty
              ? 'https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip'
              : '$m/https://github.com/MakcRe/KuGouMusicApi/archive/refs/heads/main.zip';
          log('尝试: ${m.isEmpty ? "GitHub 直连" : m}');
          await _multiThreadDownload(url, zipPath, (r, t) {
            if (t > 0) {
              final intPct = (r / t * 100).toInt();
              if (intPct % 5 == 0) {
                final mb = (r / 1024 / 1024).toStringAsFixed(1);
                final tmb = (t / 1024 / 1024).toStringAsFixed(1);
                log('[源码]   $intPct%   $mb / $tmb MB');
              }
              _emit(0.10 + (r / t) * 0.45);
            }
          });
          dlOk = true;
          break;
        } catch (e) {
          log('源失败: $e', LogLevel.warn);
        }
      }
      if (!dlOk) {
        log('源码下载失败', LogLevel.err);
        return false;
      }
      log('源码下载完成', LogLevel.ok);
      log('');

      log('【3/4】解压源码');
      final extractOk = await _ch.invokeMethod<bool>('extractSourceZip', {
        'zip': zipPath, 'dest': 'backend_runtime/backend',
      });
      if (extractOk != true) {
        log('解压失败', LogLevel.err);
        await _dumpCrash();
        return false;
      }
      log('解压完成', LogLevel.ok);
      _emit(0.60);
      log('');

      log('【4/4】npm install（3-5 分钟）');
      final npmFuture = _ch.invokeMethod<bool>('runNpmInstall');
      int lastNpmLine = 0;
      Timer? poll;
      poll = Timer.periodic(const Duration(seconds: 2), (t) async {
        try {
          final txt = await _ch.invokeMethod<String>('getNpmLog');
          if (txt != null && txt.isNotEmpty) {
            final lines = txt.split('\n').where((l) => l.trim().isNotEmpty).toList();
            if (lines.length > lastNpmLine) {
              for (int i = lastNpmLine; i < lines.length && i < lastNpmLine + 3; i++) {
                log('  ${lines[i]}');
              }
              lastNpmLine = lines.length;
            }
          }
        } catch (_) {}
      });
      final npmOk = await npmFuture;
      poll.cancel();
      if (npmOk != true) {
        log('npm install 失败', LogLevel.err);
        try {
          final fullLog = await _ch.invokeMethod<String>('getNpmLog');
          if (fullLog != null) {
            for (final l in fullLog.split('\n').take(30)) {
              if (l.trim().isNotEmpty) log('  $l', LogLevel.err);
            }
          }
        } catch (_) {}
        return false;
      }
      log('npm install 完成', LogLevel.ok);

      await _setBackendSha(remoteSha);
      _emit(1.0);
      log('');
      log('✓ 更新完成 $rShort', LogLevel.ok);
      return true;
    } catch (e) {
      log('失败: $e', LogLevel.err);
      return false;
    }
  }

  // ============ 只执行 ============
  static Future<bool> executeOnly() async {
    try {
      _resetProgress();
      log('═══ 启动后端 ═══');
      log('');
      final installed = await isInstalled();
      if (!installed) {
        log('未安装运行环境', LogLevel.err);
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
        receiveTimeout: const Duration(seconds: 2)));
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

  // ============ 测试 Cookie（保留） ============
  static Future<Map<String, dynamic>> testCookie() async {
    final result = <String, dynamic>{'steps': <Map<String, String>>[], 'ok': false};
    void add(String name, String status, {bool pass = true}) {
      (result['steps'] as List).add({
        'name': name, 'status': status, 'pass': pass.toString(),
      });
    }

    try {
      final u = SignatureManager.I.config?['user'] as Map? ?? {};
      final t = (u['token'] ?? '').toString();
      if (t.length < 20) {
        add('本地 token', '未导入或过短 (${t.length} 字符)', pass: false);
        return result;
      }
      add('本地 token', '${t.length} 字符 ✓');
      add('userid', (u['userid'] ?? '(空)').toString());
    } catch (e) {
      add('本地 token', '读取失败: $e', pass: false);
      return result;
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5)));
      final r = await dio.get('http://127.0.0.1:3000/',
        options: Options(validateStatus: (_) => true));
      if (r.statusCode == 200 || r.statusCode == 404) {
        add('后端 :3000', 'HTTP ${r.statusCode} ✓');
      } else {
        add('后端 :3000', 'HTTP ${r.statusCode}', pass: false);
        return result;
      }
    } catch (e) {
      add('后端 :3000', '无法连接', pass: false);
      return result;
    }

    final u = SignatureManager.I.config?['user'] as Map? ?? {};
    final cookie = [
      if ((u['token'] ?? '').toString().isNotEmpty) 'token=${u['token']}',
      if ((u['userid'] ?? '').toString().isNotEmpty) 'userid=${u['userid']}',
      if ((u['dfid'] ?? '').toString().isNotEmpty) 'dfid=${u['dfid']}',
      if ((u['mid'] ?? '').toString().isNotEmpty) 'mid=${u['mid']}',
      'appid=${u['appid'] ?? "3116"}',
      'clientver=${u['clientver'] ?? "11590"}',
      'KG-FAKE=${u['kg_fake'] ?? u['userid'] ?? ""}',
    ].join('; ');

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10)));
      final r = await dio.get('http://127.0.0.1:3000/search',
        queryParameters: {'keywords': 'test', 'type': 'song', 'page': 1, 'pagesize': 1},
        options: Options(headers: {'Cookie': cookie}, validateStatus: (_) => true));
      if (r.statusCode == 200) {
        final d = r.data is String ? jsonDecode(r.data) : r.data;
        if (d is Map) {
          final ec = d['error_code'] ?? d['errcode'];
          if (ec == 20028) {
            add('搜索接口', 'errcode 20028 · 风控', pass: false);
          } else if (ec != null && ec != 0) {
            add('搜索接口', 'errcode $ec', pass: false);
          } else {
            add('搜索接口', 'HTTP 200 ✓');
          }
        }
      } else {
        add('搜索接口', 'HTTP ${r.statusCode}', pass: false);
      }
    } catch (e) {
      add('搜索接口', '失败', pass: false);
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10)));
      final r = await dio.get('http://127.0.0.1:3000/song/url',
        queryParameters: {'id': 'B3A52A7A958BF0AED0EBFBA2E9A818B7', 'album_audio_id': '32100650'},
        options: Options(headers: {'Cookie': cookie}, validateStatus: (_) => true));
      if (r.statusCode == 200) {
        final d = r.data is String ? jsonDecode(r.data) : r.data;
        if (d is Map) {
          final ec = d['error_code'];
          if (ec == 20018) {
            add('免费歌', 'error_code 20018 (VIP)', pass: false);
          } else if (ec != null && ec != 0) {
            add('免费歌', 'error_code $ec', pass: false);
          } else {
            add('免费歌', 'HTTP 200 ✓');
          }
        }
      }
    } catch (e) {
      add('免费歌', '失败', pass: false);
    }

    final steps = result['steps'] as List;
    result['ok'] = steps.every((e) => (e as Map)['pass'] == 'true');
    return result;
  }

  // ============ 基础 API ============
  static void _resetProgress() {
    _nodeDlPct = 0;
    _backendDlPct = 0;
    _lastNodeIntPct = -1;
    _lastBackendIntPct = -1;
    _lastEmittedPct = -1;
    _progressCtrl.add(0.0);
  }

  static Future<bool> isInstalled() async {
    try { return await _ch.invokeMethod<bool>('unpacked') ?? false; }
    catch (_) { return false; }
  }
  static Future<bool> isRunning() async {
    try { return await _ch.invokeMethod<bool>('running') ?? false; }
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

  static Future<void> _dumpCrash() async {
    final crash = await getCrashLog();
    if (crash.isNotEmpty) {
      log('--- 崩溃日志 ---', LogLevel.err);
      for (final line in crash.split('\n').take(20)) log(line, LogLevel.err);
    }
  }
}
