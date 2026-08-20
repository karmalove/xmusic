import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/music_source_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/cover_image.dart';
import 'playlist_detail_screen.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final MusicApiService _api = MusicApiService.instance;
  MusicSourceProvider? _sourceProvider;
  List<Chart> _charts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceProvider = context.read<MusicSourceProvider>();
      _sourceProvider!.addListener(_onSourceChanged);
      _load();
    });
  }

  @override
  void dispose() {
    _sourceProvider?.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final source = context.read<MusicSourceProvider>().catalogSource;
    final isQishui = context.read<MusicSourceProvider>().isQishui;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.ensureReady();
      final charts = await _api.getCharts(source: source);
      if (!mounted) return;
      setState(() {
        _charts = charts;
        _loading = false;
        if (charts.isEmpty) {
          _error = isQishui
              ? '汽水排行榜暂不可用，可点击侧栏徽章切换到「标准」音源'
              : '暂无排行榜数据';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = isQishui
            ? '汽水排行榜暂不可用，可切换到「标准」音源'
            : '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          const SoftAppBar(title: '排行榜'),
          if (_loading)
            const SoftLoadingSliver()
          else if (_error != null)
            SoftErrorSliver(message: _error!, onRetry: _load)
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final chart = _charts[i];
                  return _ChartCard(
                    chart: chart,
                    rank: i + 1,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(
                            title: chart.name,
                            chartId: chart.id,
                            source: chart.source.isEmpty
                                ? context.read<MusicSourceProvider>().apiSource
                                : chart.source,
                          ),
                        ),
                      );
                    },
                  );
                }, childCount: _charts.length),
              ),
            ),
        ],
      ),
    );
  }
}

class SoftAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const SoftAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.background,
      title: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      actions: actions,
    );
  }
}

class SoftLoadingSliver extends StatelessWidget {
  const SoftLoadingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class SoftErrorSliver extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const SoftErrorSliver({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Chart chart;
  final int rank;
  final VoidCallback onTap;

  const _ChartCard({
    required this.chart,
    required this.rank,
    required this.onTap,
  });

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFF9F43),
    Color(0xFF00D9A5),
    Color(0xFF6C5CE7),
    Color(0xFF74B9FF),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (chart.cover.isNotEmpty)
                    CoverNetworkImage(url: chart.cover, fit: BoxFit.cover)
                  else
                    Container(
                      color: AppColors.surfaceLight,
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: _colors[(rank - 1) % _colors.length],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TOP $rank',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                chart.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
