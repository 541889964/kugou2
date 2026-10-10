import 'dart:io';
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
import 'terminal_page.dart';
import 'wallpaper_page.dart';
import 'downloads_page.dart';
import '../wallpaper_manager.dart';
import 'theme.dart';
import 'glass.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SP();
}
class _SP extends State<SettingsPage> {
  bool _importing = false;
  bool _liteOn = false, _checking = false;
  String _verifyMsg = '';

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    final s = await BackendManager.startScriptExists();
    final l = await BackendManager.isLiteOnline();
    if (!mounted) return;
    setState(() { _hasStart = s; _liteOn = l; });
  }

  Future<void> _pickFile() async {
    setState(() => _importing = true);
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null || r.files.isEmpty || r.files.single.path == null) {
        setState(() => _importing = false); return;
      }
      final m = HarParser.parse(await File(r.files.single.path!).readAsString());
      if (m.isEmpty || !HarParser.isValid(m)) {
        setState(() => _importing = false);
        _toast(m.isEmpty ? '未找到 Cookie 字段' : '字段不完整'); return;
      }
      await SignatureManager.I.updateUser(m);
      setState(() => _importing = false);
      _toast('✓ 导入成功');
    } catch (e) { setState(() => _importing = false); _toast('失败: $e'); }
  }


  void _verify() {
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
              subtitle: const Text('从 Reqable 导出', style: TextStyle(fontSize: 11.5)),
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

          _label('后端与下载'),
          _card([
            ListTile(
              leading: const IconTile(icon: Icons.terminal,
                c1: AppTheme.p, c2: AppTheme.s),
              title: const Text('启动后端终端', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('联网下载 · 解压 · 启动（实时显示）', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await Navigator.push<bool>(context,
                  MaterialPageRoute(builder: (_) => const TerminalPage()));
                if (!mounted) return;
                if (ok == true) _toast('后端已就绪');
                await _refresh();
              }),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.dns_outlined,
                c1: AppTheme.p, c2: const Color(0xFF0EA5E9)),
              title: const Text('服务器共享', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('本地/远程 · 生成分享 ID', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ServerPage()))),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.terminal,
                c1: const Color(0xFFF59E0B), c2: AppTheme.accent),
              title: const Text('生成后端脚本', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(_hasStart ? '已生成 · 点击重生成' : '生成到 Download',
                style: const TextStyle(fontSize: 11.5)),
              trailing: _generating ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _generating ? null : _generate),
            const Divider(height: 1),
            ListTile(
              leading: const IconTile(icon: Icons.download_outlined,
                c1: const Color(0xFF10B981), c2: AppTheme.s),
              title: const Text('下载管理', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('查看下载进度和文件', style: TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DownloadsPage()))),
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

  Widget _card(List<Widget> ch) => GlassCard(radius: 20, padding: EdgeInsets.zero, heavy: true,
    child: Column(children: ch));
}
