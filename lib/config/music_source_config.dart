/// TabOS 音源模式与 API source 参数映射。
///
/// 搜索音源顺序对齐官网 freeMusicPlayerStore：
/// `he = ["kuwo","netease","qq","kugou","soda"]`
class MusicSourceConfig {
  MusicSourceConfig._();

  /// 官网汽水音源 id 为 soda（旧 qishui 别名仍兼容）。
  static const sodaSource = 'soda';
  static const qishuiApiSource = sodaSource;
  static const qishuiAlias = 'qishui';

  /// YouTube 曲库（本机直连 youtube.com，不经 TabOS）。
  static const youtubeSource = 'youtube';

  /// 发现页/歌单/榜单默认走网易云，与 TabOS 官方发现页数据一致。
  static const discoverCatalogSource = 'netease';
  static const standardDefaultSource = discoverCatalogSource;

  /// 搜索页默认音源（官网 Na / 默认 kuwo）。
  static const searchDefaultSource = 'kuwo';

  /// 搜索音源顺序（官网 pe + YouTube）。
  static const searchSourceOrder = [
    'kuwo',
    'netease',
    'qq',
    'kugou',
    sodaSource,
    youtubeSource,
  ];

  /// MV 搜索音源顺序（官网 ve，不含 soda）。
  static const searchMvSourceOrder = [
    'netease',
    'qq',
    'kuwo',
    'kugou',
    youtubeSource,
  ];

  static const standardProviders = [
    (id: 'netease', label: '网易云'),
    (id: 'kuwo', label: '酷我'),
    (id: 'qq', label: 'QQ 音乐'),
    (id: 'kugou', label: '酷狗'),
    (id: youtubeSource, label: 'YouTube'),
  ];

  static bool isYoutube(String? source) => source == youtubeSource;

  static bool isSoda(String? source) =>
      source == sodaSource || source == qishuiAlias;

  /// TabOS 聚合 `/search/*` 可用的 source（汽水/YouTube 走独立接口）。
  static String tabosCompatibleSource(String source) {
    if (isYoutube(source) || isSoda(source)) {
      return discoverCatalogSource;
    }
    return source;
  }

  static String sourceLabel(String id) {
    if (isSoda(id)) return '汽水';
    if (isYoutube(id)) return 'YouTube';
    for (final item in standardProviders) {
      if (item.id == id) return item.label;
    }
    return id;
  }
}

enum MusicSourceMode {
  qishui('qishui', '汽水'),
  standard('standard', '标准');

  const MusicSourceMode(this.storageKey, this.label);

  final String storageKey;
  final String label;
}
