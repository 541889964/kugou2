import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../kugou.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../mode_manager.dart';
import '../icon_picker.dart';
import 'player_page.dart';
import 'playlist_page.dart';
import 'downloads_page.dart';
import 'local_music_page.dart';
import 'settings.dart';
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
  static const List<Widget> _pages = [
    HomePage(),
    LocalMusicPage(),
    PlaylistPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: 0);
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
        physics: const NeverScrollableScrollPhysics(),
        allowImplicitScrolling: true,
        children: _pages,
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (hasSong) const _Mini(),
        NavigationBar(
          backgroundColor: const Color(0xE61A1726),
          elevation: 0,
          height: 64,
          selectedIndex: _t,
          onDestinationSelected: (i) {
            if (i == _t) return;
            setState(() => _t = i);
            _pc.jumpToPage(i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search_outlined, size: 22), selectedIcon: Icon(Icons.search, size: 22), label: '搜索'),
            NavigationDestination(icon: Icon(Icons.folder_outlined, size: 22), selectedIcon: Icon(Icons.folder, size: 22), label: '本地'),
            NavigationDestination(icon: Icon(Icons.favorite_border, size: 22), selectedIcon: Icon(Icons.favorite, size: 22), label: '收藏'),
            NavigationDestination(icon: Icon(Icons.download_outlined, size: 22), selectedIcon: Icon(Icons.download, size: 22), label: '下载'),
            NavigationDestination(icon: Icon(Icons.settings_outlined, size: 22), selectedIcon: Icon(Icons.settings, size: 22), label: '设置'),
          ]),
      ]));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HP();
}
class _HP extends State<HomePage> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  List<Song> _l = [];
  bool _loading = false;
  String _kw = '';

  @override
  void dispose() { _c.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _s() async {
    final kw = _c.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _kw = kw; });
    final r = await KuGouApi.I.search(kw);
    if (!mounted) return;
    setState(() { _l = r; _loading = false; });
    if (r.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 200), () {
        Downloader.I.scanDownloaded(r);
      });
    } else if (KuGouApi.I.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(KuGouApi.I.lastError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ModeManager>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              (m.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.28),
              (m.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.06)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (m.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.45))),
          child: Row(children: [
            Icon(m.isLite ? Icons.diamond : Icons.music_note, size: 15,
              color: m.isLite ? AppTheme.p : AppTheme.s),
            const SizedBox(width: 8),
            Text(m.isLite ? '概念版' : '普通版',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                color: m.isLite ? AppTheme.p : AppTheme.s)),
            const Spacer(),
            Text('端口 ${m.port}',
              style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.65))),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: GlassCard(
            radius: 26,
            padding: EdgeInsets.zero,
            heavy: true,
            child: TextField(
              controller: _c,
              onSubmitted: (_) => _s(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索歌曲 / 歌手 / 专辑',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 19),
                suffixIcon: _c.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 17),
                      onPressed: () => setState(() => _c.clear()))
                  : null,
                border: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14)),
              onChanged: (_) => setState(() {})))),
        if (_kw.isNotEmpty && !_loading)
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.p.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('共 ${_l.length} 首',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.p,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3))),
              const SizedBox(width: 10),
              Text('「$_kw」', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),
            ])),
        Expanded(child: _body()),
      ])),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_kw.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: AppTheme.grad.withOpacity(0.35),
            boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.45), blurRadius: 50, spreadRadius: 6)]),
          child: Icon(Icons.headphones, size: 62, color: Colors.white.withOpacity(0.95))),
        const SizedBox(height: 24),
        Text('开始你的音乐之旅', style: TextStyle(fontSize: 15.5,
          fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
        const SizedBox(height: 8),
        Text('搜索在线音乐，或去「本地」听歌',
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55))),
      ]));
    }
    if (_l.isEmpty) return Center(child: Text('没有找到结果',
      style: TextStyle(color: Colors.white.withOpacity(0.6))));
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _l.length,
      itemExtent: 72,
      cacheExtent: 500,
      itemBuilder: (_, i) => RepaintBoundary(child: _card(_l[i])));
  }

  Widget _card(Song s) => GlassCard(
    margin: const EdgeInsets.symmetric(vertical: 3),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    radius: 16,
    onTap: () {
      PlayerService.I.playSong(s, list: _l);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
    },
    child: Row(children: [
      _cover(s, 48),
      const SizedBox(width: 12),
      Expanded(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 3),
          Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.6))),
        ])),
      _dlBtn(s),
      _favBtn(s),
    ]));

  Widget _dlBtn(Song s) => Consumer<Downloader>(
    builder: (_, dl, __) {
      final t = dl.tasks[s.hash];
      if (t != null) {
        if (t.status == 'done') return const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 20));
        if (t.status == 'failed') return IconButton(
          icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 19),
          splashRadius: 18,
          onPressed: () => dl.download(s));
        return Padding(padding: const EdgeInsets.all(10),
          child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
              value: t.progress > 0 ? t.progress : null, strokeWidth: 2)));
      }
      return IconButton(
        icon: Icon(Icons.download_outlined, color: Colors.white.withOpacity(0.65), size: 19),
        splashRadius: 18,
        onPressed: () => dl.download(s));
    });

  Widget _favBtn(Song s) => Consumer<PlaylistService>(
    builder: (_, pl, __) {
      final fav = pl.contains(s);
      return IconButton(
        icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
          color: fav ? Colors.redAccent : Colors.white54, size: 19),
        splashRadius: 18,
        onPressed: () => pl.toggle(s));
    });

  Widget _cover(Song s, double size) => SizedBox(
    width: size, height: size,
    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _iconFor(s.hash)));

  Widget _iconFor(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) {
      return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, color: Colors.white70, size: 22));
    }
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GlassCard(
        radius: 16,
        padding: EdgeInsets.zero,
        heavy: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 58, child: Row(children: [
            const SizedBox(width: 10),
            SizedBox(width: 42, height: 42,
              child: ClipRRect(borderRadius: BorderRadius.circular(9),
                child: _miniIcon(s.hash))),
            const SizedBox(width: 12),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
            ])),
            if (p.loading)
              const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
            else IconButton(onPressed: p.toggle, iconSize: 26, splashRadius: 22,
              icon: Icon(p.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white)),
            IconButton(onPressed: p.next, iconSize: 26, splashRadius: 22,
              icon: const Icon(Icons.skip_next, color: Colors.white)),
            const SizedBox(width: 4),
          ])),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: LinearProgressIndicator(value: prog, minHeight: 2.5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppTheme.p))),
        ])));
  }
  Widget _miniIcon(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return const Icon(Icons.music_note, color: Colors.white70);
    return Image.asset(p, fit: BoxFit.cover, filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white70));
  }
}
