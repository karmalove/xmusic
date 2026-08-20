import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/music_source_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/cover_image.dart';
import '../widgets/common_widgets.dart';
import '../widgets/xmusic_wordmark.dart';
import 'playlist_detail_screen.dart';

/// 对齐官网 FreeMusicApp `hv()`：推荐歌单 / 榜单精选 / 新歌 / MV。
class DiscoverScreen extends StatefulWidget {
  final VoidCallback? onOpenRecommend;
  final VoidCallback? onOpenCharts;
  final VoidCallback? onOpenPlaylists;
  final VoidCallback? onOpenMv;

  const DiscoverScreen({
    super.key,
    this.onOpenRecommend,
    this.onOpenCharts,
    this.onOpenPlaylists,
    this.onOpenMv,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MusicApiService _api = MusicApiService.instance;
  final ScrollController _scrollController = ScrollController();
  MusicSourceProvider? _sourceProvider;

  List<Song> _newSongs = [];
  List<Playlist> _playlists = [];
  List<ChartPreview> _chartPreviews = [];
  List<MusicVideo> _mvs = [];
  bool _loading = true;
  String? _error;

  final _newSongsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceProvider = context.read<MusicSourceProvider>();
      _sourceProvider!.addListener(_onSourceChanged);
      _load();
    });
  }

  @override
  void dispose() {
    _sourceProvider?.removeListener(_onSourceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    if (mounted) _load();
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

      // 与官网 hv() 一致：并行拉歌单 / 榜单 / 新歌 / MV。
      final results = await Future.wait([
        _safeCall('homePlaylists', () => _api.getDiscoverHomePlaylists()),
        _safeCall('chartPreviews', () => _api.getDiscoverChartPreviews(limit: 6)),
        _safeCall('newSongs', () => _api.getDiscoverNewSongs(limit: 18)),
        _safeCall('mvs', () => _api.getDiscoverMvs(limit: 20)),
      ]);

      final playlists = results[0] as List<Playlist>? ?? [];
      final chartPreviews = results[1] as List<ChartPreview>? ?? [];
      final newSongs = results[2] as List<Song>? ?? [];
      final mvs = results[3] as List<MusicVideo>? ?? [];

      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _chartPreviews = chartPreviews;
        _newSongs = newSongs;
        _mvs = mvs;
        _loading = false;
        if (playlists.isEmpty &&
            chartPreviews.isEmpty &&
            newSongs.isEmpty &&
            mvs.isEmpty) {
          _error = '无法加载音乐数据，请检查网络后下拉刷新';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  void _playSong(Song song, List<Song> queue) {
    context.read<PlayerProvider>().playSong(
          song,
          queue: queue,
          index: queue.indexOf(song),
        );
  }

  void _openPlaylist(Playlist pl) {
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
  }

  void _openChart(Chart chart) {
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
  }

  Future<void> _playDailyOrFm() async {
    // 每日推荐 / 私人 FM → 官网切到推荐页并播私人 FM。
    if (widget.onOpenRecommend != null) {
      widget.onOpenRecommend!();
      return;
    }
    try {
      final songs = await _api.getPersonalFm();
      if (songs.isNotEmpty && mounted) {
        _playSong(songs.first, songs);
      }
    } catch (_) {}
  }

  void _scrollToNewSongs() {
    if (_newSongs.isEmpty) return;
    final ctx = _newSongsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      _playSong(_newSongs.first, _newSongs);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            title: const Align(
              alignment: Alignment.centerLeft,
              child: XmusicWordmark(height: 20),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_error != null &&
              _newSongs.isEmpty &&
              _playlists.isEmpty &&
              _chartPreviews.isEmpty &&
              _mvs.isEmpty)
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
            SliverToBoxAdapter(
              child: _EntryCards(
                onDaily: _playDailyOrFm,
                onNewSongs: _scrollToNewSongs,
                onPersonalFm: _playDailyOrFm,
                onCharts: () => widget.onOpenCharts?.call(),
              ),
            ),
            if (_playlists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: '推荐歌单',
                  onMore: widget.onOpenPlaylists,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _playlists.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final pl = _playlists[i];
                      return PlaylistCard(
                        title: pl.name,
                        coverUrl: pl.cover,
                        badgeText: pl.playCountText,
                        onTap: () => _openPlaylist(pl),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_chartPreviews.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: '榜单精选',
                  onMore: widget.onOpenCharts,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width >= 720 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final preview = _chartPreviews[i];
                    return _ChartPreviewCard(
                      preview: preview,
                      onTap: () => _openChart(preview.chart),
                      onPlaySong: (song) {
                        _playSong(song, preview.topSongs);
                      },
                    );
                  }, childCount: _chartPreviews.length),
                ),
              ),
            ],
            if (_newSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                key: _newSongsKey,
                child: const SectionHeader(title: '新歌推荐'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final song = _newSongs[i];
                  return SongTile(
                    index: i + 1,
                    title: song.name,
                    subtitle: song.artistName,
                    coverUrl: song.cover,
                    trailing: song.durationText,
                    onTap: () => _playSong(song, _newSongs),
                  );
                }, childCount: _newSongs.length.clamp(0, 18)),
              ),
            ],
            if (_mvs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'MV 推荐',
                  onMore: widget.onOpenMv,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _mvs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final mv = _mvs[i];
                      return _MvCard(
                        mv: mv,
                        onTap: () {
                          // MV 详情播放地址需额外接口；先跳转到 MV 页。
                          widget.onOpenMv?.call();
                        },
                      );
                    },
                  ),
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

