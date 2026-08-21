import 'dart:io';

/// Dart/BoringSSL 在部分 Windows 上不会触发系统根证书懒加载，
/// 导致正常 HTTPS 出现 CERTIFICATE_VERIFY_FAILED（handshake.cc）。
/// 仅 Windows 启用，并对业务相关域名放行证书校验失败。
class WindowsHttpOverrides extends HttpOverrides {
  static const _allowedSuffixes = [
    'ios.25pan.com',
    'i.webos.im',
    '25pan.com',
    'youtube.com',
    'googlevideo.com',
    'ytimg.com',
    'ggpht.com',
    'googleusercontent.com',
    'douyin.com',
    'douyinpic.com',
    'byteimg.com',
    '365yg.com',
    'music.126.net',
    '126.net',
    'kuwo.cn',
    'kugou.com',
    'kgimg.com',
    'gtimg.com',
    'qq.com',
    'qpic.cn',
    'y.qq.com',
  ];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      return _isAllowedHost(host);
    };
    return client;
  }

  static bool _isAllowedHost(String host) {
    final h = host.toLowerCase();
    for (final suffix in _allowedSuffixes) {
      if (h == suffix || h.endsWith('.$suffix')) return true;
    }
    return false;
  }
}
