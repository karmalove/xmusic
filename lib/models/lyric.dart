class LyricLine {
  final int startMs;
  final int endMs;
  final String text;

  const LyricLine({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

class LyricData {
  final List<LyricLine> lines;

  const LyricData(this.lines);

  bool get isEmpty => lines.isEmpty;

  int indexAt(int positionMs) {
    if (lines.isEmpty) return -1;
    var lo = 0;
    var hi = lines.length - 1;
    var result = 0;
    while (lo <= hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (lines[mid].startMs <= positionMs) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }
}
