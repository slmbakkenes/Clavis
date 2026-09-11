import Foundation

/// Portable settings, persisted as `~/.config/radix/config.json`.
///
/// JSON keys, raw enum values and defaults match the React Native version's
/// store exactly, so existing config files load unchanged. Unknown keys are
/// ignored on decode; `ConfigStore` preserves them on disk when saving.
public struct Config: Codable, Equatable, Sendable {
  public enum GlobalShortcut: String, Codable, Sendable {
    case command, option, control
  }

  public enum ShowWindowOn: String, Codable, Sendable {
    case screenWithFrontmost, screenWithCursor
  }

  public enum ScratchPadColor: String, Codable, Sendable {
    case system = "SYSTEM"
    case blue = "BLUE"
    case orange = "ORANGE"
  }

  public var firstTranslationLanguage: String
  public var secondTranslationLanguage: String
  public var thirdTranslationLanguage: String?
  public var globalShortcut: GlobalShortcut
  public var showWindowOn: ShowWindowOn
  public var launchAtLogin: Bool
  public var mediaKeyForwardingEnabled: Bool
  public var scratchPadColor: ScratchPadColor
  public var searchFolders: [String]
  public var searchEngine: SearchEngine
  public var customSearchUrl: String
  /// Item id → shortcut string such as `control+option+return`.
  public var shortcuts: [String: String]
  public var showInAppBrowserBookMarks: Bool
  public var hyperKeyEnabled: Bool
  public var customItems: [CustomItem]
  public var disabledItemIds: [String]
  /// Hand-edited panel keymap overrides (chord → action name, `nil` unbinds).
  /// Not part of the RN build's persisted whitelist, but it reads the key
  /// raw, so it is carried through here. Feed it to `Keymap.resolve`.
  public var keymap: [String: String?]?

  public static let defaultShortcuts: [String: String] = Shortcut.defaults

  /// The JSON keys this model writes to `config.json`, matching PORTABLE_KEYS
  /// in `persisted-config.ts`. `keymap` is deliberately not listed: it is
  /// only written when present so a hand-edited value is never deleted.
  static let ownedKeys: [String] = [
    "firstTranslationLanguage", "secondTranslationLanguage", "thirdTranslationLanguage",
    "globalShortcut", "showWindowOn", "launchAtLogin", "mediaKeyForwardingEnabled",
    "scratchPadColor", "searchFolders", "searchEngine", "customSearchUrl", "shortcuts",
    "showInAppBrowserBookMarks", "hyperKeyEnabled", "customItems", "disabledItemIds",
  ]

  /// The panel keymap with this config's overrides applied.
  public func resolvedKeymap(onInvalid: (_ chord: String, _ action: String) -> Void = { _, _ in }) -> Keymap {
    Keymap.resolve(overrides: keymap, onInvalid: onInvalid)
  }

  public static func defaultSearchFolders(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String] {
    ["Downloads", "Documents", "Desktop", "Pictures", "Movies", "Music"].map {
      home.appendingPathComponent($0).path
    }
  }

