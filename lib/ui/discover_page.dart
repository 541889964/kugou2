import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../net_music.dart';
import '../kugou.dart';
import '../player.dart';
import '../source_manager.dart';
import 'player_page.dart';
import 'theme.dart';
import 'glass.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _D();
}
class _D extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _tab = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _daily = [];
  final Map<String, List<Map<String, dynamic>>> _ranks = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _daily = await NetMusic.dailyRecommend();
    for (final e in NetMusic.rankIds.entries) {
      final l = await NetMusic.rankSongs(e.value, limit: 40);
      _ranks[e.key] = l;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sm = context.watch<SourceManager>();
    final tabs = ['每日推荐', ...NetMusic.rankIds.keys];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('发现')),
      body: Column(children: [
        // 顶部来源提示条
        Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsPage())),
            child: GlassCard(radius: 10, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), heavy: true,
              child: Row(children: [
                Icon(sm.discover == MusicSource.concept ? Icons.diamond : Icons.cloud_queue,
                  size: 13,
                  color: sm.discover == MusicSource.concept ? AppTheme.p : const Color(0xFFFF9090)),
                const SizedBox(width: 6),
                Text('榜单来源：${sm.discoverLabel}',
                  style: TextStyle(fontSize: 11,
                    color: sm.discover == MusicSource.concept ? AppTheme.p : const Color(0xFFFF9090),
                    fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('去设置切换', style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.45))),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 13, color: Colors.white.withOpacity(0.45)),
              ])))),
        const SizedBox(height: 6),
        SizedBox(height: 40, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: tabs.length,
          itemBuilder: (_, i) {
            final active = i == _tab;
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: active ? AppTheme.p.withOpacity(0.20) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: active ? AppTheme.p.withOpacity(0.5) : Colors.white.withOpacity(0.10))),
                  padding: const EdgeInsets.symmetric(horizontal: 14), minimumSize: Size.zero),
                onPressed: () => setState(() => _tab = i),
                child: Text(tabs[i], style: TextStyle(fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white70))));
          })),
        const SizedBox(height: 6),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list()),
      ]),
    );
  }

  List<Map<String, dynamic>> get _current {
    if (_tab == 0) return _daily;
    return _ranks[NetMusic.rankIds.keys.elementAt(_tab - 1)] ?? [];
  }

  Widget _list() {
    final list = _current;
    if (list.isEmpty) return Center(child: Text('暂无数据',
      style: TextStyle(color: Colors.white.withOpacity(0.5))));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: list.length, itemExtent: 68,
      itemBuilder: (_, i) => RepaintBoundary(child: _item(list[i], i)));
  }

  Widget _item(Map<String, dynamic> m, int i) {
    final name = (m['name'] ?? '').toString();
    final artist = (m['artist'] ?? '').toString();
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 14,
      onTap: () => _play(name, artist),
      child: Row(children: [
        SizedBox(width: 28, child: Text('${i + 1}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: i < 3 ? const Color(0xFFFF6B6B) : Colors.white.withOpacity(0.5)))),
        const SizedBox(width: 12),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 2),
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.6))),
        ])),
        Icon(Icons.play_circle_outline, size: 22, color: Colors.white.withOpacity(0.5)),
      ]));
  }

  Future<void> _play(String name, String artist) async {
    if (name.isEmpty) return;
    final kw = artist.isEmpty ? name : '$name $artist';
    final r = await KuGouApi.I.searchConcept(kw, pagesize: 5);
    if (r.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到同名歌曲')));
      return;
    }
    if (!mounted) return;
    final src = SourceManager.I.discover;
    final list = r.map((x) => Song(hash: x.hash, name: x.name, singer: x.singer,
      album: x.album, albumId: x.albumId, duration: x.duration, cover: x.cover,
      audioId: x.audioId, source: src == MusicSource.netease ? 'netease' : 'concept')).toList();
    PlayerService.I.playSong(list.first, list: list);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
  }
}
