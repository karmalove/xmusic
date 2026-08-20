import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/music_source_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/cover_image.dart';
import '../widgets/common_widgets.dart';

/// 对齐官网 RecommendView：私人 FM + 雷达电台（汽水模式下走汽水源）。
class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  final MusicApiService _api = MusicApiService.instance;
  MusicSourceProvider? _sourceProvider;

  List<Song> _fmSongs = [];
  List<MusicRadioGroup> _radioGroups = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _mode = 'personal_fm'; // personal_fm | radio

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceProvider = context.read<MusicSourceProvider>();
      _sourceProvider!.addListener(_onSourceChanged);
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _sourceProvider?.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    if (mounted) _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.ensureReady();
      if (!mounted) return;
      final source = context.read<MusicSourceProvider>().apiSource;
      final results = await Future.wait([
        _loadPersonalFm(play: false, source: source),
        _api.getRadios(source: source == 'qishui' ? null : source),
      ]);
      if (!mounted) return;
      final groups = results[1] as List<MusicRadioGroup>;
      setState(() {
        _radioGroups = groups;
        _loading = false;
        if (_fmSongs.isEmpty) {
          _error = '暂无推荐，请稍后重试';
        }
      });
      if (_fmSongs.isNotEmpty) {
        _playQueue(_fmSongs, 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<List<Song>> _loadPersonalFm({
    required bool play,
    String? source,
  }) async {
    // 与官网一致：先不带 source；失败再用当前音源。
    List<Song> songs = [];
    try {
      songs = await _api.getPersonalFm();
    } catch (_) {}
    if (songs.isEmpty && source != null && source.isNotEmpty) {
      try {
        songs = await _api.getPersonalFm(source: source);
      } catch (_) {}
    }
    if (!mounted) return songs;
    setState(() {
      _fmSongs = songs;
      _mode = 'personal_fm';
    });
    if (play && songs.isNotEmpty) {
      _playQueue(songs, 0);
    }
    return songs;
  }

  void _playQueue(List<Song> queue, int index) {
    if (queue.isEmpty) return;
    context.read<PlayerProvider>().playSong(
          queue[index.clamp(0, queue.length - 1)],
          queue: queue,
          index: index.clamp(0, queue.length - 1),
        );
  }

  Future<void> _refreshFm() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final source = context.read<MusicSourceProvider>().apiSource;
      await _loadPersonalFm(play: true, source: source);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _playRadio(RadioStation radio) async {
    setState(() => _loadingMore = true);
    try {
      final songs = await _api.getRadioSongs(
        radio.id,
        source: radio.source.isNotEmpty ? radio.source : 'qq',
      );
      if (!mounted) return;
      if (songs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该电台暂无歌曲')),
        );
        return;
      }
      setState(() {
        _fmSongs = songs;
        _mode = 'radio';
      });
      _playQueue(songs, 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('电台加载失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final current = player.currentSong;
    final isQishui = context.watch<MusicSourceProvider>().isQishui;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null && _fmSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _bootstrap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final cover = current?.cover ??
        (_fmSongs.isNotEmpty ? _fmSongs.first.cover : '');
    final title = current?.name ??
        (_fmSongs.isNotEmpty ? _fmSongs.first.name : '私人 FM');
    final artist = current?.artistName ??
        (_fmSongs.isNotEmpty ? _fmSongs.first.artistName : '');

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _bootstrap,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Text(
                    '推荐',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isQishui
                          ? '汽水'
                          : (_mode == 'radio' ? '雷达' : '私人 FM'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: cover.isNotEmpty
                          ? CoverNetworkImage(url: cover, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.music_note_rounded,
                                size: 64,
                                color: AppColors.textMuted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artist,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _loadingMore ? null : _refreshFm,
                        icon: _loadingMore
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        color: AppColors.textPrimary,
                        tooltip: '换一批',
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () {
                          if (current != null) {
                            player.togglePlay();
                          } else if (_fmSongs.isNotEmpty) {
                            _playQueue(_fmSongs, 0);
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => player.next(),
                        icon: const Icon(Icons.skip_next_rounded),
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_fmSongs.length > 1) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: '当前队列'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final song = _fmSongs[i];
                return SongTile(
                  index: i + 1,
                  title: song.name,
                  subtitle: song.artistName,
                  coverUrl: song.cover,
                  trailing: song.durationText,
                  onTap: () => _playQueue(_fmSongs, i),
                );
              }, childCount: _fmSongs.length.clamp(0, 30)),
            ),
          ],
          if (_radioGroups.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: '雷达电台'),
            ),
            for (final group in _radioGroups.take(4)) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: group.radios.length.clamp(0, 12),
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final radio = group.radios[i];
                      return _RadioCard(
                        radio: radio,
                        onTap: () => _playRadio(radio),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  final RadioStation radio;
  final VoidCallback onTap;

  const _RadioCard({required this.radio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: radio.cover.isNotEmpty
                    ? CoverNetworkImage(url: radio.cover, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.surface,
                        child: const Icon(
                          Icons.radar_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              radio.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
