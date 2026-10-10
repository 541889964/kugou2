import 'dart:convert';
class HarParser {
  static const keys = ['token','userid','dfid','mid','uuid','appid','clientver','kg-fake','kg_fake'];
  static Map<String,String> parse(String c) {
    final out = <String,String>{};
    try { final j = _j(c); if (j != null) _w(j, out); } catch (_) {}
    _s(c, out);
    final n = <String,String>{};
    out.forEach((k,v) {
      var nk = k.toLowerCase();
      if (nk == 'kg-fake') nk = 'kg_fake';
      if (v.isNotEmpty && v != 'null' && v != 'undefined' && v != '0') n[nk] = v;
    });
    if ((n['kg_fake'] ?? '').isEmpty && (n['userid'] ?? '').isNotEmpty) n['kg_fake'] = n['userid']!;
    return n;
  }
  static dynamic _j(String s) {
    try { return jsonDecode(s); } catch (_) {
      final a = s.indexOf('{'), b = s.lastIndexOf('}');
      if (a >= 0 && b > a) { try { return jsonDecode(s.substring(a,b+1)); } catch (_) {} }
    }
    return null;
  }
  static void _w(dynamic n, Map<String,String> o) {
    if (n == null) return;
    if (n is Map) {
      final nm = n['name']?.toString().toLowerCase();
      final v = n['value']?.toString();
      if (nm != null && v != null) {
        if (nm == 'cookie') _ck(v, o);
        else if (keys.contains(nm) && !o.containsKey(nm)) o[nm] = v;
      }
      if (n['cookies'] is List) for (final c in n['cookies']) if (c is Map) {
        final nn = c['name']?.toString().toLowerCase();
        final vv = c['value']?.toString();
        if (nn != null && vv != null && keys.contains(nn) && !o.containsKey(nn)) o[nn] = vv;
      }
      if (n['url'] != null) _u(n['url'].toString(), o);
      if (n['postData'] is Map) {
        final t = (n['postData'] as Map)['text']?.toString();
        if (t != null) _s(t, o);
      }
      for (final x in n.values) if (x is Map || x is List) _w(x, o);
    } else if (n is List) for (final x in n) if (x is Map || x is List) _w(x, o);
  }
  static void _ck(String s, Map<String,String> o) {
    for (final p in s.split(';')) {
      final t = p.trim();
      final i = t.indexOf('=');
      if (i <= 0) continue;
      final k = t.substring(0,i).trim().toLowerCase();
      final v = t.substring(i+1).trim();
      if (keys.contains(k) && v.isNotEmpty && !o.containsKey(k)) o[k] = v;
    }
  }
  static void _u(String u, Map<String,String> o) {
    if (!u.startsWith('http') && !u.startsWith('/')) return;
    try {
      final x = Uri.parse(u.startsWith('http') ? u : 'https://x$u');
      for (final e in x.queryParameters.entries) {
        final k = e.key.toLowerCase();
        if (keys.contains(k) && !o.containsKey(k)) o[k] = e.value;
      }
    } catch (_) {}
  }
  static void _s(String s, Map<String,String> o) {
    for (final k in keys) {
      if (o.containsKey(k)) continue;
      final m = RegExp('(?<![a-zA-Z0-9_])${RegExp.escape(k)}=([^;&\\s"\'<>,\\}\\]\\[]+)',
        caseSensitive: false).firstMatch(s);
      if (m != null) {
        final v = m.group(1)!.trim();
        if (v.isNotEmpty && v != 'null' && v != 'undefined') o[k] = v;
      }
    }
  }
  static bool isValid(Map<String,String> m) =>
    (m['token'] ?? '').length >= 20 && (m['userid'] ?? '').isNotEmpty;
  static String describe(Map<String,String> m) {
    if (m.isEmpty) return '（未找到字段）';
    final b = StringBuffer();
    for (final k in ['token','userid','dfid','mid','uuid','appid','clientver','kg_fake']) {
      if (m.containsKey(k)) {
        final v = m[k]!;
        b.writeln('$k = ${v.length > 30 ? "${v.substring(0,14)}…${v.substring(v.length-6)}" : v}');
      }
    }
    return b.toString().trim();
  }
}
