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
import '../wallpaper_manager.dart';
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
      try { if (!mounted) break; await precacheImage(AssetImage(p), context); } catch (_) {}
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 120));
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

  bool _canPop() => _t == 0 ? (_hpKey.currentState?.canPopFromBack() ?? true) : false;

  @override
  Widget build(BuildContext context) {
    final hasSong = context.select<PlayerService, bool>((p) => p.current != null);
    return PopScope(
      canPop: _canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_t != 0) {
          setState(() => _t = 0);
          _pc.animateToPage(0, duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic);
          return;
        }
        _hpKey.currentState?.handleBack();
      },
      child: Scaffold(
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
      ),
    );
  }

  Widget _navBar() {
    final items = const [
      (Icons.search_outlined, Icons.search, '搜索'),
      (Icons.explore_outlined, Icons.explore, '发现'),
      (Icons.folder_outlined, Icons.folder, '本地'),
      (Icons.favorite_border, Icons.favorite, '收藏'),
      (Icons.settings_outlined, Icons.settings, '设置'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: GlassCard(
        radius: 24, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), heavy: true,
        child: Row(children: List.generate(items.length, (i) {
          final active = i == _t;
          final it = items[i];
          return Expanded(child: Material(color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (i == _t) return;
                setState(() => _t = i);
                _pc.animateToPage(i, duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: active ? AppTheme.grad : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: active ? [BoxShadow(color: AppTheme.p.withOpacity(0.45),
                    blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 4))] : null),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(active ? it.$2 : it.$1, size: 22,
                    color: active ? Colors.white : Colors.white.withOpacity(0.55)),
                  const SizedBox(height: 3),
                  Text(it.$3, style: TextStyle(fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : Colors.white.withOpacity(0.55))),
                ]))))));})));
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

  // 首页推荐数据
  bool _homeLoading = true;
  List<Map<String, dynamic>> _recommend = [];

  @override
  void initState() { super.initState(); _loadHome(); }

  Future<void> _loadHome() async {
    final r = await NetMusic.dailyRecommend();
    if (!mounted) return;
    setState(() { _recommend = r.take(12).toList(); _homeLoading = false; });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  bool canPopFromBack() => _c.text.isEmpty && _kw.isEmpty && _results.isEmpty;

  void handleBack() {
    if (_results.isNotEmpty || _kw.isNotEmpty) {
      setState(() { _results = []; _kw = ''; });
      return;
    }
    if (_c.text.isNotEmpty) { setState(() => _c.clear()); return; }
    SystemNavigator.pop();
  }

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
      Future.delayed(const Duration(milliseconds: 200), () => Downloader.I.scanDownloaded(r));
    } else if (KuGouApi.I.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(KuGouApi.I.lastError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        _header(),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: _searchBar()),
        Expanded(child: _body()),
      ])),
    );
  }

  // 顶部问候 + 来源小标
  Widget _header() {
    final sm = context.watch<SourceManager>();
    final h = DateTime.now().hour;
    final hi = h < 6 ? '晚安' : h < 12 ? '早上好' : h < 18 ? '下午好' : '晚上好';
    return Padding(padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hi, style: TextStyle(fontSize: 13,
            color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          const Text('发现音乐', style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.w900, letterSpacing: -0.4, height: 1.1)),
        ])),
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsPage())),
          child: GlassCard(radius: 20, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), heavy: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(sm.search == MusicSource.concept ? Icons.diamond : Icons.cloud,
                size: 12, color: sm.search == MusicSource.concept ? AppTheme.p : AppTheme.accent),
              const SizedBox(width: 5),
              Text(sm.searchLabel, style: TextStyle(fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: sm.search == MusicSource.concept ? AppTheme.p : AppTheme.accent)),
            ]))),
      ]));
  }

  Widget _searchBar() {
    return GlassCard(
      radius: 18, padding: EdgeInsets.zero, heavy: true,
      child: TextField(
        controller: _c, onSubmitted: (_) => _search(),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: '搜索歌曲、歌手或专辑',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 13.5),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 6, right: 4),
            child: Icon(Icons.search, size: 20, color: Colors.white.withOpacity(0.55))),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_c.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.close, size: 18), splashRadius: 16,
                onPressed: () => setState(() => _c.clear())),
            IconButton(icon: const Icon(Icons.mic_none, size: 20), splashRadius: 16,
              tooltip: '听歌识曲',
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecognizePage()))),
          ]),
          border: InputBorder.none, fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 15)),
        onChanged: (_) => setState(() {})));
  }

  Widget _body() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_kw.isNotEmpty) {
      if (_results.isEmpty) return _empty('没有找到结果\n换个关键词试试');
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _results.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.p.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('共 ${_results.length} 首', style: TextStyle(fontSize: 11,
                  color: AppTheme.p, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Text('「$_kw」', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45)))),
            ]));
          return RepaintBoundary(child: _card(_results[i - 1], i - 1));
        });
    }
    // 首页
    return RefreshIndicator(
      onRefresh: _loadHome,
      color: AppTheme.p, backgroundColor: AppTheme.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        children: [
          _quickActions(),
          const SizedBox(height: 18),
          _section('为你推荐', '基于你的口味'),
          if (_homeLoading) Padding(padding: const EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: AppTheme.p)))
          else SizedBox(height: 190, child: _recommendRow()),
          const SizedBox(height: 22),
          _section('最近在听', null),
          _emptyRecent(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = [
      (Icons.auto_awesome, '每日推荐', AppTheme.p, AppTheme.accent, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoverPage()));
      }),
      (Icons.graphic_eq, '听歌识曲', AppTheme.s, const Color(0xFF0EA5E9), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecognizePage()));
      }),
      (Icons.favorite, '我的收藏', AppTheme.accent, const Color(0xFFF97316), () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistPage()));
      }),
      (Icons.folder_special, '本地音乐', const Color(0xFF10B981), AppTheme.s, () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalMusicPage()));
      }),
    ];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(crossAxisCount: 4, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.9,
        children: actions.map((a) {
          return InkWell(borderRadius: BorderRadius.circular(16), onTap: a.$5,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconTile(icon: a.$1, c1: a.$3, c2: a.$4, size: 50),
              const SizedBox(height: 8),
              Text(a.$2, style: const TextStyle(fontSize: 11.5,
                fontWeight: FontWeight.w600, color: Colors.white)),
            ]));
        }).toList()));
  }

  Widget _section(String title, String? sub) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(title, style: const TextStyle(fontSize: 18,
        fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      const Spacer(),
      if (sub != null) Text(sub, style: TextStyle(fontSize: 11,
        color: Colors.white.withOpacity(0.4))),
    ]));

  Widget _recommendRow() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recommend.length,
      itemBuilder: (_, i) {
        final m = _recommend[i];
        final name = (m['name'] ?? '').toString();
        final artist = (m['artist'] ?? '').toString();
        final hash = '${name}_$artist';
        return Padding(padding: const EdgeInsets.only(right: 12),
          child: SizedBox(width: 140, child: GestureDetector(
            onTap: () => _playRecommend(name, artist),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 140, height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5),
                    blurRadius: 16, offset: const Offset(0, 8))]),
                child: ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: _cover(hash))),
              const SizedBox(height: 10),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
            ]))));
      });
  }

  Widget _emptyRecent() => Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GlassCard(radius: 16, padding: const EdgeInsets.all(20), heavy: true,
      child: Row(children: [
        IconTile(icon: Icons.history, c1: AppTheme.p, c2: AppTheme.s, size: 44),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('还没有播放记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('去「发现」找首好听的歌吧', style: TextStyle(fontSize: 11.5,
            color: Colors.white.withOpacity(0.5))),
        ])),
      ])));

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

  Widget _empty(String t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: AppTheme.grad.withOpacity(0.3),
          boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.4), blurRadius: 40)]),
        child: Icon(Icons.search_off, size: 52, color: Colors.white.withOpacity(0.9))),
      const SizedBox(height: 20),
      Text(t, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.6), height: 1.6)),
    ]));

  Widget _card(Song s, int i) => GlassCard(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), radius: 16,
    onTap: () {
      PlayerService.I.playSong(s, list: _results);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
    },
    child: Row(children: [
      SizedBox(width: 48, height: 48, child: ClipRRect(
        borderRadius: BorderRadius.circular(12), child: _cover(s.hash))),
      const SizedBox(width: 12),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Padding(padding: const EdgeInsets.only(left: 6),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: s.source == 'netease'
                  ? AppTheme.accent.withOpacity(0.20)
                  : AppTheme.p.withOpacity(0.20),
                borderRadius: BorderRadius.circular(4)),
              child: Text(s.source == 'netease' ? '网易' : '概念',
                style: TextStyle(fontSize: 9,
                  color: s.source == 'netease' ? AppTheme.accent : AppTheme.p,
                  fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 3),
        Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
      ])),
      _dlBtn(s), _favBtn(s),
    ]));

  Widget _dlBtn(Song s) => Consumer<Downloader>(builder: (_, dl, __) {
    final t = dl.tasks[s.hash];
    if (t != null) {
      if (t.status == 'done') return const Padding(padding: EdgeInsets.all(8),
        child: Icon(Icons.check_circle, color: AppTheme.s, size: 20));
      if (t.status == 'failed') return IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 19),
        splashRadius: 18, onPressed: () => dl.download(s));
      return Padding(padding: const EdgeInsets.all(10),
        child: SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(value: t.progress > 0 ? t.progress : null, strokeWidth: 2)));
    }
    return IconButton(icon: Icon(Icons.download_outlined, color: Colors.white.withOpacity(0.6), size: 19),
      splashRadius: 18, onPressed: () => dl.download(s));
  });

  Widget _favBtn(Song s) => Consumer<PlaylistService>(builder: (_, pl, __) {
    final fav = pl.contains(s);
    return IconButton(
      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
        color: fav ? AppTheme.accent : Colors.white54, size: 19),
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
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
    return Container(margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: GlassCard(radius: 20, padding: EdgeInsets.zero, heavy: true, onTap: open,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 60, child: Row(children: [
            const SizedBox(width: 10),
            GestureDetector(onTap: open, child: SizedBox(width: 44, height: 44,
              child: ClipRRect(borderRadius: BorderRadius.circular(11), child: _icon(s.hash)))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: open,
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
              ]))),
            if (p.loading) const Padding(padding: EdgeInsets.all(12),
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