  public init(
    firstTranslationLanguage: String = "en",
    secondTranslationLanguage: String = "de",
    thirdTranslationLanguage: String? = nil,
    globalShortcut: GlobalShortcut = .option,
    showWindowOn: ShowWindowOn = .screenWithCursor,
    launchAtLogin: Bool = true,
    mediaKeyForwardingEnabled: Bool = true,
    scratchPadColor: ScratchPadColor = .system,
    searchFolders: [String] = Config.defaultSearchFolders(),
    searchEngine: SearchEngine = .google,
    customSearchUrl: String = "https://google.com/search?q=%s",
    shortcuts: [String: String] = Config.defaultShortcuts,
    showInAppBrowserBookMarks: Bool = true,
    hyperKeyEnabled: Bool = false,
    customItems: [CustomItem] = [],
    disabledItemIds: [String] = [],
    keymap: [String: String?]? = nil
  ) {
    self.firstTranslationLanguage = firstTranslationLanguage
    self.secondTranslationLanguage = secondTranslationLanguage
    self.thirdTranslationLanguage = thirdTranslationLanguage
    self.globalShortcut = globalShortcut
    self.showWindowOn = showWindowOn
    self.launchAtLogin = launchAtLogin
    self.mediaKeyForwardingEnabled = mediaKeyForwardingEnabled
    self.scratchPadColor = scratchPadColor
    self.searchFolders = searchFolders
    self.searchEngine = searchEngine
    self.customSearchUrl = customSearchUrl
    self.shortcuts = shortcuts
    self.showInAppBrowserBookMarks = showInAppBrowserBookMarks
    self.hyperKeyEnabled = hyperKeyEnabled
    self.customItems = customItems
    self.disabledItemIds = disabledItemIds
    self.keymap = keymap
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Config()
    firstTranslationLanguage =
      try c.decodeIfPresent(String.self, forKey: .firstTranslationLanguage) ?? d.firstTranslationLanguage
    secondTranslationLanguage =
      try c.decodeIfPresent(String.self, forKey: .secondTranslationLanguage) ?? d.secondTranslationLanguage
    thirdTranslationLanguage = try c.decodeIfPresent(String.self, forKey: .thirdTranslationLanguage)
    globalShortcut = try c.decodeIfPresent(GlobalShortcut.self, forKey: .globalShortcut) ?? d.globalShortcut
    showWindowOn = try c.decodeIfPresent(ShowWindowOn.self, forKey: .showWindowOn) ?? d.showWindowOn
    launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
    mediaKeyForwardingEnabled =
      try c.decodeIfPresent(Bool.self, forKey: .mediaKeyForwardingEnabled) ?? d.mediaKeyForwardingEnabled
    scratchPadColor = try c.decodeIfPresent(ScratchPadColor.self, forKey: .scratchPadColor) ?? d.scratchPadColor
    searchFolders = try c.decodeIfPresent([String].self, forKey: .searchFolders) ?? d.searchFolders
    searchEngine = try c.decodeIfPresent(SearchEngine.self, forKey: .searchEngine) ?? d.searchEngine
    customSearchUrl = try c.decodeIfPresent(String.self, forKey: .customSearchUrl) ?? d.customSearchUrl
    // Same as the TS hydrate: symbols such as ⌘ become canonical tokens.
    shortcuts = ShortcutFormat.normalize(
      try c.decodeIfPresent([String: String].self, forKey: .shortcuts) ?? d.shortcuts)
    showInAppBrowserBookMarks =
      try c.decodeIfPresent(Bool.self, forKey: .showInAppBrowserBookMarks) ?? d.showInAppBrowserBookMarks
    hyperKeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .hyperKeyEnabled) ?? d.hyperKeyEnabled
    customItems = try c.decodeIfPresent([CustomItem].self, forKey: .customItems) ?? d.customItems
    disabledItemIds = try c.decodeIfPresent([String].self, forKey: .disabledItemIds) ?? d.disabledItemIds
    keymap = try c.decodeIfPresent([String: String?].self, forKey: .keymap)
  }
}

/// A user-created item from the "create item" widget. `type` is always
/// `CUSTOM` on disk; it is kept so the JSON stays byte-compatible.
public struct CustomItem: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var icon: String
  public var color: String?
  public var text: String
  public var type: String

  public init(
    id: String = UUID().uuidString.lowercased(), name: String, icon: String = "Apple",
    color: String? = nil, text: String, type: String = "CUSTOM"
  ) {
    self.id = id
    self.name = name
    self.icon = icon
    self.color = color
    self.text = text
    self.type = type
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "Apple"
    color = try c.decodeIfPresent(String.self, forKey: .color)
    text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    type = try c.decodeIfPresent(String.self, forKey: .type) ?? "CUSTOM"
  }
}
