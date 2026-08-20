class Artist {
  final String id;
  final String name;
  final String source;

  const Artist({required this.id, required this.name, this.source = ''});

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'source': source};
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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
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
    final artists = artistsRaw is List
        ? artistsRaw
              .map(
                (e) => e is Map
                    ? Artist.fromJson(Map<String, dynamic>.from(e))
                    : null,
              )
              .whereType<Artist>()
              .toList()
        : <Artist>[];

    return Song(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      durationMs: parseInt(json['durationMs']),
      artists: artists,
      album: Album.fromJson(
        json['album'] is Map
            ? Map<String, dynamic>.from(json['album'] as Map)
            : null,
      ),
      playable: json['playable'] != false,
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
  };

  String get uniqueKey => '$source:$id';

  static int parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString().split('.').first ?? '0') ?? 0;
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

  const Playlist({
    required this.id,
    required this.name,
    this.cover = '',
    this.source = '',
    this.songCount = 0,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['title']?.toString() ?? '',
    cover: json['cover']?.toString() ?? json['pic']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
    songCount: Song.parseInt(json['songCount'] ?? json['trackCount']),
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
