import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = ServerManager.I;
    _addrC.text = m.address;
    _userC.text = m.username;
    _passC.text = m.password;
  }

  @override
  void dispose() {
    _addrC.dispose(); _userC.dispose(); _passC.dispose(); _importC.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2)));
  }

  Future<void> _save() async {
    if (_addrC.text.trim().isEmpty) { _toast('地址不能为空'); return; }
    if (_userC.text.trim().isEmpty) { _toast('用户名不能为空'); return; }
    setState(() => _busy = true);
    await ServerManager.I.save(
      address: _addrC.text, username: _userC.text, password: _passC.text);
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
        address: _addrC.text, username: _userC.text, password: _passC.text);
      final id = await ServerManager.I.uploadShare();
      if (!mounted) return;
      setState(() => _busy = false);
      _showShareDialog(id);
    } catch (e) {
      setState(() => _busy = false);
      _toast('上传失败：$e');
    }
  }

  void _showShareDialog(String id) {
    final url = 'https://jsonblob.com/api/jsonBlob/$id';
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF17171B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('分享 ID 已生成', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('把下面这串 ID 发给对方，对方在「导入」里粘贴即可读取你的配置。',
          style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.6)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: SelectableText(id,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13,
              color: Color(0xFF9C8FD0), letterSpacing: 1))),
        const SizedBox(height: 10),
        Text(url, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
      ]),
      actions: [
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: id));
          Navigator.pop(context); _toast('已复制 ID');
        }, child: const Text('复制 ID')),
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: url));
          Navigator.pop(context); _toast('已复制链接');
        }, child: const Text('复制链接')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
      ]));
  }

  Future<void> _import() async {
    final id = _importC.text.trim();
    if (id.isEmpty) { _toast('请输入分享 ID'); return; }
    setState(() => _busy = true);
    try {
      await ServerManager.I.importShare(id);
      if (!mounted) return;
      _addrC.text = ServerManager.I.address;
      _userC.text = ServerManager.I.username;
      _passC.text = ServerManager.I.password;
      setState(() => _busy = false);
      _toast('导入成功');
    } catch (e) {
      setState(() => _busy = false);
      _toast('导入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ServerManager>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('服务器')),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), children: [
        _label('连接信息'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(16), child: Column(children: [
          _field('后端地址', _addrC, hint: 'http://192.168.1.100:3000'),
          const SizedBox(height: 12),
          _field('用户名', _userC, hint: 'your-username'),
          const SizedBox(height: 12),
          _field('密码', _passC, hint: '••••••', obscure: true),
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
                : const Text('上传共享'))),
          ]),
        ])),
        const SizedBox(height: 20),
        _label('导入别人的服务器'),
        GlassCard(radius: 14, padding: const EdgeInsets.all(16), child: Column(children: [
          _field('分享 ID', _importC, hint: '例如 1234567890123456789'),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppTheme.p),
            onPressed: _busy ? null : _import,
            child: const Text('导入'))),
        ])),
        const SizedBox(height: 20),
        if (m.shareId.isNotEmpty) ...[
          _label('我的分享 ID'),
          GlassCard(radius: 14, padding: const EdgeInsets.all(14), child: Row(children: [
            const Icon(Icons.link, size: 18, color: Color(0xFF9C8FD0)),
            const SizedBox(width: 10),
            Expanded(child: SelectableText(m.shareId,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5,
                color: Color(0xFF9C8FD0), letterSpacing: 0.5))),
            IconButton(icon: const Icon(Icons.copy, size: 18), splashRadius: 18,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: m.shareId));
                _toast('已复制');
              }),
          ])),
          const SizedBox(height: 20),
        ],
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(
          '说明：填写后端地址、用户名、密码后点击「保存到本地」，凭据会保存到 '
          '/storage/emulated/0/Music/KuGou/server.json，下次启动自动读取。'
          '点击「上传共享」把这份配置匿名上传到公开 JSON 存储（jsonblob.com），'
          '系统返回分享 ID。把 ID 告诉别人，别人在下方「导入」粘贴即可读到你的配置。'
          '如果你更愿意自己部署 KuGouMusicApi，也可以用「设置 - 后端脚本」生成启动脚本，'
          '在 Termux 里运行，只在本机使用。',
          style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.5), height: 1.8))),
        const SizedBox(height: 32),
      ]));
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
    child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
      letterSpacing: 1.2, color: Colors.white.withOpacity(0.5))));

  Widget _field(String label, TextEditingController c, {String? hint, bool obscure = false}) {
    return TextField(
      controller: c, obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55)),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3)),
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
