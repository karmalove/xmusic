import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var trayChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    setupTrayChannelIfNeeded()
  }

  func setupTrayChannel(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "xmusic/tray",
      binaryMessenger: controller.engine.binaryMessenger
    )
    trayChannel = channel
    StatusItemController.shared.configure(appDelegate: self, channel: channel)
  }

  private func setupTrayChannelIfNeeded() {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      setupTrayChannel(with: controller)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showMainWindow(nil)
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  @objc func showMainWindow(_ sender: Any?) {
    NSApp.setActivationPolicy(.regular)

    if let window = mainFlutterWindow {
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    } else {
      for window in NSApp.windows where window.canBecomeKey {
        window.makeKeyAndOrderFront(nil)
      }
    }

    NSApp.activate(ignoringOtherApps: true)

    // Defer hiding the status item until after the menu action finishes.
    DispatchQueue.main.async {
      StatusItemController.shared.hide()
    }
  }

  func enterBackground() {
    setupTrayChannelIfNeeded()
    StatusItemController.shared.show()
    NSApp.setActivationPolicy(.accessory)
  }

  func enterForeground() {
    NSApp.setActivationPolicy(.regular)
    StatusItemController.shared.hide()
  }
}
