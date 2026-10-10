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
class _LMP extends State<LocalMusicPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _fc = TextEditingController();
  String _f = '';
  @override
  void dispose() { _fc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sc = context.watch<LocalMusicScanner>();
    final list = _f.isEmpty ? sc.songs : sc.songs.where((s) =>
      s.name.toLowerCase().contains(_f.toLowerCase()) ||
      s.singer.toLowerCase().contains(_f.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('本地音乐', style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text('共 ${sc.songs.length} 首', style: TextStyle(fontSize: 11,
                color: Colors.white.withOpacity(0.5))),
            ]),
            const Spacer(),
            IconButton(
              icon: sc.scanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
              onPressed: sc.scanning ? null : () => sc.scan()),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: GlassCard(radius: 18, padding: EdgeInsets.zero, heavy: true,
            child: TextField(controller: _fc, onChanged: (v) => setState(() => _f = v),
              decoration: InputDecoration(
                hintText: '筛选本地音乐…',
                prefixIcon: const Icon(Icons.filter_list, size: 20),
                suffixIcon: _f.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18),
                  onPressed: () { _fc.clear(); setState(() => _f = ''); }) : null,
                border: InputBorder.none, fillColor: Colors.transparent)))),
        if (sc.status.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(alignment: Alignment.centerLeft,
              child: Text(sc.status, style: TextStyle(fontSize: 11.5,
                color: Colors.white.withOpacity(0.55))))),
        Expanded(child: _body(sc, list)),
      ])),
    );
  }

  Widget _body(LocalMusicScanner sc, List list) {
    if (sc.scanning && sc.songs.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(), const SizedBox(height: 16),
      Text(sc.status, style: TextStyle(color: Colors.white.withOpacity(0.7)))]));
    if (sc.songs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: AppTheme.grad.withOpacity(0.3),
          boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.4), blurRadius: 40)]),
        child: Icon(Icons.folder_open, size: 52, color: Colors.white.withOpacity(0.9))),
      const SizedBox(height: 22),
      const Text('还没有扫描本地音乐', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('点击右上角 ↻ 开始扫描', style: TextStyle(fontSize: 12,
        color: Colors.white.withOpacity(0.5))),
      const SizedBox(height: 22),
      FilledButton.icon(onPressed: () => sc.scan(),
        icon: const Icon(Icons.search), label: const Text('扫描音乐')),
    ])));
    if (list.isEmpty) return Center(child: Text('没有匹配的歌曲',
      style: TextStyle(color: Colors.white.withOpacity(0.5))));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: list.length,
      itemBuilder: (_, i) => RepaintBoundary(child: _tile(list[i], i, sc)));
  }

  Widget _tile(dynamic s, int i, LocalMusicScanner sc) {
    final ip = IconPicker.forHash(s.hash);
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 16,
      onTap: () {
        PlayerService.I.playFromList(s, sc.songs, i: i);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
      },
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35),
              blurRadius: 10, offset: const Offset(0, 4))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: ip.isEmpty ? Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
              child: const Icon(Icons.music_note, color: Colors.white, size: 24))
              : Image.asset(ip, fit: BoxFit.cover, filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(gradient: AppTheme.discGrad),
                  child: const Icon(Icons.music_note, color: Colors.white, size: 24))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
        ])),
        Consumer<PlaylistService>(builder: (_, pl, __) {
          final fav = pl.contains(s);
          return IconButton(icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
            color: fav ? AppTheme.accent : Colors.white54, size: 19),
            splashRadius: 18, onPressed: () => pl.toggle(s));
        }),
        IconButton(icon: Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.5), size: 19),
          splashRadius: 18, onPressed: () => _del(sc, s)),
      ]));
  }

  void _del(LocalMusicScanner sc, dynamic s) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('删除文件？'),
      content: Text('${s.name}\n${s.localPath}', style: const TextStyle(fontSize: 12)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            Navigator.pop(context);
            final ok = await sc.deleteFile(s.localPath);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ok ? '已删除' : '删除失败')));
          }, child: const Text('删除'))]));
  }
}
