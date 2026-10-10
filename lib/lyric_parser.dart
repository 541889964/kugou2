class LyricLine {
  final int time;
  final String text;
  LyricLine(this.time, this.text);
}
class LyricParser {
  static List<LyricLine> parse(String raw) {
    if (raw.isEmpty) return [];
    final lines = <LyricLine>[];
    final reg = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
    for (final line in raw.split('\n')) {
      final ms = reg.allMatches(line).toList();
      if (ms.isEmpty) continue;
      final text = line.replaceAll(reg, '').trim();
      if (text.isEmpty) continue;
      for (final m in ms) {
        final min = int.tryParse(m.group(1)!) ?? 0;
        final sec = int.tryParse(m.group(2)!) ?? 0;
        final msPart = m.group(3);
        final msVal = msPart != null
          ? int.tryParse(msPart.padRight(3, '0').substring(0, 3)) ?? 0 : 0;
        lines.add(LyricLine(min * 60000 + sec * 1000 + msVal, text));
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}
