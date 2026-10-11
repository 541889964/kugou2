import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../kugou.dart';
import '../net_music.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../announcement.dart';
import '../icon_picker.dart';
import '../source_manager.dart';
import 'player_page.dart';
import 'playlist_page.dart';
import 'discover_page.dart';
import 'local_music_page.dart';
import 'settings.dart';
import 'search_page.dart';
import 'recognize_page.dart';
import 'theme.dart';
import 'glass.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _R();
}

class _R extends State<RootPage> {
  int _t = 0;
  late final PageController _pc;
  static const _pages = <Widget>[
    HomePage(), DiscoverPage(), LocalMusicPage(), PlaylistPage(), SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showAd());
  }

  Future<void> _showAd() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final agreed = await showAnnouncement(context);
    if (!agreed) {
      SystemNavigator.pop();
      await Future.delayed(const Duration(milliseconds: 180));
      exit(0);
    }
  }

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasSong = context.select<PlayerService, bool>((p) => p.current != null);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _t = i),
        children: _pages,
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (hasSong) const _Mini(),
        _navBar(),
      ]),
    );
  }

  Widget _navBar() {
    const items = [
      (Icons.home_outlined, Icons.home, '首页'),
      (Icons.explore_outlined, Icons.explore, '发现'),
      (Icons.folder_outlined, Icons.folder, '本地'),
      (Icons.favorite_border, Icons.favorite, '收藏'),
      (Icons.person_outline, Icons.person, '我的'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        heavy: true,
        child: Row(children: List.generate(items.length, (i) {
          final active = i == _t;
          final it = items[i];
          return Expanded(child: Material(color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (i == _t) return;
                setState(() => _t = i);
                _pc.animateToPage(i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? AppTheme.grad : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: active ? [BoxShadow(
                    color: AppTheme.p.withOpacity(0.5),
                    blurRadius: 14, spreadRadius: -4,
                    offset: const Offset(0, 4))] : null),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(active ? it.$2 : it.$1, size: 21,
                    color: active ? Colors.white : Colors.white.withOpacity(0.55)),
                  const SizedBox(height: 2),
                  Text(it.$3, style: TextStyle(fontSize: 9.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? Colors.white : Colors.white.withOpacity(0.55))),
                ])))));
        }))));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HPState();
}

class _HPState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  List<Map<String, dynamic>> _rec = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await NetMusic.dailyRecommend();
      if (mounted) setState(() {
        _rec = r.take(20).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: TextStyle(fontSize: 13,
                color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              const Text('发现音乐', style: TextStyle(fontSize: 26,
                fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1)),
            ])),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              splashRadius: 20,
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage()))),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassCard(radius: 22, padding: EdgeInsets.zero, heavy: true,
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(Icons.search, size: 19, color: Colors.white.withOpacity(0.55)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('搜索歌曲、歌手或专辑',
                    style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.4)))),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RecognizePage())),
                    child: Icon(Icons.mic_none, size: 20,
                      color: Colors.white.withOpacity(0.7))),
                ]))))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _quick(Icons.auto_awesome, '每日推荐', AppTheme.p, AppTheme.accent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverPage()))),
            _quick(Icons.graphic_eq, '听歌识曲', AppTheme.s, const Color(0xFF0EA5E9),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecognizePage()))),
            _quick(Icons.favorite, '我的收藏', AppTheme.accent, const Color(0xFFF97316),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistPage()))),
            _quick(Icons.folder_special, '本地音乐', const Color(0xFF10B981), AppTheme.s,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalMusicPage()))),
          ])),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(children: [
            Container(width: 3, height: 16, decoration: BoxDecoration(
              color: AppTheme.p, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('为你推荐', style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const Spacer(),
            GestureDetector(
              onTap: _load,
              child: Text('换一批', style: TextStyle(fontSize: 11.5,
                color: AppTheme.p, fontWeight: FontWeight.w700))),
          ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list()),
      ])),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  Widget _quick(IconData i, String label, Color c1, Color c2, VoidCallback onTap) {
    return Expanded(child: InkWell(borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          IconTile(icon: i, c1: c1, c2: c2, size: 52),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: Colors.white)),
        ]))));
  }

  Widget _list() {
    if (_rec.isEmpty) return Center(child: Text('暂无推荐',
      style: TextStyle(color: Colors.white.withOpacity(0.5))));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _rec.length,
      itemExtent: 66,
      cacheExtent: 400,
      itemBuilder: (_, i) => RepaintBoundary(child: _row(_rec[i], i)));
  }

  Widget _row(Map<String, dynamic> m, int i) {
    final name = (m['name'] ?? '').toString();
    final artist = (m['artist'] ?? '').toString();
    final hash = 'rec_${name}_$artist';
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      radius: 14,
      onTap: () => _play(name, artist),
      child: Row(children: [
        SizedBox(width: 30, child: Text('${i + 1}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: i < 3 ? AppTheme.accent : Colors.white.withOpacity(0.4)))),
        const SizedBox(width: 6),
        SizedBox(width: 44, height: 44, child: ClipRRect(
          borderRadius: BorderRadius.circular(9), child: _cover(hash))),
        const SizedBox(width: 12),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
        ])),
        Icon(Icons.play_circle_outline, size: 22,
          color: Colors.white.withOpacity(0.5)),
      ]));
  }

  Widget _cover(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return Container(decoration: const BoxDecoration(
      gradient: AppTheme.discGrad),
      child: const Icon(Icons.music_note, color: Colors.white70, size: 20));
    return Image.asset(p, fit: BoxFit.cover, filterQuality: FilterQuality.low,
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
        const SnackBar(content: Text('未找到匹配歌曲')));
      return;
    }
    if (!mounted) return;
    PlayerService.I.playSong(r.first, list: r);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
  }
}

class _Mini extends StatelessWidget {
  const _Mini();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    final s = p.current;
    if (s == null) return const SizedBox.shrink();
    final dur = p.duration?.inMilliseconds ?? 0;
    final cur = p.position.inMilliseconds.clamp(0, dur > 0 ? dur : 1);
    final prog = dur > 0 ? cur / dur : 0.0;
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
    return Container(margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: GlassCard(radius: 20, padding: EdgeInsets.zero, heavy: true, onTap: open,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 58, child: Row(children: [
            const SizedBox(width: 10),
            SizedBox(width: 42, height: 42,
              child: ClipRRect(borderRadius: BorderRadius.circular(11),
                child: _icon(s.hash))),
            const SizedBox(width: 12),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.55))),
            ])),
            if (p.loading)
              const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)))
            else IconButton(onPressed: p.toggle, iconSize: 28, splashRadius: 22,
              icon: Icon(p.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white)),
            IconButton(onPressed: p.next, iconSize: 26, splashRadius: 22,
              icon: const Icon(Icons.skip_next, color: Colors.white)),
            const SizedBox(width: 4),
          ])),
          ClipRRect(borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            child: LinearProgressIndicator(value: prog, minHeight: 2.5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(AppTheme.p))),
        ])));
  }
  Widget _icon(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return const Icon(Icons.music_note, color: Colors.white70);
    return Image.asset(p, fit: BoxFit.cover, filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white70));
  }
}
