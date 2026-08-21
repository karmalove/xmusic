import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// 对齐网页 PlayerBar / FullPlayer 的「播放列表」面板。
class PlayQueueSheet extends StatefulWidget {
  const PlayQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const PlayQueueSheet(),
    );
  }

  @override
  State<PlayQueueSheet> createState() => _PlayQueueSheetState();
}

class _PlayQueueSheetState extends State<PlayQueueSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToCurrent = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent(int index) {
    if (!_scrollController.hasClients || index < 0) return;
    const itemExtent = 64.0;
    final target = (index * itemExtent) -
        (_scrollController.position.viewportDimension / 2) +
        (itemExtent / 2);
    _scrollController.jumpTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlist = player.playlist;
    final currentIndex = player.currentIndex;
    final height = MediaQuery.sizeOf(context).height * 0.62;

    if (!_didScrollToCurrent && playlist.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _didScrollToCurrent = true;
        _scrollToCurrent(currentIndex);
      });
    }

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  Text(
                    '播放列表',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${playlist.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '定位当前',
                    onPressed: playlist.isEmpty
                        ? null
                        : () => _scrollToCurrent(currentIndex),
                    icon: const Icon(
                      Icons.my_location_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    tooltip: '清空列表',
                    onPressed: playlist.isEmpty
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text(
                                  '清空播放列表？',
                                  style: TextStyle(color: AppColors.textPrimary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      '清空',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await player.clearPlaylist();
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: playlist.isEmpty
                  ? const Center(
                      child: Text(
                        '播放列表为空',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemExtent: 64,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: playlist.length,
                      itemBuilder: (_, i) {
                        final song = playlist[i];
                        final active = i == currentIndex;
                        return Material(
                          color: active
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => player.playAt(i),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: active && player.isPlaying
                                        ? const Icon(
                                            Icons.graphic_eq_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          )
                                        : Text(
                                            '${i + 1}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: active
                                                  ? AppColors.primary
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                  ),
                                  AlbumCover(
                                    url: song.cover,
                                    size: 44,
                                    radius: 8,
                                    showShadow: false,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: active
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
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
                                  Text(
                                    song.durationText,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '移除',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        player.removeFromPlaylist(i),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
