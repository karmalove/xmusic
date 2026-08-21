import 'dart:isolate';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../config/music_source_config.dart';
import '../models/song.dart';

/// YouTube 曲库音源（搜索 + 音频流）。
///
/// 说明：部分地区无法访问 music.youtube.com，因此走 youtube.com 搜索与
/// 音频流解析（youtube_explode_dart），效果接近「用 YouTube 当曲库」。
class YoutubeMusicApiService {
  YoutubeMusicApiService._();

  static final YoutubeMusicApiService instance = YoutubeMusicApiService._();

  static const sourceId = MusicSourceConfig.youtubeSource;

  final YoutubeExplode _yt = YoutubeExplode();

  /// 分页缓存：query → 当前列表游标。
  final Map<String, VideoSearchList> _songPages = {};
  final Map<String, SearchList> _playlistPages = {};
  final Map<String, SearchList> _channelPages = {};

  Future<List<Song>> searchSongs(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final key = 'songs:$q';
    VideoSearchList list;
    if (page <= 1 || !_songPages.containsKey(key)) {
      list = await _yt.search.search(q, filter: TypeFilters.video);
      _songPages[key] = list;
    } else {
      final next = await _songPages[key]!.nextPage();
      if (next == null) return [];
      list = next;
      _songPages[key] = next;
    }

    return list
        .where((v) => !v.isLive)
        .where((v) {
          final d = v.duration;
          if (d == null) return true;
          // 过滤超长合集，保留常见单曲/MV
          return d.inMinutes < 20;
        })
        .map(_videoToSong)
        .toList();
  }

  Future<List<Playlist>> searchPlaylists(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final key = 'pl:$q';
    SearchList list;
    if (page <= 1 || !_playlistPages.containsKey(key)) {
      list = await _yt.search.searchContent(q, filter: TypeFilters.playlist);
      _playlistPages[key] = list;
    } else {
      final next = await _playlistPages[key]!.nextPage();
      if (next == null) return [];
      list = next;
      _playlistPages[key] = next;
    }

    return list.whereType<SearchPlaylist>().map((p) {
      final id = p.id.value;
      final cover = p.thumbnails.isNotEmpty
          ? p.thumbnails.first.url.toString()
          : 'https://img.youtube.com/vi/0/hqdefault.jpg';
      return Playlist(
        id: id,
        name: p.title,
        cover: cover,
        source: sourceId,
        songCount: p.videoCount,
      );
    }).toList();
  }

  Future<List<Artist>> searchArtists(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final key = 'ch:$q';
    SearchList list;
    if (page <= 1 || !_channelPages.containsKey(key)) {
      list = await _yt.search.searchContent(q, filter: TypeFilters.channel);
      _channelPages[key] = list;
    } else {
      final next = await _channelPages[key]!.nextPage();
      if (next == null) return [];
      list = next;
      _channelPages[key] = next;
    }

    return list.whereType<SearchChannel>().map((c) {
      final cover = c.thumbnails.isNotEmpty
          ? c.thumbnails.first.url.toString()
          : '';
      return Artist(
        id: c.id.value,
        name: c.name,
        source: sourceId,
        cover: cover,
      );
    }).toList();
  }

  Future<List<Album>> searchAlbums(String query, {int page = 1}) async {
    // YouTube 无独立专辑索引，用歌单搜索近似
    final playlists = await searchPlaylists(query, page: page);
    return playlists
        .map(
          (p) => Album(
            id: p.id,
            name: p.name,
            cover: p.cover,
            source: sourceId,
          ),
        )
        .toList();
  }

  Future<List<MusicVideo>> searchMvs(String query, {int page = 1}) async {
    final songs = await searchSongs(query, page: page);
    return songs
        .map(
          (s) => MusicVideo(
            id: s.id,
            name: s.name,
            cover: s.cover,
            source: sourceId,
            artist: s.artistName,
          ),
        )
        .toList();
  }

  Future<List<String>> searchSuggest(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      return await _yt.search.getQuerySuggestions(q);
    } catch (_) {
      return [];
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId, {int page = 1}) async {
    if (playlistId.isEmpty) return [];
    final videos = <Video>[];
    var i = 0;
    final start = (page - 1) * 50;
    final end = start + 50;
    await for (final v in _yt.playlists.getVideos(playlistId)) {
      if (i >= end) break;
      if (i >= start) videos.add(v);
      i++;
    }
    return videos.where((v) => !v.isLive).map(_videoToSong).toList();
  }

  /// 解析可播音频 URL（仅 audio-only，绝不返回带画面的 muxed，避免卡死）。
  Future<String> getSongUrl(String videoId) async {
    // 放到独立 isolate，避免 youtube_explode 解析阻塞 UI
    return Isolate.run(() => _resolveAudioUrlInIsolate(videoId)).timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw Exception('YouTube 取流超时，请稍后重试'),
    );
  }

  /// just_audio 播放 googlevideo 时可选 UA（优先无 header，避免本地代理卡死）。
  static const playbackHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
    'Referer': 'https://www.youtube.com/',
  };

  static Future<String> _resolveAudioUrlInIsolate(String videoId) async {
    final yt = YoutubeExplode();
    try {
      // 一次请求即可；ios 客户端通常带 mp4a，不必串行多轮
      final manifest = await yt.videos.streams.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidSdkless,
        ],
      );

      final url = _pickAudioOnlyUrl(manifest);
      if (url == null) {
        throw Exception('该视频没有可播放的音频流（仅支持音频，不支持视频轨）');
      }
      return url;
    } finally {
      yt.close();
    }
  }

  /// 只选音频轨：优先 Apple 友好的 mp4/aac，约 128kbps 便于快速起播。
  static String? _pickAudioOnlyUrl(StreamManifest manifest) {
    final audio = manifest.audioOnly.toList();
    if (audio.isEmpty) return null;

    final apple = audio.where(_isAppleFriendlyAudio).toList();
    final pool = apple.isNotEmpty
        ? apple
        : audio.where((a) => a.container != StreamContainer.webM).toList();
    final candidates = pool.isNotEmpty ? pool : audio;

    const target = 128000;
    candidates.sort((a, b) {
      final da = (a.bitrate.bitsPerSecond - target).abs();
      final db = (b.bitrate.bitsPerSecond - target).abs();
      return da.compareTo(db);
    });
    return candidates.first.url.toString();
  }

  static bool _isAppleFriendlyAudio(AudioOnlyStreamInfo stream) {
    final container = stream.container.name.toLowerCase();
    final codec = stream.audioCodec.toLowerCase();
    if (container == 'webm') return false;
    if (codec.contains('opus') || codec.contains('vorbis')) return false;
    return container == 'mp4' ||
        codec.contains('mp4a') ||
        codec.contains('aac');
  }

  Song _videoToSong(Video v) {
    final id = v.id.value;
    return Song(
      id: id,
      name: v.title,
      cover: v.thumbnails.highResUrl,
      source: sourceId,
      durationMs: v.duration?.inMilliseconds ?? 0,
      artists: [
        Artist(
          id: v.channelId.value,
          name: v.author,
          source: sourceId,
        ),
      ],
      album: const Album(id: '', name: ''),
      playable: true,
    );
  }

  void dispose() {
    _yt.close();
  }
}
