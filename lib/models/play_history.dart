import 'song.dart';

class PlayHistoryItem {
  final Song song;
  final DateTime playedAt;
  final int playCount;

  const PlayHistoryItem({
    required this.song,
    required this.playedAt,
    this.playCount = 1,
  });

  factory PlayHistoryItem.fromJson(Map<String, dynamic> json) {
    return PlayHistoryItem(
      song: Song.fromJson(Map<String, dynamic>.from(json['song'] as Map)),
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        Song.parseInt(json['playedAt']),
      ),
      playCount: Song.parseInt(json['playCount']).clamp(1, 99999),
    );
  }

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'playedAt': playedAt.millisecondsSinceEpoch,
    'playCount': playCount,
  };

  PlayHistoryItem copyWith({DateTime? playedAt, int? playCount}) =>
      PlayHistoryItem(
        song: song,
        playedAt: playedAt ?? this.playedAt,
        playCount: playCount ?? this.playCount,
      );

  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(playedAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24 &&
        now.day == playedAt.day &&
        now.month == playedAt.month) {
      return '${playedAt.hour.toString().padLeft(2, '0')}:${playedAt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final playedDay = DateTime(playedAt.year, playedAt.month, playedAt.day);
    if (playedDay == yesterday) {
      return '昨天 ${playedAt.hour.toString().padLeft(2, '0')}:${playedAt.minute.toString().padLeft(2, '0')}';
    }
    return '${playedAt.month}月${playedAt.day}日';
  }
}
