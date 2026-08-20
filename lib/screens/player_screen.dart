import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lyric_view.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(
            body: Center(
              child: Text(
                '暂无播放',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Scaffold(
          body: BlurredCoverBackground(
            imageUrl: song.cover,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                song.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                song.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            player.isLiked(song)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: player.isLiked(song)
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          onPressed: () => player.toggleLike(song),
                          tooltip: player.isLiked(song) ? '取消喜欢' : '我喜欢',
                        ),
                        IconButton(
                          icon: Icon(
                            player.showLyrics
                                ? Icons.lyrics_rounded
                                : Icons.album_rounded,
                            color: player.showLyrics
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          onPressed: player.toggleShowLyrics,
                          tooltip: player.showLyrics ? '显示封面' : '显示歌词',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: player.showLyrics
                        ? LyricView(
                            lyrics: player.lyrics,
                            position: player.position,
                            loading: player.lyricsLoading,
                            songName: song.name,
                            artistName: song.artistName,
                          )
                        : GestureDetector(
                            onTap: player.toggleShowLyrics,
                            child: _CoverView(song: song),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                    child: _PlayerProgressBar(player: player),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: player.shuffle
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          iconSize: 24,
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          iconSize: 36,
                          onPressed: player.previous,
                        ),
                        GestureDetector(
                          onTap: player.togglePlay,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.gradientPrimary,
                            ),
                            child: player.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : Icon(
                                    player.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 36,
                                    color: Colors.black,
                                  ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 36,
                          onPressed: player.next,
                        ),
                        IconButton(
                          icon: Icon(
                            player.repeatMode == PlayerRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: player.repeatMode != PlayerRepeatMode.off
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          iconSize: 24,
                          onPressed: player.toggleRepeat,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerProgressBar extends StatelessWidget {
  final PlayerProvider player;

  const _PlayerProgressBar({required this.player});

  String _format(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? player.position;
        final durationMs = player.duration.inMilliseconds;
        final progress = durationMs > 0
            ? (position.inMilliseconds / durationMs).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: progress,
                onChanged: durationMs <= 0
                    ? null
                    : (v) {
                        player.seek(
                          Duration(milliseconds: (v * durationMs).round()),
                        );
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(position),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    _format(player.duration),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoverView extends StatelessWidget {
  final Song song;

  const _CoverView({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: AspectRatio(
            aspectRatio: 1,
            child: AlbumCover(
              url: song.cover,
              size: double.infinity,
              radius: 20,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                song.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.artistName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '点按封面查看歌词',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
