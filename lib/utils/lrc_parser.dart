import '../models/lyric.dart';

/// 解析 LRC 格式歌词文本
class LrcParser {
  static final _timeTag = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');

  static LyricData? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final entries = <({int ms, String text})>[];

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final matches = _timeTag.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      var text = trimmed.replaceAll(_timeTag, '').trim();
      if (text.isEmpty) continue;

      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final frac = m.group(3);
        var ms = (min * 60 + sec) * 1000;
        if (frac != null) {
          ms += int.parse(frac.padRight(3, '0').substring(0, 3));
        }
        entries.add((ms: ms, text: text));
      }
    }

    if (entries.isEmpty) return null;

    entries.sort((a, b) => a.ms.compareTo(b.ms));

    final lines = <LyricLine>[];
    for (var i = 0; i < entries.length; i++) {
      final endMs = i + 1 < entries.length
          ? entries[i + 1].ms
          : entries[i].ms + 5000;
      lines.add(LyricLine(
        startMs: entries[i].ms,
        endMs: endMs,
        text: entries[i].text,
      ));
    }

    return LyricData(_filterMetaLines(lines));
  }

  static bool isMetaLine(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^(词|曲|编曲|制作人|监制|混音|录音|出品|发行|策划|合声|和声|编写|工程|助理|吉他|贝斯|鼓|钢琴|OP|SP)').hasMatch(t)) {
      return true;
    }
    if (RegExp(r'(编写|工程|助理|Studio|studio)').hasMatch(t) && t.length < 30) {
      return true;
    }
    if (RegExp(r'^[\u4e00-\u9fff\w\s\-()]+\s[-–—]\s[\u4e00-\u9fff\w\s\-()]+$').hasMatch(t) &&
        t.length < 40) {
      return true;
    }
    return false;
  }

  static List<LyricLine> _filterMetaLines(List<LyricLine> lines) {
    return lines.where((l) => !isMetaLine(l.text)).toList();
  }

  static bool _isMetaLine(String text) => isMetaLine(text);
}
