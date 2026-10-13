import AppKit
import Carbon
import ClavisCore

/// Owns the global shortcuts (toggle, settings, per-item) and the in-app key
/// monitors that feed the `InputRouter`.
@MainActor
final class HotKeyManager {
  static let shared = HotKeyManager()

  /// Fired with the item id when one of the per-item shortcuts is pressed.
  var onItemHotKey: ((String) -> Void)?

  private var router: InputRouter?
  private var mainHotKey: GlobalHotKey?
  private var settingsHotKey: GlobalHotKey?
  private var itemHotKeys: [GlobalHotKey] = []
  /// Set while settings records a shortcut; also applies to shortcuts
  /// registered in the meantime.
  private(set) var itemHotKeysPaused = false
  private var monitors: [Any] = []

  private init() {}

  func start(router: InputRouter, config: Config) {
    self.router = router

    settingsHotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_Comma), modifiers: [.command], trigger: .keyUp) {
      PanelManager.shared.showWindow(target: .settings)
    }
    settingsHotKey?.isPaused = true
    PanelManager.shared.onShow = { [weak self] _ in self?.settingsHotKey?.isPaused = false }
    PanelManager.shared.onHide = { [weak self] in self?.settingsHotKey?.isPaused = true }

    apply(config: config)

    let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let isPanelEvent = MainActor.assumeIsolated { PanelManager.shared.owns(event.window) }
      // Other windows of this process (the folder picker, alerts) keep their
      // keys; routing them would swallow Enter and Esc there and act on the
      // hidden panel instead.
      guard isPanelEvent else { return event }
      let keyCode = event.keyCode
      let flags = event.modifierFlags
      let characters = event.characters
      let isRepeat = event.isARepeat
      // Local monitors run on the main thread; the SDK block isn't annotated.
      let consumed = MainActor.assumeIsolated {
        HotKeyManager.shared.router?.keyDown(
          keyCode: keyCode, flags: flags, characters: characters, isRepeat: isRepeat) ?? false
      }
      return consumed ? nil : event
    }
    if let monitor {
      monitors.append(monitor)
    } else {
      NSLog("Could not install the local key monitor; panel navigation keys will not work")
    }
  }

  /// Re-registers everything derived from config: the toggle modifier and the
  /// per-item shortcuts.
  func apply(config: Config) {
    let modifier: NSEvent.ModifierFlags =
      switch config.globalShortcut {
      case .command: .command
      case .option: .option
      case .control: .control
      }
    // Carbon refuses a duplicate combo within one process, so previous
    // registrations go first, items included: an item holding the new toggle
    // combo would otherwise win and the launcher could not be opened.
    for hotKey in itemHotKeys { hotKey.invalidate() }
    itemHotKeys.removeAll()
    mainHotKey?.invalidate()
    // Toggle on key-down (the old build was inconsistent between the two);
    // it feels snappier and nothing depends on the release.
    mainHotKey = GlobalHotKey(keyCode: UInt32(kVK_Space), modifiers: modifier) {
      PanelManager.shared.toggle()
    }

    // Registration succeeds across processes, so two running builds would
    // both act on every item shortcut.
    guard SystemHooks.areAllowed else { return }
    for (id, raw) in config.shortcuts where !raw.isEmpty {
      guard let shortcut = Shortcut(parsing: raw) else {
        NSLog("Ignoring invalid shortcut for \(id): \(raw)")
        continue
      }
      guard let keyCode = KeyCodes.keyCode(forShortcutToken: shortcut.key) else {
        NSLog("Ignoring shortcut with unsupported key for \(id): \(raw)")
        continue
      }
      var flags: NSEvent.ModifierFlags = []
      if shortcut.modifiers.contains(.command) { flags.insert(.command) }
      if shortcut.modifiers.contains(.option) { flags.insert(.option) }
      if shortcut.modifiers.contains(.control) { flags.insert(.control) }
      if shortcut.modifiers.contains(.shift) { flags.insert(.shift) }
      itemHotKeys.append(
        GlobalHotKey(keyCode: keyCode, modifiers: flags, trigger: .keyUp) { [weak self] in
          self?.onItemHotKey?(id)
        })
      itemHotKeys.last?.isPaused = itemHotKeysPaused
    }
  }

  /// While a shortcut is being recorded, Clavis's own global shortcuts are
  /// unregistered so pressing an existing combo reaches the recorder instead
  /// of running its item.
  func setItemHotKeysPaused(_ paused: Bool) {
    itemHotKeysPaused = paused
    for hotKey in itemHotKeys { hotKey.isPaused = paused }
    settingsHotKey?.isPaused = paused || !PanelManager.shared.isVisible
  }
}
