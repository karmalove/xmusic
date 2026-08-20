import Cocoa
import FlutterMacOS

final class StatusItemController: NSObject {
  static let shared = StatusItemController()

  private var statusItem: NSStatusItem?
  private weak var appDelegate: AppDelegate?
  private var channel: FlutterMethodChannel?

  private var title: String?
  private var artist: String?
  private var isPlaying = false
  private var showTitleInBar = false

  private override init() {
    super.init()
  }

  func configure(appDelegate: AppDelegate, channel: FlutterMethodChannel) {
    self.appDelegate = appDelegate
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      if call.method == "showWindow" {
        DispatchQueue.main.async { [weak self] in
          self?.appDelegate?.showMainWindow(nil)
          result(nil)
        }
      } else if call.method == "updatePlayback" {
        let args = call.arguments as? [String: Any] ?? [:]
        let newTitle = args["title"] as? String
        let newArtist = args["artist"] as? String
        let newPlaying = (args["isPlaying"] as? Bool) ?? false
        let newShowTitle = (args["showTitleInBar"] as? Bool) ?? false
        let menuNeedsUpdate =
          newTitle != self.title ||
          newArtist != self.artist ||
          newPlaying != self.isPlaying ||
          newShowTitle != self.showTitleInBar
        self.title = newTitle
        self.artist = newArtist
        self.isPlaying = newPlaying
        self.showTitleInBar = newShowTitle
        self.refreshAppearance()
        if menuNeedsUpdate {
          self.statusItem?.menu = self.buildMenu()
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func show() {
    if statusItem == nil {
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
      if let button = item.button {
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      }
      statusItem = item
    }
    refreshAppearance()
    statusItem?.menu = nil
  }

  func hide() {
    if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
      statusItem = nil
    }
  }

  @objc private func statusItemClicked(_ sender: Any?) {
    guard let event = NSApp.currentEvent else {
      playNext()
      return
    }
    if event.type == .rightMouseUp {
      showContextMenu()
    } else {
      playNext()
    }
  }

  private func showContextMenu() {
    guard let item = statusItem, let button = item.button else { return }
    let menu = buildMenu()
    // Temporarily attach menu so it pops under the status item
    item.menu = menu
    menu.delegate = self
    button.performClick(nil)
  }

  private func refreshAppearance() {
    guard let item = statusItem, let button = item.button else { return }

    let image = Self.menuBarImage()
    button.image = image
    button.imagePosition = .imageLeft

    let showTitle = showTitleInBar && (title?.isEmpty == false)
    item.length = showTitle ? NSStatusItem.variableLength : NSStatusItem.squareLength

    if showTitle, let title {
      let label = truncated(title, max: 18)
      button.title = " \(label)"
      var tip = title
      if let artist, !artist.isEmpty {
        tip = "\(title) — \(artist)"
      }
      tip += isPlaying ? "  · 播放中" : "  · 已暂停"
      tip += "\n左键：下一首 · 右键：更多"
      button.toolTip = tip
    } else {
      button.title = ""
      button.toolTip = "XMUSIC\n左键：下一首 · 右键：查看当前播放"
    }
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let nowPlaying: String
    if let title, !title.isEmpty {
      if let artist, !artist.isEmpty {
        nowPlaying = truncated("\(title) — \(artist)", max: 40)
      } else {
        nowPlaying = truncated(title, max: 40)
      }
    } else {
      nowPlaying = "暂无播放"
    }

    let info = NSMenuItem(title: nowPlaying, action: nil, keyEquivalent: "")
    info.isEnabled = false
    menu.addItem(info)
    menu.addItem(NSMenuItem.separator())

    let playPause = NSMenuItem(
      title: isPlaying ? "暂停" : "播放",
      action: #selector(togglePlay),
      keyEquivalent: ""
    )
    playPause.target = self
    menu.addItem(playPause)

    let next = NSMenuItem(title: "下一首", action: #selector(playNext), keyEquivalent: "")
    next.target = self
    menu.addItem(next)

    let prev = NSMenuItem(title: "上一首", action: #selector(playPrevious), keyEquivalent: "")
    prev.target = self
    menu.addItem(prev)

    menu.addItem(NSMenuItem.separator())

    let show = NSMenuItem(
      title: "显示 XMUSIC",
      action: #selector(showMainWindowAction(_:)),
      keyEquivalent: ""
    )
    show.target = self
    menu.addItem(show)

    menu.addItem(NSMenuItem.separator())

    let quit = NSMenuItem(
      title: "退出 XMUSIC",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quit.target = NSApp
    menu.addItem(quit)

    return menu
  }

  @objc private func showMainWindowAction(_ sender: Any?) {
    appDelegate?.showMainWindow(sender)
  }

  @objc private func playNext() {
    channel?.invokeMethod("next", arguments: nil)
  }

  @objc private func playPrevious() {
    channel?.invokeMethod("previous", arguments: nil)
  }

  @objc private func togglePlay() {
    channel?.invokeMethod("togglePlay", arguments: nil)
  }

  private func truncated(_ text: String, max: Int) -> String {
    guard text.count > max else { return text }
    let end = text.index(text.startIndex, offsetBy: max)
    return String(text[..<end]) + "…"
  }

  private static func menuBarImage() -> NSImage? {
    if let image = NSImage(named: "MenuBarIcon") {
      image.isTemplate = true
      image.size = NSSize(width: 18, height: 18)
      return image
    }

    if #available(macOS 11.0, *) {
      if let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "XMUSIC") {
        image.isTemplate = true
        return image
      }
    }

    return nil
  }
}

extension StatusItemController: NSMenuDelegate {
  func menuDidClose(_ menu: NSMenu) {
    // Detach menu so left-click goes back to "next track"
    statusItem?.menu = nil
  }
}
