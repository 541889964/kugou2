import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'signature_manager.dart';

enum InsightLevel { plain, info, ok, warn, err, header, value }

class InsightLine {
  final String text;
  final InsightLevel level;
  InsightLine(this.text, this.level);
}

class HarAnalysisResult {
  final Map<String, String> creds;
  final Map<String, String> sources;
  final List<String> insights;
  final int score;
  final bool saved;
  const HarAnalysisResult({
    required this.creds,
    required this.sources,
    required this.insights,
    required this.score,
    required this.saved,
  });
}

class HarAnalyzer {
  HarAnalyzer._();

  static const _knownKeys = <String, List<String>>{
    'token':     ['token', 'access_token', 'auth', 'authorization'],
    'userid':    ['userid', 'user_id', 'uid', 'kugouid'],
    'dfid':      ['dfid', 'device_id', 'deviceid', 'df_id'],
    'mid':       ['mid', 'machine_id', 'machineid'],
    'uuid':      ['uuid', 'kg_uuid'],
    'appid':     ['appid', 'app_id'],
    'clientver': ['clientver', 'client_ver', 'ver'],
    'kg_fake':   ['kg-fake', 'kg_fake', 'kgfake'],
  };

  static Future<HarAnalysisResult> analyze(
    File harFile, {
    required void Function(InsightLine) onLine,
    bool save = true,
  }) async {
    final creds = <String, String>{};
    final sources = <String, String>{};
    final insights = <String>[];

    void emit(String t, [InsightLevel lv = InsightLevel.plain]) =>
        onLine(InsightLine(t, lv));
    void head(String t) => onLine(InsightLine(t, InsightLevel.header));

    head('▶ [1/8] 读取 HAR 文件');
    if (!await harFile.exists()) {
      emit('  ✗ 文件不存在', InsightLevel.err);
      return _fail(creds, sources, insights, onLine);
    }
    final content = await harFile.readAsString();
    final kb = (content.length / 1024).toStringAsFixed(1);
    emit('  路径: ${harFile.path}');
    emit('  大小: $kb KB');
    await Future.delayed(const Duration(milliseconds: 120));

    head('▶ [2/8] 解析 JSON');
    dynamic root;
    try {
      root = jsonDecode(content);
    } catch (e) {
      emit('  ✗ JSON 非法: $e', InsightLevel.err);
      return _fail(creds, sources, insights, onLine);
    }
    if (root is! Map) {
      emit('  ✗ 不是对象格式', InsightLevel.err);
      return _fail(creds, sources, insights, onLine);
    }
    final entries = ((root['log'] as Map?)?['entries'] as List?) ?? const [];
    emit('  请求总数: ${entries.length}');
    await Future.delayed(const Duration(milliseconds: 120));

    head('▶ [3/8] 全量扫描请求');
    int kugouReqs = 0;
    int withCookie = 0;
    int withBody = 0;
    final hostStats = <String, int>{};
    for (final e in entries) {
      if (e is! Map) continue;
      final req = e['request'] as Map?;
      if (req == null) continue;
      final url = (req['url'] ?? '').toString();
      final host = Uri.tryParse(url)?.host ?? '';
      if (host.isNotEmpty) hostStats[host] = (hostStats[host] ?? 0) + 1;
      if (host.contains('kugou') || url.contains('kugou')) kugouReqs++;
      final headers = (req['headers'] as List?) ?? const [];
      for (final h in headers) {
        if (h is Map && (h['name'] ?? '').toString().toLowerCase() == 'cookie') {
          withCookie++;
          break;
        }
      }
      if (req['postData'] != null) withBody++;
    }
    emit('  酷狗域请求: $kugouReqs / ${entries.length}');
    emit('  含 Cookie 头: $withCookie');
    emit('  含 POST Body: $withBody');
    final topHosts = hostStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final h in topHosts.take(5)) {
      emit('    · ${h.key}  (${h.value})', InsightLevel.info);
    }
    await Future.delayed(const Duration(milliseconds: 160));

