import 'package:http/http.dart' as http;

import 'package:xmusic/config/api_config.dart';
import 'package:xmusic/models/song.dart';
import 'package:xmusic/services/music_secure_session.dart';

List<Map<String, dynamic>> extractList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (data is Map) {
    final list = data['list'];
    print('  list is List? ${list is List}, len=${list is List ? list.length : 0}');
    if (list is List) {
      print('  first item is Map? ${list.isNotEmpty ? list.first is Map : "empty"}');
      print('  whereType count: ${list.whereType<Map>().length}');
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return [];
}

Future<void> main() async {
  final session = MusicSecureSession();
  await session.ensureSession();

  final response = await http.get(
    Uri.parse(
      '${ApiConfig.musicApi}/recommend/personal-fm?t=${DateTime.now().millisecondsSinceEpoch}',
    ),
    headers: session.headers,
  );

  final result = await session.decodeResponse(response);
  print('code check: ${result['code']} != 0 => ${result['code'] != 0}');

  final extracted = extractList(result['data']);
  print('extracted: ${extracted.length}');

  if (extracted.isNotEmpty) {
    final song = Song.fromJson(extracted.first);
    print('song: ${song.name} / ${song.artistName}');
  }
}
