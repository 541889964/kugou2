import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../playlist.dart';
import '../player.dart';
import '../icon_picker.dart';
import 'player_page.dart';
import 'theme.dart';
import 'glass.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});
  @override
  State<PlaylistPage> createState() => _P();
}
class _P extends State<PlaylistPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pl = context.watch<PlaylistService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('我的收藏', style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text('共 ${pl.songs.length} 首', style: TextStyle(fontSize: 11,
                color: Colors.white.withOpacity(0.5))),
            ]),
            const Spacer(),
            if (pl.songs.isNotEmpty) IconButton(icon: const Icon(Icons.play_arrow),
              onPressed: () {
                PlayerService.I.playFromList(pl.songs.first, pl.songs);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
              }),
            if (pl.songs.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep),
              onPressed: () => pl.clear()),
          ])),
        Expanded(child: pl.songs.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: AppTheme.grad.withOpacity(0.3)),
                child: Icon(Icons.favorite_border, size: 52, color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 22),
              const Text('还没有收藏歌曲', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('点击 ♡ 加入收藏（自动备份）',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            ]))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: pl.songs.length, itemExtent: 68, itemBuilder: (_, i) {
            final s = pl.songs[i];
            final ip = IconPicker.forHash(s.hash);
            return RepaintBoundary(child: GlassCard(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              radius: 14,
              onTap: () {
                PlayerService.I.playFromList(s, pl.songs, i: i);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
              },
              child: Row(children: [
                SizedBox(width: 46, height: 46, child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ip.isEmpty ? Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
                    child: const Icon(Icons.music_note, color: Colors.white54, size: 22))
                    : Image.asset(ip, fit: BoxFit.cover, filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(gradient: AppTheme.discGrad),
                        child: const Icon(Icons.music_note, color: Colors.white54, size: 22))))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
                ])),
                IconButton(icon: const Icon(Icons.favorite, color: AppTheme.accent, size: 19),
                  splashRadius: 18, onPressed: () => pl.toggle(s)),
              ])));
          })),
      ])),
    );
  }
}
