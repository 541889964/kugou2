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
  static const _pages = <Widget>[
    HomePage(), LocalMusicPage(), PlaylistPage(), DownloadsPage(), SettingsPage(),
  ];
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 340),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final offset = Tween<Offset>(begin: const Offset(0.10, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(opacity: anim,
            child: SlideTransition(position: offset, child: child));
        },
        child: KeyedSubtree(key: ValueKey(_t), child: _pages[_t]),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (p.current != null) const _Mini(),
        NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: _t,
          onDestinationSelected: (i) => setState(() => _t = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: '搜索'),
            NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: '本地'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: '收藏'),
            NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: '下载'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
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
  List<Song> _l = [];
  bool _loading = false;
  String _kw = '';

  Future<void> _s() async {
    final kw = _c.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _kw = kw; });
    final r = await KuGouApi.I.search(kw);
    if (!mounted) return;
    setState(() { _l = r; _loading = false; });
    Downloader.I.scanDownloaded(r);
    if (r.isEmpty && KuGouApi.I.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(KuGouApi.I.lastError!)));
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              (m.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.28),
              (m.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.06)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (m.isLite ? AppTheme.p : AppTheme.s).withOpacity(0.45))),
          child: Row(children: [
            Icon(m.isLite ? Icons.diamond : Icons.music_note, size: 16,
              color: m.isLite ? AppTheme.p : AppTheme.s),
            const SizedBox(width: 8),
            Text(m.isLite ? '概念版' : '普通版',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: m.isLite ? AppTheme.p : AppTheme.s)),
            const Spacer(),
            Text('端口 ${m.port}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: GlassCard(
            radius: 28,
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _c,
              onSubmitted: (_) => _s(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索歌曲 / 歌手 / 专辑',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _c.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _c.clear()))
                  : null,
                border: InputBorder.none,
                fillColor: Colors.transparent),
              onChanged: (_) => setState(() {})))),
        Expanded(child: _body()),
      ])),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_kw.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: AppTheme.grad.withOpacity(0.35),
            boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.5), blurRadius: 60, spreadRadius: 8)]),
          child: Icon(Icons.headphones, size: 68, color: Colors.white.withOpacity(0.95))),
        const SizedBox(height: 26),
        Text('开始你的音乐之旅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.9))),
        const SizedBox(height: 8),
        Text('搜索在线音乐，或去「本地」听歌', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.55))),
      ]));
    }
    if (_l.isEmpty) return Center(child: Text('没有找到结果',
      style: TextStyle(color: Colors.white.withOpacity(0.6))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        child: Text('找到 ${_l.length} 首',
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6), letterSpacing: 0.5))),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        itemCount: _l.length,
        itemBuilder: (_, i) => _card(_l[i]))),
    ]);
  }

  Widget _card(Song s) => GlassCard(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(10),
    onTap: () {
      PlayerService.I.playSong(s, list: _l);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
    },
    child: Row(children: [
      _cover(s, 52),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 3),
        Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
      ])),
      Consumer<Downloader>(builder: (_, dl, __) {
        final t = dl.tasks[s.hash];
        if (t != null) {
          if (t.status == 'done') return const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22);
          if (t.status == 'failed') return IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 20),
            onPressed: () => dl.download(s));
          return Padding(padding: const EdgeInsets.all(10),
            child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(value: t.progress > 0 ? t.progress : null, strokeWidth: 2)));
        }
        return IconButton(icon: Icon(Icons.download_outlined,
          color: Colors.white.withOpacity(0.65), size: 20), onPressed: () => dl.download(s));
      }),
      Consumer<PlaylistService>(builder: (_, pl, __) {
        final fav = pl.contains(s);
        return IconButton(icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
          color: fav ? Colors.redAccent : Colors.white54, size: 20),
          onPressed: () => pl.toggle(s));
      }),
    ]));

  Widget _cover(Song s, double size) {
    return Container(width: size, height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: _iconFor(s.hash)));
  }

  Widget _iconFor(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) {
      return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, color: Colors.white70));
    }
    return Image.asset(p, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, color: Colors.white70)));
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
        radius: 18,
        padding: EdgeInsets.zero,
        opacity: 0.16,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 60, child: Row(children: [
            const SizedBox(width: 10),
            Container(width: 44, height: 44,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
              child: ClipRRect(borderRadius: BorderRadius.circular(10),
                child: _miniIcon(s.hash))),
            const SizedBox(width: 12),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.6))),
            ])),
            if (p.loading)
              const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            else IconButton(onPressed: p.toggle, iconSize: 26,
              icon: Icon(p.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white)),
            IconButton(onPressed: p.next, iconSize: 26,
              icon: const Icon(Icons.skip_next, color: Colors.white)),
            const SizedBox(width: 4),
          ])),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
            child: LinearProgressIndicator(value: prog, minHeight: 3,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppTheme.p))),
        ])));
  }

  Widget _miniIcon(String hash) {
    final p = IconPicker.forHash(hash);
    if (p.isEmpty) return const Icon(Icons.music_note, color: Colors.white70);
    return Image.asset(p, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white70));
  }
}
