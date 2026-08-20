import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/music_source_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/cover_image.dart';

class MvScreen extends StatefulWidget {
  const MvScreen({super.key});

  @override
  State<MvScreen> createState() => _MvScreenState();
}

class _MvScreenState extends State<MvScreen> {
  final MusicApiService _api = MusicApiService.instance;
  MusicSourceProvider? _sourceProvider;

  List<Song> _songs = [];
  bool _loading = true;
  String? _error;

  static const _keywords = ['官方MV', 'MV', '音乐视频', '热门MV'];

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
    super.dispose();
  }

  void _onSourceChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final source = context.read<MusicSourceProvider>().catalogSource;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.ensureReady();
      final collected = <Song>[];
      final seen = <String>{};

      for (final keyword in _keywords) {
        final batch = await _api.searchSongs(keyword, source: source);
        for (final song in batch) {
          if (seen.add(song.uniqueKey)) collected.add(song);
        }
        if (collected.length >= 30) break;
      }

      if (!mounted) return;
      setState(() {
        _songs = collected.take(30).toList();
        _loading = false;
        if (_songs.isEmpty) _error = '暂无 MV 内容，请稍后重试';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  void _playSong(Song song) {
    context.read<PlayerProvider>().playSong(
          song,
          queue: _songs,
          index: _songs.indexOf(song),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                '搜索 MV 相关歌曲，点击即可播放音频',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_error != null && _songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final song = _songs[i];
                  return _MvCard(song: song, onTap: () => _playSong(song));
                }, childCount: _songs.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _MvCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _MvCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: song.cover.isNotEmpty
                      ? CoverNetworkImage(url: song.cover, fit: BoxFit.cover)
                      : Container(color: AppColors.surfaceLight),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                ),
              ),
              const Positioned(
                right: 8,
                bottom: 8,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            song.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
