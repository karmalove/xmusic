# Xmusic

跨平台音乐播放器，支持 **Android、iOS、Windows、macOS、Linux**。

UI 参考汽水音乐风格 —— 深色主题、渐变强调色、模糊封面背景、沉浸式全屏播放器。

## 音乐资源

本项目使用 [i.webos.im](https://i.webos.im/) 提供的音乐 API 服务（TabOS 音乐后端），支持：

- 多平台音源搜索（酷我、网易云、QQ 音乐、酷狗）
- 私人 FM 推荐
- 排行榜与歌单
- 歌词发现
- 高品质音频播放

## 功能特性

- **发现页** — 私人 FM、排行榜、推荐歌单、新歌推荐
- **搜索** — 歌曲/歌单搜索，热门搜索快捷入口
- **播放器** — 全屏沉浸式播放界面，支持播放/暂停、上下曲、进度拖动、循环/随机
- **迷你播放条** — 底部常驻，快速控制播放
- **安全通信** — ECDH + HKDF + AES-GCM 加密 API 通信

## 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Flutter 3.x |
| 音频 | just_audio + audio_session |
| 状态管理 | Provider |
| 加密 | cryptography (ECDH P-256, HKDF, AES-GCM) |
| 序列化 | msgpack_dart |
| 网络 | http + cached_network_image |

## 快速开始

### 环境要求

- Flutter SDK >= 3.12
- 对应平台的开发工具链（Xcode / Android Studio / Visual Studio）

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# iOS 模拟器
flutter run -d ios

# Android 模拟器/设备
flutter run -d android
```

### 构建发布版

```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release
# 发布 zip 需随包附带 VC++ 运行库 DLL（msvcp140 / vcruntime140 / vcruntime140_1）
# CI 已自动打包；若手动分发请从 System32 复制上述 DLL 到 exe 同目录
# 或安装 https://aka.ms/vs/17/release/vc_redist.x64.exe

# Linux
flutter build linux --release

# iOS
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── config/
│   └── api_config.dart       # API 配置
├── models/
│   └── song.dart             # 数据模型
├── services/
│   ├── music_secure_session.dart  # 安全会话 (ECDH/HKDF/AES)
│   └── music_api_service.dart     # 音乐 API 客户端
├── providers/
│   └── player_provider.dart  # 播放器状态管理
├── theme/
│   └── app_theme.dart        # 汽水音乐风格主题
├── screens/
│   ├── home_screen.dart      # 主界面 (Tab 导航)
│   ├── discover_screen.dart  # 发现页
│   ├── search_screen.dart    # 搜索页
│   ├── player_screen.dart    # 全屏播放器
│   └── playlist_detail_screen.dart  # 歌单/排行榜详情
└── widgets/
    └── common_widgets.dart   # 通用 UI 组件
```

## 注意事项

- 音乐 API 需要网络连接
- API 服务由第三方提供，可用性取决于服务端状态
- Windows：若提示缺少 `vcruntime140_1.dll`，安装 [VC++ x64 运行库](https://aka.ms/vs/17/release/vc_redist.x64.exe)，或使用 Release 包内已附带的 DLL / `vc_redist.x64.exe`
- Windows：若出现 `CERTIFICATE_VERIFY_FAILED` / `handshake.cc`，请使用 v1.0.4+（已处理系统根证书懒加载问题）
- 本项目仅供学习交流使用

## License

MIT
