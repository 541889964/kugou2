import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../kugou.dart';
import '../player.dart';
import '../playlist.dart';
import '../downloader.dart';
import '../icon_picker.dart';
import '../source_manager.dart';
import 'player_page.dart';
import 'theme.dart';
import 'glass.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SP();
}
class _SP extends State<SearchPage> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  List<Song> _results = [];
  bool _loading = false, _loadingMore = false, _hasMore = true;
  int _page = 1;
  String _kw = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _search() async {
    final kw = _c.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    final src = SourceManager.I.search;
    setState(() { _loading = true; _results = []; _page = 1; _hasMore = true; _kw = kw; });
    final r = await KuGouApi.I.search(kw, page: 1, source: src.name);
    if (!mounted) return;
    setState(() { _results = r; _loading = false; _hasMore = r.length >= 20; });
    Downloader.I.scanDownloaded(r);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    final r = await KuGouApi.I.search(_kw, page: _page, source: SourceManager.I.search.name);
    if (!mounted) return;
    setState(() { _results.addAll(r); _loadingMore = false; _hasMore = r.length >= 20; });
  }

  @override
  void dispose() { _c.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, size: 22), splashRadius: 20,
              onPressed: () => Navigator.pop(context)),
            Expanded(child: GlassCard(radius: 22, padding: EdgeInsets.zero, heavy: true,
              child: TextField(
                controller: _c, autofocus: true, onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '搜索歌曲、歌手或专辑',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _c.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 17), splashRadius: 16,
                        onPressed: () => setState(() => _c.clear()))
                    : null,
                  border: InputBorder.none, fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13)),
                onChanged: (_) => setState(() {})))),
          ])),
        if (_kw.isNotEmpty && !_loading)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.p.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('共 ${_results.length} 首', style: TextStyle(fontSize: 11,
                  color: AppTheme.p, fontWeight: FontWeight.w800))),
            ])),
        Expanded(child: _body()),
      ])),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty && _kw.isNotEmpty) return _empty('没有找到结果');
    if (_results.isEmpty) return _empty('搜索你想听的音乐');
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _results.length) {
          return const Padding(padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return RepaintBoundary(child: _row(_results[i]));
      });
  }

  Widget _empty(String t) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: AppTheme.grad.withOpacity(0.3),
        boxShadow: [BoxShadow(color: AppTheme.p.withOpacity(0.4), blurRadius: 40)]),
      child: Icon(Icons.search, size: 52, color: Colors.white.withOpacity(0.9))),
    const SizedBox(height: 20),
    Text(t, style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.6))),
  ]));

  Widget _row(Song s) => GlassCard(
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
          Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
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
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
      ])),
      Consumer<Downloader>(builder: (_, dl, __) {
        final t = dl.tasks[s.hash];
        if (t != null) {
          if (t.status == 'done') return const Padding(padding: EdgeInsets.all(8),
            child: Icon(Icons.check_circle, color: AppTheme.s, size: 19));
          return Padding(padding: const EdgeInsets.all(10),
            child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                value: t.progress > 0 ? t.progress : null, strokeWidth: 2)));
        }
        return IconButton(icon: Icon(Icons.download_outlined,
          color: Colors.white.withOpacity(0.6), size: 18),
          splashRadius: 18, onPressed: () => dl.download(s));
      }),
      Consumer<PlaylistService>(builder: (_, pl, __) {
        final fav = pl.contains(s);
        return IconButton(
          icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
            color: fav ? AppTheme.accent : Colors.white54, size: 18),
          splashRadius: 18, onPressed: () => pl.toggle(s));
      }),
    ]));

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
