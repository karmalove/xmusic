import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

class LocalMusicProvider extends ChangeNotifier {
  static const _storageKey = 'xmusic_local_music_v1';

  List<Song> _songs = [];
  bool _ready = false;

  List<Song> get songs => _songs;
  bool get isReady => _ready;

  LocalMusicProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _songs = decoded
              .map(
                (e) => e is Map
                    ? Song.fromJson(Map<String, dynamic>.from(e))
                    : null,
              )
              .whereType<Song>()
              .where((s) => s.source == 'local' && s.playUrl != null)
              .where((s) => File(s.playUrl!).existsSync())
              .toList();
        }
      } catch (_) {}
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_songs.map((e) => e.toJson()).toList()),
    );
  }

  Future<int> importFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'm4a',
        'aac',
        'flac',
        'wav',
        'ogg',
        'wma',
        'aiff',
      ],
      allowMultiple: true,
    );
    if (files.isEmpty) return 0;

    var added = 0;
    final next = [..._songs];
    for (final file in files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      if (!File(path).existsSync()) continue;

      final id = path;
      if (next.any((s) => s.id == id)) continue;

      final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      next.add(
        Song(
          id: id,
          name: name.isEmpty ? file.name : name,
          source: 'local',
          artists: const [Artist(id: 'local', name: '本地音乐')],
          playUrl: path,
        ),
      );
      added++;
    }

    if (added > 0) {
      _songs = next;
      notifyListeners();
      await _save();
    }
    return added;
  }

  Future<void> remove(String uniqueKey) async {
    _songs = _songs.where((s) => s.uniqueKey != uniqueKey).toList();
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _songs = [];
    notifyListeners();
    await _save();
  }
}
