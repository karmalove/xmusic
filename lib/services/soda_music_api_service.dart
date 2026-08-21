import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/song.dart';
import 'music_secure_session.dart';

/// 汽水（官网 soda）搜索 / 播放，对齐网页 `/api/music/soda/*`。
class SodaMusicApiService {
  SodaMusicApiService._();

  static final SodaMusicApiService instance = SodaMusicApiService._();

  static const sourceId = 'soda';

  final MusicSecureSession _session = MusicSecureSession();

  /// query|type → next_cursor
  final Map<String, String> _cursors = {};

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    await _session.ensureSession();
    final uri = Uri.parse('${ApiConfig.musicApi}$path').replace(
      queryParameters: query,
    );
    var response = await http.get(uri, headers: _session.headers);

    if (response.statusCode == 401 &&
        response.headers['x-tabos-music-retry'] == '1') {
      _session.invalidate();
      await _session.ensureSession(force: true);
      response = await http.get(uri, headers: _session.headers);
    }

    if (response.statusCode != 200) {
      throw Exception('汽水接口失败 (${response.statusCode}): $path');
    }

    final result = await _session.decodeResponse(response);
    if (result is! Map) {
      throw Exception('汽水接口响应异常');
    }
    final map = Map<String, dynamic>.from(result);
    final code = map['code'];
    if (code != null && code != 0 && code != 0.0) {
      throw Exception(map['message']?.toString() ?? '汽水接口错误');
    }
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }

  Future<Map<String, dynamic>> _search(
    String query, {
    required String type,
    int page = 1,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return {};

    final key = '$type:$q';
    final params = <String, String>{
      'q': q,
      'type': type,
      'search_type': type,
    };
    if (page > 1) {
      final cursor = _cursors[key];
      if (cursor == null || cursor.isEmpty) return {};
      params['cursor'] = cursor;
    } else {
      _cursors.remove(key);
    }

    final data = await _get('/soda/search', query: params);
    final next = data['next_cursor']?.toString() ?? '';
    if (next.isNotEmpty) {
      _cursors[key] = next;
    } else {
      _cursors.remove(key);
    }
    return data;
  }

  bool hasMore(String query, String type) {
    final key = '$type:${query.trim()}';
    final c = _cursors[key];
    return c != null && c.isNotEmpty;
  }

  Future<List<Song>> searchSongs(String query, {int page = 1}) async {
    final data = await _search(query, type: 'track', page: page);
    final list = data['songs'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => _songFromSoda(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  Future<List<Playlist>> searchPlaylists(String query, {int page = 1}) async {
    final data = await _search(query, type: 'playlist', page: page);
    final list = data['playlists'];
    if (list is! List) return [];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return Playlist(
        id: m['id']?.toString() ?? '',
        name: m['title']?.toString() ?? m['name']?.toString() ?? '',
        cover: m['cover']?.toString() ?? '',
        source: sourceId,
        songCount: Song.parseInt(m['count'] ?? m['songCount']),
      );
    }).where((p) => p.id.isNotEmpty && p.name.isNotEmpty).toList();
  }

  Future<List<Album>> searchAlbums(String query, {int page = 1}) async {
    final data = await _search(query, type: 'album', page: page);
    final list = data['albums'];
    if (list is! List) return [];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return Album(
        id: m['id']?.toString() ?? '',
        name: m['title']?.toString() ?? m['name']?.toString() ?? '',
        cover: m['cover']?.toString() ?? '',
        source: sourceId,
      );
    }).where((a) => a.id.isNotEmpty && a.name.isNotEmpty).toList();
  }

  Future<List<Artist>> searchArtists(String query, {int page = 1}) async {
    final data = await _search(query, type: 'artist', page: page);
    final list = data['artists'];
    if (list is! List) return [];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return Artist(
        id: m['id']?.toString() ?? '',
        name: m['title']?.toString() ?? m['name']?.toString() ?? '',
        source: sourceId,
        cover: m['cover']?.toString() ?? '',
      );
    }).where((a) => a.id.isNotEmpty && a.name.isNotEmpty).toList();
  }

  Future<List<MusicVideo>> searchMvs(String query, {int page = 1}) async {
    final data = await _search(query, type: 'video', page: page);
    final list = data['videos'] ?? data['mvs'];
    if (list is! List) return [];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return MusicVideo(
        id: m['id']?.toString() ?? m['mediaId']?.toString() ?? '',
        name: m['title']?.toString() ?? m['name']?.toString() ?? '',
        cover: m['cover']?.toString() ?? '',
        source: sourceId,
        artist: m['artistsText']?.toString() ??
            m['artist']?.toString() ??
            '',
      );
    }).where((v) => v.id.isNotEmpty && v.name.isNotEmpty).toList();
  }

  Future<List<String>> searchSuggest(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final data = await _get('/soda/search/suggest', query: {'q': q});
      final raw = data['raw'];
      dynamic sugs;
      if (raw is Map) {
        final inner = raw['data'];
        if (inner is Map) sugs = inner['sugs'];
        sugs ??= raw['sugs'];
      }
      sugs ??= data['sugs'] ?? data['suggestions'];
      if (sugs is! List) return [];
      return sugs
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['suggestion'] ?? e['name'] ?? e['keyword']).toString();
            }
            return '';
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> getSongUrl(String mediaId) async {
    final data = await _get('/soda/media/${Uri.encodeComponent(mediaId)}/playable');
    final play = data['play'];
    if (play is Map) {
      final url = _pickUrl(Map<String, dynamic>.from(play));
      if (url != null) return url;
    }

    final urls = data['play_urls'];
    if (urls is List && urls.isNotEmpty) {
      // 优先非 preview、更高码率
      final parsed = urls.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return (
          url: m['url']?.toString() ?? '',
          preview: m['preview'] == true,
          bitrate: Song.parseInt(m['bitrate']),
          role: m['url_role']?.toString() ?? '',
        );
      }).where((e) => e.url.startsWith('http')).toList();

      if (parsed.isEmpty) {
        throw Exception('汽水无可播放地址');
      }

      parsed.sort((a, b) {
        if (a.preview != b.preview) return a.preview ? 1 : -1;
        if (a.role == 'main' && b.role != 'main') return -1;
        if (b.role == 'main' && a.role != 'main') return 1;
        return b.bitrate.compareTo(a.bitrate);
      });
      return parsed.first.url;
    }

    final direct = _pickUrl(data);
    if (direct != null) return direct;
    throw Exception('无法获取汽水播放地址');
  }

  String? _pickUrl(Map<String, dynamic> map) {
    for (final key in ['url', 'main', 'main_url', 'backup', 'backup_url']) {
      final v = map[key]?.toString() ?? '';
      if (v.startsWith('http://') || v.startsWith('https://')) return v;
    }
    return null;
  }

  Song _songFromSoda(Map<String, dynamic> json) {
    var artists = <Artist>[];
    final artistsRaw = json['artists'];
    if (artistsRaw is List) {
      artists = artistsRaw
          .whereType<Map>()
          .map((e) => Artist.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.name.isNotEmpty)
          .toList();
    }
    final artistsText = json['artistsText']?.toString() ?? '';
    if (artists.isEmpty && artistsText.isNotEmpty) {
      artists = [
        Artist(id: '', name: artistsText, source: sourceId),
      ];
    }

    return Song(
      id: json['mediaId']?.toString() ??
          json['id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      source: sourceId,
      durationMs: Song.parseInt(
        json['durationMs'] ?? json['duration_ms'] ?? json['duration'],
        treatSmallAsSeconds: true,
      ),
      artists: artists,
      album: Album.fromJson(
        json['album'] is Map
            ? Map<String, dynamic>.from(json['album'] as Map)
            : null,
      ),
      playable: json['playable'] != false,
    );
  }
}
