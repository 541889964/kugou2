import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../playlist.dart';
import '../player.dart';
import '../icon_picker.dart';
import 'player_page.dart';
import 'theme.dart';
import 'glass.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});
  @override
  Widget build(BuildContext context) {
    final pl = context.watch<PlaylistService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('收藏 (${pl.songs.length})'),
        actions: [
          if (pl.songs.isNotEmpty) IconButton(icon: const Icon(Icons.play_arrow),
            onPressed: () {
              PlayerService.I.playFromList(pl.songs.first, pl.songs);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
            }),
          if (pl.songs.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep),
            onPressed: () => pl.clear()),
        ]),
      body: pl.songs.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.white.withOpacity(0.25)),
            const SizedBox(height: 20),
            Text('还没有收藏歌曲', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15)),
            const SizedBox(height: 8),
            Text('点击 ♡ 加入收藏（自动备份到 Music/KuGou/）',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ]))
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: pl.songs.length, itemBuilder: (_, i) {
            final s = pl.songs[i];
            return GlassCard(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onTap: () {
                PlayerService.I.playFromList(s, pl.songs, i: i);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
              },
              child: Row(children: [
                _cover(s, 48),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(s.singer, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                ])),
                IconButton(icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  onPressed: () => pl.toggle(s)),
              ]));
          }));
  }
  Widget _cover(dynamic s, double size) {
    final Widget inner;
    if (s.cover != null && s.cover!.isNotEmpty) {
      inner = CachedNetworkImage(imageUrl: s.cover!, fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _icon(s));
    } else {
      inner = _icon(s);
    }
    return SizedBox(width: size, height: size,
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: inner));
  }
  Widget _icon(dynamic s) {
    final p = IconPicker.forHash(s.hash);
    if (p.isEmpty) return Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 24));
    return Image.asset(p, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: AppTheme.discGrad),
        child: const Icon(Icons.music_note, color: Colors.white54, size: 24)));
  }
}
