/// 根据歌曲 hash 稳定选择一个图标（同一首歌永远同一个）
class IconPicker {
  static const List<String> _all = [
    'assets/icons/icon_01.jpg',
    'assets/icons/icon_02.jpg',
    'assets/icons/icon_03.jpg',
    'assets/icons/icon_04.jpg',
    'assets/icons/icon_05.jpg',
    'assets/icons/icon_06.jpg',
    'assets/icons/icon_07.jpg',
    'assets/icons/icon_08.jpg',
    'assets/icons/icon_09.jpg',
    'assets/icons/icon_10.jpg',
    'assets/icons/icon_11.jpg',
    'assets/icons/icon_12.jpg',
    'assets/icons/icon_13.jpg',
    'assets/icons/icon_14.jpg',
    'assets/icons/icon_15.jpg',
    'assets/icons/icon_16.jpg',
    'assets/icons/icon_17.jpg',
    'assets/icons/icon_18.jpg',
    'assets/icons/icon_19.jpg',
    'assets/icons/icon_20.jpg',
    'assets/icons/icon_21.jpg',
    'assets/icons/icon_22.jpg',
    'assets/icons/icon_23.jpg',
    'assets/icons/icon_24.jpg',
    'assets/icons/icon_25.jpg',
    'assets/icons/icon_26.jpg',
    'assets/icons/icon_27.png',
  ];

  static String forHash(String hash) {
    if (_all.isEmpty) return '';
    int h = 0;
    for (final c in hash.codeUnits) { h = (h * 31 + c) & 0x7fffffff; }
    return _all[h % _all.length];
  }
}
