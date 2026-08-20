import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/music_source_config.dart';
import '../providers/music_source_provider.dart';
import '../theme/app_theme.dart';
import 'xmusic_wordmark.dart';

enum AppNavItem {
  discover,
  playlists,
  mv,
  recommend,
  charts,
  recent,
  local,
  liked,
  search,
  settings,
}

class AppSidebar extends StatefulWidget {
  final AppNavItem selected;
  final ValueChanged<AppNavItem> onSelect;

  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  /// 默认收起，点开「发现」后才显示歌单 / MV。
  bool _discoverExpanded = false;

  bool get _discoverActive =>
      widget.selected == AppNavItem.discover ||
      widget.selected == AppNavItem.playlists ||
      widget.selected == AppNavItem.mv;

  @override
  void didUpdateWidget(covariant AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final onChild = widget.selected == AppNavItem.playlists ||
        widget.selected == AppNavItem.mv;
    if (onChild && !_discoverExpanded) {
      _discoverExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: XmusicWordmark(height: 18),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _DiscoverSectionHeader(
                    expanded: _discoverExpanded,
                    active: _discoverActive,
                    onTap: () {
                      final willExpand = !_discoverExpanded;
                      setState(() => _discoverExpanded = willExpand);
                      // 点「发现」进入发现首页，不自动选中歌单。
                      widget.onSelect(AppNavItem.discover);
                    },
                  ),
                  if (_discoverExpanded) ...[
                    _SubNavTile(
                      icon: Icons.queue_music_rounded,
                      label: '歌单',
                      selected: widget.selected == AppNavItem.playlists,
                      onTap: () => widget.onSelect(AppNavItem.playlists),
                    ),
                    _SubNavTile(
                      icon: Icons.ondemand_video_outlined,
                      label: 'MV',
                      selected: widget.selected == AppNavItem.mv,
                      onTap: () => widget.onSelect(AppNavItem.mv),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _NavTile(
                    icon: Icons.star_outline_rounded,
                    label: '推荐',
                    selected: widget.selected == AppNavItem.recommend,
                    badge: Selector<MusicSourceProvider, String>(
                      selector: (_, p) => p.badgeLabel,
                      builder: (_, label, __) => _SourceBadge(
                        label: label,
                        onTap: () => _showSourceSheet(context),
                      ),
                    ),
                    onTap: () => widget.onSelect(AppNavItem.recommend),
                  ),
                  _NavTile(
                    icon: Icons.emoji_events_outlined,
                    label: '排行榜',
                    selected: widget.selected == AppNavItem.charts,
                    onTap: () => widget.onSelect(AppNavItem.charts),
                  ),
                  const SizedBox(height: 12),
                  _NavTile(
                    icon: Icons.history_rounded,
                    label: '最近播放',
                    selected: widget.selected == AppNavItem.recent,
                    onTap: () => widget.onSelect(AppNavItem.recent),
                  ),
                  _NavTile(
                    icon: Icons.audio_file_outlined,
                    label: '本地音乐',
                    selected: widget.selected == AppNavItem.local,
                    onTap: () => widget.onSelect(AppNavItem.local),
                  ),
                  _NavTile(
                    icon: Icons.favorite_border_rounded,
                    label: '我喜欢的音乐',
                    selected: widget.selected == AppNavItem.liked,
                    onTap: () => widget.onSelect(AppNavItem.liked),
                  ),
                  const SizedBox(height: 12),
                  _NavTile(
                    icon: Icons.search_rounded,
                    label: '搜索',
                    selected: widget.selected == AppNavItem.search,
                    onTap: () => widget.onSelect(AppNavItem.search),
                  ),
                  _NavTile(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    selected: widget.selected == AppNavItem.settings,
                    onTap: () => widget.onSelect(AppNavItem.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceSheet(BuildContext context) {
    final provider = context.read<MusicSourceProvider>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '切换音源',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '不登录也可以使用汽水接口',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _SourceOption(
                  title: '汽水',
                  subtitle: '抖音汽水音乐 · 无需登录即可使用',
                  selected: provider.isQishui,
                  onTap: () async {
                    await provider.setMode(MusicSourceMode.qishui);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _SourceOption(
                  title: '标准',
                  subtitle: '酷我 / 网易云 / QQ / 酷狗',
                  selected: !provider.isQishui,
                  onTap: () async {
                    await provider.setMode(MusicSourceMode.standard);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                if (!provider.isQishui) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '标准音源',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in MusicSourceConfig.standardProviders)
                        ChoiceChip(
                          label: Text(item.label),
                          selected: provider.standardProvider == item.id,
                          onSelected: (_) async {
                            await provider.setStandardProvider(item.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: provider.standardProvider == item.id
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                          backgroundColor: AppColors.background,
                          side: BorderSide(
                            color: provider.standardProvider == item.id
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiscoverSectionHeader extends StatelessWidget {
  final bool expanded;
  final bool active;
  final VoidCallback onTap;

  const _DiscoverSectionHeader({
    required this.expanded,
    required this.active,
    required this.onTap,
  });

  static const _activeBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final highlighted = active;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: highlighted ? _activeBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 20,
                  color: highlighted ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '发现',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: highlighted ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: highlighted ? Colors.white70 : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (badge != null) badge!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SourceBadge({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isQishui = label == MusicSourceMode.qishui.label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isQishui ? AppColors.primary : AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isQishui ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SourceOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
