class Artist {
  final String id;
  final String name;
  final String source;
  final String cover;

  const Artist({
    required this.id,
    required this.name,
    this.source = '',
    this.cover = '',
  });

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
    cover: json['cover']?.toString() ??
        json['pic']?.toString() ??
        json['avatar']?.toString() ??
        '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'cover': cover,
  };
}

class Album {
  final String id;
  final String name;
  final String cover;
  final String source;

  const Album({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
  });

  factory Album.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Album(id: '', name: '');
    return Album(
      id: json['id']?.toString() ??
          json['albumid']?.toString() ??
          json['albumId']?.toString() ??
          '',
      name: json['name']?.toString() ?? json['albumname']?.toString() ?? '',
      cover: json['cover']?.toString() ??
          json['pic']?.toString() ??
          json['img']?.toString() ??
          '',
      source: json['source']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cover': cover,
    'source': source,
  };
}

class Song {
  final String id;
  final String name;
  final String cover;
  final String source;
  final int durationMs;
  final List<Artist> artists;
  final Album album;
  final bool playable;
  String? playUrl;

  Song({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
    this.durationMs = 0,
    this.artists = const [],
    this.album = const Album(id: '', name: ''),
    this.playable = true,
    this.playUrl,
  });

  String get artistName =>
      artists.map((a) => a.name).where((n) => n.isNotEmpty).join(' / ');

  String get durationText {
    final totalSec = durationMs ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final artistsRaw = json['artists'];
    var artists = artistsRaw is List
        ? artistsRaw
              .map(
                (e) => e is Map
                    ? Artist.fromJson(Map<String, dynamic>.from(e))
                    : null,
              )
              .whereType<Artist>()
              .toList()
        : <Artist>[];

    if (artists.isEmpty) {
      final text = json['artistsText']?.toString() ??
          json['artist']?.toString() ??
          '';
      if (text.isNotEmpty) {
        artists = [
          Artist(
            id: '',
            name: text,
            source: json['source']?.toString() ?? '',
          ),
        ];
      }
    }

    return Song(
      id: json['mediaId']?.toString() ??
          json['id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      durationMs: parseInt(
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
      playUrl: json['playUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cover': cover,
    'source': source,
    'durationMs': durationMs,
    'artists': artists.map((a) => a.toJson()).toList(),
    'album': album.toJson(),
    'playable': playable,
    if (playUrl != null) 'playUrl': playUrl,
  };

  String get uniqueKey => '$source:$id';

  bool get isLocal => source == 'local';

  static int parseInt(dynamic value, {bool treatSmallAsSeconds = false}) {
    if (value is int) {
      if (treatSmallAsSeconds && value > 0 && value < 10000) return value * 1000;
      return value;
    }
    if (value is double) {
      final n = value.round();
      if (treatSmallAsSeconds && n > 0 && n < 10000) return n * 1000;
      return n;
    }
    final n = int.tryParse(value?.toString().split('.').first ?? '0') ?? 0;
    if (treatSmallAsSeconds && n > 0 && n < 10000) return n * 1000;
    return n;
  }

  Song copyWith({String? playUrl}) => Song(
    id: id,
    name: name,
    cover: cover,
    source: source,
    durationMs: durationMs,
    artists: artists,
    album: album,
    playable: playable,
    playUrl: playUrl ?? this.playUrl,
  );
}

class Playlist {
  final String id;
  final String name;
  final String cover;
  final String source;
  final int songCount;
  final int playCount;

  const Playlist({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
    this.songCount = 0,
    this.playCount = 0,
  });

  String get uniqueKey => '$source:$id';

  String get playCountText {
    if (playCount <= 0) {
      if (songCount <= 0) return '';
      return '$songCount 首';
    }
    if (playCount >= 100000000) {
      return '${(playCount / 100000000).toStringAsFixed(1)}亿';
    }
    if (playCount >= 10000) {
      return '${(playCount / 10000).toStringAsFixed(1)}万';
    }
    return '$playCount';
  }

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['title']?.toString() ?? '',
    cover: json['cover']?.toString() ?? json['pic']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
    songCount: Song.parseInt(json['songCount'] ?? json['trackCount']),
    playCount: Song.parseInt(
      json['playCount'] ?? json['playcount'] ?? json['listenCount'] ?? json['heat'],
    ),
  );
}

class Chart {
  final String id;
  final String name;
  final String cover;
  final String source;

  const Chart({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
  });

  factory Chart.fromJson(Map<String, dynamic> json) => Chart(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['title']?.toString() ?? '',
    cover: json['cover']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
  );
}

class ChartPreview {
  final Chart chart;
  final List<Song> topSongs;

  const ChartPreview({required this.chart, required this.topSongs});
}

class PlaylistCategory {
  final String id;
  final String name;

  const PlaylistCategory({required this.id, required this.name});

  factory PlaylistCategory.fromJson(Map<String, dynamic> json) =>
      PlaylistCategory(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      );
}

class RadioStation {
  final String id;
  final String name;
  final String cover;
  final String source;
  final String description;

  const RadioStation({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
    this.description = '',
  });

  factory RadioStation.fromJson(Map<String, dynamic> json, {String fallbackSource = ''}) =>
      RadioStation(
        id: json['id']?.toString() ??
            json['radioId']?.toString() ??
            json['radio_id']?.toString() ??
            '',
        name: json['name']?.toString() ?? json['title']?.toString() ?? '',
        cover: json['cover']?.toString() ??
            json['pic_url']?.toString() ??
            json['pic']?.toString() ??
            json['image']?.toString() ??
            '',
        source: json['source']?.toString() ??
            json['provider']?.toString() ??
            json['platform']?.toString() ??
            fallbackSource,
        description: json['description']?.toString() ??
            json['desc']?.toString() ??
            '',
      );
}

class MusicRadioGroup {
  final String name;
  final List<RadioStation> radios;

  const MusicRadioGroup({required this.name, required this.radios});
}

class MusicVideo {
  final String id;
  final String name;
  final String cover;
  final String source;
  final String artist;

  const MusicVideo({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
    this.artist = '',
  });

  factory MusicVideo.fromJson(Map<String, dynamic> json, {String fallbackSource = ''}) {
    var artist = json['artist']?.toString() ?? '';
    final artistsRaw = json['artists'];
    if (artist.isEmpty && artistsRaw is List) {
      artist = artistsRaw
          .map((e) => e is Map ? e['name']?.toString() ?? '' : e.toString())
          .where((s) => s.isNotEmpty)
          .join(' / ');
    }
    return MusicVideo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ??
          json['pic']?.toString() ??
          json['img']?.toString() ??
          '',
      source: json['source']?.toString() ?? fallbackSource,
      artist: artist,
    );
  }
}
