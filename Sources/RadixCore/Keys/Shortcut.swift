import Foundation

/// Global hotkey strings as stored under `shortcuts` in config.json, e.g.
/// "control+option+return". Token order is user-defined and preserved; only
/// the tokens themselves are normalised (symbols and aliases to words,
/// lowercase).
public enum ShortcutFormat {
  static let aliases: [String: String] = [
    "cmd": "command",
    "⌘": "command",
    "⌥": "option",
    "⌃": "control",
    "⇧": "shift",
    "↩": "return",
    "␣": "space",
    "→": "right",
    "←": "left",
    "↑": "up",
    "↓": "down",
    "\u{f703}": "right",
    "\u{f702}": "left",
    "\u{f700}": "up",
    "\u{f701}": "down",
    "\r": "return",
  ]

  static let modifierWords: [String: Modifiers] = [
    "command": .command, "option": .option, "control": .control, "shift": .shift,
  ]

  static let namedKeys: Set<String> = ["return", "space", "right", "left", "up", "down"]

  public static func normalizeToken(_ token: String) -> String {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    let lowercased = trimmed.lowercased()
    return aliases[trimmed] ?? aliases[lowercased] ?? lowercased
  }

  public static func normalize(_ shortcut: String) -> String {
    shortcut.split(separator: "+", omittingEmptySubsequences: false)
      .map { normalizeToken(String($0)) }
      .filter { !$0.isEmpty }
      .joined(separator: "+")
  }

  public static func normalize(_ shortcuts: [String: String]) -> [String: String] {
    shortcuts.mapValues(normalize)
  }

  /// Mirrors `validShortcutTokensRegex`:
  /// `^(cmd|control|option|command|shift|return|space|right|left|up|down|[a-ú]|[0-9])$`.
  public static func isValidToken(_ token: String) -> Bool {
    if token == "cmd" || modifierWords[token] != nil || namedKeys.contains(token) { return true }
    guard token.unicodeScalars.count == 1, let scalar = token.unicodeScalars.first else { return false }
    return ("a"..."ú").contains(scalar) || ("0"..."9").contains(scalar)
  }

  /// Display symbols for a shortcut, one per token ("⌃", "⌥", "↩", "q", ...).
  public static func symbols(_ shortcut: String) -> [String] {
    shortcut.split(separator: "+").map { token in
      switch token {
      case "control": "⌃"
      case "option": "⌥"
      case "cmd", "command": "⌘"
      case "shift": "⇧"
      case "return": "↩"
      case "space": "␣"
      case "right": "→"
      case "left": "←"
      case "up": "↑"
      case "down": "↓"
      default: String(token)
      }
    }
  }
}

/// A parsed global shortcut. `string` reproduces the normalised input exactly,
/// including the user's modifier order.
public struct Shortcut: Sendable, Hashable, CustomStringConvertible {
  public let modifiers: Modifiers
  /// The non-modifier token: "return", "space", "right", ..., or a single
  /// character such as "q" or "1".
  public let key: String
  public let string: String

  public var description: String { string }

  /// Fails on an unknown token, a missing key, or more than one key.
  public init?(parsing raw: String) {
    let normalized = ShortcutFormat.normalize(raw)
    var modifiers: Modifiers = []
    var key: String?
    for token in normalized.split(separator: "+").map(String.init) {
      guard ShortcutFormat.isValidToken(token) else { return nil }
      if let modifier = ShortcutFormat.modifierWords[token == "cmd" ? "command" : token] {
        modifiers.insert(modifier)
      } else {
        if key != nil { return nil }
        key = token
      }
    }
    guard let key else { return nil }
    self.modifiers = modifiers
    self.key = key
    self.string = normalized
  }

  public static let defaults: [String: String] = [
    "resize_fullscreen": "control+option+return",
    "lock": "command+option+q",
    "resize_right_half": "control+option+right",
    "resize_left_half": "control+option+left",
    "resize_top_half": "control+option+up",
    "resize_bottom_half": "control+option+down",
    "resize_top_left": "control+option+u",
    "resize_top_right": "control+option+i",
    "resize_bottom_left": "control+option+j",
    "resize_bottom_right": "control+option+k",
    "move_next_screen": "control+option+command+right",
    "move_previous_screen": "control+option+command+left",
    "scratchpad": "command+shift+space",
    "clipboard_manager": "command+option+v",
  ]
}
