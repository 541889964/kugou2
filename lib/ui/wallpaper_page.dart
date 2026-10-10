import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wallpaper_manager.dart';

class WallpaperPage extends StatefulWidget {
  const WallpaperPage({super.key});
  @override
  State<WallpaperPage> createState() => _W();
}
class _W extends State<WallpaperPage> {
  late final PageController _pc;
  int _cur = 0;
  bool _ui = true;
  @override
  void initState() {
    super.initState();
    _cur = WallpaperManager.I.index;
    _pc = PageController(initialPage: _cur);
  }
  @override
  void dispose() { _pc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final list = WallpaperManager.all;
    if (list.isEmpty) return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Text('没有壁纸', style: TextStyle(color: Colors.white))));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        GestureDetector(
          onTap: () => setState(() => _ui = !_ui),
          child: PageView.builder(
            controller: _pc, physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            onPageChanged: (i) {
              setState(() => _cur = i);
              WallpaperManager.I.setIndex(i);
            },
            itemBuilder: (_, i) => _page(list[i], i == _cur))),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          top: _ui ? 0 : -100, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 8, right: 8, bottom: 12),
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
              const Spacer(),
              Text('${_cur + 1} / ${list.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.check, size: 22, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已应用为壁纸')));
                }),
            ])),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          bottom: _ui ? 0 : -140, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.85), Colors.transparent])),
            child: SizedBox(height: 72, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final active = i == _cur;
                return GestureDetector(
                  onTap: () => _pc.animateToPage(i,
                    duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: active ? 60 : 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? Colors.white : Colors.white.withOpacity(0.25),
                        width: active ? 2 : 1)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.asset(list[i], fit: BoxFit.cover, filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black26)))));
              }))),
        ),
      ]),
    );
  }
  Widget _page(String path, bool active) => Container(color: Colors.black,
    child: Center(child: AnimatedScale(
      duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic,
      scale: active ? 1.0 : 0.94,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: active ? 1.0 : 0.55,
        child: Image.asset(path, fit: BoxFit.contain, filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24, size: 80))))));
}
