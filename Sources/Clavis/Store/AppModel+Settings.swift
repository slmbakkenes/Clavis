import AppKit
import ClavisCore

/// A shortcut being captured in settings. `keys` is what was pressed so far,
/// shown back to the user; `error` explains a rejected combination.
struct ShortcutRecording: Equatable {
  enum Target: Equatable {
    /// Assigns the recorded shortcut to this item.
    case item(String)
    /// Filters Settings > Items by the recorded shortcut.
    case filter
  }

  let target: Target
  var keys: [String] = []
  var error: String?
  /// A shortcut was accepted and is on show; further keys don't record.
  var isFinished = false
}

/// Settings actions. Everything goes through `updateConfig`/`updateState`, so
/// saves stay merge-safe and hotkeys, hooks and login item follow along.
extension AppModel {
  /// How long a recorded shortcut stays visible before the recorder closes.
  static let recordedShortcutDisplay: Duration = .milliseconds(1200)

  // MARK: Items

  /// Every item that can be enabled, disabled or given a shortcut, including
  /// disabled ones, sorted by name.
  var settingsItems: [Item] {
    allItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  func isItemEnabled(_ id: String) -> Bool {
    !config.disabledItemIds.contains(id)
  }

  /// Disabling also removes the item's shortcut, as before.
  func setItem(_ id: String, enabled: Bool) {
    updateConfig { config in
      config.disabledItemIds.removeAll { $0 == id }
      if !enabled {
        config.disabledItemIds.append(id)
        config.shortcuts[id] = nil
      }
    }
  }

  // MARK: Shortcuts

  /// Assigns a shortcut. Returns false when another item already uses it.
  @discardableResult
  func setShortcut(_ shortcut: String, for itemID: String) -> Bool {
    let normalized = ShortcutFormat.normalize(shortcut)
    if !normalized.isEmpty, let owner = itemUsingShortcut(normalized, except: itemID) {
      ToastManager.shared.show(text: "Shortcut already used by \(itemName(for: owner))", variant: .error, timeout: 4)
      return false
    }
    updateConfig { $0.shortcuts[itemID] = normalized.isEmpty ? nil : normalized }
    return true
  }

  /// Compares key and modifiers, not strings: "option+control+k" and
  /// "control+option+k" are the same combination, and Carbon would register
  /// only one of them.
  func itemUsingShortcut(_ shortcut: String, except itemID: String) -> String? {
    guard let wanted = Shortcut(parsing: shortcut) else { return nil }
    return config.shortcuts.first { id, raw in
      guard id != itemID, let existing = Shortcut(parsing: raw) else { return false }
      return existing.modifiers == wanted.modifiers && existing.key == wanted.key
    }?.key
  }

  func itemName(for id: String) -> String {
    allItems.first { $0.id == id }?.name ?? id
  }

  /// ⌘/⌥/⌃ + Space open Clavis itself (Settings > General).
  static func isLauncherCombination(_ shortcut: Shortcut) -> Bool {
    shortcut.key == "space" && [Modifiers.command, .option, .control].contains(shortcut.modifiers)
  }

  func clearShortcut(for itemID: String) {
    updateConfig { $0.shortcuts[itemID] = nil }
  }

  func restoreDefaultShortcuts() {
    updateConfig { $0.shortcuts = Config.defaultShortcuts }
  }

  func startRecordingShortcut(for itemID: String) {
    beginRecording(.item(itemID))
  }

  func startRecordingShortcutFilter() {
    beginRecording(.filter)
  }

  /// Closes the recorder and registers Clavis's shortcuts again.
  func cancelShortcutRecording() {
    shortcutRecording = nil
    HotKeyManager.shared.setItemHotKeysPaused(false)
  }

  /// Called by the input router with the pressed combination, modifiers
  /// first ("command", "option", "control", "shift") then the key token.
  func recordShortcut(keys: [String]) {
    guard var recording = shortcutRecording, !recording.isFinished else { return }
    recording.keys = keys
    recording.error = nil
    let raw = keys.joined(separator: "+")

    guard let shortcut = Shortcut(parsing: raw), KeyCodes.keyCode(forShortcutToken: shortcut.key) != nil else {
      recording.error = "That key can't be used in a shortcut"
      shortcutRecording = recording
      return
    }

    switch recording.target {
    case .filter:
      shortcutFilter = shortcut.string
    case .item(let itemID):
      // A global ⇧K would take that key away from every app.
      guard !shortcut.modifiers.isDisjoint(with: [.command, .option, .control]) else {
        recording.error = "Add ⌘, ⌥ or ⌃"
        shortcutRecording = recording
        return
      }
      guard !Self.isLauncherCombination(shortcut) else {
        recording.error = "Reserved for opening Clavis"
        shortcutRecording = recording
        return
      }
      if let owner = itemUsingShortcut(shortcut.string, except: itemID) {
        recording.error = "Already used by \(itemName(for: owner))"
        shortcutRecording = recording
        return
      }
      setShortcut(shortcut.string, for: itemID)
    }

    // Shortcuts stay unregistered while the result is on show, so releasing
    // the keys just pressed can't run the item, and further presses are
    // ignored instead of reassigning it.
    recording.isFinished = true
    shortcutRecording = recording
    let shown = recording
    Task { [weak self] in
      try? await Task.sleep(for: Self.recordedShortcutDisplay)
      guard let self, shortcutRecording == shown else { return }
      cancelShortcutRecording()
    }
  }

  private func beginRecording(_ target: ShortcutRecording.Target) {
    shortcutRecording = ShortcutRecording(target: target)
    HotKeyManager.shared.setItemHotKeysPaused(true)
  }

  // MARK: General

  func setSaveClipboardHistory(_ enabled: Bool) {
    updateState { $0.clipboard.saveHistory = enabled }
    clipboard.setSaveHistory(enabled)
  }

  /// Picks one or more folders for file search. The picker takes focus, which
  /// hides the panel, so settings reopen afterwards.
  func addSearchFolders() {
    // Out of the button action, so the modal loop doesn't run nested inside
    // SwiftUI's event handling.
    Task { @MainActor [weak self] in
      let previousApp = NSWorkspace.shared.frontmostApplication
      PanelManager.shared.hideWindow()
      let picker = NSOpenPanel()
      picker.canChooseDirectories = true
      picker.canChooseFiles = false
      picker.allowsMultipleSelection = true
      picker.prompt = "Add"
      NSApp.activate()
      let response = picker.runModal()
      if response == .OK, let self {
        let picked = picker.urls.map { $0.standardizedFileURL.path }
        updateConfig { config in
          for path in picked where !config.searchFolders.contains(path) {
            config.searchFolders.append(path)
          }
        }
      }
      // Hand focus back, or window actions would target Clavis afterwards.
      if let previousApp, previousApp != NSRunningApplication.current {
        previousApp.activate()
      }
      PanelManager.shared.showWindow(target: .settings)
    }
  }

  func removeSearchFolder(_ path: String) {
    updateConfig { $0.searchFolders.removeAll { $0 == path } }
  }
}
