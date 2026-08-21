import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/cover_image.dart';

class BlurredCoverBackground extends StatelessWidget {
  final String? imageUrl;
  final Widget child;
  final List<Color>? fallbackColors;

  const BlurredCoverBackground({
    super.key,
    this.imageUrl,
    required this.child,
    this.fallbackColors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null && imageUrl!.isNotEmpty)
          CoverNetworkImage(
            url: imageUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 480,
            memCacheHeight: 480,
            maxWidthDiskCache: 480,
            maxHeightDiskCache: 480,
            placeholder: (_, __) => _fallbackGradient(),
            errorWidget: (_, __, ___) => _fallbackGradient(),
          )
        else
          _fallbackGradient(),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(color: AppColors.background.withValues(alpha: 0.75)),
        ),
        child,
      ],
    );
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              fallbackColors ??
              [
                const Color(0xFF1A1A2E),
                const Color(0xFF16213E),
                AppColors.background,
              ],
        ),
      ),
    );
  }
}

class AlbumCover extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final bool showShadow;

  const AlbumCover({
    super.key,
    this.url,
    required this.size,
    this.radius = 16,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final safeSize = size.isFinite && size > 0 ? size : 200.0;
    final cacheSize = (safeSize * dpr).round().clamp(64, 2048);

    final image = url != null && url!.isNotEmpty
        ? CoverNetworkImage(
            url: url!,
            fit: BoxFit.cover,
            memCacheWidth: cacheSize,
            memCacheHeight: cacheSize,
            maxWidthDiskCache: 512,
            maxHeightDiskCache: 512,
            placeholder: (_, __) => _placeholder(safeSize),
            errorWidget: (_, __, ___) => _placeholder(safeSize),
          )
        : _placeholder(safeSize);

    // 非有限尺寸：铺满父布局（用于 FlexibleSpace 背景等）
    if (!size.isFinite || size <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: showShadow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }

  Widget _placeholder([double? iconBase]) {
    final base = iconBase ?? (size.isFinite && size > 0 ? size : 80.0);
    return Container(
      color: AppColors.surfaceLight,
      child: Icon(
        Icons.music_note_rounded,
        size: base * 0.4,
        color: AppColors.textMuted,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;

  const SectionHeader({super.key, required this.title, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: const Row(
                children: [
                  Text(
                    '更多',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? coverUrl;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final int? index;

  const SongTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.trailing,
    this.trailingWidget,
    this.onTap,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              if (index != null) ...[
                SizedBox(
                  width: 28,
                  child: Text(
                    '$index',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              AlbumCover(
                url: coverUrl,
                size: 48,
                radius: 10,
                showShadow: false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null)
                trailingWidget!
              else if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              if (trailingWidget == null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final String? badgeText;
  final VoidCallback? onTap;

  const PlaylistCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.maxHeight.isFinite;
          final coverSize = bounded
              ? (constraints.maxHeight - 46).clamp(96.0, 140.0)
              : 140.0;

          final titleText = Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          );

          return SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AlbumCover(url: coverUrl, size: coverSize, radius: 14),
                    if (badgeText != null && badgeText!.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (bounded) Expanded(child: titleText) else titleText,
              ],
            ),
          );
        },
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final String title;
  final String artist;
  final String? lyric;
  final String? coverUrl;
  final bool isPlaying;
  final bool isLoading;
  final bool showLyrics;
  final double progress;
  final int queueCount;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback? onQueue;

  const MiniPlayer({
    super.key,
    required this.title,
    required this.artist,
    this.lyric,
    this.coverUrl,
    required this.isPlaying,
    required this.isLoading,
    this.showLyrics = false,
    required this.progress,
    this.queueCount = 0,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onClose,
    this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = showLyrics && lyric != null && lyric!.isNotEmpty
        ? lyric!
        : artist;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress.clamp(0, 1),
          backgroundColor: Colors.transparent,
          color: AppColors.primary,
          minHeight: 2,
        ),
        Material(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        AlbumCover(
                          url: coverUrl,
                          size: 44,
                          radius: 8,
                          showShadow: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: showLyrics && lyric != null
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isLoading ? null : onPlayPause,
                  icon: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.textPrimary,
                          size: 28,
                        ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                if (onQueue != null)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: onQueue,
                        tooltip: '播放列表',
                        icon: const Icon(
                          Icons.queue_music_rounded,
                          color: AppColors.textPrimary,
                          size: 26,
                        ),
                      ),
                      if (queueCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(minWidth: 16),
                            child: Text(
                              queueCount > 99 ? '99+' : '$queueCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                IconButton(
                  onPressed: onClose,
                  tooltip: '停止播放',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
