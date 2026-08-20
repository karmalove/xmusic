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
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final result = await _get(
      '/search/playlists?q=${Uri.encodeComponent(query.trim())}&source=$source&page=$page&page_size=20',
    );
    return _extractList(result['data']).map(Playlist.fromJson).toList();
  }

  Future<List<Album>> searchAlbums(String query,
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final result = await _get(
      '/search/albums?q=${Uri.encodeComponent(query.trim())}&source=$source&page=$page&page_size=20',
    );
    return _extractList(result['data']).map(Album.fromJson).toList();
  }

  Future<List<Artist>> searchArtists(String query,
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final result = await _get(
      '/search/artists?q=${Uri.encodeComponent(query.trim())}&source=$source&page=$page&page_size=20',
    );
    return _extractList(result['data']).map(Artist.fromJson).toList();
  }

  Future<List<String>> searchSuggest(String query,
      {String source = ApiConfig.defaultSource}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final result = await _get(
      '/search/suggest?q=${Uri.encodeComponent(q)}&source=$source',
    );
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['name'] ?? e['keyword'] ?? e['suggest']).toString();
            }
            return '';
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (data is Map) {
      final list = data['suggestions'] ?? data['list'] ?? data['hot'];
      if (list is List) {
        return list
            .map((e) {
              if (e is String) return e;
              if (e is Map) {
                return (e['name'] ?? e['keyword'] ?? e['suggest']).toString();
              }
              return '';
            })
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  Future<List<MusicVideo>> searchMvs(String query,
      {String source = ApiConfig.defaultSource, int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final result = await _get(
      '/search/mvs?q=${Uri.encodeComponent(query.trim())}'
      '&source=$source&page=$page&page_size=20',
    );
    return _extractList(result['data'])
        .map((e) => MusicVideo.fromJson(e, fallbackSource: source))
        .where((m) => m.id.isNotEmpty && m.name.isNotEmpty)
        .map((m) => m.source.isEmpty
            ? MusicVideo(
                id: m.id,
                name: m.name,
                cover: m.cover,
                source: source,
                artist: m.artist,
              )
            : m)
        .toList();
  }

  Future<List<String>> getHotSearch(
      {String source = ApiConfig.defaultSource}) async {
    final result = await _get('/hot-search?source=$source');
    final data = result['data'];
    Iterable raw = const [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      final list = data['hot'] ?? data['list'];
      if (list is List) raw = list;
    }
    return raw
        .map((e) {
          if (e is String) return e;
          if (e is Map) {
            return (e['name'] ?? e['keyword'] ?? e['searchWord']).toString();
          }
          return '';
        })
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  /// 热搜：与官网一致，优先酷我 → 网易云 → QQ → 酷狗。
  static const hotSearchSources = ['kuwo', 'netease', 'qq', 'kugou'];

  Future<List<String>> getHotSearchPreferred() async {
    for (final src in hotSearchSources) {
      try {
        final hot = await getHotSearch(source: src);
        if (hot.isNotEmpty) return hot;
      } catch (_) {}
    }
    return [];
  }

  Future<List<String>> searchSuggestPreferred(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    for (final src in hotSearchSources) {
      try {
        final list = await searchSuggest(q, source: src);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return [];
  }

  /// 官网推荐页私人 FM：`/recommend/personal-fm`（可不带 source）。
  Future<List<Song>> getPersonalFm({String? source}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    final qs = source != null && source.isNotEmpty
        ? 'source=${Uri.encodeComponent(source)}&t=$t'
        : 't=$t';
    final result = await _get('/recommend/personal-fm?$qs');
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  /// 官网推荐页雷达电台：默认优先 qq（与 RecommendView 一致）。
  static const recommendRadioSources = ['qq', 'netease', 'kuwo', 'kugou'];

  Future<List<MusicRadioGroup>> getRadios({String? source}) async {
    final sources = source != null && source.isNotEmpty
        ? [source, ...recommendRadioSources.where((s) => s != source)]
        : recommendRadioSources;
    for (final src in sources) {
      try {
        final result = await _get('/radios/${Uri.encodeComponent(src)}');
        final data = result['data'];
        final rawGroups = data is List
            ? data
            : (data is Map && data['groups'] is List
                ? data['groups'] as List
                : <dynamic>[]);
        final groups = <MusicRadioGroup>[];
        for (final g in rawGroups) {
          if (g is! Map) continue;
          final map = Map<String, dynamic>.from(g);
          final radiosRaw = map['radios'];
          if (radiosRaw is! List) continue;
          final radios = radiosRaw
              .map((e) => e is Map
                  ? RadioStation.fromJson(
                      Map<String, dynamic>.from(e),
                      fallbackSource: src,
                    )
                  : null)
              .whereType<RadioStation>()
              .where((r) => r.id.isNotEmpty && r.name.isNotEmpty)
              .map((r) => r.source.isEmpty
                  ? RadioStation(
                      id: r.id,
                      name: r.name,
                      cover: r.cover,
                      source: src,
                      description: r.description,
                    )
                  : r)
              .toList();
          if (radios.isEmpty) continue;
          groups.add(MusicRadioGroup(
            name: map['name']?.toString() ?? '雷达',
            radios: radios,
          ));
        }
        if (groups.isNotEmpty) return groups;
      } catch (_) {}
    }
    return [];
  }

  Future<List<Song>> getRadioSongs(
    String radioId, {
    String source = 'qq',
    int pageSize = 20,
  }) async {
    final result = await _get(
      '/radios/songs/${Uri.encodeComponent(source)}/${Uri.encodeComponent(radioId)}'
      '?page=1&page_size=$pageSize&t=${DateTime.now().millisecondsSinceEpoch}',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  /// 官网发现页 MV：音源优先 netease → qq → kuwo → kugou。
  static const discoverMvSources = ['netease', 'qq', 'kuwo', 'kugou'];

  Future<List<MusicVideo>> getDiscoverMvs({int limit = 20}) async {
    for (final src in discoverMvSources) {
      try {
        for (final order in ['最新', '']) {
          final qs = StringBuffer(
            'page=1&page_size=$limit',
          );
          if (order.isNotEmpty) {
            qs.write('&order=${Uri.encodeComponent(order)}');
          }
          final result =
              await _get('/mvs/list/${Uri.encodeComponent(src)}?$qs');
          final mvs = _extractList(result['data'])
              .map((e) => MusicVideo.fromJson(e, fallbackSource: src))
              .where((m) => m.id.isNotEmpty && m.name.isNotEmpty)
              .map((m) => m.source.isEmpty
                  ? MusicVideo(
                      id: m.id,
                      name: m.name,
                      cover: m.cover,
                      source: src,
                      artist: m.artist,
                    )
                  : m)
              .take(limit)
              .toList();
          if (mvs.isNotEmpty) return mvs;
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<Song>> getRecommendNewSongs(
      {String source = ApiConfig.defaultSource,
      int page = 1,
      int pageSize = 30}) async {
    final result = await _get(
      '/recommend/new-songs?source=$source&page=$page&page_size=$pageSize',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  Future<List<PlaylistCategory>> getPlaylistCategories({
    String source = ApiConfig.defaultSource,
  }) async {
    final result =
        await _get('/playlists/categories/${Uri.encodeComponent(source)}');
    final catsData = result['data'];
    final categories = _extractList(catsData);
    if (categories.isEmpty && catsData is List) {
      return catsData
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : null)
          .whereType<Map<String, dynamic>>()
          .map(PlaylistCategory.fromJson)
          .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
          .toList();
    }
    return categories
        .map(PlaylistCategory.fromJson)
        .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
        .toList();
  }

  /// 官网发现页音源优先级（与 FreeMusicApp 一致）。
  static const discoverPlaylistSources = ['netease', 'kuwo', 'qq', 'kugou'];
  static const discoverChartSources = ['netease', 'kuwo', 'qq', 'kugou'];
  static const discoverNewSongSources = ['qq', 'netease', 'kuwo', 'kugou'];
  static const playlistSquareDefaultSource = 'netease';

  /// 官网发现页「推荐歌单」：
  /// `categoryPlaylists(firstSource, "全部", 1, 20)`
  Future<List<Playlist>> getDiscoverHomePlaylists() async {
    for (final src in discoverPlaylistSources) {
      try {
        final playlists = await getCategoryPlaylists(
          '全部',
          source: src,
          page: 1,
          pageSize: 20,
        );
        final valid = playlists
            .where((p) => p.id.isNotEmpty && p.name.isNotEmpty)
            .map((p) => p.source.isEmpty
                ? Playlist(
                    id: p.id,
                    name: p.name,
                    cover: p.cover,
                    source: src,
                    songCount: p.songCount,
                    playCount: p.playCount,
                  )
                : p)
            .take(20)
            .toList();
        if (valid.isNotEmpty) return valid;
      } catch (_) {}
    }
    return [];
  }

  /// 兼容旧调用：发现页推荐歌单走官网逻辑。
  Future<List<Playlist>> getRecommendPlaylists(
      {String source = ApiConfig.defaultSource}) {
    return getDiscoverHomePlaylists();
  }

  /// 与官网「榜单精选」匹配的榜名别名。
  static const _featuredChartAliases = [
    ['飙升榜', '云音乐飙升榜', '网易云音乐飙升榜'],
    ['新歌榜', '云音乐新歌榜', '网易云音乐新歌榜'],
    ['热歌榜', '云音乐热歌榜', '网易云音乐热歌榜'],
    ['原创榜', '原创歌曲榜', '网易原创歌曲榜', '云音乐原创榜'],
    ['黑胶VIP爱听榜', '黑胶VIP热歌榜', 'VIP热歌榜', 'VIP爱听榜'],
    ['实时热度榜', '热度榜'],
  ];

  static String _normalizeChartName(String name) {
    return name
        .replaceAll(RegExp(r'[\s\u00a0·•\-—_｜|:：()（）【】\[\]]'), '')
        .toLowerCase();
  }

  Future<List<Playlist>> getCategoryPlaylists(
    String categoryId, {
    String source = ApiConfig.defaultSource,
    int page = 1,
    int pageSize = 30,
  }) async {
    final cat = categoryId.trim().isEmpty ? '全部' : categoryId.trim();
    final result = await _get(
      '/playlists/category/${Uri.encodeComponent(source)}/${Uri.encodeComponent(cat)}?page=$page&page_size=$pageSize',
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
      {String source = ApiConfig.defaultSource,
      int page = 1,
      int pageSize = 50}) async {
    final result = await _get(
      '/charts/songs/${Uri.encodeComponent(source)}/${Uri.encodeComponent(chartId)}?page=$page&page_size=$pageSize',
    );
    return _extractList(result['data']).map(Song.fromJson).toList();
  }

  List<Chart> _pickFeaturedCharts(List<Chart> charts, {int limit = 6}) {
    final selected = <Chart>[];
    final used = <String>{};
    final normalized = charts
        .map((c) => (chart: c, name: _normalizeChartName(c.name)))
        .toList();

    for (final aliases in _featuredChartAliases) {
      final aliasNorms = aliases.map(_normalizeChartName).toList();
      for (final item in normalized) {
        if (item.chart.id.isEmpty || used.contains(item.chart.id)) continue;
        final hit = aliasNorms.any(
          (a) =>
              item.name == a ||
              item.name.contains(a) ||
              a.contains(item.name),
        );
        if (!hit) continue;
        used.add(item.chart.id);
        selected.add(item.chart);
        break;
      }
      if (selected.length >= limit) break;
    }

    if (selected.isEmpty) {
      for (final chart in charts) {
        if (selected.length >= limit) break;
        if (chart.id.isEmpty || used.contains(chart.id)) continue;
        used.add(chart.id);
        selected.add(chart);
      }
    }
    return selected.take(limit).toList();
  }

  /// 官网发现页「榜单精选」：按 xd 音源顺序取第一个有数据的源。
  Future<List<ChartPreview>> getDiscoverChartPreviews({int limit = 6}) async {
    for (final src in discoverChartSources) {
      try {
        final charts = await getCharts(source: src);
        if (charts.isEmpty) continue;
        final targets = _pickFeaturedCharts(charts, limit: limit);
        if (targets.isEmpty) continue;

        final results = await Future.wait(
          targets.map((chart) async {
            final chartSource = chart.source.isEmpty ? src : chart.source;
            try {
              final songs = await getChartSongs(
                chart.id,
                source: chartSource,
                pageSize: 3,
              );
              if (songs.isEmpty) return null;
              return ChartPreview(
                chart: chart.source.isEmpty
                    ? Chart(
                        id: chart.id,
                        name: chart.name,
                        cover: chart.cover,
                        source: src,
                      )
                    : chart,
                topSongs: songs,
              );
            } catch (_) {
              return null;
            }
          }),
        );

        final previews = results.whereType<ChartPreview>().toList();
        if (previews.isNotEmpty) return previews;
      } catch (_) {}
    }
    return [];
  }

  Future<List<ChartPreview>> getChartPreviews({
    String source = ApiConfig.defaultSource,
    int limit = 6,
  }) {
    return getDiscoverChartPreviews(limit: limit);
  }

  /// 官网发现页「新歌」：按 qq → netease → kuwo → kugou 取第一个成功源。
  Future<List<Song>> getDiscoverNewSongs({int limit = 18}) async {
    for (final src in discoverNewSongSources) {
      try {
        final songs = await getRecommendNewSongs(
          source: src,
          page: 1,
          pageSize: limit,
        );
        final valid = songs
            .where((s) => s.id.isNotEmpty && s.name.isNotEmpty)
            .map((s) => s.source.isEmpty
                ? Song(
                    id: s.id,
                    name: s.name,
                    cover: s.cover,
                    source: src,
                    durationMs: s.durationMs,
                    artists: s.artists,
                    album: s.album,
                    playable: s.playable,
                    playUrl: s.playUrl,
                  )
                : s)
            .take(limit)
            .toList();
        if (valid.isNotEmpty) return valid;
      } catch (_) {}
    }
    return [];
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
