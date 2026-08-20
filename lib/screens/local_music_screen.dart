import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/local_music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'charts_screen.dart';

class LocalMusicScreen extends StatelessWidget {
  const LocalMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LocalMusicProvider, List<Song>>(
      selector: (_, p) => p.songs,
      builder: (context, songs, _) {
        final local = context.read<LocalMusicProvider>();
        final player = context.read<PlayerProvider>();
        return CustomScrollView(
          slivers: [
            SoftAppBar(
              title: '本地音乐',
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    final count = await local.importFiles();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          count > 0 ? '已添加 $count 首本地歌曲' : '未选择文件',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  label: const Text(
                    '导入',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            if (songs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.audio_file_outlined,
                        size: 64,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '还没有本地音乐',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '点击右上角导入本地音频文件',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => local.importFiles(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('导入文件'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = songs[index];
                  return Dismissible(
                    key: ValueKey(song.uniqueKey),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: AppColors.error.withValues(alpha: 0.85),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => local.remove(song.uniqueKey),
                    child: SongTile(
                      index: index + 1,
                      title: song.name,
                      subtitle: song.artistName,
                      coverUrl: song.cover,
                      onTap: () => player.playSong(
                        song,
                        queue: List.from(songs),
                        index: index,
                      ),
                    ),
                  );
                }, childCount: songs.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}
