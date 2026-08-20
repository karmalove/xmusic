import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/play_history.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/xmusic_wordmark.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: AppColors.background,
          title: const Align(
            alignment: Alignment.centerLeft,
            child: XmusicWordmark(height: 16, compact: true),
          ),
          actions: [
            Selector<PlayerProvider, bool>(
              selector: (_, p) => p.history.isNotEmpty,
              builder: (context, hasHistory, _) {
                if (!hasHistory) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => _confirmClear(
                    context,
                    context.read<PlayerProvider>(),
                  ),
                  child: const Text(
                    '清空',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ],
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              '设置',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Selector<PlayerProvider, (bool, bool, bool)>(
            selector: (_, p) =>
                (p.backgroundPlayback, p.showLyrics, p.showTraySong),
            builder: (context, flags, _) {
              final player = context.read<PlayerProvider>();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: flags.$1,
                      onChanged: player.setBackgroundPlayback,
                      activeThumbColor: AppColors.primary,
                      title: const Text(
                        '后台播放',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        Platform.isMacOS
                            ? '关闭窗口后音乐继续在状态栏播放（macOS 默认开启）'
                            : '关闭后切到后台或离开应用会暂停播放',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      value: flags.$2,
                      onChanged: player.setShowLyrics,
                      activeThumbColor: AppColors.primary,
                      title: const Text(
                        '显示歌词',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: const Text(
                        '播放页与迷你播放条显示滚动歌词',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (Platform.isMacOS)
                      SwitchListTile(
                        value: flags.$3,
                        onChanged: player.setShowTraySong,
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          '状态栏显示歌曲',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: const Text(
                          '关闭后状态栏仅显示 XMUSIC 图标，右键菜单查看当前播放',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Selector<PlayerProvider, List<PlayHistoryItem>>(
          selector: (_, p) => p.history,
          builder: (context, history, _) {
            final player = context.read<PlayerProvider>();
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        const Text(
                          '播放历史',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${history.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        if (history.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => player.playHistory(),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              '播放全部',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                      return _HistoryTile(
                        item: item,
                        onTap: () => player.playHistory(startIndex: index),
                        onDelete: () =>
                            player.removeHistoryItem(item.song.uniqueKey),
                      );
                    }, childCount: history.length),
                  ),
              ],
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    PlayerProvider player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('清空播放历史？'),
        content: const Text(
          '此操作不可恢复。',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await player.clearHistory();
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final PlayHistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.song.uniqueKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.error.withValues(alpha: 0.85),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: SongTile(
        title: item.song.name,
        subtitle: item.song.artistName,
        coverUrl: item.song.cover,
        trailing: item.relativeTime,
        onTap: onTap,
      ),
    );
  }
}
