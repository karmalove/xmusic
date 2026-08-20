import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/xmusic_wordmark.dart';
import 'playlist_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MusicApiService _api = MusicApiService.instance;
  List<Song> _personalFm = [];
  List<Song> _newSongs = [];
  List<Playlist> _playlists = [];
  List<Chart> _charts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T?> _safeCall<T>(String name, Future<T> Function() fn) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await fn();
      } catch (e) {
        debugPrint('API $name failed (attempt ${attempt + 1}): $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.ensureReady();

      final results = await Future.wait([
        _safeCall('personalFm', _api.getPersonalFm),
        _safeCall('newSongs', _api.getRecommendNewSongs),
        _safeCall('playlists', _api.getRecommendPlaylists),
        _safeCall('charts', _api.getCharts),
      ]);

      final personalFm = results[0] as List<Song>? ?? [];
      final newSongs = results[1] as List<Song>? ?? [];
      final playlists = results[2] as List<Playlist>? ?? [];
      final charts = results[3] as List<Chart>? ?? [];

      if (mounted) {
        setState(() {
          _personalFm = personalFm;
          _newSongs = newSongs;
          _playlists = playlists;
          _charts = charts;
          _loading = false;
          if (personalFm.isEmpty &&
              newSongs.isEmpty &&
              playlists.isEmpty &&
              charts.isEmpty) {
            _error = '无法加载音乐数据，请检查网络后下拉刷新';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  void _playSong(Song song, List<Song> queue) {
    context.read<PlayerProvider>().playSong(
          song,
          queue: queue,
          index: queue.indexOf(song),
        );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: false,
            backgroundColor: AppColors.background,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Align(
                alignment: Alignment.bottomLeft,
                child: XmusicWordmark(height: 20),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_error != null &&
              _personalFm.isEmpty &&
              _newSongs.isEmpty &&
              _charts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 56,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            if (_personalFm.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _FeaturedCard(
                  song: _personalFm.first,
                  onPlay: () => _playSong(_personalFm.first, _personalFm),
                  onPlayAll: () =>
                      context.read<PlayerProvider>().playQueue(_personalFm),
                ),
              ),
            ],
            if (_charts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: '排行榜',
                  onMore: () {},
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _charts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final chart = _charts[i];
                      return _ChartChip(
                        chart: chart,
                        rank: i + 1,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(
                                title: chart.name,
                                chartId: chart.id,
                                source: chart.source,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_playlists.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: '推荐歌单')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final pl = _playlists[i];
                      return PlaylistCard(
                        title: pl.name,
                        coverUrl: pl.cover,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(
                                title: pl.name,
                                playlistId: pl.id,
                                source: pl.source,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_newSongs.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: '新歌推荐')),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final song = _newSongs[i];
                    return SongTile(
                      index: i + 1,
                      title: song.name,
                      subtitle: song.artistName,
                      coverUrl: song.cover,
                      trailing: song.durationText,
                      onTap: () => _playSong(song, _newSongs),
                    );
                  },
                  childCount: _newSongs.length.clamp(0, 20),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback onPlayAll;

  const _FeaturedCard({
    required this.song,
    required this.onPlay,
    required this.onPlayAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.3,
              child: AlbumCover(url: song.cover, size: 160, radius: 80),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '私人 FM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artistName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.play_arrow_rounded,
                      label: '播放',
                      filled: true,
                      onTap: onPlay,
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: Icons.queue_music_rounded,
                      label: '播放全部',
                      onTap: onPlayAll,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.black : AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartChip extends StatelessWidget {
  final Chart chart;
  final int rank;
  final VoidCallback onTap;

  const _ChartChip({
    required this.chart,
    required this.rank,
    required this.onTap,
  });

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFF9F43),
    Color(0xFF00D9A5),
    Color(0xFF6C5CE7),
    Color(0xFF74B9FF),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Text(
              '$rank',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _colors[(rank - 1) % _colors.length],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                chart.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
