import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SearchSettings extends ChangeNotifier {
  static final SearchSettings I = SearchSettings._();
  SearchSettings._();
  int _pageSize = 30;
  int get pageSize => _pageSize;
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _pageSize = sp.getInt('search_page_size') ?? 30;
    notifyListeners();
  }
  Future<void> setPageSize(int v) async {
    _pageSize = v.clamp(10, 100);
    (await SharedPreferences.getInstance()).setInt('search_page_size', _pageSize);
    notifyListeners();
  }
}
