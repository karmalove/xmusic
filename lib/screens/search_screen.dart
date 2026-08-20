import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/xmusic_wordmark.dart';
import 'playlist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final MusicApiService _api = MusicApiService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  bool _loading = false;
  bool _searched = false;
  String _query = '';
  String? _error;

  static const _hotSearches = [
    '周杰伦',
    '邓紫棋',
    '林俊杰',
    '薛之谦',
    '毛不易',
    '陈奕迅',
    '五月天',
    '李荣浩',
    '华晨宇',
    '张学友',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;

    _focusNode.unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _query = q;
      _error = null;
      _songs = [];
      _playlists = [];
    });

    List<Song> songs = [];
    List<Playlist> playlists = [];
    String? error;

    try {
      songs = await _api.searchSongs(q);
    } catch (e) {
      error = '歌曲搜索失败: $e';
    }

    try {
      playlists = await _api.searchPlaylists(q);
    } catch (e) {
      error ??= '歌单搜索失败: $e';
    }

    if (mounted) {
      setState(() {
        _songs = songs;
        _playlists = playlists;
        _loading = false;
        if (songs.isEmpty && playlists.isEmpty && error != null) {
          _error = error;
        }
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _searched = false;
      _songs = [];
      _playlists = [];
      _error = null;
      _query = '';
    });
  }

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: '搜索歌曲、歌手、专辑',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: IconButton(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _search(),
                    tooltip: '搜索',
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                            color: AppColors.primary,
                            onPressed: () => _search(),
                            tooltip: '搜索',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: AppColors.textMuted,
                            onPressed: _clear,
                            tooltip: '清除',
                          ),
                        ],
                      );
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: _search,
                onEditingComplete: () => _search(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _searched
                ? _buildResults()
                : _buildHotSearches(),
          ),
        ],
      ),
    );
  }

  Widget _buildHotSearches() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '热门搜索',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _hotSearches.asMap().entries.map((entry) {
            final isHot = entry.key < 3;
            return GestureDetector(
              onTap: () {
                _controller.text = entry.value;
                _search(entry.value);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: isHot
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        )
                      : null,
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isHot ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isHot ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_error != null && _songs.isEmpty && _playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
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

    if (_songs.isEmpty && _playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '未找到"$_query"的相关结果',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_songs.isNotEmpty) ...[
          SectionHeader(title: '歌曲 (${_songs.length})'),
          ..._songs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            return SongTile(
              title: song.name,
              subtitle: '${song.artistName} · ${song.album.name}',
              coverUrl: song.cover,
              trailing: song.durationText,
              onTap: () => context.read<PlayerProvider>().playSong(
                song,
                queue: _songs,
                index: index,
              ),
            );
          }),
        ],
        if (_playlists.isNotEmpty) ...[
          SectionHeader(title: '歌单 (${_playlists.length})'),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _playlists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final pl = _playlists[i];
                return PlaylistCard(
                  title: pl.name,
                  coverUrl: pl.cover,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(
                          title: pl.name,
                          playlistId: pl.id,
                          source: pl.source,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }
}
