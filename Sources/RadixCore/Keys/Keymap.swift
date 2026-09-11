import Foundation

/// Semantic in-panel actions. Widgets implement the subset they care about.
public enum PanelAction: String, CaseIterable, Sendable {
  case confirm
  case dismiss
  case selectNext
  case selectPrevious
  case selectLeft
  case selectRight
  case deleteSelected
  case editSelected
  case cycleScratchpadColor
}

/// Chord -> action. Lookup is two-level: the full chord is tried first, then
/// the bare key. So "shift+enter" falls back to "enter" (the handler still
/// sees shift set), while an explicit "shift+enter" entry can override it.
///
/// Prefer chords with modifiers: a bare letter binding still lets that letter
/// reach the search input, since only navigation keys are swallowed natively.
public struct Keymap: Sendable, Equatable {
  public private(set) var bindings: [String: PanelAction]

  public init(bindings: [String: PanelAction]) {
    self.bindings = bindings
  }

  public static let `default` = Keymap(bindings: [
    "enter": .confirm,
    "escape": .dismiss,
    "down": .selectNext,
    "up": .selectPrevious,
    "left": .selectLeft,
    "right": .selectRight,
    "control+j": .selectNext,
    "control+k": .selectPrevious,
    "shift+delete": .deleteSelected,
    "command+e": .editSelected,
    "tab": .cycleScratchpadColor,
  ])

  /// Merges user overrides over the defaults. An explicit nil or "" unbinds a
  /// default; an unknown action is dropped (and reported via `onInvalid`) so a
  /// typo in config.json can't silently swallow a key.
  public static func resolve(
    overrides: [String: String?]?,
    onInvalid: (_ chord: String, _ action: String) -> Void = { _, _ in }
  ) -> Keymap {
    guard let overrides else { return .default }
    var merged = Keymap.default.bindings

    for (chord, action) in overrides {
      let normalizedChord = chord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      if normalizedChord.isEmpty { continue }

      guard let action, !action.isEmpty else {
        merged[normalizedChord] = nil
        continue
      }
      guard let panelAction = PanelAction(rawValue: action) else {
        onInvalid(chord, action)
        continue
      }
      merged[normalizedChord] = panelAction
    }
    return Keymap(bindings: merged)
  }

  public func action(for chord: Chord) -> PanelAction? {
    bindings[chord.string] ?? bindings[chord.key.name]
  }

  public func action(for key: Key, modifiers: Modifiers) -> PanelAction? {
    action(for: Chord(key, modifiers: modifiers))
  }
}
