import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/music_source_settings.dart';
import '../widgets/xmusic_wordmark.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          floating: true,
          backgroundColor: AppColors.background,
          title: Align(
            alignment: Alignment.centerLeft,
            child: XmusicWordmark(height: 16, compact: true),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              '音源',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: MusicSourceSettings()),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
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
                            ? '关闭窗口后音乐继续在状态栏播放（默认开启）'
                            : Platform.isWindows || Platform.isLinux
                                ? '桌面端默认开启，窗口失焦不会暂停播放'
                                : '默认开启；关闭后切到后台会暂停播放',
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
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
