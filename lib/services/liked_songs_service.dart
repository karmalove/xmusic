import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

class LikedSongsService {
  static const _storageKey = 'xmusic_liked_songs_v1';
  static const _maxItems = 500;

  Future<List<Song>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e is Map ? Song.fromJson(Map<String, dynamic>.from(e)) : null)
          .whereType<Song>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(songs.map((e) => e.toJson()).toList()),
    );
  }

  List<Song> toggle(List<Song> current, Song song) {
    final next = [...current];
    final index = next.indexWhere((s) => s.uniqueKey == song.uniqueKey);
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.insert(0, song);
      if (next.length > _maxItems) {
        return next.sublist(0, _maxItems);
      }
    }
    return next;
  }

  bool contains(List<Song> current, Song song) =>
      current.any((s) => s.uniqueKey == song.uniqueKey);
}
