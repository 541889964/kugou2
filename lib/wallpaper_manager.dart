import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperManager extends ChangeNotifier {
  static final WallpaperManager I = WallpaperManager._();
  WallpaperManager._();

  static const List<String> _all = [
    'assets/wallpapers/w_01.jpg',
    'assets/wallpapers/w_02.jpg',
    'assets/wallpapers/w_03.jpg',
    'assets/wallpapers/w_04.jpg',
    'assets/wallpapers/w_05.jpg',
    'assets/wallpapers/w_06.jpg',
    'assets/wallpapers/w_07.jpg',
    'assets/wallpapers/w_08.jpg',
    'assets/wallpapers/w_09.jpg',
    'assets/wallpapers/w_10.jpg',
    'assets/wallpapers/w_11.jpg',
    'assets/wallpapers/w_12.jpg',
    'assets/wallpapers/w_13.jpg',
  ];

  static List<String> get all => List.unmodifiable(_all);
  static int get count => _all.length;

  int _index = 0;
  int get index => _index;
  String get current => _all.isEmpty ? 'assets/wallpaper.jpg' : _all[_index];

  static const _key = 'wallpaper_index';

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _index = (sp.getInt(_key) ?? 0).clamp(0, _all.isEmpty ? 0 : _all.length - 1);
    notifyListeners();
  }

  Future<void> setIndex(int i) async {
    if (_all.isEmpty) return;
    _index = i.clamp(0, _all.length - 1);
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_key, _index);
    notifyListeners();
  }

  Future<void> next() async {
    if (_all.isEmpty) return;
    await setIndex((_index + 1) % _all.length);
  }
  Future<void> prev() async {
    if (_all.isEmpty) return;
    await setIndex((_index - 1 + _all.length) % _all.length);
  }
}
