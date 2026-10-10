import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MusicSource { concept, netease }

class SourceManager extends ChangeNotifier {
  static final SourceManager I = SourceManager._();
  SourceManager._();
  MusicSource _search = MusicSource.concept;
  MusicSource _discover = MusicSource.netease;
  MusicSource get search => _search;
  MusicSource get discover => _discover;
  String get searchLabel => _search == MusicSource.concept ? '酷狗概念版' : '网易云';
  String get discoverLabel => _discover == MusicSource.concept ? '酷狗概念版' : '网易云';
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _search = (sp.getString('source_search') == 'netease') ? MusicSource.netease : MusicSource.concept;
    _discover = (sp.getString('source_discover') == 'concept') ? MusicSource.concept : MusicSource.netease;
    notifyListeners();
  }
  Future<void> setSearch(MusicSource s) async {
    _search = s;
    (await SharedPreferences.getInstance()).setString('source_search', s.name);
    notifyListeners();
  }
  Future<void> setDiscover(MusicSource s) async {
    _discover = s;
    (await SharedPreferences.getInstance()).setString('source_discover', s.name);
    notifyListeners();
  }
}
