import 'package:xmusic/services/music_api_service.dart';

Future<void> main() async {
  final api = MusicApiService();

  for (final q in ['周杰伦', '晴天', '']) {
    print('\n=== search: "$q" ===');
    try {
      final songs = await api.searchSongs(q);
      print('songs: ${songs.length}');
      if (songs.isNotEmpty) print('  first: ${songs.first.name}');
      final playlists = await api.searchPlaylists(q);
      print('playlists: ${playlists.length}');
      if (playlists.isNotEmpty) print('  first: ${playlists.first.name}');
    } catch (e, st) {
      print('ERROR: $e');
      print(st.toString().split('\n').take(4).join('\n'));
    }
  }
}
