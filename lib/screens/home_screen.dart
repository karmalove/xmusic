import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    (icon: Icons.explore_rounded, label: '发现'),
    (icon: Icons.search_rounded, label: '搜索'),
    (icon: Icons.library_music_rounded, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _moveToBackground();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [DiscoverScreen(), SearchScreen(), LibraryScreen()],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Selector<PlayerProvider, _MiniPlayerViewModel?>(
              selector: (_, player) {
                final song = player.currentSong;
                if (song == null) return null;
                return _MiniPlayerViewModel(
                  title: song.name,
                  artist: song.artistName,
                  lyric: player.currentLyric,
                  coverUrl: song.cover,
                  isPlaying: player.isPlaying,
                  isLoading: player.isLoading,
                  showLyrics: player.showLyrics,
                  progress: player.progress,
                );
              },
              builder: (context, vm, _) {
                if (vm == null) return const SizedBox.shrink();
                final player = context.read<PlayerProvider>();
                return MiniPlayer(
                  title: vm.title,
                  artist: vm.artist,
                  lyric: vm.lyric,
                  coverUrl: vm.coverUrl,
                  isPlaying: vm.isPlaying,
                  isLoading: vm.isLoading,
                  showLyrics: vm.showLyrics,
                  progress: vm.progress,
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const PlayerScreen(),
                      transitionsBuilder: (_, anim, __, child) {
                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: child,
                        );
                      },
                    ),
                  ),
                  onPlayPause: player.togglePlay,
                  onNext: player.next,
                  onClose: player.stopPlayback,
                );
              },
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (i) => setState(() => _currentIndex = i),
                items: _tabs
                    .map(
                      (t) => BottomNavigationBarItem(
                        icon: Icon(t.icon),
                        label: t.label,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToBackground() async {
    if (!Platform.isAndroid) return;
    try {
      await const MethodChannel('xmusic/app').invokeMethod('moveToBackground');
    } catch (_) {}
  }
}

class _MiniPlayerViewModel {
  final String title;
  final String artist;
  final String? lyric;
  final String? coverUrl;
  final bool isPlaying;
  final bool isLoading;
  final bool showLyrics;
  final double progress;

  const _MiniPlayerViewModel({
    required this.title,
    required this.artist,
    required this.lyric,
    required this.coverUrl,
    required this.isPlaying,
    required this.isLoading,
    required this.showLyrics,
    required this.progress,
  });

  @override
  bool operator ==(Object other) {
    return other is _MiniPlayerViewModel &&
        title == other.title &&
        artist == other.artist &&
        lyric == other.lyric &&
        coverUrl == other.coverUrl &&
        isPlaying == other.isPlaying &&
        isLoading == other.isLoading &&
        showLyrics == other.showLyrics &&
        (progress - other.progress).abs() < 0.02;
  }

  @override
  int get hashCode => Object.hash(
    title,
    artist,
    lyric,
    coverUrl,
    isPlaying,
    isLoading,
    showLyrics,
    (progress * 50).round(),
  );
}
