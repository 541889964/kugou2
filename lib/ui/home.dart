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
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    for (final p in IconPicker.all) {
      try { if (!mounted) break; await precacheImage(AssetImage(p), context); } catch (_) {}
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 100));
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
        radius: 24, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), heavy: true,
        child: Row(children: List.generate(items.length, (i) {
          final active = i == _t;
          final it = items[i];
          return Expanded(child: Material(color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (i == _t) return;
                setState(() => _t = i);
                _pc.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? AppTheme.grad : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: active ? [BoxShadow(color: AppTheme.p.withOpacity(0.5),
                    blurRadius: 14, spreadRadius: -4, offset: const Offset(0, 4))] : null),
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

  bool _homeLoading = true;
  List<Map<String, dynamic>> _recommend = [];
  List<Map<String, dynamic>> _rank = [];

  @override
  void initState() { super.initState(); _loadHome(); }

  Future<void> _loadHome() async {
    setState(() => _homeLoading = true);
    final r = await NetMusic.dailyRecommend();
    final rank = await NetMusic.rankSongs(3778678, limit: 20);
    if (!mounted) return;
    setState(() {
      _recommend = r.take(30).toList();
      _rank = rank.take(20).toList();
      _homeLoading = false;
    });
  }

  Future<void> _loadMore() async {
    final r = await NetMusic.dailyRecommend();
    if (!mounted) return;
    setState(() => _recommend = r.take(60).toList());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加载更多')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sm = context.watch<SourceManager>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
          child: Row(children: [
            const Text('发现', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const SizedBox(width: 20),
            Text('免费听', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.45))),
            const SizedBox(width: 16),
            Text('乐库', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.45))),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchPage())),
              child: GlassCard(radius: 20, padding: const EdgeInsets.all(10), heavy: true,
                child: const Icon(Icons.search, size: 20, color: Colors.white))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecognizePage())),
              child: GlassCard(radius: 20, padding: const EdgeInsets.all(10), heavy: true,
                child: const Icon(Icons.mic_none, size: 20, color: Colors.white))),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.p.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6)),
              child: Text('来源 ${sm.searchLabel}', style: TextStyle(fontSize: 10,
                color: AppTheme.p, fontWeight: FontWeight.w700))),
          ])),
        Expanded(child: RefreshIndicator(
          onRefresh: _loadHome, color: AppTheme.p, backgroundColor: AppTheme.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _bigBanner(),
              const SizedBox(height: 18),
              _sectionTitle('概念 er 新推', more: _loadMore),
              _songList(_recommend.take(3).toList(), 'new'),
              const SizedBox(height: 18),
              _sectionTitle('小众宝藏佳作'),
              _bigCoverCard(),
              const SizedBox(height: 18),
              _sectionTitle('热歌榜'),
              _songList(_rank.take(5).toList(), 'rank'),
              const SizedBox(height: 18),
              _sectionTitle('频道推荐'),
              _channelGrid(),
              const SizedBox(height: 20),
            ]))),
      ])),
    );
  }

  Widget _bigBanner() {
    if (_recommend.isEmpty) return const SizedBox(height: 220);
    final top3 = _recommend.take(3).toList();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppTheme.p.withOpacity(0.22), AppTheme.s.withOpacity(0.14)]),
          border: Border.all(color: Colors.white.withOpacity(0.10))),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          AspectRatio(aspectRatio: 1, child: ClipRRect(
            borderRadius: BorderRadius.circular(14), child: _cover('b_${top3[0]['name']}'))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('小语种', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: top3.map((m) => Text((m['name'] ?? '').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))).toList())),
            Row(children: [
              Expanded(child: Text('耳朵环球旅行，这些神曲绝了', maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.55)))),
              Container(width: 26, height: 26,
                decoration: BoxDecoration(color: AppTheme.s.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.play_arrow, size: 15, color: Colors.white)),
            ]),
          ])),
        ])));
  }

  Widget _bigCoverCard() {
    if (_recommend.isEmpty) return const SizedBox(height: 180);
    final m = _recommend.first;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2A1F3A).withOpacity(0.7),
          border: Border.all(color: Colors.white.withOpacity(0.10))),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          AspectRatio(aspectRatio: 0.78, child: ClipRRect(
            borderRadius: BorderRadius.circular(14), child: _cover('big_${m['name']}'))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('MUSIC\nSTORY001', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, color: Color(0xFFD4C57A), height: 1.1)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('角色替换', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text((m['artist'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB8A8FF), fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('《${m['name']}》', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.5))),
            ]),
          ])),
        ])));
  }

  Widget _sectionTitle(String t, {VoidCallback? more}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
    child: Row(children: [
      Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      const Spacer(),
      if (more != null) IconButton(icon: const Icon(Icons.chevron_right, size: 22),
        splashRadius: 18, onPressed: more),
    ]));

  Widget _songList(List<Map<String, dynamic>> list, String tag) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(children: list.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      final name = (m['name'] ?? '').toString();
      final artist = (m['artist'] ?? '').toString();
      final hash = '${tag}_${name}_$artist';
      return FadeInItem(index: i, child: RepaintBoundary(child: GlassCard(
        margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), radius: 14,
        onTap: () => _playRec(name, artist),
        child: Row(children: [
          SizedBox(width: 46, height: 46, child: ClipRRect(
            borderRadius: BorderRadius.circular(10), child: _cover(hash))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
          ])),
        ]))));
    }).toList());
  }

  Widget _channelGrid() {
    final items = [
      ('南部档案 · 影视剧', '5581 订阅', true),
      ('术力口 · 什么都可以发', '1721 订阅', false),
    ];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: items.map((it) {
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: it.$3 ? 8 : 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 0.85, child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: it.$3 ? [const Color(0xFF7C4A3A), const Color(0xFF7C4A3A).withOpacity(0.4)]
                                : [const Color(0xFF9B2C5C), const Color(0xFF9B2C5C).withOpacity(0.4)]),
                border: Border.all(color: Colors.white.withOpacity(0.10))),
              child: Stack(children: [
                const Positioned(top: 10, left: 12,
                  child: Text('CHANNEL·K', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1))),
                Positioned(bottom: 10, left: 12, right: 12,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(it.$2, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.65))),
                  ])),
              ]))),
            const SizedBox(height: 6),
            Text('喜欢盐焗虾就好', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.5))),
          ])));
      }).toList()));
  }

  Future<void> _playRec(String name, String artist) async {
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

  Widget _cover(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
      child: const Icon(Icons.music_note, color: Colors.white70, size: 22));
    return Image.asset(p, fit: BoxFit.cover, filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, color: Colors.white70, size: 22)));
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
            GestureDetector(onTap: open, child: SizedBox(width: 42, height: 42,
              child: ClipRRect(borderRadius: BorderRadius.circular(11), child: _icon(s.hash)))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: open,
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.55))),
              ]))),
            if (p.loading)
              const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
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
