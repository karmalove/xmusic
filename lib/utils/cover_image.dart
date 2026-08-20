import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 网易云等 CDN 会拦截 Dart 默认 UA（返回 403 / ua_acl.access）。
class CoverImage {
  CoverImage._();

  static const browserUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  static Map<String, String> headersFor(String? url) {
    final headers = <String, String>{
      'User-Agent': browserUserAgent,
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };

    final u = (url ?? '').toLowerCase();
    if (u.contains('music.126.net') ||
        u.contains('126.net') ||
        u.contains('netease')) {
      headers['Referer'] = 'https://music.163.com/';
    } else if (u.contains('gtimg') || u.contains('qq.com')) {
      headers['Referer'] = 'https://y.qq.com/';
    } else if (u.contains('kugou') || u.contains('kgimg')) {
      headers['Referer'] = 'https://www.kugou.com/';
    } else if (u.contains('kuwo')) {
      headers['Referer'] = 'https://www.kuwo.cn/';
    }

    return headers;
  }
}

/// 统一带防盗链 headers 的网络封面图。
class CoverNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final FilterQuality filterQuality;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  const CoverNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.filterQuality = FilterQuality.low,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: CoverImage.headersFor(url),
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      filterQuality: filterQuality,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
