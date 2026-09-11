import Foundation

/// System Settings entries, ported from the previous build's
/// `systemPreferences.tsx`: every installed preference pane plus a manual
/// list for the settings that no longer ship a pane bundle.
@MainActor
enum PreferencePanes {
  /// Scans the pane directories off the main thread.
  static func load() async -> [Item] {
    let scanned = await Task.detached(priority: .utility) { scanPanes() }.value
    return scanned.map(scannedItem) + manualItems
  }

  // MARK: Scanned panes

  /// What a pane scan yields; plain data so it can leave the background task.
  struct ScannedPane: Sendable {
    /// The pane bundle path, also the item id.
    let path: String
    let name: String
  }

  nonisolated static let paneDirectories = [
    "/System/Library/PreferencePanes",
    "/Library/PreferencePanes",
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/PreferencePanes").path,
  ]

  /// Covered by `manualItems` or not meaningful on current macOS.
  nonisolated static let ignoredPanes: Set<String> = [
    "ClassKitPreferencePane.prefPane",
    "ClassroomSettings.prefPane",
    "DesktopScreenEffectsPref.prefPane",
    "DigiHubDiscs.prefPane",
    "EnergySaver.prefPane",
    "EnergySaverPref.prefPane",
    "Expose.prefPane",
    "PrintAndFax.prefPane",
    "Spotlight.prefPane",
    "Sound.prefPane",
    "UniversalAccessPref.prefPane",
    "TouchID.prefPane",
    "Displays.prefPane",
    "Battery.prefPane",
    "Network.prefPane",
    "Passwords.prefPane",
  ]

  nonisolated static let nameMappings: [String: String] = [
    "Accounts.prefPane": "Users & Groups",
    "AppleIDPrefPane.prefPane": "Apple ID",
    "DateAndTime.prefPane": "Date & Time",
    "DesktopScreenEffectsPref.prefPane": "Desktop & Screen Saver",
    "FamilySharingPrefPane.prefPane": "Family",
    "PrintAndScan.prefPane": "Printers & Scanners",
    "PrivacyAndSecurity.prefPane": "Privacy & Security",
    "SharingPref.prefPane": "Sharing",
    "TouchID.prefPane": "Touch ID",
    "UniversalAccessPref.prefPane": "Accessibility",
  ]

  nonisolated static func scanPanes() -> [ScannedPane] {
    let fileManager = FileManager.default
    var panes: [ScannedPane] = []
    for directory in paneDirectories {
      // A missing directory (usually the user or global one) is normal.
      guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
      for fileName in entries.sorted() where fileName.hasSuffix(".prefPane") && !ignoredPanes.contains(fileName) {
        let path = "\(directory)/\(fileName)"
        guard let name = paneName(fileName: fileName, panePath: path) else { continue }
        panes.append(ScannedPane(path: path, name: name))
      }
    }
    return panes
  }

  /// The display name from the pane's Info.plist, else a known mapping, else
  /// the file name split on capitals ("SoftwareUpdate" -> "Software Update").
  /// Returns nil for a plist that exists but cannot be parsed.
  nonisolated static func paneName(fileName: String, panePath: String) -> String? {
    let plistPath = "\(panePath)/Contents/Info.plist"
    if FileManager.default.fileExists(atPath: plistPath) {
      let plist: [String: Any]
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: plistPath))
        guard let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
          NSLog("Skipping preference pane \(fileName): Info.plist is not a dictionary")
          return nil
        }
        plist = dictionary
      } catch {
        NSLog("Skipping preference pane \(fileName): \(error)")
        return nil
      }
      if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
        return displayName
      }
    }
    return nameMappings[fileName] ?? splitOnCapitals(fileName.replacingOccurrences(of: ".prefPane", with: ""))
  }

  nonisolated static func splitOnCapitals(_ text: String) -> String {
    var words: [String] = []
    for character in text {
      if character.isUppercase || words.isEmpty {
        words.append(String(character))
      } else {
        words[words.count - 1].append(character)
      }
    }
    return words.joined(separator: " ")
  }

  /// Panes open by path, which System Settings resolves to the right
  /// section. Pane bundles mostly lack their own icon, so the System
  /// Settings icon is used, as the previous build did.
  private static func scannedItem(_ pane: ScannedPane) -> Item {
    Item(
      id: pane.path, kind: .preferencePane, name: pane.name, icon: .file("/System/Applications/System Settings.app")
    ) { _ in
      try Workspace.open(path: pane.path)
    }
  }

  // MARK: Manual panes

  private static var manualItems: [Item] {
    [
      manual(
        id: "wallpaper_settings", name: "Wallpaper", symbol: "photo",
        url: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"),
      manual(
        id: "siri_settings", name: "Siri & Spotlight", symbol: "magnifyingglass",
        path: "/System/Library/PreferencePanes/Spotlight.prefPane"),
      manual(
        id: "wifi_settings", name: "Wi-Fi", alias: "wifi", symbol: "wifi",
        url: "x-apple.systempreferences:com.apple.wifi-settings-extension"),
      manual(
        id: "sound_settings", name: "Sound", symbol: "speaker.wave.2.fill",
        path: "/System/Library/PreferencePanes/Sound.prefPane"),
      manual(
        id: "accessibility_settings", name: "Accessibility", symbol: "accessibility",
        path: "/System/Library/PreferencePanes/UniversalAccessPref.prefPane"),
      manual(
        id: "password_settings", name: "Touch ID & Password", symbol: "touchid",
        path: "/System/Library/PreferencePanes/TouchID.prefPane"),
      manual(
        id: "display_settings", name: "Display", symbol: "display",
        path: "/System/Library/PreferencePanes/Displays.prefPane"),
      manual(
        id: "battery_settings", name: "Battery", symbol: "battery.100percent",
        url: "x-apple.systempreferences:com.apple.preference.battery"),
      manual(
        id: "network_settings", name: "Network", symbol: "network",
        path: "/System/Library/PreferencePanes/Network.prefPane"),
    ]
  }

  private static func manual(id: String, name: String, alias: String? = nil, symbol: String, path: String) -> Item {
    Item(id: id, kind: .preferencePane, name: name, alias: alias, icon: .symbol(symbol)) { _ in
      try Workspace.open(path: path)
    }
  }

  private static func manual(id: String, name: String, alias: String? = nil, symbol: String, url: String) -> Item {
    Item(id: id, kind: .preferencePane, name: name, alias: alias, icon: .symbol(symbol)) { _ in
      try Workspace.open(urlString: url)
    }
  }
}
