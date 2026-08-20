/// 音乐 API 配置
/// 资源来源: https://i.webos.im/ (代理至 TabOS 音乐服务)
class ApiConfig {
  static const String proxyUrl = 'https://i.webos.im/';
  static const String apiBase = 'https://ios.25pan.com';
  static const String musicApi = '$apiBase/api/music';
  static const String sessionApi = '$apiBase/api/v1/music/secure/session';
  static const String defaultSource = 'netease';
  static const String qishuiSource = 'qishui';

  static const String acceptHeader =
      'application/vnd.tabos.music+json; charset=utf-8';
}
