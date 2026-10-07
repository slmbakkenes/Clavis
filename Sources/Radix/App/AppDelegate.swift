import AppKit
import RadixCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var model: AppModel!
  private var router: InputRouter!
  private let applicationLoader = ApplicationLoader()
  private let scriptLoader = ScriptLoader()
  private let clipboardMonitor = ClipboardMonitor()
  private let systemHooks = SystemHooks()
  private let mediaKeyForwarder = MediaKeyForwarder()
  private let hyperKey = HyperKey()
  /// Last hook failure shown, so a missing permission is reported once rather
  /// than on every config change.
  private var reportedHookErrors: Set<String> = []
  /// `pkill` and `make install` send SIGTERM, which skips
  /// applicationWillTerminate unless it is routed through NSApp.terminate.
  private var terminationSignalSource: DispatchSourceSignal?
  /// Bookmark files change rarely; re-reading them on every show is wasted IO.
  private static let bookmarkRefreshInterval: TimeInterval = 300
  private var bookmarksLoadedAt: Date?
  private var isLoadingBookmarks = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Gruvbox dark until config says otherwise (see `Theme`), so the alert
    // below matches the panel when the config can't be read.
    NSApp.appearance = NSAppearance(named: .darkAqua)

    let store = ConfigStore()
    let loaded: (config: Config, state: AppState)
    do {
      loaded = try store.load()
    } catch {
      // Don't run on defaults silently: a typo in config.json would otherwise
      // be overwritten on the next save.
      let alert = NSAlert()
      alert.messageText = "Radix cannot read its configuration"
      alert.informativeText = "\(error)\n\nFix ~/.config/radix and relaunch."
      // Accessory apps aren't active, so the alert would open behind everything.
      NSApp.activate()
      alert.window.level = .floating
      alert.runModal()
      NSApp.terminate(nil)
      return
    }

    installTerminationSignalHandler()
    applyAppearance(loaded.config.appearance)
    model = AppModel(store: store, config: loaded.config, state: loaded.state)
    router = InputRouter(model: model)

    PanelManager.shared.setRootView(RootView(model: model))
    model.onPreferredHeightChanged = { height in
      PanelManager.shared.setHeight(height)
    }
    // Size before the first show so the panel doesn't open tall and shrink.
    PanelManager.shared.setHeight(model.preferredPanelHeight)
    startLoadingSearchSources()
    startClipboard()
    PanelManager.shared.preferredScreen = preferredScreen(for: loaded.config)
    HotKeyManager.shared.start(router: router, config: loaded.config)
    applySystemHooks(loaded.config)
    HotKeyManager.shared.onItemHotKey = { [weak self] id in
      Task { await self?.model.runFromShortcut(itemID: id) }
    }
    systemHooks.observe { [weak self] in
      guard let self else { return }
      // Another Radix build launched or quit: install or drop system hooks.
      HotKeyManager.shared.apply(config: model.config)
      applySystemHooks(model.config)
    }

    let panelOnShow = PanelManager.shared.onShow
    PanelManager.shared.onShow = { [weak self] target in
      panelOnShow?(target)
      guard let self else { return }
      let wasTrusted = model.isAccessibilityTrusted
      model.onShow(target: target)
      // Hooks that failed for lack of Accessibility work once it is granted.
      if !wasTrusted && model.isAccessibilityTrusted {
        applySystemHooks(model.config)
      }
      reloadBookmarksIfStale()
    }
    let panelOnHide = PanelManager.shared.onHide
    PanelManager.shared.onHide = { [weak self] in
      panelOnHide?()
      self?.model.onHide()
    }

    model.onConfigChanged = { [weak self] old, config in
      guard let self else { return }
      guard let old else {
        PanelManager.shared.preferredScreen = preferredScreen(for: config)
        HotKeyManager.shared.apply(config: config)
        applySystemHooks(config)
        syncLaunchAtLogin(config.launchAtLogin)
        return
      }
      // Only what changed is re-applied: text fields such as the custom search
      // URL save on every keystroke, and re-registering every hotkey, event tap
      // and the hidutil remap per character would be wasteful.
      if old.showWindowOn != config.showWindowOn {
        PanelManager.shared.preferredScreen = preferredScreen(for: config)
      }
      if old.globalShortcut != config.globalShortcut || old.shortcuts != config.shortcuts {
        HotKeyManager.shared.apply(config: config)
      }
      if old.mediaKeyForwardingEnabled != config.mediaKeyForwardingEnabled
        || old.hyperKeyEnabled != config.hyperKeyEnabled
      {
        applySystemHooks(config)
      }
      if old.launchAtLogin != config.launchAtLogin {
        syncLaunchAtLogin(config.launchAtLogin)
      }
      if old.appearance != config.appearance {
        applyAppearance(config.appearance)
      }
    }
    syncLaunchAtLogin(loaded.config.launchAtLogin)

    PanelManager.shared.showWindow()
  }

  private func installTerminationSignalHandler() {
    signal(SIGTERM, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    source.setEventHandler {
      MainActor.assumeIsolated { NSApp.terminate(nil) }
    }
    source.resume()
    terminationSignalSource = source
  }

  func applicationWillTerminate(_ notification: Notification) {
    model?.flushPendingSaves()
    model?.clipboard.flushPendingSave()
    // The hyperkey remap is system-wide and would outlive the process.
    do {
      try hyperKey.setEnabled(false)
    } catch {
      NSLog("Could not remove the hyper key mapping: \(error)")
    }
  }

  /// Picks the gruvbox variant. The app appearance also settles the vibrancy
  /// material and every AppKit control that resolves a semantic colour;
  /// `nil` follows the system, including when it switches at sunset.
  private func applyAppearance(_ appearance: Config.Appearance) {
    switch appearance {
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    case .system: NSApp.appearance = nil
    }
  }

  /// Media keys and the hyperkey follow config, but only while no other
  /// Radix build is running (see `SystemHooks`).
  private func applySystemHooks(_ config: Config) {
    let allowed = SystemHooks.areAllowed
    setHook(named: "Media key forwarding") {
      try mediaKeyForwarder.setEnabled(allowed && config.mediaKeyForwardingEnabled)
    }
    setHook(named: "Hyper key") {
      try hyperKey.setEnabled(allowed && config.hyperKeyEnabled)
    }
  }

  private func setHook(named name: String, _ apply: () throws -> Void) {
    do {
      try apply()
    } catch {
      let message = "\(name): \(error)"
      NSLog(message)
      if reportedHookErrors.insert(message).inserted {
        ToastManager.shared.show(text: message, variant: .error, timeout: 5)
      }
    }
  }

  private func startClipboard() {
    clipboardMonitor.onText = { [weak self] text, bundle in
      self?.model.clipboard.addText(text, bundle: bundle)
    }
    clipboardMonitor.onFile = { [weak self] name, path, bundle in
      self?.model.clipboard.addFile(name: name, path: path, bundle: bundle)
    }
    clipboardMonitor.start()
    // Both builds write into the same images directory; cleaning up while the
    // other one runs would delete images its history still shows.
    if SystemHooks.areAllowed {
      model.clipboard.cleanUpOrphanedImages()
    }
  }

  private func startLoadingSearchSources() {
    model.builtInItems = BuiltInItems.make()
    applicationLoader.start { [weak self] items in
      NSLog("Search sources: \(items.count) applications")
      self?.model.applications = items
      self?.model.refreshRunningApplications()
    }
    scriptLoader.start { [weak self] items in
      NSLog("Search sources: \(items.count) scripts")
      self?.model.scripts = items
    }
    Task { [weak self] in
      let panes = await PreferencePanes.load()
      NSLog("Search sources: \(panes.count) preference panes")
      self?.model.preferencePanes = panes
    }
    reloadBookmarksIfStale()
  }

  private func reloadBookmarksIfStale() {
    guard !isLoadingBookmarks else { return }
    if let loadedAt = bookmarksLoadedAt, Date().timeIntervalSince(loadedAt) < Self.bookmarkRefreshInterval {
      return
    }
    isLoadingBookmarks = true
    Task { [weak self] in
      let bookmarks = await BookmarkLoader.load()
      guard let self else { return }
      NSLog("Search sources: \(bookmarks.count) bookmarks")
      model.bookmarks = bookmarks
      bookmarksLoadedAt = Date()
      isLoadingBookmarks = false
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    PanelManager.shared.showWindow()
    return true
  }

  private func preferredScreen(for config: Config) -> PreferredScreen {
    switch config.showWindowOn {
    case .screenWithFrontmost: .frontmost
    case .screenWithCursor: .withMouse
    }
  }

  /// Only the installed app registers as a login item: an unbundled
  /// `make debug` run or a differently identified build would otherwise start
  /// at login alongside it and fight over the toggle shortcut.
  private func syncLaunchAtLogin(_ enabled: Bool) {
    let isFinalBundle = Bundle.main.bundleIdentifier == "com.svenbakkenes.radix"
    let wanted = enabled && isFinalBundle
    guard LaunchAtLogin.isEnabled != wanted else { return }
    do {
      try LaunchAtLogin.set(wanted)
    } catch {
      NSLog("Launch at login: \(error)")
    }
  }
}
