/// TabOS 音源模式与 API source 参数映射。
class MusicSourceConfig {
  MusicSourceConfig._();

  static const qishuiApiSource = 'qishui';
  /// 发现页/歌单/榜单默认走网易云，与 TabOS 官方发现页数据一致。
  static const discoverCatalogSource = 'netease';
  static const standardDefaultSource = discoverCatalogSource;
  /// 搜索页默认音源（与网页一致，Na="kuwo"）。
  static const searchDefaultSource = 'kuwo';
  /// 搜索音源顺序（与官网 pe 一致，不含汽水）。
  static const searchSourceOrder = ['kuwo', 'netease', 'qq', 'kugou'];
  /// MV 搜索音源顺序（与官网 Oa 一致）。
  static const searchMvSourceOrder = ['netease', 'qq', 'kuwo', 'kugou'];

  static const standardProviders = [
    (id: 'netease', label: '网易云'),
    (id: 'kuwo', label: '酷我'),
    (id: 'qq', label: 'QQ 音乐'),
    (id: 'kugou', label: '酷狗'),
  ];
}

enum MusicSourceMode {
  qishui('qishui', '汽水'),
  standard('standard', '标准');

  const MusicSourceMode(this.storageKey, this.label);

  final String storageKey;
  final String label;
}
