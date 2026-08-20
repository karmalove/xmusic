import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';

typedef TrayAction = Future<void> Function();

/// Bridges Flutter playback state to the macOS menu-bar status item.
class MacosTrayService {
  MacosTrayService._();

  static final MacosTrayService instance = MacosTrayService._();

  static const _channel = MethodChannel('xmusic/tray');

  TrayAction? onNext;
  TrayAction? onTogglePlay;
  TrayAction? onPrevious;
  TrayAction? onShowWindow;

  bool _ready = false;
  String? _lastTitle;
  String? _lastArtist;
  bool? _lastPlaying;
  bool? _lastShowTitleInBar;

  void init({
    required TrayAction onNext,
    required TrayAction onTogglePlay,
    required TrayAction onPrevious,
    required TrayAction onShowWindow,
  }) {
    if (!Platform.isMacOS) return;

    this.onNext = onNext;
    this.onTogglePlay = onTogglePlay;
    this.onPrevious = onPrevious;
    this.onShowWindow = onShowWindow;

    _channel.setMethodCallHandler(_handleCall);
    _ready = true;
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'next':
        await onNext?.call();
        return null;
      case 'togglePlay':
        await onTogglePlay?.call();
        return null;
      case 'previous':
        await onPrevious?.call();
        return null;
      case 'showWindow':
        await onShowWindow?.call();
        return null;
      default:
        throw PlatformException(code: 'unimplemented', message: call.method);
    }
  }

  Future<void> updatePlayback({
    Song? song,
    required bool isPlaying,
    required bool showTitleInBar,
  }) async {
    if (!_ready || !Platform.isMacOS) return;

    final title = song?.name;
    final artist = song?.artistName;
    if (title == _lastTitle &&
        artist == _lastArtist &&
        isPlaying == _lastPlaying &&
        showTitleInBar == _lastShowTitleInBar) {
      return;
    }
    _lastTitle = title;
    _lastArtist = artist;
    _lastPlaying = isPlaying;
    _lastShowTitleInBar = showTitleInBar;

    try {
      await _channel.invokeMethod('updatePlayback', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'showTitleInBar': showTitleInBar,
      });
    } catch (e) {
      debugPrint('MacosTrayService.updatePlayback failed: $e');
    }
  }

  Future<void> clear() =>
      updatePlayback(song: null, isPlaying: false, showTitleInBar: false);

  Future<void> showWindow() => _channel.invokeMethod('showWindow');
}
