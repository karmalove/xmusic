import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/local_music_provider.dart';
import 'providers/music_source_provider.dart';
import 'providers/player_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'utils/windows_http_overrides.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows：修复 Dart 无法懒加载系统根证书导致的 SSL 握手失败
  if (Platform.isWindows) {
    HttpOverrides.global = WindowsHttpOverrides();
  }

  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const XmusicApp());
}

class XmusicApp extends StatelessWidget {
  const XmusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicSourceProvider()),
        ChangeNotifierProvider(create: (_) => LocalMusicProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'XMUSIC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