class _EntryCards extends StatelessWidget {
  final VoidCallback onDaily;
  final VoidCallback onNewSongs;
  final VoidCallback onPersonalFm;
  final VoidCallback onCharts;

  const _EntryCards({
    required this.onDaily,
    required this.onNewSongs,
    required this.onPersonalFm,
    required this.onCharts,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        title: '每日推荐',
        subtitle: '根据你的口味生成',
        colors: const [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
        onTap: onDaily,
      ),
      (
        title: '新歌首发',
        subtitle: '抢先听最新单曲',
        colors: const [Color(0xFFF5AF19), Color(0xFFF12711)],
        onTap: onNewSongs,
      ),
      (
        title: '私人FM',
        subtitle: '懂你的音乐电台',
        colors: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
        onTap: onPersonalFm,
      ),
      (
        title: '排行榜',
        subtitle: '实时热门音乐',
        colors: const [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
        onTap: onCharts,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _EntryCard(
                      title: cards[i].title,
                      subtitle: cards[i].subtitle,
                      colors: cards[i].colors,
                      onTap: cards[i].onTap,
                    ),
                  ),
                ],
              ],
            );
          }
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final c in cards)
                _EntryCard(
                  title: c.title,
                  subtitle: c.subtitle,
                  colors: c.colors,
                  onTap: c.onTap,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _EntryCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MvCard extends StatelessWidget {
  final MusicVideo mv;
  final VoidCallback onTap;

  const _MvCard({required this.mv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    mv.cover.isNotEmpty
                        ? CoverNetworkImage(url: mv.cover, fit: BoxFit.cover)
                        : Container(color: AppColors.surface),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mv.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (mv.artist.isNotEmpty)
              Text(
                mv.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPreviewCard extends StatelessWidget {
  final ChartPreview preview;
  final VoidCallback onTap;
  final ValueChanged<Song> onPlaySong;

  const _ChartPreviewCard({
    required this.preview,
    required this.onTap,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    final chart = preview.chart;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: chart.cover.isNotEmpty
                          ? CoverNetworkImage(
                              url: chart.cover,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.background,
                              child: const Icon(
                                Icons.emoji_events_outlined,
                                color: AppColors.textMuted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chart.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: preview.topSongs.length.clamp(0, 3),
                  itemBuilder: (_, i) {
                    final song = preview.topSongs[i];
                    return InkWell(
                      onTap: () => onPlaySong(song),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                song.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
