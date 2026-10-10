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
  final _hpKey = GlobalKey<_HPState>();
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
      try {
        if (!mounted) break;
        await precacheImage(AssetImage(p), context);
      } catch (_) {}
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
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        heavy: true,
        child: Row(
          children: List.generate(items.length, (i) {
            final active = i == _t;
            final it = items[i];
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
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
                      boxShadow: active ? [
                        BoxShadow(color: AppTheme.p.withOpacity(0.5),
                          blurRadius: 14, spreadRadius: -4,
                          offset: const Offset(0, 4))
                      ] : null),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(active ? it.$2 : it.$1, size: 21,
                        color: active ? Colors.white : Colors.white.withOpacity(0.55)),
                      const SizedBox(height: 2),
                      Text(it.$3, style: TextStyle(fontSize: 9.5,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? Colors.white : Colors.white.withOpacity(0.55))),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
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

  final _c = TextEditingController();
  List<Song> _results = [];
  bool _searching = false;
  String _kw = '';

  bool _homeLoading = true;
  List<Map<String, dynamic>> _recommend = [];
  List<Map<String, dynamic>> _rank = [];
  int _bannerIndex = 0;

  @override
  void initState() { super.initState(); _loadHome(); }

  Future<void> _loadHome() async {
    setState(() => _homeLoading = true);
    final r = await NetMusic.dailyRecommend();
    final rank = await NetMusic.rankSongs(3778678, limit: 20);
    if (!mounted) return;
    setState(() {
      _recommend = r.take(20).toList();
      _rank = rank.take(20).toList();
      _homeLoading = false;
    });
  }

  Future<void> _loadMore() async {
    final r = await NetMusic.dailyRecommend();
    if (!mounted) return;
    setState(() => _recommend = r.take(40).toList());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已加载更多推荐')));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Future<void> _search() async {
    final kw = _c.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    final src = SourceManager.I.search;
    setState(() { _searching = true; _kw = kw; });
    final r = await KuGouApi.I.search(kw, source: src.name);
    if (!mounted) return;
    setState(() { _results = r; _searching = false; });
    if (r.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200),
        () => Downloader.I.scanDownloaded(r));
    } else if (KuGouApi.I.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KuGouApi.I.lastError!)));
    }
  }

  void _clearSearch() {
    setState(() { _results = []; _kw = ''; _c.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        if (_kw.isEmpty) _topTabs() else _searchHeader(),
        if (_kw.isEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: _searchBar()),
        Expanded(child: _body()),
      ])),
    );
  }

  // 顶部：发现 / 免费听 / 乐库（仿酷狗）
  Widget _topTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(children: [
        const Text('发现', style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(width: 22),
        Text('免费听', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.45))),
        const SizedBox(width: 18),
        Text('乐库', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.45))),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.search, size: 22, color: Colors.white),
          splashRadius: 20,
          onPressed: () => FocusScope.of(context).requestFocus(FocusNode())),
        IconButton(
          icon: const Icon(Icons.history, size: 22, color: Colors.white),
          splashRadius: 20,
          onPressed: () {}),
      ]));
  }

  // 搜索状态下的顶栏
  Widget _searchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          splashRadius: 20,
          onPressed: _clearSearch),
        const Text('搜索结果', style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('共 ${_results.length} 首', style: TextStyle(
          fontSize: 12, color: AppTheme.p, fontWeight: FontWeight.w700)),
      ]));
  }

  Widget _searchBar() {
    return GlassCard(
      radius: 22, padding: EdgeInsets.zero, heavy: true,
      child: TextField(
        controller: _c,
        onSubmitted: (_) => _search(),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5, color: Colors.white),
        decoration: InputDecoration(
          hintText: '曲风盲盒 · 随机心动',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 6, right: 2),
            child: Icon(Icons.search, size: 19, color: Colors.white.withOpacity(0.55))),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_c.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.close, size: 17), splashRadius: 16,
                onPressed: () => setState(() => _c.clear())),
            IconButton(icon: const Icon(Icons.mic_none, size: 19), splashRadius: 16,
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecognizePage()))),
          ]),
          border: InputBorder.none, fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 13)),
        onChanged: (_) => setState(() {})));
  }

  Widget _body() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_kw.isNotEmpty) {
      if (_results.isEmpty) return _empty('没有找到结果\n换个关键词试试');
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _results.length,
        itemExtent: 66,
        itemBuilder: (_, i) => RepaintBoundary(child: _songRow(_results[i])));
    }
    return RefreshIndicator(
      onRefresh: _loadHome, color: AppTheme.p, backgroundColor: AppTheme.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _bigBanner(),
          const SizedBox(height: 18),
          _sectionTitle('概念 er 新推', more: _loadMore),
          _songList(_recommend.take(3).toList(), '新推'),
          const SizedBox(height: 18),
          _sectionTitle('小众宝藏佳作'),
          _bigCoverCard(),
          const SizedBox(height: 18),
          _sectionTitle('热歌榜', more: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DiscoverPage()))),
          _songList(_rank.take(4).toList(), '榜单'),
          const SizedBox(height: 18),
          _sectionTitle('频道推荐'),
          _channelGrid(),
          const SizedBox(height: 20),
        ],
      ));
  }

  // 大横幅：图片 + 右侧文字列表（仿酷狗）
  Widget _bigBanner() {
    if (_recommend.isEmpty) return const SizedBox(height: 200);
    final top3 = _recommend.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppTheme.p.withOpacity(0.22), AppTheme.s.withOpacity(0.14)]),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.20),
            blurRadius: 24, spreadRadius: -6)]),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // 左侧封面
          AspectRatio(aspectRatio: 1, child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _cover('banner_${top3[0]['name']}'))),
          const SizedBox(width: 14),
          // 右侧列表
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('小语种', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900)),
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: top3.map((m) {
                  return Text((m['name'] ?? '').toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, height: 1.4));
                }).toList())),
              Row(children: [
                Expanded(child: Text('耳朵环球旅行，这些神曲绝了',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5,
                    color: Colors.white.withOpacity(0.55)))),
                Container(width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.s.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.play_arrow, size: 15, color: Colors.white)),
              ]),
            ])),
        ])));
  }

  // 大封面卡片（左图右字）
  Widget _bigCoverCard() {
    final m = _recommend.isNotEmpty ? _recommend.first : null;
    if (m == null) return const SizedBox(height: 180);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2A1F3A).withOpacity(0.7),
          border: Border.all(color: Colors.white.withOpacity(0.10))),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          AspectRatio(aspectRatio: 0.78, child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _cover('big_${m['name']}'))),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('MUSIC\nSTORY001',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                  color: Color(0xFFD4C57A), height: 1.1, letterSpacing: -0.5)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('角色替换', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text((m['artist'] ?? '').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12,
                    color: Color(0xFFB8A8FF), fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('《${m['name']}》',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5,
                    color: Colors.white.withOpacity(0.5))),
              ]),
            ])),
        ])));
  }

  Widget _sectionTitle(String t, {VoidCallback? more}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
    child: Row(children: [
      Text(t, style: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      const Spacer(),
      if (more != null)
        IconButton(icon: const Icon(Icons.chevron_right, size: 22),
          splashRadius: 18, onPressed: more),
    ]));

  Widget _songList(List<Map<String, dynamic>> list, String tag) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(children: list.map((m) {
      final name = (m['name'] ?? '').toString();
      final artist = (m['artist'] ?? '').toString();
      final hash = '${tag}_${name}_$artist';
      return RepaintBoundary(child: GlassCard(
        margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        radius: 14,
        onTap: () => _playRecommend(name, artist),
        child: Row(children: [
          SizedBox(width: 46, height: 46, child: ClipRRect(
            borderRadius: BorderRadius.circular(10), child: _cover(hash))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11,
                color: Colors.white.withOpacity(0.55))),
          ])),
          Icon(Icons.favorite_border, size: 19,
            color: Colors.white.withOpacity(0.5)),
        ])));
    }).toList());
  }

  // 频道推荐：2 列网格
  Widget _channelGrid() {
    final items = [
      ('南部档案 · 影视剧', '5581 订阅', 'ch1', const Color(0xFF7C4A3A)),
      ('术力口 · 什么都可以发', '1721 订阅', 'ch2', const Color(0xFF9B2C5C)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: items.map((it) {
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: it.$3 == 'ch1' ? 8 : 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 0.85, child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [it.$4, it.$4.withOpacity(0.4)]),
                border: Border.all(color: Colors.white.withOpacity(0.10))),
              child: Stack(children: [
                const Positioned(top: 10, left: 12,
                  child: Text('CHANNEL·K', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1))),
                Positioned(bottom: 10, left: 12, right: 12, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(it.$2, style: TextStyle(fontSize: 10,
                    color: Colors.white.withOpacity(0.65))),
                ])),
              ]))),
            const SizedBox(height: 6),
            Text('喜欢盐焗虾就好', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.5))),
          ])));
      }).toList()));
  }

  Future<void> _playRecommend(String name, String artist) async {
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

  Widget _empty(String t) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: AppTheme.grad.withOpacity(0.3),
        boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.4), blurRadius: 40)]),
      child: Icon(Icons.search_off, size: 52, color: Colors.white.withOpacity(0.9))),
    const SizedBox(height: 20),
    Text(t, textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.6), height: 1.6)),
  ]));

  Widget _songRow(Song s) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: 14,
      onTap: () {
        PlayerService.I.playSong(s, list: _results);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
      },
      child: Row(children: [
        SizedBox(width: 46, height: 46, child: ClipRRect(
          borderRadius: BorderRadius.circular(10), child: _cover(s.hash))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(s.name, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5,
                fontWeight: FontWeight.w600))),
            Padding(padding: const EdgeInsets.only(left: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: s.source == 'netease'
                    ? AppTheme.accent.withOpacity(0.20)
                    : AppTheme.p.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(3)),
                child: Text(s.source == 'netease' ? '网易' : '酷狗',
                  style: TextStyle(fontSize: 8.5,
                    color: s.source == 'netease' ? AppTheme.accent : AppTheme.p,
                    fontWeight: FontWeight.w800)))),
          ]),
          const SizedBox(height: 3),
          Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11,
              color: Colors.white.withOpacity(0.55))),
        ])),
        _dlBtn(s), _favBtn(s),
      ]));
  }

  Widget _dlBtn(Song s) => Consumer<Downloader>(builder: (_, dl, __) {
    final t = dl.tasks[s.hash];
    if (t != null) {
      if (t.status == 'done') return const Padding(padding: EdgeInsets.all(8),
        child: Icon(Icons.check_circle, color: AppTheme.s, size: 19));
      if (t.status == 'failed') return IconButton(
        icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 18),
        splashRadius: 18, onPressed: () => dl.download(s));
      return Padding(padding: const EdgeInsets.all(10),
        child: SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(
            value: t.progress > 0 ? t.progress : null, strokeWidth: 2)));
    }
    return IconButton(
      icon: Icon(Icons.download_outlined,
        color: Colors.white.withOpacity(0.6), size: 18),
      splashRadius: 18, onPressed: () => dl.download(s));
  });

  Widget _favBtn(Song s) => Consumer<PlaylistService>(builder: (_, pl, __) {
    final fav = pl.contains(s);
    return IconButton(
      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
        color: fav ? AppTheme.accent : Colors.white54, size: 18),
      splashRadius: 18, onPressed: () => pl.toggle(s));
  });

  Widget _cover(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
      child: const Icon(Icons.music_note, color: Colors.white70, size: 22));
    return Image.asset(p, fit: BoxFit.cover, filterQuality: FilterQuality.low,
      gaplessPlayback: true,
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
    void open() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const PlayerPage()));
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: GlassCard(
        radius: 20, padding: EdgeInsets.zero, heavy: true, onTap: open,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 58, child: Row(children: [
            const SizedBox(width: 10),
            GestureDetector(onTap: open, child: SizedBox(width: 42, height: 42,
              child: ClipRRect(borderRadius: BorderRadius.circular(11),
                child: _icon(s.hash)))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: open,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700)),
                Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5,
                    color: Colors.white.withOpacity(0.55))),
              ]))),
            if (p.loading)
              const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)))
            else IconButton(
              onPressed: p.toggle, iconSize: 28, splashRadius: 22,
              icon: Icon(
                p.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white)),
            IconButton(
              onPressed: p.next, iconSize: 26, splashRadius: 22,
              icon: const Icon(Icons.skip_next, color: Colors.white)),
            const SizedBox(width: 4),
          ])),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20)),
            child: LinearProgressIndicator(
              value: prog, minHeight: 2.5,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(AppTheme.p))),
        ])));
  }
  Widget _icon(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return const Icon(Icons.music_note, color: Colors.white70);
    return Image.asset(p, fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white70));
  }
}
