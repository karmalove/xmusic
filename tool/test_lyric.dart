import 'package:xmusic/models/song.dart';
import 'package:xmusic/services/music_api_service.dart';

Future<void> main() async {
  final api = MusicApiService();
  final songs = await api.searchSongs('晴天');
  if (songs.isEmpty) {
    print('no songs');
    return;
  }
  final song = songs.first;
  print('song: ${song.name} / ${song.artistName}');
  final lyrics = await api.fetchLyrics(song);
  print('lines: ${lyrics?.lines.length ?? 0}');
  if (lyrics != null && lyrics.lines.isNotEmpty) {
    for (final line in lyrics.lines.take(5)) {
      print('[${line.startMs}ms] ${line.text}');
    }
  }
}
