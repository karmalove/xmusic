import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/music_source_config.dart';

/// 管理「汽水 / 标准」音源模式，并映射到 TabOS API `source` 参数。
class MusicSourceProvider extends ChangeNotifier {
  static const _prefMode = 'xmusic_source_mode';
  static const _prefStandardProvider = 'xmusic_standard_provider';
  static const _prefQishuiBound = 'xmusic_qishui_bound';

  MusicSourceMode _mode = MusicSourceMode.standard;
  String _standardProvider = MusicSourceConfig.standardDefaultSource;
  bool _qishuiBound = false;
  bool _ready = false;

  MusicSourceMode get mode => _mode;
  String get standardProvider => _standardProvider;
  bool get qishuiBound => _qishuiBound;
  bool get isReady => _ready;

  bool get isQishui => _mode == MusicSourceMode.qishui;

  /// 当前请求使用的 TabOS `source` 参数。
  String get apiSource => isQishui
      ? MusicSourceConfig.qishuiApiSource
      : _standardProvider;

  /// 发现页歌单/榜单：汽水 catalog 403，统一用网易云发现流。
  String get catalogSource => isQishui
      ? MusicSourceConfig.discoverCatalogSource
      : _standardProvider;

  String get modeDescription => isQishui
      ? '使用抖音汽水音乐接口。不登录也可使用基础推荐；登录后可获得更精准推荐与 SVIP 音质（即将支持）。'
      : '使用酷我、网易云、QQ 音乐、酷狗等多平台聚合接口。';

  String get bindStatusLabel => _qishuiBound ? '已绑定' : '未绑定';

  /// 侧栏「推荐」旁徽章文案：汽水 / 酷我 / 网易云 …
  String get badgeLabel {
    if (isQishui) return MusicSourceMode.qishui.label;
    for (final item in MusicSourceConfig.standardProviders) {
      if (item.id == _standardProvider) return item.label;
    }
    return MusicSourceMode.standard.label;
  }

  MusicSourceProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeKey = prefs.getString(_prefMode);
    _mode = MusicSourceMode.values.firstWhere(
      (m) => m.storageKey == modeKey,
      orElse: () => MusicSourceMode.standard,
    );
    _standardProvider =
        prefs.getString(_prefStandardProvider) ??
        MusicSourceConfig.standardDefaultSource;
    _qishuiBound = prefs.getBool(_prefQishuiBound) ?? false;
    _ready = true;
    notifyListeners();
  }

  Future<void> setMode(MusicSourceMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMode, mode.storageKey);
  }

  Future<void> setStandardProvider(String providerId) async {
    if (_standardProvider == providerId) return;
    _standardProvider = providerId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStandardProvider, providerId);
  }

  /// 预留：扫码绑定汽水账号（当前仅 UI 占位）。
  Future<void> markQishuiBound(bool bound) async {
    _qishuiBound = bound;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefQishuiBound, bound);
  }
}
