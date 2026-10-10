import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../net_music.dart';
import '../kugou.dart';
import '../player.dart';
import '../source_manager.dart';
import '../icon_picker.dart';
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
    final tabs = ['每日推荐', ...NetMusic.rankIds.keys];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        _topBar(),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: tabs.length,
            itemBuilder: (_, i) {
              final active = i == _tab;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: active ? AppTheme.grad : null,
                      color: active ? null : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.10))),
                    child: Center(
                      child: Text(tabs[i],
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                          color: active ? Colors.white : Colors.white.withOpacity(0.7)))),
                  ),
                ),
              );
            })),
        const SizedBox(height: 10),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list()),
      ])),
    );
  }

  Widget _topBar() {
    final sm = context.watch<SourceManager>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(children: [
        const Text('发现', style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsPage())),
          child: GlassCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            heavy: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                sm.discover == MusicSource.concept ? Icons.diamond : Icons.cloud,
                size: 12,
                color: sm.discover == MusicSource.concept ? AppTheme.p : AppTheme.accent),
              const SizedBox(width: 5),
              Text(sm.discoverLabel, style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700,
                color: sm.discover == MusicSource.concept ? AppTheme.p : AppTheme.accent)),
            ]))),
      ]));
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
      itemExtent: 62,
      itemBuilder: (_, i) => RepaintBoundary(child: _rankRow(list[i], i)));
  }

  Widget _rankRow(Map<String, dynamic> m, int i) {
    final name = (m['name'] ?? '').toString();
    final artist = (m['artist'] ?? '').toString();
    final hash = 'rank_${name}_$artist';
    Color rankColor;
    if (i == 0) rankColor = AppTheme.accent;
    else if (i == 1) rankColor = AppTheme.p;
    else if (i == 2) rankColor = AppTheme.s;
    else rankColor = Colors.white.withOpacity(0.4);

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      radius: 14,
      onTap: () => _play(name, artist),
      child: Row(children: [
        SizedBox(width: 30, child: Text('${i + 1}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: rankColor))),
        const SizedBox(width: 6),
        SizedBox(width: 42, height: 42, child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _cover(hash))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11,
              color: Colors.white.withOpacity(0.55))),
        ])),
        Icon(Icons.play_circle_outline, size: 22,
          color: Colors.white.withOpacity(0.5)),
      ]));
  }

  Widget _cover(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
      child: const Icon(Icons.music_note, color: Colors.white70, size: 20));
    return Image.asset(p, fit: BoxFit.cover, filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, color: Colors.white70, size: 20)));
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
    final list = r.map((x) => Song(
      hash: x.hash, name: x.name, singer: x.singer,
      album: x.album, albumId: x.albumId, duration: x.duration,
      cover: x.cover, audioId: x.audioId,
      source: src == MusicSource.netease ? 'netease' : 'concept')).toList();
    PlayerService.I.playSong(list.first, list: list);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
  }
}
