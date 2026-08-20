import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/common_widgets.dart';
import 'charts_screen.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'liked_music_screen.dart';
import 'local_music_screen.dart';
import 'mv_screen.dart';
import 'player_screen.dart';
import 'playlists_screen.dart';
import 'recent_play_screen.dart';
import 'recommend_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppNavItem _nav = AppNavItem.discover;

  static const _wideBreakpoint = 800.0;

  Widget _pageFor(AppNavItem item) {
    switch (item) {
      case AppNavItem.discover:
        return DiscoverScreen(
          onOpenRecommend: () => setState(() => _nav = AppNavItem.recommend),
          onOpenCharts: () => setState(() => _nav = AppNavItem.charts),
          onOpenPlaylists: () => setState(() => _nav = AppNavItem.playlists),
          onOpenMv: () => setState(() => _nav = AppNavItem.mv),
        );
      case AppNavItem.recommend:
        return const RecommendScreen();
      case AppNavItem.playlists:
        return const PlaylistsScreen();
      case AppNavItem.mv:
        return const MvScreen();
      case AppNavItem.charts:
        return const ChartsScreen();
      case AppNavItem.recent:
        return const RecentPlayScreen();
      case AppNavItem.local:
        return const LocalMusicScreen();
      case AppNavItem.liked:
        return const LikedMusicScreen();
      case AppNavItem.search:
        return const SearchScreen();
      case AppNavItem.settings:
        return const LibraryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _moveToBackground();
      },
      child: Scaffold(
        drawer: wide
            ? null
            : Drawer(
                backgroundColor: AppColors.surface,
                child: AppSidebar(
                  selected: _nav,
                  onSelect: (item) {
                    setState(() => _nav = item);
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
        body: Column(
          children: [
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        AppSidebar(
                          selected: _nav,
                          onSelect: (item) => setState(() => _nav = item),
                        ),
                        Expanded(child: _pageFor(_nav)),
                      ],
                    )
                  : Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                            child: Row(
                              children: [
                                Builder(
                                  builder: (context) => IconButton(
                                    icon: const Icon(Icons.menu_rounded),
                                    onPressed: () =>
                                        Scaffold.of(context).openDrawer(),
                                  ),
                                ),
                                Text(
                                  _mobileTitle(_nav),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: _pageFor(_nav)),
                      ],
                    ),
            ),
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
            if (!wide)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _mobileTabIndex(_nav),
                  onTap: (i) => setState(() => _nav = _mobileTabItem(i)),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.explore_outlined),
                      label: '发现',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.emoji_events_outlined),
                      label: '排行',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search_rounded),
                      label: '搜索',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.library_music_rounded),
                      label: '我的',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _mobileTitle(AppNavItem item) {
    switch (item) {
      case AppNavItem.discover:
        return '发现';
      case AppNavItem.playlists:
        return '歌单';
      case AppNavItem.mv:
        return 'MV';
      case AppNavItem.recommend:
        return '推荐';
      case AppNavItem.charts:
        return '排行榜';
      case AppNavItem.recent:
        return '最近播放';
      case AppNavItem.local:
        return '本地音乐';
      case AppNavItem.liked:
        return '我喜欢的音乐';
      case AppNavItem.search:
        return '搜索';
      case AppNavItem.settings:
        return '设置';
    }
  }

  int _mobileTabIndex(AppNavItem item) {
    switch (item) {
      case AppNavItem.discover:
      case AppNavItem.playlists:
      case AppNavItem.mv:
      case AppNavItem.recommend:
        return 0;
      case AppNavItem.charts:
        return 1;
      case AppNavItem.search:
        return 2;
      case AppNavItem.settings:
      case AppNavItem.recent:
      case AppNavItem.local:
      case AppNavItem.liked:
        return 3;
    }
  }

  AppNavItem _mobileTabItem(int index) {
    switch (index) {
      case 0:
        return AppNavItem.discover;
      case 1:
        return AppNavItem.charts;
      case 2:
        return AppNavItem.search;
      default:
        return AppNavItem.settings;
    }
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
