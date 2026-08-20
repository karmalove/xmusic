import 'package:xmusic/services/music_api_service.dart';

Future<void> main() async {
  final api = MusicApiService();

  Future<void> test(String name, Future<dynamic> Function() fn) async {
    try {
      final result = await fn();
      final count = result is List ? result.length : result;
      print('OK $name => $count');
      if (result is List && result.isNotEmpty) {
        print('  first: ${result.first}');
      }
    } catch (e, st) {
      print('FAIL $name => $e');
      print(st.toString().split('\n').take(3).join('\n'));
    }
  }

  await test('personalFm', api.getPersonalFm);
  await test('newSongs', api.getRecommendNewSongs);
  await test('charts', api.getCharts);
  await test('playlists', api.getRecommendPlaylists);
  await test('search', () => api.searchSongs('周杰伦'));
}
