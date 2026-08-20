import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/play_history.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'charts_screen.dart';

class RecentPlayScreen extends StatelessWidget {
  const RecentPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, List<PlayHistoryItem>>(
      selector: (_, p) => p.history,
      builder: (context, history, _) {
        final player = context.read<PlayerProvider>();
        return CustomScrollView(
          slivers: [
            SoftAppBar(
              title: '最近播放',
              actions: [
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: () => player.playHistory(),
                    child: const Text(
                      '播放全部',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            if (history.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '还没有播放记录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '听过的歌曲会显示在这里',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = history[index];
                  return SongTile(
                    title: item.song.name,
                    subtitle: item.song.artistName,
                    coverUrl: item.song.cover,
                    trailing: item.relativeTime,
                    onTap: () => player.playHistory(startIndex: index),
                  );
                }, childCount: history.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}
