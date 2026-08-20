import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/play_history.dart';
import '../models/song.dart';

class PlayHistoryService {
  static const _storageKey = 'xmusic_play_history_v1';
  static const _maxItems = 200;

  Future<List<PlayHistoryItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e is Map
              ? PlayHistoryItem.fromJson(Map<String, dynamic>.from(e))
              : null)
          .whereType<PlayHistoryItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<PlayHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  List<PlayHistoryItem> record(List<PlayHistoryItem> current, Song song) {
    final now = DateTime.now();
    final existingIndex =
        current.indexWhere((e) => e.song.uniqueKey == song.uniqueKey);

    final next = [...current];
    if (existingIndex >= 0) {
      final old = next.removeAt(existingIndex);
      next.insert(
        0,
        old.copyWith(playedAt: now, playCount: old.playCount + 1),
      );
    } else {
      next.insert(0, PlayHistoryItem(song: song, playedAt: now));
    }

    if (next.length > _maxItems) {
      return next.sublist(0, _maxItems);
    }
    return next;
  }
}
