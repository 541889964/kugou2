import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../server_manager.dart';
import '../mode_manager.dart';
import 'theme.dart';
import 'glass.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({super.key});
  @override
  State<ServerPage> createState() => _S();
}
class _S extends State<ServerPage> {
  final _addrC = TextEditingController();
  final _userC = TextEditingController();
  final _passC = TextEditingController();
  final _importC = TextEditingController();
  final Map<String, TextEditingController> _extraC = {};
  bool _busy = false, _pingBusy = false;
  bool? _remoteOnline;

  @override
  void initState() {
    super.initState();
    final m = ServerManager.I;
    _addrC.text = m.address.isEmpty ? ModeManager.I.backendUrl : m.address;
    _userC.text = m.username;
    _passC.text = m.password;
    for (final f in m.provider.fields) {
      _extraC[f.key] = TextEditingController(text: m.extraFields[f.key] ?? '');
    }
  }
  @override
  void dispose() {
    _addrC.dispose(); _userC.dispose(); _passC.dispose(); _importC.dispose();
    for (final c in _extraC.values) c.dispose();
    super.dispose();
  }
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2)));
  }
  Map<String, String> _collect() {
    final m = <String, String>{};
    _extraC.forEach((k, v) { if (v.text.isNotEmpty) m[k] = v.text.trim(); });
    return m;
  }
  Future<void> _ping() async {
    setState(() => _pingBusy = true);
    final ok = await ServerManager.I.pingRemote();
    setState(() { _pingBusy = false; _remoteOnline = ok; });
    _toast(ok ? '远程服务器在线' : '远程服务器离线');
  }
  Future<void> _switchMode(String mode) async {
    await ServerManager.I.setServerMode(mode);
    setState(() {});
    _toast(mode == 'local' ? '已切换本地' : '已切换远程');
  }
  Future<void> _save() async {
    if (_addrC.text.trim().isEmpty) { _toast('地址不能为空'); return; }
    setState(() => _busy = true);
    await ServerManager.I.save(address: _addrC.text, username: _userC.text,
      password: _passC.text, providerId: ServerManager.I.providerId, extra: _collect());
    setState(() => _busy = false);
    _toast('已保存');
  }
  Future<void> _upload() async {
    if (_addrC.text.trim().isEmpty) { _toast('请填写地址'); return; }
    setState(() => _busy = true);
    try {
      await ServerManager.I.save(address: _addrC.text, username: _userC.text,
        password: _passC.text, providerId: ServerManager.I.providerId, extra: _collect());
      final id = await ServerManager.I.uploadShare();
      if (!mounted) return;
      setState(() => _busy = false);
      _showResult(id);
    } catch (e) { setState(() => _busy = false); _toast('上传失败：$e'); }
  }
  void _showResult(String id) {
    final p = ServerManager.I.provider;
    final token = '${p.id}:$id';
    final enc = ServerManager.I.exportEncrypted();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('上传成功'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        _blk('服务器', p.name), const SizedBox(height: 10),
        _blk('分享串', token, hl: true), const SizedBox(height: 10),
        _blk('离线加密串', enc, small: true),
      ])),
      actions: [
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: token));
          Navigator.pop(context); _toast('已复制分享串');
        }, child: const Text('复制分享串')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
      ]));
  }
  Widget _blk(String l, String v, {bool hl = false, bool small = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
    const SizedBox(height: 5),
    Container(width: double.infinity, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hl ? AppTheme.p.withOpacity(0.15) : Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hl ? AppTheme.p.withOpacity(0.5) : Colors.white.withOpacity(0.08))),
      child: SelectableText(v, style: TextStyle(fontFamily: 'monospace',
        fontSize: small ? 9.5 : 12,
        color: hl ? const Color(0xFFB8A8FF) : Colors.white70))),
  ]);
  Future<void> _import() async {
    final s = _importC.text.trim();
    if (s.isEmpty) { _toast('请输入分享串'); return; }
    setState(() => _busy = true);
    try {
      await ServerManager.I.importShare(s);
      if (!mounted) return;
      _addrC.text = ServerManager.I.address;
      _userC.text = ServerManager.I.username;
      _passC.text = ServerManager.I.password;
      setState(() => _busy = false);
      _toast('导入成功');
    } catch (e) { setState(() => _busy = false); _toast('导入失败：$e'); }
  }
  Future<void> _open(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    try { await launchUrl(u, mode: LaunchMode.externalApplication); } catch (_) {}
  }
  Future<void> _pick() async {
    final cur = ServerManager.I.providerId;
    final chosen = await showModalBottomSheet<String>(context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(width: 36, height: 4, decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('选择上传服务器', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 8),
        for (final p in kProviders)
          ListTile(
            leading: Icon(p.id == cur ? Icons.radio_button_checked : Icons.radio_button_off,
              color: p.id == cur ? AppTheme.p : Colors.white38, size: 20),
            title: Text(p.name, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(p.desc, style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
            onTap: () => Navigator.pop(context, p.id)),
        const SizedBox(height: 10),
      ])));
    if (chosen != null && chosen != cur) {
      for (final c in _extraC.values) c.dispose();
      _extraC.clear();
      final p = kProviders.firstWhere((x) => x.id == chosen);
      for (final f in p.fields) {
        _extraC[f.key] = TextEditingController(text: ServerManager.I.extraFields[f.key] ?? '');
      }
      await ServerManager.I.save(address: _addrC.text, username: _userC.text,
        password: _passC.text, providerId: chosen);
      setState(() {});
    }
  }
  Widget _guide(ServerProvider p) {
    if (p.signupUrl.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        const Icon(Icons.check_circle, size: 15, color: AppTheme.s),
        const SizedBox(width: 8),
        Text('${p.name} 无需注册，直接上传即可',
          style: const TextStyle(fontSize: 12, color: AppTheme.s)),
      ]));
    final miss = p.fields.where((f) => (_extraC[f.key]?.text ?? '').isEmpty).toList();
    final ok = miss.isEmpty;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (ok ? AppTheme.s : Colors.orangeAccent).withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (ok ? AppTheme.s : Colors.orangeAccent).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.verified_user : Icons.warning_amber_rounded, size: 17,
            color: ok ? AppTheme.s : Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(ok ? '已配置 ${p.name} 账号' : '还没有 ${p.name} 账号？',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: ok ? AppTheme.s : Colors.orangeAccent))),
        ]),
        const SizedBox(height: 8),
        Text(ok ? '${p.name} 的 API Key 已填写，可以上传共享。'
          : '第一步：去注册账号。第二步：复制 API Key 填到下方。',
          style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.72), height: 1.6)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: Colors.white.withOpacity(0.18)),
            foregroundColor: Colors.white.withOpacity(0.85)),
          onPressed: () => _open(p.signupUrl),
          icon: const Icon(Icons.open_in_new, size: 14),
          label: Text(ok ? '打开 ${p.name}' : '去 ${p.name} 注册'))),
      ]));
  }
  Widget _modeBtn(String title, IconData icon, String mode) {
    final m = ServerManager.I;
    final active = m.serverMode == mode;
    return Material(color: active ? AppTheme.p.withOpacity(0.18) : Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(borderRadius: BorderRadius.circular(10),
        onTap: _busy ? null : () => _switchMode(mode),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppTheme.p.withOpacity(0.5) : Colors.white.withOpacity(0.08))),
          child: Column(children: [
            Icon(icon, size: 20, color: active ? AppTheme.p : Colors.white60),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.white60)),
          ]))));
  }
  @override
  Widget build(BuildContext context) {
    final m = context.watch<ServerManager>();
    final p = m.provider;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('服务器共享')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        _label('1 · 选择上传服务器'),
        GlassCard(radius: 14, padding: EdgeInsets.zero, heavy: true, child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: IconTile(icon: Icons.cloud_outlined, c1: AppTheme.p, c2: AppTheme.s),
          title: Text(p.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          subtitle: Text(p.desc, style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _pick)),
        const SizedBox(height: 10),
        _guide(p),
        const SizedBox(height: 22),
        _label('2 · 连接信息'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(16), heavy: true, child: Column(children: [
          _field('后端地址', _addrC, hint: 'http://127.0.0.1:3000'),
          const SizedBox(height: 12),
          _field('用户名（可选）', _userC),
          const SizedBox(height: 12),
          _field('密码（可选）', _passC, obscure: true),
          for (final f in p.fields) ...[
            const SizedBox(height: 12),
            _field(f.label, _extraC[f.key]!, hint: f.hint, obscure: f.obscure, onChanged: () => setState(() {})),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.white.withOpacity(0.18))),
              onPressed: _busy ? null : _save, child: const Text('保存'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: AppTheme.p),
              onPressed: _busy ? null : _upload,
              child: _busy ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)) : Text('上传到 ${p.name}'))),
          ]),
        ])),
        const SizedBox(height: 22),
        _label('3 · 导入'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(16), heavy: true, child: Column(children: [
          _field('分享串 / 加密串', _importC, hint: 'jsonblob:xxx 或 KGv1:xxx'),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppTheme.p),
            onPressed: _busy ? null : _import, child: const Text('导入'))),
        ])),
        const SizedBox(height: 22),
        _label('4 · 服务器模式'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(14), heavy: true, child: Column(children: [
          Row(children: [
            Expanded(child: _modeBtn('本地', Icons.phone_android, 'local')),
            const SizedBox(width: 10),
            Expanded(child: _modeBtn('远程', Icons.cloud, 'remote')),
          ]),
          if (m.serverMode == 'remote') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(m.hasRemote ? m.address : '未配置远程',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.6)))),
              SizedBox(height: 30, child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.white.withOpacity(0.18)),
                  foregroundColor: Colors.white.withOpacity(0.8)),
                onPressed: _pingBusy ? null : _ping,
                icon: _pingBusy ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_remoteOnline == null ? Icons.network_check
                    : _remoteOnline! ? Icons.check_circle : Icons.error_outline, size: 14),
                label: Text(_remoteOnline == null ? '检测' : (_remoteOnline! ? '在线' : '离线'),
                  style: const TextStyle(fontSize: 11)))),
            ]),
          ],
          if (m.hasRemote) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: TextButton.icon(
              onPressed: () async {
                final c = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('清空远程配置？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
                  ]));
                if (c == true) { await ServerManager.I.clearRemote(); setState(() {}); }
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              label: const Text('删除远程配置', style: TextStyle(fontSize: 12, color: Colors.redAccent)))),
          ],
        ])),
        const SizedBox(height: 32),
      ]));
  }
  Widget _label(String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
      letterSpacing: 0.8, color: Colors.white.withOpacity(0.7))));
  Widget _field(String label, TextEditingController c, {String? hint, bool obscure = false, VoidCallback? onChanged}) {
    return TextField(controller: c, obscureText: obscure, onChanged: (_) => onChanged?.call(),
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55)),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.3)),
        filled: true, fillColor: Colors.black.withOpacity(0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.p.withOpacity(0.6))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)));
  }
}
