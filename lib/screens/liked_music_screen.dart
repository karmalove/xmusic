import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'charts_screen.dart';

class LikedMusicScreen extends StatelessWidget {
  const LikedMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, List<Song>>(
      selector: (_, p) => p.likedSongs,
      builder: (context, liked, _) {
        final player = context.read<PlayerProvider>();
        return CustomScrollView(
          slivers: [
            SoftAppBar(
              title: '我喜欢的音乐',
              actions: [
                if (liked.isNotEmpty)
                  TextButton(
                    onPressed: () => player.playLiked(),
                    child: const Text(
                      '播放全部',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            if (liked.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 64,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '还没有喜欢的歌曲',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '在播放页点击红心即可收藏',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = liked[index];
                  return SongTile(
                    index: index + 1,
                    title: song.name,
                    subtitle: song.artistName,
                    coverUrl: song.cover,
                    trailingWidget: IconButton(
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () => player.toggleLike(song),
                    ),
                    onTap: () => player.playLiked(startIndex: index),
                  );
                }, childCount: liked.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}
