import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String title;
  final String? playlistId;
  final String? chartId;
  final String source;

  const PlaylistDetailScreen({
    super.key,
    required this.title,
    this.playlistId,
    this.chartId,
    this.source = 'kuwo',
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final MusicApiService _api = MusicApiService.instance;
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = widget.chartId != null
          ? await _api.getChartSongs(widget.chartId!, source: widget.source)
          : await _api.getPlaylistSongs(
              widget.playlistId!,
              source: widget.source,
            );
      if (mounted) setState(() { _songs = songs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _songs.isNotEmpty ? _songs.first.cover : null;

    return Scaffold(
      body: BlurredCoverBackground(
        imageUrl: coverUrl,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (coverUrl != null)
                      Opacity(
                        opacity: 0.4,
                        child: AlbumCover(
                          url: coverUrl,
                          size: double.infinity,
                          radius: 0,
                          showShadow: false,
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.background.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (coverUrl != null)
                            AlbumCover(url: coverUrl, size: 120, radius: 16),
                          const SizedBox(height: 16),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_songs.length} 首歌曲',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_songs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('暂无歌曲', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _PlayButton(
                        onTap: () => context
                            .read<PlayerProvider>()
                            .playQueue(_songs),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.shuffle_rounded),
                        color: AppColors.textSecondary,
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final song = _songs[i];
                    return SongTile(
                      index: i + 1,
                      title: song.name,
                      subtitle: song.artistName,
                      coverUrl: song.cover,
                      trailing: song.durationText,
                      onTap: () => context.read<PlayerProvider>().playSong(
                            song,
                            queue: _songs,
                            index: i,
                          ),
                    );
                  },
                  childCount: _songs.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.gradientPrimary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
            SizedBox(width: 6),
            Text(
              '播放全部',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
