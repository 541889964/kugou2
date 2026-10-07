import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SearchSettings extends ChangeNotifier {
  static final SearchSettings I = SearchSettings._();
  SearchSettings._();
  int _pageSize = 30;
  int get pageSize => _pageSize;
  static const _key = 'search_page_size';
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _pageSize = sp.getInt(_key) ?? 30;
    notifyListeners();
  }
  Future<void> setPageSize(int v) async {
    _pageSize = v.clamp(10, 100);
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_key, _pageSize);
    notifyListeners();
  }
}
