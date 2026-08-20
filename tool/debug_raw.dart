import 'package:http/http.dart' as http;

import 'package:xmusic/config/api_config.dart';
import 'package:xmusic/services/music_secure_session.dart';

Future<void> main() async {
  final session = MusicSecureSession();
  await session.ensureSession();
  print('session ok: ${session.sessionId}');

  final response = await http.get(
    Uri.parse(
      '${ApiConfig.musicApi}/recommend/personal-fm?t=${DateTime.now().millisecondsSinceEpoch}',
    ),
    headers: session.headers,
  );

  print('status: ${response.statusCode}');
  print('encrypted: ${response.headers['x-tabos-music-encrypted']}');

  final result = await session.decodeResponse(response);
  print('result type: ${result.runtimeType}');
  print('result: $result');

  if (result is Map) {
    print('code: ${result['code']} (${result['code'].runtimeType})');
    print('data type: ${result['data']?.runtimeType}');
    final data = result['data'];
    if (data is Map) {
      print('data keys: ${data.keys.toList()}');
      print('list type: ${data['list']?.runtimeType}');
      print('list len: ${data['list'] is List ? (data['list'] as List).length : 'n/a'}');
      if (data['list'] is List && (data['list'] as List).isNotEmpty) {
        print('first item type: ${(data['list'] as List).first.runtimeType}');
        print('first item: ${(data['list'] as List).first}');
      }
    }
  }
}
