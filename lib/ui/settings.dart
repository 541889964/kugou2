import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../backend_manager.dart';
import '../har_parser.dart';
import '../local_music.dart';
import '../mode_manager.dart';
import '../search_settings.dart';
import '../signature_manager.dart';
import '../source_manager.dart';
import '../updater.dart';
import 'server_page.dart';
import 'wallpaper_page.dart';
import '../wallpaper_manager.dart';
import 'theme.dart';
import 'glass.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SP();
}
class _SP extends State<SettingsPage> {
  bool _importing = false, _generating = false, _hasStart = false;
  bool _liteOn = false, _stdOn = false, _checking = false;
  String? _githubUrl;
  String _verifyMsg = '';

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    final s = await BackendManager.startScriptExists();
    final l = await BackendManager.isLiteOnline();
    final g = await BackendManager.getGithubUrl();
    if (!mounted) return;
    setState(() { _hasStart = s; _liteOn = l; _stdOn = l; _githubUrl = g; });
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

  Future<void> _parseFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) { setState(() => _importing = false); _toast('文件不存在'); return; }
      final m = HarParser.parse(await f.readAsString());
      if (m.isEmpty || !HarParser.isValid(m)) {
        setState(() => _importing = false);
        _toast(m.isEmpty ? '未找到 Cookie 字段' : '字段不完整'); return;
      }
      await SignatureManager.I.updateUser(m);
      setState(() => _importing = false);
      _toast('✓ 导入成功');
    } catch (e) { setState(() => _importing = false); _toast('解析失败: $e'); }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final (ok, msg) = await BackendManager.generateScripts();
    if (!mounted) return;
    setState(() { _generating = false; _hasStart = ok; });
    if (ok) {
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('脚本已生成'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('在 Termux 里运行：', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8)),
            child: SelectableText(BackendManager.startCmd,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.s))),
        ]),
        actions: [
          TextButton(onPressed: () {
            Clipboard.setData(ClipboardData(text: BackendManager.startCmd));
            Navigator.pop(context);
            _toast('已复制');
          }, child: const Text('复制')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('好'))]));
    } else { _toast(msg); }
  }

  Future<void> _verify() async {
    final u = SignatureManager.I.config?['user'] as Map?;
    final t = (u?['token'] ?? '').toString();
    setState(() => _verifyMsg = t.length >= 20 ? '✓ 已导入' : '✗ 未导入');
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s),
      behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final up = context.watch<Updater>();
    final srcMgr = context.watch<SourceManager>();
    final ss = context.watch<SearchSettings>();
    final u = SignatureManager.I.config?['user'] as Map?;
    final hasToken = ((u?['token'] ?? '') as String).isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text('设置', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, letterSpacing: -0.4))),

          _label('账户'),
          _card([
            ListTile(
              leading: IconTile(
                icon: hasToken ? Icons.person : Icons.person_outline,
                c1: hasToken ? AppTheme.s : AppTheme.accent,
                c2: hasToken ? const Color(0xFF0EA5E9) : const Color(0xFFF97316)),
              title: Text(hasToken ? 'userid: ${u?['userid']}' : '未导入账号',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(hasToken
                ? 'token: ${(u?['token'] as String).substring(0, 12)}…'
                : '点下面导入 HAR', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              trailing: IconButton(icon: const Icon(Icons.verified_user, size: 20), onPressed: _verify)),
            if (_verifyMsg.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(_verifyMsg, style: TextStyle(fontSize: 11.5,
                color: _verifyMsg.startsWith('✓') ? AppTheme.s : Colors.redAccent))),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.file_upload_outlined,
                c1: AppTheme.p, c2: AppTheme.accent),
              title: const Text('导入 HAR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('从 Reqable 导出', style: const TextStyle(fontSize: 11.5)),
              trailing: _importing ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _importing ? null : _pickFile),
          ]),
          const SizedBox(height: 20),

          _label('内容来源'),
          _card([
            SwitchListTile(
              secondary: const IconTile(icon: Icons.search, c1: AppTheme.p, c2: AppTheme.accent),
              title: const Text('搜索来源', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(srcMgr.searchLabel, style: const TextStyle(fontSize: 11.5)),
              value: srcMgr.search == MusicSource.netease,
              activeColor: AppTheme.p,
              onChanged: (v) => srcMgr.setSearch(v ? MusicSource.netease : MusicSource.concept)),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const IconTile(icon: Icons.explore_outlined,
                c1: AppTheme.s, c2: const Color(0xFF0EA5E9)),
              title: const Text('榜单来源', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(srcMgr.discoverLabel, style: const TextStyle(fontSize: 11.5)),
              value: srcMgr.discover == MusicSource.concept,
              activeColor: AppTheme.p,
              onChanged: (v) => srcMgr.setDiscover(v ? MusicSource.concept : MusicSource.netease)),
          ]),
          const SizedBox(height: 20),

          _label('外观'),
          _card([
            ListTile(
              leading: const IconTile(icon: Icons.wallpaper_outlined,
                c1: AppTheme.accent, c2: const Color(0xFFF97316)),
              title: const Text('壁纸', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('共 ${WallpaperManager.count} 张 · 第 ${WallpaperManager.I.index + 1} 张',
                style: const TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WallpaperPage()))),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Text('每次搜索数量', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.p.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('${ss.pageSize} 首', style: TextStyle(fontSize: 11.5,
                    color: AppTheme.p, fontWeight: FontWeight.w700))),
              ])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Slider(value: ss.pageSize.toDouble(), min: 10, max: 100, divisions: 18,
                label: '${ss.pageSize}',
                onChanged: (v) => SearchSettings.I.setPageSize(v.toInt()))),
          ]),
          const SizedBox(height: 20),

          _label('后端'),
          _card([
            ListTile(
              leading: const IconTile(icon: Icons.dns_outlined,
                c1: AppTheme.p, c2: const Color(0xFF0EA5E9)),
              title: const Text('服务器共享', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('用户名/密码本地保存 · 生成分享 ID', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ServerPage()))),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.terminal,
                c1: const Color(0xFFF59E0B), c2: AppTheme.accent),
              title: const Text('生成后端脚本', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(_hasStart ? '已生成 · 点击重生成' : '生成到 Download · Termux 部署',
                style: const TextStyle(fontSize: 11.5)),
              trailing: _generating ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _generating ? null : _generate),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.diamond_outlined,
                c1: AppTheme.s, c2: const Color(0xFF10B981)),
              title: const Text('概念版 :3000', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(_liteOn ? '在线' : '未启动', style: const TextStyle(fontSize: 11.5)),
              trailing: _checking ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () async {
                      setState(() => _checking = true);
                      final l = await BackendManager.isLiteOnline();
                      setState(() { _liteOn = l; _checking = false; });
                    })),
          ]),
          const SizedBox(height: 20),

          _label('其他'),
          _card([
            ListTile(
              leading: const IconTile(icon: Icons.folder_outlined,
                c1: const Color(0xFF10B981), c2: AppTheme.s),
              title: const Text('扫描本地音乐', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(LocalMusicScanner.I.scanning ? '扫描中…'
                : '共 ${LocalMusicScanner.I.songs.length} 首', style: const TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => LocalMusicScanner.I.scan()),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.cloud_download_outlined,
                c1: AppTheme.p, c2: AppTheme.s),
              title: const Text('检查云端更新', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(up.status.isEmpty ? '点击检查' : up.status,
                style: const TextStyle(fontSize: 11.5)),
              trailing: up.checking ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
              onTap: up.checking ? null : () => Updater.I.check()),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.description_outlined,
                c1: AppTheme.s, c2: const Color(0xFF0EA5E9)),
              title: Text('签名版本 v${SignatureManager.I.version}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('来源: ${SignatureManager.I.source}', style: const TextStyle(fontSize: 11.5)),
            ),
          ]),
          const SizedBox(height: 32),
          Center(child: Text('⚠️ 仅供个人学习研究',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11))),
          const SizedBox(height: 16),
        ],
      )),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
      letterSpacing: 1.5, color: Colors.white.withOpacity(0.5))));

  Widget _card(List<Widget> ch) => GlassCard(
    radius: 20, padding: EdgeInsets.zero, heavy: true,
    child: Column(children: ch));
}
