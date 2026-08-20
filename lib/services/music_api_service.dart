import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/lyric.dart';
import '../models/song.dart';
import '../utils/lrc_parser.dart';
import 'music_secure_session.dart';

class MusicApiService {
  MusicApiService._();

  static final MusicApiService instance = MusicApiService._();

  factory MusicApiService() => instance;

  final MusicSecureSession _session = MusicSecureSession();

  /// Ensures the secure session is ready before parallel API calls.
  Future<void> ensureReady() => _session.ensureSession();

  Future<Map<String, dynamic>> _get(String path, {bool retry = true}) async {
    await _session.ensureSession();

    final response = await http.get(
      Uri.parse('${ApiConfig.musicApi}$path'),
      headers: _session.headers,
    );

    if (response.statusCode == 401 &&
        response.headers['x-tabos-music-retry'] == '1' &&
        retry) {
      _session.invalidate();
      await _session.ensureSession(force: true);
      return _get(path, retry: false);
    }

    if (response.statusCode != 200) {
      throw Exception('API 请求失败 (${response.statusCode}): $path');
    }

    final result = await _session.decodeResponse(response);

    if (result is Map) {
      final code = result['code'];
      if (code != null && code != 0 && code != 0.0) {
        throw Exception(result['message']?.toString() ?? 'API 错误');
      }
      return Map<String, dynamic>.from(result);
    }

    return {'data': result, 'code': 0};
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (data is Map) {
      final list = data['list'];
      if (list is List) {
        return list
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
    return [];
  }

  Future<List<Song>> searchSongs(String query,
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final result = await _get(
      '/search/songs?q=${Uri.encodeComponent(query.trim())}&source=$source&page=$page&page_size=30',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  Future<List<Playlist>> searchPlaylists(String query,
      {String source = ApiConfig.defaultSource}) async {
    if (query.trim().isEmpty) return [];
    final result = await _get(
      '/search/playlists?q=${Uri.encodeComponent(query.trim())}&source=$source&page=1&page_size=20',
    );
    return _extractList(result['data']).map(Playlist.fromJson).toList();
  }

  Future<List<Song>> getPersonalFm() async {
    final result =
        await _get('/recommend/personal-fm?t=${DateTime.now().millisecondsSinceEpoch}');
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  Future<List<Song>> getRecommendNewSongs(
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    final result = await _get(
      '/recommend/new-songs?source=$source&page=$page&page_size=30',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  Future<List<Playlist>> getRecommendPlaylists(
      {String source = ApiConfig.defaultSource}) async {
    // /recommend/playlists 服务端未实现 (501)，改用分类歌单 + 搜索兜底
    try {
      final catsResult =
          await _get('/playlists/categories/${Uri.encodeComponent(source)}');
      final catsData = catsResult['data'];
      final categories = _extractList(catsData);
      if (categories.isEmpty && catsData is List) {
        categories.addAll(
          catsData
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
              .whereType<Map<String, dynamic>>(),
        );
      }

      for (final cat in categories.take(3)) {
        final catId = cat['id']?.toString() ?? '';
        if (catId.isEmpty) continue;
        final plResult = await _get(
          '/playlists/category/${Uri.encodeComponent(source)}/${Uri.encodeComponent(catId)}?page=1&page_size=10',
        );
        final playlists =
            _extractList(plResult['data']).map(Playlist.fromJson).toList();
        if (playlists.isNotEmpty) return playlists;
      }
    } catch (_) {}

    return searchPlaylists('热门', source: source);
  }

  Future<List<Playlist>> getCategoryPlaylists(
    String categoryId, {
    String source = ApiConfig.defaultSource,
    int page = 1,
  }) async {
    final result = await _get(
      '/playlists/category/${Uri.encodeComponent(source)}/${Uri.encodeComponent(categoryId)}?page=$page&page_size=30',
    );
    return _extractList(result['data']).map(Playlist.fromJson).toList();
  }

  Future<List<Chart>> getCharts({String source = ApiConfig.defaultSource}) async {
    final result = await _get('/charts?source=$source');
    final list = result['data'];
    if (list is List) {
      return list
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .map(Chart.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<Song>> getChartSongs(String chartId,
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    final result = await _get(
      '/charts/songs/${Uri.encodeComponent(source)}/${Uri.encodeComponent(chartId)}?page=$page&page_size=50',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  Future<List<Song>> getPlaylistSongs(String playlistId,
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    final result = await _get(
      '/playlists/songs/${Uri.encodeComponent(source)}/${Uri.encodeComponent(playlistId)}?page=$page&page_size=50',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  Future<String> getSongUrl(Song song) async {
    final result = await _get(
      '/songs/url/${Uri.encodeComponent(song.source)}/${Uri.encodeComponent(song.id)}',
    );
    final data = result['data'];
    if (data is Map && data['url'] != null) {
      return data['url'] as String;
    }
    throw Exception('无法获取播放地址');
  }

  Future<LyricData?> fetchLyrics(Song song) async {
    try {
      final result = await _get(
        '/lyrics/discover?id=${Uri.encodeComponent(song.id)}'
        '&source=${Uri.encodeComponent(song.source)}'
        '&name=${Uri.encodeComponent(song.name)}'
        '&artist=${Uri.encodeComponent(song.artistName)}'
        '&duration_ms=${song.durationMs}',
      );
      final data = result['data'];
      if (data is! Map) return null;

      final map = Map<String, dynamic>.from(data);
      final selected = map['selected'];
      final linesRaw = selected is Map
          ? selected['lines'] ?? map['lines']
          : map['lines'];

      if (linesRaw is List && linesRaw.isNotEmpty) {
        final lines = linesRaw
            .map((e) => e is Map ? _parseLyricLine(Map<String, dynamic>.from(e)) : null)
            .whereType<LyricLine>()
            .where((l) => l.text.isNotEmpty && !LrcParser.isMetaLine(l.text))
            .toList();
        if (lines.isNotEmpty) return LyricData(lines);
      }

      final lrcText = _pickLrcText(map);
      return LrcParser.parse(lrcText);
    } catch (_) {
      return null;
    }
  }

  LyricLine? _parseLyricLine(Map<String, dynamic> json) {
    final text = json['text']?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return LyricLine(
      startMs: Song.parseInt(json['startMs']),
      endMs: Song.parseInt(json['endMs']),
      text: text,
    );
  }

  String? _pickLrcText(Map<String, dynamic> data) {
    final selected = data['selected'];
    if (selected is Map) {
      for (final key in ['lrc', 'lyric', 'rawLrc', 'content']) {
        final v = selected[key]?.toString();
        if (v != null && v.trim().isNotEmpty) return v;
      }
    }
    for (final key in ['lrc', 'lyric', 'rawLrc', 'content']) {
      final v = data[key]?.toString();
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  @Deprecated('Use fetchLyrics')
  Future<String?> discoverLyric(Song song) async {
    final data = await fetchLyrics(song);
    if (data == null || data.isEmpty) return null;
    return data.lines.map((l) => l.text).join('\n');
  }
}
