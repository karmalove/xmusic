import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lyric.dart';
import '../models/play_history.dart';
import '../models/song.dart';
import '../config/music_source_config.dart';
import '../services/liked_songs_service.dart';
import '../services/macos_tray_service.dart';
import '../services/music_api_service.dart';
import '../services/play_history_service.dart';
import '../services/youtube_music_api_service.dart';

enum PlayerRepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _prefBackground = 'xmusic_background_playback';
  static const _prefShowLyrics = 'xmusic_show_lyrics';
  static const _prefShowTraySong = 'xmusic_show_tray_song';

  final MusicApiService _api = MusicApiService.instance;
  final AudioPlayer _player = AudioPlayer();
  final PlayHistoryService _historyService = PlayHistoryService();
  final LikedSongsService _likedService = LikedSongsService();
  final Map<String, LyricData?> _lyricCache = {};

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<ProcessingState>? _processingStateSub;

  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;
  int _playGeneration = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.all;
  bool _shuffle = false;
  String? _error;
  LyricData? _lyrics;
  bool _lyricsLoading = false;
  String? _lyricsSongKey;
  List<PlayHistoryItem> _history = [];
  List<Song> _liked = [];
  bool _backgroundPlayback = false;
  bool _showLyrics = true;
  bool _showTraySong = false;
  bool _stopping = false;

  int _lastNotifiedSecond = -1;
  int _lastLyricIndex = -1;
  int _lastProgressMilli = -1;
  bool _lastTrayPlaying = false;
  String? _lastTraySongKey;

  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  PlayerRepeatMode get repeatMode => _repeatMode;
  bool get shuffle => _shuffle;
  String? get error => _error;
  LyricData? get lyrics => _lyrics;
  bool get lyricsLoading => _lyricsLoading;
  List<PlayHistoryItem> get history => _history;
  List<Song> get historySongs => _history.map((e) => e.song).toList();
  List<Song> get likedSongs => _liked;
  bool get backgroundPlayback => _backgroundPlayback;
  bool get showLyrics => _showLyrics;
  bool get showTraySong => _showTraySong;

  String? get currentLyric {
    if (!_showLyrics || _lyrics == null || _lyrics!.isEmpty) return null;
    final index = _lyrics!.indexAt(_position.inMilliseconds);
    if (index < 0) return null;
    return _lyrics!.lines[index].text;
  }

  double get progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  PlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    WidgetsBinding.instance.addObserver(this);
    _history = await _historyService.load();
    _liked = await _likedService.load();
    final prefs = await SharedPreferences.getInstance();
    _backgroundPlayback = prefs.getBool(_prefBackground) ?? true;
    _showLyrics = prefs.getBool(_prefShowLyrics) ?? true;
    _showTraySong = prefs.getBool(_prefShowTraySong) ?? false;
    notifyListeners();

    MacosTrayService.instance.init(
      onNext: next,
      onTogglePlay: togglePlay,
      onPrevious: previous,
      onShowWindow: _showMainWindow,
    );
    _syncTray();

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Windows 等桌面端 audio_session 可能不可用，不影响播放
    }

    _playerStateSub = _player.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      _isLoading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (wasPlaying != _isPlaying || !_isLoading) {
        notifyListeners();
        _syncTray();
      } else if (_isLoading) {
        notifyListeners();
      }
    });

    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      _maybeNotifyPosition(pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _processingStateSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  void _maybeNotifyPosition(Duration pos) {
    final sec = pos.inSeconds;
    final progressMilli = _duration.inMilliseconds > 0
        ? (pos.inMilliseconds * 20 / _duration.inMilliseconds).floor()
        : 0;

    var shouldNotify = false;

    if (sec != _lastNotifiedSecond) {
      _lastNotifiedSecond = sec;
      shouldNotify = true;
    }

    if (progressMilli != _lastProgressMilli) {
      _lastProgressMilli = progressMilli;
      shouldNotify = true;
    }

    if (_showLyrics && _lyrics != null && !_lyrics!.isEmpty) {
      final idx = _lyrics!.indexAt(pos.inMilliseconds);
      if (idx != _lastLyricIndex) {
        _lastLyricIndex = idx;
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  void _resetPositionTrackers() {
    _lastNotifiedSecond = -1;
    _lastProgressMilli = -1;
    _lastLyricIndex = -1;
  }

  void _syncTray() {
    final songKey = _currentSong == null
        ? null
        : '${_currentSong!.source}:${_currentSong!.id}';
    if (songKey == _lastTraySongKey && _isPlaying == _lastTrayPlaying) {
      return;
    }
    _lastTraySongKey = songKey;
    _lastTrayPlaying = _isPlaying;

    MacosTrayService.instance.updatePlayback(
      song: _currentSong,
      isPlaying: _isPlaying,
      showTitleInBar: _showTraySong,
    );
  }

  Future<void> _showMainWindow() async {
    if (!Platform.isMacOS) return;
    try {
      await MacosTrayService.instance.showWindow();
    } catch (_) {}
  }

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0}) async {
    final gen = ++_playGeneration;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      // 先停掉上一首，避免旧缓冲占死
      try {
        await _player.stop();
      } catch (_) {}

      if (queue != null) {
        _playlist = queue;
        _currentIndex = index;
      } else if (!_playlist.any((s) => s.id == song.id)) {
        _playlist = [song];
        _currentIndex = 0;
      } else {
        _currentIndex = _playlist.indexWhere((s) => s.id == song.id);
      }

      _currentSong = song;
      _resetPositionTrackers();
      notifyListeners();
      _syncTray();

      if (song.isLocal) {
        _lyrics = null;
        _lyricsLoading = false;
        _lyricCache[song.uniqueKey] = null;
      } else {
        // 歌词异步，不阻塞起播
        unawaited(_loadLyrics(song));
      }

      if (gen != _playGeneration) return;

      if (song.isLocal && song.playUrl != null) {
        await _player.setFilePath(song.playUrl!);
      } else if (song.playUrl != null &&
          (song.playUrl!.startsWith('http://') ||
              song.playUrl!.startsWith('https://'))) {
        await _setRemoteUrl(song, song.playUrl!);
      } else {
        final url = await _api.getSongUrl(song);
        if (gen != _playGeneration) return;
        await _setRemoteUrl(song, url);
      }

      if (gen != _playGeneration) return;
      await _player.play();
      await _recordHistory(song);
    } catch (e) {
      if (gen != _playGeneration) return;
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// YouTube：先无 header 起播（避免 just_audio 本地代理卡死），失败再带 header。
  Future<void> _setRemoteUrl(Song song, String url) async {
    final isYt = MusicSourceConfig.isYoutube(song.source) ||
        url.contains('googlevideo.com');

    if (!isYt) {
      await _player
          .setUrl(url)
          .timeout(const Duration(seconds: 20));
      return;
    }

    try {
      await _player
          .setUrl(url)
          .timeout(const Duration(seconds: 15));
      return;
    } catch (_) {
      await _player
          .setUrl(url, headers: YoutubeMusicApiService.playbackHeaders)
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    await playSong(songs[startIndex], queue: songs, index: startIndex);
  }

  Future<void> _loadLyrics(Song song) async {
    final key = '${song.source}:${song.id}';
    _lyricsSongKey = key;

    if (_lyricCache.containsKey(key)) {
      _lyrics = _lyricCache[key];
      _lyricsLoading = false;
      _lastLyricIndex = -1;
      notifyListeners();
      return;
    }

    _lyricsLoading = true;
    _lyrics = null;
    notifyListeners();

    final data = await _api.fetchLyrics(song);
    _lyricCache[key] = data;

    if (_lyricsSongKey == key) {
      _lyrics = data;
      _lyricsLoading = false;
      _lastLyricIndex = -1;
      notifyListeners();
    }
  }

  Future<void> _recordHistory(Song song) async {
    _history = _historyService.record(_history, song);
    notifyListeners();
    await _historyService.save(_history);
  }

  Future<void> removeHistoryItem(String uniqueKey) async {
    _history = _history.where((e) => e.song.uniqueKey != uniqueKey).toList();
    notifyListeners();
    await _historyService.save(_history);
  }

  Future<void> clearHistory() async {
    _history = [];
    notifyListeners();
    await _historyService.save(_history);
  }

  Future<void> playHistory({int startIndex = 0}) async {
    if (_history.isEmpty) return;
    await playQueue(historySongs, startIndex: startIndex);
  }

  bool isLiked(Song song) => _likedService.contains(_liked, song);

  Future<void> toggleLike(Song song) async {
    _liked = _likedService.toggle(_liked, song);
    notifyListeners();
    await _likedService.save(_liked);
  }

  Future<void> playLiked({int startIndex = 0}) async {
    if (_liked.isEmpty) return;
    await playQueue(_liked, startIndex: startIndex);
  }

  /// 播放当前队列中指定下标（对齐网页 playlist panel 点击切歌）。
  Future<void> playAt(int index) async {
    if (_playlist.isEmpty) return;
    final i = index.clamp(0, _playlist.length - 1);
    await playSong(_playlist[i], queue: _playlist, index: i);
  }

  /// 从播放列表移除一首；若删的是当前曲则自动切到下一首或停止。
  Future<void> removeFromPlaylist(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    final removingCurrent = index == _currentIndex;
    final next = List<Song>.from(_playlist)..removeAt(index);
    if (next.isEmpty) {
      await stopPlayback();
      return;
    }
    _playlist = next;
    if (removingCurrent) {
      final newIndex = index.clamp(0, next.length - 1);
      await playSong(next[newIndex], queue: next, index: newIndex);
    } else {
      if (index < _currentIndex) _currentIndex -= 1;
      notifyListeners();
    }
  }

  /// 清空播放列表并停止（对齐网页 clearAll）。
  Future<void> clearPlaylist() => stopPlayback();

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_shuffle) {
      _currentIndex = (_currentIndex + 1 + _playlist.length) % _playlist.length;
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    await playSong(
      _playlist[_currentIndex],
      queue: _playlist,
      index: _currentIndex,
    );
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await playSong(
      _playlist[_currentIndex],
      queue: _playlist,
      index: _currentIndex,
    );
  }

  void toggleRepeat() {
    _repeatMode = switch (_repeatMode) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void _onSongCompleted() {
    if (_stopping || _currentSong == null) return;
    if (_repeatMode == PlayerRepeatMode.one && _currentSong != null) {
      playSong(_currentSong!);
      return;
    }
    if (_repeatMode == PlayerRepeatMode.off &&
        _currentIndex >= _playlist.length - 1) {
      return;
    }
    next();
  }

  Future<void> setBackgroundPlayback(bool enabled) async {
    _backgroundPlayback = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefBackground, enabled);
  }

  Future<void> setShowLyrics(bool enabled) async {
    _showLyrics = enabled;
    _lastLyricIndex = -1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefShowLyrics, enabled);
  }

  Future<void> setShowTraySong(bool enabled) async {
    _showTraySong = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefShowTraySong, enabled);
    _lastTraySongKey = null;
    _syncTray();
  }

  void toggleShowLyrics() => setShowLyrics(!_showLyrics);

  Future<void> stopPlayback() async {
    _stopping = true;
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
    _isLoading = false;
    _currentSong = null;
    _playlist = [];
    _currentIndex = 0;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lyrics = null;
    _stopping = false;
    _resetPositionTrackers();
    notifyListeners();
    _lastTraySongKey = null;
    _syncTray();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 桌面端窗口失焦/最小化不应打断播放；后台开关仅作用于移动端。
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return;
    if (_backgroundPlayback) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _processingStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
