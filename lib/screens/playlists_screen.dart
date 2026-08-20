import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/music_source_config.dart';
import '../models/song.dart';
import '../providers/music_source_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final MusicApiService _api = MusicApiService.instance;
  MusicSourceProvider? _sourceProvider;

  List<PlaylistCategory> _categories = [];
  List<Playlist> _playlists = [];
  String _squareSource = MusicApiService.playlistSquareDefaultSource;
  String? _selectedCategoryId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
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
    // 歌单广场默认跟网页一样固定 netease，不因音源模式清空。
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = false;
    });

    try {
      await _api.ensureReady();
      final categories =
          await _api.getPlaylistCategories(source: _squareSource);
      if (!mounted) return;

      // 与官网「歌单广场」一致：始终把「全部」放在最前。
      final withAll = <PlaylistCategory>[
        const PlaylistCategory(id: '全部', name: '全部'),
        ...categories.where(
          (c) => c.name != '全部' && c.id != '全部' && c.id != '10000000',
        ),
      ];

      final categoryId = _selectedCategoryId ?? '全部';
      final playlists = await _api.getCategoryPlaylists(
        categoryId.isEmpty ? '全部' : categoryId,
        source: _squareSource,
        page: 1,
        pageSize: 20,
      );

      if (!mounted) return;
      setState(() {
        _categories = withAll;
        _selectedCategoryId = categoryId;
        _playlists = playlists;
        _page = 1;
        _hasMore = playlists.length >= 20;
        _loading = false;
        if (playlists.isEmpty) _error = '该分类暂无歌单';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _loadCategory(String categoryId) async {
    if (_selectedCategoryId == categoryId && !_loading) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _loading = true;
      _error = null;
      _page = 1;
    });

    try {
      final playlists = await _api.getCategoryPlaylists(
        categoryId.isEmpty ? '全部' : categoryId,
        source: _squareSource,
        page: 1,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _hasMore = playlists.length >= 20;
        _loading = false;
        if (playlists.isEmpty) _error = '该分类暂无歌单';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final categoryId = _selectedCategoryId ?? '全部';
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final more = await _api.getCategoryPlaylists(
        categoryId.isEmpty ? '全部' : categoryId,
        source: _squareSource,
        page: next,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _playlists = [..._playlists, ...more];
        _page = next;
        _hasMore = more.length >= 20;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _switchSource(String source) async {
    if (_squareSource == source) return;
    setState(() {
      _squareSource = source;
      _selectedCategoryId = '全部';
    });
    await _load();
  }

  void _openPlaylist(Playlist pl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          title: pl.name,
          playlistId: pl.id,
          source: pl.source.isEmpty ? _squareSource : pl.source,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  children: [
                    for (final item in MusicSourceConfig.standardProviders)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.label),
                          selected: _squareSource == item.id,
                          onSelected: (_) => _switchSource(item.id),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _squareSource == item.id
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.surface,
                          side: BorderSide(
                            color: _squareSource == item.id
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final selected = cat.id == _selectedCategoryId;
                      return FilterChip(
                        label: Text(cat.name),
                        selected: selected,
                        onSelected: (_) => _loadCategory(cat.id),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color:
                              selected ? AppColors.primary : AppColors.divider,
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null && _playlists.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= _playlists.length) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }
                      final pl = _playlists[i];
                      return PlaylistCard(
                        title: pl.name,
                        coverUrl: pl.cover,
                        badgeText: pl.playCountText,
                        onTap: () => _openPlaylist(pl),
                      );
                    },
                    childCount: _playlists.length + (_loadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