    head('▶ [4/8] 智能提取凭证');
    final found = <String, _Hit>{};

    void record(String key, String value, String source, {int weight = 1}) {
      if (value.isEmpty || value == 'null' || value == 'undefined') return;
      final prev = found[key];
      if (prev == null || weight > prev.weight) {
        found[key] = _Hit(value, source, weight);
      }
    }

    String norm(String k) => k.toLowerCase().trim().replaceAll('-', '_');

    for (final e in entries) {
      if (e is! Map) continue;
      final req = e['request'] as Map?;
      if (req == null) continue;
      final headers = (req['headers'] as List?) ?? const [];
      for (final h in headers) {
        if (h is! Map) continue;
        if ((h['name'] ?? '').toString().toLowerCase() != 'cookie') continue;
        final cv = (h['value'] ?? '').toString();
        for (final part in cv.split(';')) {
          final t = part.trim();
          final i = t.indexOf('=');
          if (i <= 0) continue;
          final k = norm(t.substring(0, i));
          final v = t.substring(i + 1).trim();
          for (final kv in _knownKeys.entries) {
            if (kv.value.map(norm).contains(k)) {
              record(kv.key, v, 'Cookie: $k', weight: 3);
            }
          }
        }
      }
    }

    for (final e in entries) {
      if (e is! Map) continue;
      final url = ((e['request'] as Map?)?['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      for (final q in uri.queryParameters.entries) {
        final k = norm(q.key);
        for (final kv in _knownKeys.entries) {
          if (kv.value.map(norm).contains(k)) {
            record(kv.key, q.value, 'URL: ${q.key}', weight: 2);
          }
        }
      }
    }

    for (final e in entries) {
      if (e is! Map) continue;
      final pd = (e['request'] as Map?)?['postData'] as Map?;
      if (pd == null) continue;
      final text = (pd['text'] ?? '').toString();
      if (text.isEmpty) continue;
      try {
        final j = jsonDecode(text);
        if (j is Map) {
          _deepScan(j, (k, v) {
            final nk = norm(k);
            for (final kv in _knownKeys.entries) {
              if (kv.value.map(norm).contains(nk)) {
                record(kv.key, v.toString(), 'Body: $k', weight: 2);
              }
            }
          });
        }
      } catch (_) {
        for (final pair in text.split('&')) {
          final i = pair.indexOf('=');
          if (i <= 0) continue;
          final k = norm(Uri.decodeComponent(pair.substring(0, i)));
          final v = Uri.decodeComponent(pair.substring(i + 1));
          for (final kv in _knownKeys.entries) {
            if (kv.value.map(norm).contains(k)) {
              record(kv.key, v, 'Body: $k', weight: 2);
            }
          }
        }
      }
    }

    for (final e in entries) {
      if (e is! Map) continue;
      final c = ((e['response'] as Map?)?['content'] as Map?)?['text'];
      if (c is! String || c.isEmpty || c.length > 200000) continue;
      for (final kv in _knownKeys.entries) {
        final pattern = RegExp(
          '"(${kv.value.join('|')})"\\s*:\\s*"?([\\w\\-\\d]+)"?',
          caseSensitive: false);
        final m = pattern.firstMatch(c);
        if (m != null) record(kv.key, m.group(2)!, 'Response', weight: 1);
      }
    }

    for (final k in _knownKeys.keys) {
      final h = found[k];
      if (h == null) {
        emit('  ✗ $k 未找到', InsightLevel.warn);
        continue;
      }
      final v = h.value;
      final disp = v.length > 40
          ? '${v.substring(0, 20)}…${v.substring(v.length - 8)}'
          : v;
      emit('  ✓ $k = $disp  ← ${h.source}', InsightLevel.value);
      creds[k] = v;
      sources[k] = h.source;
    }
    await Future.delayed(const Duration(milliseconds: 160));

    head('▶ [5/8] 交叉验证 & 智能补全');
    final tok = creds['token'] ?? '';
    if (tok.length < 20) {
      emit('  ⚠ token 过短 (${tok.length} 字符)，可能无效', InsightLevel.warn);
      insights.add('token 长度异常');
    } else {
      emit('  ✓ token 长度 ${tok.length} 字符，符合酷狗格式', InsightLevel.ok);
    }
    if ((creds['kg_fake'] ?? '').isEmpty) {
      final uid = creds['userid'] ?? '';
      if (uid.isNotEmpty) {
        creds['kg_fake'] = uid;
        sources['kg_fake'] = '自动补全: = userid';
        emit('  ⚙ kg_fake 缺失 → 自动填充为 userid', InsightLevel.info);
      }
    }
    if ((creds['dfid'] ?? '').isEmpty) {
      final mid = creds['mid'] ?? '';
      if (mid.isNotEmpty && mid.length >= 8) {
        creds['dfid'] = mid;
        sources['dfid'] = '自动补全: = mid';
        emit('  ⚙ dfid 缺失 → 尝试用 mid 顶替', InsightLevel.info);
        insights.add('dfid 为推断值');
      }
    }
    creds.putIfAbsent('appid', () => '3116');
    sources.putIfAbsent('appid', () => '默认值');
    creds.putIfAbsent('clientver', () => '11590');
    sources.putIfAbsent('clientver', () => '默认值');
    creds.putIfAbsent('uuid', () => '-');
    sources.putIfAbsent('uuid', () => '默认值');

    int score = 0;
    if (tok.length >= 20) score += 40;
    if ((creds['userid'] ?? '').isNotEmpty) score += 20;
    if ((creds['mid'] ?? '').isNotEmpty) score += 10;
    if ((creds['dfid'] ?? '').isNotEmpty) score += 10;
    if (sources['dfid'] != '自动补全: = mid') score += 10;
    if (creds['appid'] == '3116') score += 5;
    if (creds['clientver'] == '11590') score += 5;
    final grade = score >= 90 ? 'A+' : score >= 75 ? 'A' : score >= 60 ? 'B' : score >= 40 ? 'C' : 'D';
    emit('  综合评分: $score / 100  (等级 $grade)',
        score >= 75 ? InsightLevel.ok : InsightLevel.warn);
    await Future.delayed(const Duration(milliseconds: 160));

    head('▶ [6/8] 写入本地配置');
    bool saved = false;
    if (save) {
      try {
        await SignatureManager.I.updateUser(creds);
        emit('  ✓ 已写入 signature.json 与 cookie.json', InsightLevel.ok);
        saved = true;
      } catch (e) {
        emit('  ✗ 写入失败: $e', InsightLevel.err);
      }
    } else {
      emit('  ⏸ 已跳过保存（干跑模式）', InsightLevel.info);
    }
    await Future.delayed(const Duration(milliseconds: 160));

    head('▶ [7/8] 本地格式验证');
    final u = SignatureManager.I.config?['user'] as Map?;
    if (u != null && (u['token'] ?? '').toString().length >= 20) {
      emit('  ✓ SignatureManager 已加载新凭证', InsightLevel.ok);
    } else {
      emit('  ⚠ SignatureManager 未读回 token', InsightLevel.warn);
    }
    await Future.delayed(const Duration(milliseconds: 160));

    head('▶ [8/8] 实时 API 验证');
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8)));
      final ping = await dio.get('http://127.0.0.1:3000/',
          options: Options(validateStatus: (_) => true));
      if (ping.statusCode != null && ping.statusCode! < 500) {
        emit('  ✓ 后端在线 HTTP ${ping.statusCode}', InsightLevel.ok);
        final cookie = _cookieFrom(creds);
        final r = await dio.get('http://127.0.0.1:3000/search',
          queryParameters: {'keywords': 'test', 'type': 'song', 'page': 1, 'pagesize': 1},
          options: Options(headers: {'Cookie': cookie}, validateStatus: (_) => true));
        if (r.statusCode == 200) {
          final d = r.data is String ? jsonDecode(r.data) : r.data;
          final ec = (d is Map) ? (d['error_code'] ?? d['errcode']) : null;
          if (ec == 20028) {
            emit('  ⚠ 搜索接口触发风控 20028', InsightLevel.warn);
            insights.add('风控');
          } else if (ec != null && ec != 0) {
            emit('  ✗ 搜索返回错误码 $ec', InsightLevel.err);
          } else {
            emit('  ✓ 搜索接口正常', InsightLevel.ok);
          }
        }
        final r2 = await dio.get('http://127.0.0.1:3000/song/url',
          queryParameters: {'id': 'B3A52A7A958BF0AED0EBFBA2E9A818B7', 'album_audio_id': '32100650'},
          options: Options(headers: {'Cookie': cookie}, validateStatus: (_) => true));
        if (r2.statusCode == 200) {
          final d = r2.data is String ? jsonDecode(r2.data) : r2.data;
          final ec = (d is Map) ? d['error_code'] : null;
          if (ec == 20018) {
            emit('  ⚠ 免费歌返回 20018（VIP 限制）', InsightLevel.warn);
            insights.add('账号无 VIP');
          } else if (ec != null && ec != 0) {
            emit('  ✗ song/url 错误码 $ec', InsightLevel.err);
          } else {
            emit('  ✓ song/url 接口正常', InsightLevel.ok);
          }
        }
      } else {
        emit('  ✗ 后端返回 HTTP ${ping.statusCode}', InsightLevel.err);
      }
    } catch (e) {
      emit('  ⚠ 后端未启动，跳过 API 验证', InsightLevel.warn);
      insights.add('后端离线');
    }

    head('── 分析完成 ──');
    emit('凭证字段: ${creds.length} 个');
    emit('异常提示: ${insights.isEmpty ? "无" : insights.join(" / ")}');
    emit('', InsightLevel.plain);
    onLine(InsightLine(score >= 75 ? '✓ HAR 分析成功' : '⚠ HAR 分析完成（有警告）',
        score >= 75 ? InsightLevel.ok : InsightLevel.warn));

    return HarAnalysisResult(
      creds: creds, sources: sources, insights: insights,
      score: score, saved: saved);
  }

  static void _deepScan(Map m, void Function(String, dynamic) cb) {
    m.forEach((k, v) {
      if (v is Map) {
        _deepScan(v, cb);
      } else if (v is List) {
        for (final e in v) {
          if (e is Map) _deepScan(e, cb);
        }
      } else {
        cb(k.toString(), v);
      }
    });
  }

  static String _cookieFrom(Map<String, String> c) => [
    if ((c['token'] ?? '').isNotEmpty) 'token=${c['token']}',
    if ((c['userid'] ?? '').isNotEmpty) 'userid=${c['userid']}',
    if ((c['dfid'] ?? '').isNotEmpty) 'dfid=${c['dfid']}',
    if ((c['mid'] ?? '').isNotEmpty) 'mid=${c['mid']}',
    'appid=${c['appid'] ?? "3116"}',
    'clientver=${c['clientver'] ?? "11590"}',
    'KG-FAKE=${c['kg_fake'] ?? c['userid'] ?? ""}',
  ].join('; ');

  static HarAnalysisResult _fail(
    Map<String, String> c, Map<String, String> s, List<String> i,
    void Function(InsightLine) onLine,
  ) {
    onLine(InsightLine('✗ 分析失败', InsightLevel.err));
    return HarAnalysisResult(
      creds: c, sources: s, insights: i, score: 0, saved: false);
  }
}

class _Hit {
  final String value;
  final String source;
  final int weight;
  const _Hit(this.value, this.source, this.weight);
}
