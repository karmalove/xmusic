import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/music_source_config.dart';
import '../models/song.dart';
import '../providers/music_source_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/cover_image.dart';
import '../widgets/common_widgets.dart';
import '../widgets/xmusic_wordmark.dart';
import 'playlist_detail_screen.dart';

enum _SearchTab { songs, playlists, albums, artists, mvs }

/// 单音源搜索缓存（对齐官网 musicCatalog 的 I[source]）。
class _SourceBucket {
  List<Song> songs = [];
  List<Playlist> playlists = [];
  List<Album> albums = [];
  List<Artist> artists = [];
  List<MusicVideo> mvs = [];
  int page = 0;
  bool hasMore = false;
  bool loading = false;
  bool loaded = false;
}

/// 对齐官网搜索：多音源并行、音源 chip 带数量、Tab 含 MV、默认酷我。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _historyKey = 'xmusic_search_history';

  final MusicApiService _api = MusicApiService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  MusicSourceProvider? _sourceProvider;
  Timer? _suggestTimer;
  int _searchSeq = 0;

  final Map<String, _SourceBucket> _buckets = {
    for (final s in MusicSourceConfig.searchSourceOrder) s: _SourceBucket(),
  };

  List<String> _hotSearches = [];
  List<String> _history = [];
  List<String> _suggestions = [];

  bool _loading = false;
  bool _loadingMore = false;
  bool _searched = false;
  bool _showDropdown = false;
  bool _hotLoading = false;
  String _query = '';
  String? _error;
  String _searchSource = MusicSourceConfig.searchDefaultSource;
  _SearchTab _tab = _SearchTab.songs;

  List<String> get _activeSources {
    final provider = _sourceProvider;
    if (provider != null && provider.isQishui) {
      return const [MusicSourceConfig.qishuiApiSource];
    }
    return _tab == _SearchTab.mvs
        ? MusicSourceConfig.searchMvSourceOrder
        : MusicSourceConfig.searchSourceOrder;
  }

  _SourceBucket get _bucket =>
      _buckets.putIfAbsent(_searchSource, _SourceBucket.new);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onQueryChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceProvider = context.read<MusicSourceProvider>();
      _sourceProvider!.addListener(_onSourceChanged);
      if (_sourceProvider!.isQishui) {
        _searchSource = MusicSourceConfig.qishuiApiSource;
      } else {
        _searchSource = MusicSourceConfig.searchDefaultSource;
      }
      _loadHot();
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _sourceProvider?.removeListener(_onSourceChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onQueryChanged);
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    final provider = context.read<MusicSourceProvider>();
    if (provider.isQishui) {
      if (_searchSource != MusicSourceConfig.qishuiApiSource) {
        setState(() => _searchSource = MusicSourceConfig.qishuiApiSource);
        if (_searched && _query.isNotEmpty) _search(_query);
      }
    } else if (_searchSource == MusicSourceConfig.qishuiApiSource) {
      setState(() => _searchSource = MusicSourceConfig.searchDefaultSource);
      if (_searched && _query.isNotEmpty) _search(_query);
    }
  }

  void _onFocusChanged() {
    setState(() => _showDropdown = _focusNode.hasFocus);
  }

  void _onQueryChanged() {
    _suggestTimer?.cancel();
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 200), () {
      _refreshSuggestions(q);
    });
  }

  void _onScroll() {
    if (!_searched || _loading || _loadingMore) return;
    if (!_bucket.hasMore) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 260) {
      _loadMore();
    }
  }

  Future<void> _loadHot() async {
    setState(() => _hotLoading = true);
    try {
      await _api.ensureReady();
      final hot = await _api.getHotSearchPreferred();
      if (!mounted) return;
      setState(() {
        _hotSearches = hot.isNotEmpty
            ? hot.take(15).toList()
            : const [
                '周杰伦',
                '邓紫棋',
                '林俊杰',
                '薛之谦',
                '毛不易',
                '陈奕迅',
                '五月天',
                '李荣浩',
              ];
        _hotLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hotSearches = const [
          '周杰伦',
          '邓紫棋',
          '林俊杰',
          '薛之谦',
          '毛不易',
          '陈奕迅',
          '五月天',
          '李荣浩',
        ];
        _hotLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    if (!mounted) return;
    setState(() => _history = list);
  }

  Future<void> _saveHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ..._history.where((e) => e != q)].take(15).toList();
    setState(() => _history = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, next);
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> _refreshSuggestions(String q) async {
    try {
      final remote = await _api.searchSuggestPreferred(q);
      final local = <String>{
        ..._history.where((e) => e.contains(q)),
        ..._hotSearches.where((e) => e.contains(q)),
        ...remote,
      }.where((e) => e.trim().isNotEmpty).take(12).toList();
      if (!mounted || _controller.text.trim() != q) return;
      setState(() => _suggestions = local);
    } catch (_) {
      final local = <String>{
        ..._history.where((e) => e.contains(q)),
        ..._hotSearches.where((e) => e.contains(q)),
      }.take(12).toList();
      if (!mounted || _controller.text.trim() != q) return;
      setState(() => _suggestions = local);
    }
  }

  void _resetBuckets() {
    for (final src in _buckets.keys.toList()) {
      _buckets[src] = _SourceBucket();
    }
    for (final src in _activeSources) {
      _buckets.putIfAbsent(src, _SourceBucket.new);
    }
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;

    if (_controller.text != q) {
      _controller.value = TextEditingValue(
        text: q,
        selection: TextSelection.collapsed(offset: q.length),
      );
    }

    _focusNode.unfocus();
    await _saveHistory(q);

    final sources = _activeSources;
    if (sources.isEmpty) return;
    if (!sources.contains(_searchSource)) {
      _searchSource = sources.first;
    }

    final seq = ++_searchSeq;
    _resetBuckets();

    setState(() {
      _loading = true;
      _searched = true;
      _query = q;
      _error = null;
      _showDropdown = false;
    });

    try {
      await _api.ensureReady();
      if (!mounted || seq != _searchSeq) return;

      // 官网：先搜主音源（默认酷我），再后台补齐其他音源。
      final primary = _searchSource;
      await _loadSource(primary, tab: _tab, page: 1, replace: true, seq: seq);
      if (!mounted || seq != _searchSeq) return;

      setState(() => _loading = false);

      for (final src in sources) {
        if (src == primary) continue;
        unawaited(_loadSource(src, tab: _tab, page: 1, replace: true, seq: seq));
      }
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _loading = false;
        _error = '搜索失败: $e';
      });
    }
  }

  Future<void> _loadSource(
    String source, {
    required _SearchTab tab,
    required int page,
    required bool replace,
    required int seq,
  }) async {
    final bucket = _buckets.putIfAbsent(source, _SourceBucket.new);
    if (bucket.loading) return;
    bucket.loading = true;

    try {
      switch (tab) {
        case _SearchTab.songs:
          final songs =
              await _api.searchSongs(_query, source: source, page: page);
          if (!mounted || seq != _searchSeq) return;
          bucket.songs = replace ? songs : [...bucket.songs, ...songs];
          bucket.hasMore = songs.length >= 30;
          bucket.page = page;
          bucket.loaded = true;
        case _SearchTab.playlists:
          final list =
              await _api.searchPlaylists(_query, source: source, page: page);
          if (!mounted || seq != _searchSeq) return;
          bucket.playlists = replace ? list : [...bucket.playlists, ...list];
          bucket.hasMore = list.length >= 20;
          bucket.page = page;
          bucket.loaded = true;
        case _SearchTab.albums:
          final list =
              await _api.searchAlbums(_query, source: source, page: page);
          if (!mounted || seq != _searchSeq) return;
          bucket.albums = replace ? list : [...bucket.albums, ...list];
          bucket.hasMore = list.length >= 20;
          bucket.page = page;
          bucket.loaded = true;
        case _SearchTab.artists:
          final list =
              await _api.searchArtists(_query, source: source, page: page);
          if (!mounted || seq != _searchSeq) return;
          bucket.artists = replace ? list : [...bucket.artists, ...list];
          bucket.hasMore = list.length >= 20;
          bucket.page = page;
          bucket.loaded = true;
        case _SearchTab.mvs:
          final list =
              await _api.searchMvs(_query, source: source, page: page);
          if (!mounted || seq != _searchSeq) return;
          bucket.mvs = replace ? list : [...bucket.mvs, ...list];
          bucket.hasMore = list.length >= 20;
          bucket.page = page;
          bucket.loaded = true;
      }
      if (mounted && seq == _searchSeq) setState(() {});
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      if (source == _searchSource && replace) {
        setState(() {
          _error = context.read<MusicSourceProvider>().isQishui
              ? '汽水搜索暂不可用，请切换到标准音源'
              : '搜索失败: $e';
        });
      }
    } finally {
      bucket.loading = false;
    }
  }

  Future<void> _selectSource(String source) async {
    if (_searchSource == source) return;
    setState(() {
      _searchSource = source;
      _error = null;
    });
    if (!_searched || _query.isEmpty) return;

    final bucket = _buckets.putIfAbsent(source, _SourceBucket.new);
    final needsLoad = !bucket.loaded || _countFor(source) == 0;
    if (!needsLoad) return;

    setState(() => _loading = true);
    await _loadSource(
      source,
      tab: _tab,
      page: 1,
      replace: true,
      seq: _searchSeq,
    );
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _switchTab(_SearchTab tab) async {
    if (_tab == tab) return;

    final sources = tab == _SearchTab.mvs
        ? MusicSourceConfig.searchMvSourceOrder
        : MusicSourceConfig.searchSourceOrder;
    final provider = context.read<MusicSourceProvider>();
    final nextSources =
        provider.isQishui ? const [MusicSourceConfig.qishuiApiSource] : sources;

    setState(() {
      _tab = tab;
      _error = null;
      if (!nextSources.contains(_searchSource)) {
        _searchSource = nextSources.first;
      }
    });

    if (!_searched || _query.isEmpty) return;

    final seq = _searchSeq;
    final primary = _searchSource;
    final bucket = _buckets.putIfAbsent(primary, _SourceBucket.new);
    final empty = _countFor(primary) == 0;

    if (empty || !bucket.loaded) {
      setState(() => _loading = true);
      await _loadSource(primary, tab: tab, page: 1, replace: true, seq: seq);
      if (!mounted) return;
      setState(() => _loading = false);
    }

    for (final src in nextSources) {
      if (src == primary) continue;
      final b = _buckets.putIfAbsent(src, _SourceBucket.new);
      if (!b.loaded && !b.loading) {
        unawaited(_loadSource(src, tab: tab, page: 1, replace: true, seq: seq));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_bucket.hasMore) return;
    setState(() => _loadingMore = true);
    await _loadSource(
      _searchSource,
      tab: _tab,
      page: _bucket.page + 1,
      replace: false,
      seq: _searchSeq,
    );
    if (!mounted) return;
    setState(() => _loadingMore = false);
  }

  int _countFor(String source) {
    final b = _buckets[source];
    if (b == null) return 0;
    return switch (_tab) {
      _SearchTab.songs => b.songs.length,
      _SearchTab.playlists => b.playlists.length,
      _SearchTab.albums => b.albums.length,
      _SearchTab.artists => b.artists.length,
      _SearchTab.mvs => b.mvs.length,
    };
  }

  String _sourceLabel(String id) {
    if (id == MusicSourceConfig.qishuiApiSource) return '汽水';
    for (final item in MusicSourceConfig.standardProviders) {
      if (item.id == id) return item.label;
    }
    return id;
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _searched = false;
      _error = null;
      _query = '';
      _suggestions = [];
      _showDropdown = _focusNode.hasFocus;
      _resetBuckets();
    });
  }

  bool get _isCurrentTabEmpty => _countFor(_searchSource) == 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: XmusicWordmark(height: 16, compact: true),
            ),
          ),
          _buildSearchBar(),
          if (_searched) _buildTabsAndSources(),
          Expanded(
            child: Stack(
              children: [
                if (_loading && _isCurrentTabEmpty)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                else if (_searched)
                  _buildResults()
                else
                  _buildIdleBody(),
                if (_showDropdown && !_loading) _buildDropdown(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _focusNode.hasFocus
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.divider,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: '搜索歌曲、歌手、歌单、专辑、MV...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  onPressed: _clear,
                  tooltip: '清除',
                );
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onSubmitted: _search,
          onTap: () => setState(() => _showDropdown = true),
        ),
      ),
    );
  }

  Widget _buildTabsAndSources() {
    final sources = _activeSources;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              for (final tab in _SearchTab.values)
                Expanded(
                  child: TextButton(
                    onPressed: () => _switchTab(tab),
                    style: TextButton.styleFrom(
                      foregroundColor: _tab == tab
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      switch (tab) {
                        _SearchTab.songs => '歌曲',
                        _SearchTab.playlists => '歌单',
                        _SearchTab.albums => '专辑',
                        _SearchTab.artists => '歌手',
                        _SearchTab.mvs => 'MV',
                      },
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            _tab == tab ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (sources.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final src in sources)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${_sourceLabel(src)} ${_countFor(src)}'),
                      selected: _searchSource == src,
                      onSelected: (_) => _selectSource(src),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _searchSource == src
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: _searchSource == src
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${_countFor(_searchSource)} 条结果',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (_history.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  '清空',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in _history)
                _Chip(label: item, onTap: () => _search(item)),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            const Text(
              '热门搜索',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_hotLoading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _hotSearches.length; i++)
              _Chip(
                label: _hotSearches[i],
                hot: i < 3,
                onTap: () => _search(_hotSearches[i]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    final q = _controller.text.trim();
    final items = q.isEmpty
        ? {
            ..._history.take(8),
            ..._hotSearches.take(8),
          }.toList()
        : _suggestions;

    if (items.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      right: 20,
      top: 0,
      child: Material(
        color: AppColors.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (_, i) {
              final text = items[i];
              final isHistory = _history.contains(text);
              return ListTile(
                dense: true,
                leading: Icon(
                  isHistory ? Icons.history_rounded : Icons.trending_up_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                title: Text(
                  text,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => _search(text),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null && _isCurrentTabEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _search(_query),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isCurrentTabEmpty) {
      final loadingOther = _bucket.loading;
      return Center(
        child: Text(
          loadingOther ? '搜索中...' : '未找到"$_query"的相关结果',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final bucket = _bucket;
    return switch (_tab) {
      _SearchTab.songs => ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: bucket.songs.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= bucket.songs.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            final song = bucket.songs[i];
            return SongTile(
              title: song.name,
              subtitle: '${song.artistName} · ${song.album.name}',
              coverUrl: song.cover,
              trailing: song.durationText,
              onTap: () => context.read<PlayerProvider>().playSong(
                    song,
                    queue: bucket.songs,
                    index: i,
                  ),
            );
          },
        ),
      _SearchTab.playlists => GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.68,
          ),
          itemCount: bucket.playlists.length,
          itemBuilder: (_, i) {
            final pl = bucket.playlists[i];
            return PlaylistCard(
              title: pl.name,
              coverUrl: pl.cover,
              badgeText: pl.playCountText,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(
                      title: pl.name,
                      playlistId: pl.id,
                      source: pl.source.isEmpty ? _searchSource : pl.source,
                    ),
                  ),
                );
              },
            );
          },
        ),
      _SearchTab.albums => ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: bucket.albums.length,
          itemBuilder: (_, i) {
            final album = bucket.albums[i];
            return SongTile(
              title: album.name,
              subtitle: album.source.isEmpty ? '专辑' : _sourceLabel(album.source),
              coverUrl: album.cover,
              onTap: () => _search(album.name),
            );
          },
        ),
      _SearchTab.artists => ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: bucket.artists.length,
          itemBuilder: (_, i) {
            final artist = bucket.artists[i];
            return ListTile(
              leading: AlbumCover(url: artist.cover, size: 48, radius: 24),
              title: Text(
                artist.name,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                artist.source.isEmpty ? '歌手' : _sourceLabel(artist.source),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => _search(artist.name),
            );
          },
        ),
      _SearchTab.mvs => GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: bucket.mvs.length,
          itemBuilder: (_, i) {
            final mv = bucket.mvs[i];
            return _MvSearchCard(mv: mv);
          },
        ),
    };
  }
}

class _MvSearchCard extends StatelessWidget {
  final MusicVideo mv;

  const _MvSearchCard({required this.mv});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                mv.cover.isNotEmpty
                    ? CoverNetworkImage(url: mv.cover, fit: BoxFit.cover)
                    : Container(color: AppColors.surface),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          mv.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (mv.artist.isNotEmpty)
          Text(
            mv.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool hot;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.onTap,
    this.hot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: hot
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: hot ? AppColors.primary : AppColors.textSecondary,
            fontWeight: hot ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
