import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../server_manager.dart';
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
  bool _busy = false;
  bool _pingBusy = false;
  bool? _remoteOnline;

  @override
  void initState() {
    super.initState();
    final m = ServerManager.I;
    _addrC.text = m.address;
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

  Map<String, String> _collectExtra() {
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
    _toast(mode == 'local' ? '已切换到本地后端' : '已切换到远程服务器');
  }

  Future<void> _save() async {
    if (_addrC.text.trim().isEmpty) { _toast('地址不能为空'); return; }
    if (_userC.text.trim().isEmpty) { _toast('用户名不能为空'); return; }
    setState(() => _busy = true);
    await ServerManager.I.save(
      address: _addrC.text, username: _userC.text, password: _passC.text,
      providerId: ServerManager.I.providerId, extra: _collectExtra());
    setState(() => _busy = false);
    _toast('已保存到 Music/KuGou/server.json');
  }

  Future<void> _upload() async {
    if (_addrC.text.trim().isEmpty || _userC.text.trim().isEmpty) {
      _toast('请先填写地址和用户名'); return;
    }
    setState(() => _busy = true);
    try {
      await ServerManager.I.save(
        address: _addrC.text, username: _userC.text, password: _passC.text,
        providerId: ServerManager.I.providerId, extra: _collectExtra());
      final id = await ServerManager.I.uploadShare();
      if (!mounted) return;
      setState(() => _busy = false);
      _showUploadResult(id);
    } catch (e) {
      setState(() => _busy = false);
      _toast('上传失败：$e');
    }
  }

  void _showUploadResult(String id) {
    final p = ServerManager.I.provider;
    final token = '${p.id}:$id';
    final encrypted = ServerManager.I.exportEncrypted();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF17171B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        const SizedBox(width: 8),
        const Text('上传成功', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tokenBlock('服务器', p.name),
          const SizedBox(height: 10),
          _tokenBlock('分享 ID', id),
          const SizedBox(height: 10),
          _tokenBlock('推荐分享串', token, highlight: true),
          const SizedBox(height: 10),
          _tokenBlock('离线加密串（无需服务器）', encrypted, small: true),
          const SizedBox(height: 12),
          Text('把「推荐分享串」或「离线加密串」发给对方，对方在「导入」粘贴即可。',
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.6), height: 1.6)),
        ],
      )),
      actions: [
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: token));
          Navigator.pop(context); _toast('已复制分享串');
        }, child: const Text('复制分享串')),
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: encrypted));
          Navigator.pop(context); _toast('已复制加密串');
        }, child: const Text('复制加密串')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
      ]));
  }

  Widget _tokenBlock(String label, String value, {bool highlight = false, bool small = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11,
        color: Colors.white.withOpacity(0.55), letterSpacing: 0.5)),
      const SizedBox(height: 5),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight
            ? const Color(0xFF7C6CB0).withOpacity(0.15)
            : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
              ? const Color(0xFF7C6CB0).withOpacity(0.5)
              : Colors.white.withOpacity(0.08))),
        child: SelectableText(value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: small ? 9.5 : 12,
            color: highlight ? const Color(0xFFB8A8FF) : Colors.white70,
            height: 1.5)),
      ),
    ]);
  }

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
      _toast('导入成功（来源：${ServerManager.I.provider.name}）');
    } catch (e) {
      setState(() => _busy = false);
      _toast('导入失败：$e');
    }
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) { _toast('无效链接'); return; }
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (!ok) _toast('无法打开浏览器');
    } catch (e) {
      _toast('打开失败：$e');
    }
  }

  Future<void> _showProviderPicker() async {
    final current = ServerManager.I.providerId;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF17171B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: const [
            Text('选择上传服务器', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ])),
        const SizedBox(height: 8),
        for (final p in kProviders)
          ListTile(
            leading: Icon(
              p.id == current ? Icons.radio_button_checked : Icons.radio_button_off,
              color: p.id == current ? const Color(0xFF7C6CB0) : Colors.white38,
              size: 20),
            title: Text(p.name, style: const TextStyle(
              fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(p.desc, style: TextStyle(
              fontSize: 11.5, color: Colors.white.withOpacity(0.55), height: 1.5)),
            onTap: () => Navigator.pop(context, p.id)),
        const SizedBox(height: 10),
      ])));
    if (chosen != null && chosen != current) {
      // 清空旧 extra 控制器，重建
      for (final c in _extraC.values) c.dispose();
      _extraC.clear();
      final p = kProviders.firstWhere((x) => x.id == chosen);
      for (final f in p.fields) {
        _extraC[f.key] = TextEditingController(
          text: ServerManager.I.extraFields[f.key] ?? '');
      }
      await ServerManager.I.save(
        address: _addrC.text, username: _userC.text, password: _passC.text,
        providerId: chosen);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ServerManager>();
    final p = m.provider;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('服务器共享')),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), children: [
        _label('1 · 选择上传服务器'),
        GlassCard(radius: 14, padding: EdgeInsets.zero, child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF7C6CB0).withOpacity(0.18),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.cloud_outlined,
              color: Color(0xFF9C8FD0), size: 20)),
          title: Text(p.name, style: const TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
          subtitle: Text(p.desc, style: TextStyle(
            fontSize: 11.5, color: Colors.white.withOpacity(0.55), height: 1.5)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _showProviderPicker,
        )),
        const SizedBox(height: 10),
        _accountGuide(p),
        const SizedBox(height: 22),
        _label('2 · 填写连接信息'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(16), child: Column(children: [
          _field('后端地址', _addrC, hint: 'http://192.168.1.100:3000'),
          const SizedBox(height: 12),
          _field('用户名', _userC, hint: 'your-username'),
          const SizedBox(height: 12),
          _field('密码', _passC, hint: '••••••', obscure: true),
          for (final f in p.fields) ...[
            const SizedBox(height: 12),
            _field(f.label, _extraC[f.key]!, hint: f.hint, obscure: f.obscure),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.white.withOpacity(0.18))),
              onPressed: _busy ? null : _save,
              child: const Text('保存到本地'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: AppTheme.p),
              onPressed: _busy ? null : _upload,
              child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('上传到 ${p.name}'))),
          ]),
        ])),
        const SizedBox(height: 22),
        _label('3 · 导入别人的服务器'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(16), child: Column(children: [
          _field('分享串 / 加密串', _importC,
            hint: 'jsonblob:xxxx 或 KGv1:xxxxx 或纯 ID'),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppTheme.p),
            onPressed: _busy ? null : _import,
            child: const Text('导入'))),
        ])),
        const SizedBox(height: 22),
        _label('4 · 服务器模式'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            Expanded(child: _modeBtn('本地后端', Icons.phone_android, 'local', m)),
            const SizedBox(width: 10),
            Expanded(child: _modeBtn('远程服务器', Icons.cloud, 'remote', m)),
          ]),
          if (m.serverMode == 'remote') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(
                m.hasRemote ? m.address : '尚未配置远程地址',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5,
                  color: Colors.white.withOpacity(0.6)))),
              const SizedBox(width: 8),
              SizedBox(height: 30, child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.white.withOpacity(0.18)),
                  foregroundColor: Colors.white.withOpacity(0.8)),
                onPressed: _pingBusy ? null : _ping,
                icon: _pingBusy
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _remoteOnline == null ? Icons.network_check
                      : _remoteOnline! ? Icons.check_circle : Icons.error_outline,
                      size: 14),
                label: Text(_remoteOnline == null ? '检测' : (_remoteOnline! ? '在线' : '离线'),
                  style: const TextStyle(fontSize: 11)))),
            ]),
          ],
          if (m.hasRemote) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: TextButton.icon(
              onPressed: () async {
                final c = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF17171B),
                  title: const Text('清空远程配置？'),
                  content: const Text('将删除本机保存的远程地址、用户名、密码。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
                  ]));
                if (c == true) { await ServerManager.I.clearRemote(); setState(() {}); }
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              label: const Text('删除我的远程配置', style: TextStyle(fontSize: 12, color: Colors.redAccent)))),
          ],
        ])),
        const SizedBox(height: 22),
        _label('5 · 使用提示'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '· 每个服务器需要填的字段不同。例如 jsonblob / dpaste / npoint 无需注册；'
            'jsonbin 需要 X-Master-Key，pastebin 需要 API Dev Key。\n'
            '· 上传成功后，客户端会生成两种分享串：\n'
            '   1) 服务器分享串  —— 形如 "jsonblob:1234567890"，对方需联网读取\n'
            '   2) 离线加密串    —— 形如 "KGv1:xxx…"，无需服务器，直接解密\n'
            '· 两种串都已用 XOR+Base64 加密混淆，抓包者看不懂内容。\n'
            '· 所有凭据同时保存在 /storage/emulated/0/Music/KuGou/server.json，下次启动自动读取。',
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.5), height: 1.9))),
        const SizedBox(height: 32),
      ]));
  }

  Widget _accountGuide(ServerProvider p) {
    // 不需要账号的服务器
    if (p.signupUrl.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 15, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Text('${p.name} 无需注册，直接上传即可',
            style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
        ]));
    }

    // 需要账号的服务器
    final missingFields = p.fields.where((f) => (_extraC[f.key]?.text ?? '').isEmpty).toList();
    final hasAccount = missingFields.isEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (hasAccount ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (hasAccount ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(hasAccount ? Icons.verified_user : Icons.warning_amber_rounded,
            size: 17,
            color: hasAccount ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(
            hasAccount ? '已配置 ${p.name} 账号' : '还没有 ${p.name} 账号？',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: hasAccount ? Colors.greenAccent : Colors.orangeAccent))),
        ]),
        const SizedBox(height: 8),
        Text(
          hasAccount
            ? '${p.name} 的 API Key 已填写，可以上传共享。'
            : '第一步：点下方按钮去浏览器注册账号。第二步：从账号页复制 API Key，回本页填入，即可上传。',
          style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.72), height: 1.65)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              foregroundColor: Colors.white.withOpacity(0.85)),
            onPressed: () => _openUrl(p.signupUrl),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: Text(hasAccount ? '打开 ${p.name}' : '去 ${p.name} 注册',
              style: const TextStyle(fontSize: 12)))),
          if (!hasAccount) ...[
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: AppTheme.p),
              onPressed: () {
                // 滚动到 API Key 输入框
                FocusScope.of(context).requestFocus(FocusNode());
                _toast('请在下方「${missingFields.first.label}」输入框粘贴');
              },
              icon: const Icon(Icons.keyboard_arrow_down, size: 14),
              label: const Text('已有账号', style: TextStyle(fontSize: 12)))),
          ],
        ]),
      ]));
  }

  Widget _modeBtn(String title, IconData icon, String mode, ServerManager m) {
    final active = m.serverMode == mode;
    return Material(
      color: active ? AppTheme.p.withOpacity(0.18) : Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _busy ? null : () => _switchMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppTheme.p.withOpacity(0.5)
              : Colors.white.withOpacity(0.08))),
          child: Column(children: [
            Icon(icon, size: 20, color: active ? AppTheme.p : Colors.white60),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.white60)),
          ]))));
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
    child: Text(t, style: TextStyle(fontSize: 12,
      fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.white.withOpacity(0.7))));

  Widget _field(String label, TextEditingController c, {String? hint, bool obscure = false}) {
    return TextField(
      controller: c, obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55)),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.p.withOpacity(0.6))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)));
  }
}
