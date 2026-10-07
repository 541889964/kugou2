import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../local_music.dart';
import '../player.dart';
import '../playlist.dart';
import '../icon_picker.dart';
import 'player_page.dart';
import 'theme.dart';
import 'glass.dart';

class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({super.key});
  @override
  State<LocalMusicPage> createState() => _LMP();
}
class _LMP extends State<LocalMusicPage> {
  final _filterCtrl = TextEditingController();
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final sc = context.watch<LocalMusicScanner>();
    final filtered = _filter.isEmpty
      ? sc.songs
      : sc.songs.where((s) =>
          s.name.toLowerCase().contains(_filter.toLowerCase()) ||
          s.singer.toLowerCase().contains(_filter.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('本地音乐 (${sc.songs.length})'),
        actions: [
          IconButton(
            icon: sc.scanning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
            onPressed: sc.scanning ? null : () => sc.scan()),
        ]),
      body: Column(children: [
        if (sc.status.isNotEmpty)
          Container(width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black.withOpacity(0.25),
            child: Text(sc.status, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: GlassCard(radius: 28, padding: EdgeInsets.zero,
            child: TextField(
              controller: _filterCtrl,
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                hintText: '筛选本地音乐…',
                prefixIcon: const Icon(Icons.filter_list, size: 20),
                suffixIcon: _filter.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 18),
                      onPressed: () { _filterCtrl.clear(); setState(() => _filter = ''); })
                  : null,
                border: InputBorder.none,
                fillColor: Colors.transparent)))),
        Expanded(child: _buildBody(sc, filtered)),
      ]),
    );
  }
  Widget _buildBody(LocalMusicScanner sc, List filtered) {
    if (sc.scanning && sc.songs.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(sc.status, style: TextStyle(color: Colors.white.withOpacity(0.7))),
      ]));
    }
    if (sc.songs.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open, size: 80, color: Colors.white.withOpacity(0.25)),
          const SizedBox(height: 20),
          Text('还没有扫描本地音乐', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15)),
          const SizedBox(height: 8),
          Text('点击右上角 ↻ 开始扫描', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: () => sc.scan(), icon: const Icon(Icons.search), label: const Text('扫描音乐')),
        ])));
    }
    if (filtered.isEmpty) return Center(child: Text('没有匹配的歌曲',
      style: TextStyle(color: Colors.white.withOpacity(0.6))));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _tile(filtered[i], i, sc));
  }
  Widget _tile(dynamic s, int i, LocalMusicScanner sc) {
    final iconPath = IconPicker.forHash(s.hash);
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: () {
        final list = sc.songs;
        PlayerService.I.playFromList(s, list, i: i);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
      },
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: iconPath.isEmpty
              ? Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
                  child: const Icon(Icons.music_note, color: Colors.white, size: 24))
              : Image.asset(iconPath, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(gradient: AppTheme.discGrad),
                    child: const Icon(Icons.music_note, color: Colors.white, size: 24))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 2),
          Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
        ])),
        Consumer<PlaylistService>(builder: (_, pl, __) {
          final fav = pl.contains(s);
          return IconButton(
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? Colors.redAccent : Colors.white54, size: 20),
            onPressed: () => pl.toggle(s));
        }),
        IconButton(icon: Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.5), size: 20),
          onPressed: () => _confirmDelete(sc, s)),
      ]),
    );
  }
  void _confirmDelete(LocalMusicScanner sc, dynamic s) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('删除文件？'),
      content: Text('${s.name}\n${s.localPath}', style: const TextStyle(fontSize: 12)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            Navigator.pop(context);
            final ok = await sc.deleteFile(s.localPath);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ok ? '已删除' : '删除失败')));
          },
          child: const Text('删除')),
      ]));
  }
}
