import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../net_music.dart';
import '../kugou.dart';
import '../player.dart';
import '../source_manager.dart';
import 'player_page.dart';
import 'settings.dart';
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
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            const Text('发现', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
              child: GlassCard(radius: 20, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), heavy: true,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(sm.discover == MusicSource.concept ? Icons.diamond : Icons.cloud,
                    size: 12,
                    color: sm.discover == MusicSource.concept ? AppTheme.p : AppTheme.accent),
                  const SizedBox(width: 5),
                  Text(sm.discoverLabel, style: TextStyle(fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: sm.discover == MusicSource.concept ? AppTheme.p : AppTheme.accent)),
                ]))),
          ])),
        SizedBox(height: 42, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tabs.length,
          itemBuilder: (_, i) {
            final active = i == _tab;
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(duration: const Duration(milliseconds: 240),
                decoration: BoxDecoration(
                  gradient: active ? AppTheme.grad : null,
                  color: active ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active
                    ? Colors.transparent : Colors.white.withOpacity(0.10))),
                child: Material(color: Colors.transparent, child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _tab = i),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Center(child: Text(tabs[i], style: TextStyle(fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : Colors.white.withOpacity(0.7))))))));
          })),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list()),
      ])),
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: list.length,
      itemBuilder: (_, i) => RepaintBoundary(child: _item(list[i], i)));
  }

  Widget _item(Map<String, dynamic> m, int i) {
    final name = (m['name'] ?? '').toString();
    final artist = (m['artist'] ?? '').toString();
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: 16,
      onTap: () => _play(name, artist),
      child: Row(children: [
        SizedBox(width: 32, child: Text('${i + 1}',
          style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w900,
            color: i == 0 ? AppTheme.accent
              : i == 1 ? AppTheme.p
              : i == 2 ? AppTheme.s
              : Colors.white.withOpacity(0.4)))),
        const SizedBox(width: 10),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
        ])),
        Container(width: 32, height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08)),
          child: Icon(Icons.play_arrow, size: 18, color: Colors.white.withOpacity(0.8))),
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
