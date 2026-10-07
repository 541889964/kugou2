import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../backend_manager.dart';
import '../har_parser.dart';
import '../local_music.dart';
import '../mode_manager.dart';
import '../signature_manager.dart';
import '../updater.dart';
import 'server_page.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SP();
}
class _SP extends State<SettingsPage> {
  bool _importing = false, _generating = false, _hasStart = false;
  bool _liteOn = false, _stdOn = false, _checking = false, _uploading = false;
  String? _githubUrl;
  String _verifyMsg = '';
  @override
  void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    final s = await BackendManager.startScriptExists();
    final l = await BackendManager.isLiteOnline();
    final st = await BackendManager.isStandardOnline();
    final g = await BackendManager.getGithubUrl();
    if (!mounted) return;
    setState(() { _hasStart = s; _liteOn = l; _stdOn = st; _githubUrl = g; });
  }
  Future<void> _refreshOnline() async {
    setState(() => _checking = true);
    final l = await BackendManager.isLiteOnline();
    final st = await BackendManager.isStandardOnline();
    if (!mounted) return;
    setState(() { _liteOn = l; _stdOn = st; _checking = false; });
    _toast('概念:${l ? "✓" : "✗"}  普通:${st ? "✓" : "✗"}');
  }
  Future<void> _pickFile() async {
    setState(() => _importing = true);
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (r == null || r.files.isEmpty || r.files.single.path == null) {
        setState(() => _importing = false); return;
      }
      await _parseFile(r.files.single.path!);
    } catch (e) { setState(() => _importing = false); _toast('失败: $e'); }
  }
  Future<void> _manualPath() async {
    final c = TextEditingController();
    final p = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('输入 HAR 路径'),
      content: TextField(controller: c, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: const InputDecoration(hintText: '/storage/emulated/0/Download/xxx.har')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('确定')),
      ]));
    if (p == null || p.isEmpty) return;
    setState(() => _importing = true);
    await _parseFile(p);
  }
  Future<void> _parseFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) { setState(() => _importing = false); _toast('文件不存在'); return; }
      final m = HarParser.parse(await f.readAsString());
      if (m.isEmpty || !HarParser.isValid(m)) {
        setState(() => _importing = false);
        _showResult(path, m, m.isEmpty ? '未找到 Cookie 字段' : '字段不完整');
        return;
      }
      await SignatureManager.I.updateUser(m);
      setState(() => _importing = false);
      _showResult(path, m, '✓ 导入成功');
    } catch (e) { setState(() => _importing = false); _toast('解析失败: $e'); }
  }
  void _showResult(String path, Map<String, String> m, String s) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(s.startsWith('✓') ? Icons.check_circle : Icons.warning_amber,
          color: s.startsWith('✓') ? Colors.greenAccent : Colors.orangeAccent),
        const SizedBox(width: 10),
        Flexible(child: Text(s, style: const TextStyle(fontSize: 15)))],
      ),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('文件:', style: TextStyle(fontSize: 12)),
        SelectableText(path, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white.withOpacity(0.6))),
        const SizedBox(height: 12),
        const Text('提取结果:', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Container(width: double.maxFinite, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(HarParser.describe(m), style: const TextStyle(fontFamily: 'monospace',
            fontSize: 11, color: Colors.greenAccent, height: 1.6))),
      ])),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))]));
  }
  Future<void> _generate() async {
    setState(() => _generating = true);
    final (ok, msg) = await BackendManager.generateScripts();
    if (!mounted) return;
    setState(() { _generating = false; _hasStart = ok; });
    if (ok) _showScriptDialog();
    else _toast(msg);
  }
  void _showScriptDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.check_circle, color: Colors.greenAccent),
        SizedBox(width: 10), Text('脚本已生成'),
      ]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Termux 启动:', style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(BackendManager.startCmd, style: const TextStyle(fontFamily: 'monospace',
            fontSize: 11, color: Colors.greenAccent))),
        const SizedBox(height: 14),
        const Text('Termux 停止:', style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(BackendManager.stopCmd, style: const TextStyle(fontFamily: 'monospace',
            fontSize: 11, color: Colors.amber))),
      ])),
      actions: [
        TextButton(onPressed: () {
          Clipboard.setData(ClipboardData(text: '${BackendManager.startCmd}\n${BackendManager.stopCmd}'));
          Navigator.pop(context); _toast('已复制');
        }, child: const Text('复制全部')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
      ]));
  }
  Future<void> _upload() async {
    final tokenC = TextEditingController();
    final repoC = TextEditingController();
    final pathC = TextEditingController(text: 'kugou-backend-start.sh');
    final go = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('上传脚本到 GitHub'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: tokenC, obscureText: true,
          decoration: const InputDecoration(labelText: 'GitHub Token')),
        const SizedBox(height: 8),
        TextField(controller: repoC,
          decoration: const InputDecoration(labelText: '仓库', hintText: 'username/my-repo')),
        const SizedBox(height: 8),
        TextField(controller: pathC, decoration: const InputDecoration(labelText: '文件路径')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('上传')),
      ]));
    if (go != true) return;
    final parts = repoC.text.trim().split('/');
    if (parts.length != 2 || tokenC.text.trim().isEmpty) { _toast('参数不完整'); return; }
    setState(() => _uploading = true);
    final (ok, msg) = await BackendManager.uploadToGithub(
      owner: parts[0], repo: parts[1], token: tokenC.text.trim(), path: pathC.text.trim());
    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) {
      setState(() => _githubUrl = msg);
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cloud_done, color: Colors.greenAccent),
          SizedBox(width: 10), Text('上传成功'),
        ]),
        content: SelectableText(msg, style: const TextStyle(fontFamily: 'monospace',
          fontSize: 11, color: Colors.greenAccent)),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))]));
    } else { _toast('✗ $msg'); }
  }
  Future<void> _verify() async {
    final u = SignatureManager.I.config?['user'] as Map?;
    final t = (u?['token'] ?? '').toString();
    setState(() => _verifyMsg = t.length >= 20 ? '✓ 已导入' : '✗ 未导入');
  }
  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3)));
  }
  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<ModeManager>();
    final up = context.watch<Updater>();
    final u = SignatureManager.I.config?['user'] as Map?;
    final hasToken = ((u?['token'] ?? '') as String).isNotEmpty;
    return Scaffold(appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), children: [
        _s('账号'),
        _c([
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: (hasToken ? Colors.green : Colors.orange).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
              child: Icon(hasToken ? Icons.person : Icons.person_outline,
                color: hasToken ? Colors.green : Colors.orange, size: 22)),
            title: Text(hasToken ? 'userid: ${u?['userid']}' : '未导入账号',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(hasToken ? 'token: ${(u?['token'] as String).substring(0, 12)}…'
              : '点下面导入 HAR', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            trailing: IconButton(icon: const Icon(Icons.verified_user), onPressed: _verify)),
          if (_verifyMsg.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(_verifyMsg, style: TextStyle(fontSize: 12,
              color: _verifyMsg.startsWith('✓') ? Colors.greenAccent : Colors.redAccent))),
          const Divider(height: 1),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: AppTheme.p.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: _importing ? const Padding(padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined, color: AppTheme.p, size: 22)),
            title: const Text('导入 HAR 文件', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('从 Reqable 导出', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importing ? null : _pickFile),
          const Divider(height: 1),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.keyboard, color: Colors.blueGrey, size: 22)),
            title: const Text('手动输入路径', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('备用', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importing ? null : _manualPath),
        ]),
        const SizedBox(height: 22),
        _s('服务器共享'),
        _c([
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: const Color(0xFF7C6CB0).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.dns_outlined, color: Color(0xFF9C8FD0), size: 22)),
            title: const Text('服务器配置与共享', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('用户名/密码本地保存 · 生成分享 ID 给他人导入',
              style: TextStyle(fontSize: 11.5)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ServerPage()))),
        ]),
        const SizedBox(height: 22),
        _s('后端状态'),
        _c([
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: (_liteOn ? Colors.green : Colors.orange).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.diamond_outlined, color: _liteOn ? Colors.green : Colors.orange, size: 22)),
            title: const Text('概念版 :3000', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_liteOn ? '在线' : '未启动', style: const TextStyle(fontSize: 12)),
            trailing: _checking ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshOnline)),
          const Divider(height: 1),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: (_stdOn ? Colors.green : Colors.orange).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.music_note_outlined,
                color: _stdOn ? Colors.green : Colors.orange, size: 22)),
            title: const Text('普通版 :3001', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_stdOn ? '在线' : '未启动', style: const TextStyle(fontSize: 12))),
        ]),
        const SizedBox(height: 22),
        _s('后端脚本'),
        _c([
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: _generating ? const Padding(padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.terminal, color: Colors.amber, size: 22)),
            title: const Text('生成启动/停止脚本', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_hasStart ? '已生成 · 点此重生成' : '生成到 Download',
              style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _generating ? null : _generate),
          if (_hasStart) ...[
            const Divider(height: 1),
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: _uploading ? const Padding(padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file, color: Colors.purpleAccent, size: 22)),
              title: const Text('上传脚本到 GitHub', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('成功后显示 Git 后端入口', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _uploading ? null : _upload),
          ],
        ]),
        if (_githubUrl != null) ...[
          const SizedBox(height: 22),
          _s('Git 后端'),
          _c([
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cloud, color: Colors.purpleAccent, size: 22)),
              title: const Text('远程脚本（已上传）', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_githubUrl!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              trailing: IconButton(icon: const Icon(Icons.copy, size: 18),
                onPressed: () { Clipboard.setData(ClipboardData(text: _githubUrl!)); _toast('已复制'); })),
          ]),
        ],
        const SizedBox(height: 22),
        _s('本地音乐'),
        _c([
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: AppTheme.s.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.folder_outlined, color: AppTheme.s, size: 22)),
            title: const Text('扫描本地音乐', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(LocalMusicScanner.I.scanning
              ? '扫描中…' : '共 ${LocalMusicScanner.I.songs.length} 首',
              style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LocalMusicScanner.I.scan()),
        ]),
        const SizedBox(height: 22),
        _s('播放模式'),
        _c([
          SwitchListTile(
            secondary: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: (mgr.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
              child: Icon(mgr.isLite ? Icons.diamond_outlined : Icons.music_note_outlined,
                color: mgr.isLite ? AppTheme.p : AppTheme.s, size: 22)),
            title: Text(mgr.isLite ? '概念版（VIP）' : '普通版（免费）',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('端口 ${mgr.port}', style: const TextStyle(fontSize: 12)),
            value: mgr.isLite, onChanged: (v) => mgr.switchMode(v)),
        ]),
        const SizedBox(height: 22),
        _s('签名配置'),
        _c([
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: AppTheme.p.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.description_outlined, color: AppTheme.p, size: 22)),
            title: Text('当前 v${SignatureManager.I.version}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('来源: ${SignatureManager.I.source}', style: const TextStyle(fontSize: 12))),
          const Divider(height: 1),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: up.checking ? const Padding(padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_download_outlined, color: Colors.green, size: 22)),
            title: const Text('检查云端更新', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(up.status.isEmpty ? '点击检查' : up.status, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: up.checking ? null : () => Updater.I.check()),
        ]),
        const SizedBox(height: 32),
        Center(child: Text('⚠️ 仅供个人学习研究',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11))),
        const SizedBox(height: 24),
      ]));
  }
  Widget _s(String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
      letterSpacing: 1.2, color: Colors.white.withOpacity(0.5))));
  Widget _c(List<Widget> ch) => Container(
    decoration: BoxDecoration(color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Column(children: ch)));
}
