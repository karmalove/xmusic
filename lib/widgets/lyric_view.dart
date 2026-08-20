import 'package:flutter/material.dart';

import '../models/lyric.dart';
import '../theme/app_theme.dart';

class LyricView extends StatefulWidget {
  final LyricData? lyrics;
  final Duration position;
  final bool loading;
  final String songName;
  final String artistName;

  const LyricView({
    super.key,
    required this.lyrics,
    required this.position,
    required this.loading,
    required this.songName,
    required this.artistName,
  });

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  final _scrollController = ScrollController();
  int _currentIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics != oldWidget.lyrics) {
      _currentIndex = -1;
    }
    _syncScroll();
  }

  void _syncScroll() {
    final lyrics = widget.lyrics;
    if (lyrics == null || lyrics.isEmpty) return;

    final index = lyrics.indexAt(widget.position.inMilliseconds);
    if (index < 0 || index == _currentIndex) return;
    _currentIndex = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const itemHeight = 52.0;
      final target = index * itemHeight -
          (_scrollController.position.viewportDimension / 2) +
          itemHeight / 2;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    final lyrics = widget.lyrics;
    if (lyrics == null || lyrics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.songName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.artistName,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '暂无歌词',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentIndex = _currentIndex >= 0 ? _currentIndex : lyrics.indexAt(widget.position.inMilliseconds);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final isCurrent = index == currentIndex;
        final distance = (index - currentIndex).abs();

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCurrent ? 22 : 16,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                color: isCurrent
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(
                        alpha: (0.75 - distance * 0.12).clamp(0.25, 0.75),
                      ),
                height: 1.6,
              ),
            ),
          ),
        );
      },
    );
  }
}
