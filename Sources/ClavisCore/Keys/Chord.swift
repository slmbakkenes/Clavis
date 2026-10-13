/// An in-panel key press: a key plus modifiers, serialised as
/// "control+command+shift+<key>" with the modifiers in that fixed order so
/// keymap lookups are stable.
public struct Chord: Sendable, Hashable {
  public var key: Key
  public var modifiers: Modifiers

  /// `.option` is dropped: the keymap string format never had an option
  /// token (chordFromKey in the old build never emitted one), so an
  /// option-chord resolves to the bare-key binding rather than to a string
  /// that silently loses a modifier.
  public init(_ key: Key, modifiers: Modifiers = []) {
    self.key = key
    self.modifiers = modifiers.subtracting(.option)
  }

  /// "shift+enter", "control+j", "enter".
  public var string: String {
    var parts: [String] = []
    if modifiers.contains(.control) { parts.append("control") }
    if modifiers.contains(.command) { parts.append("command") }
    if modifiers.contains(.shift) { parts.append("shift") }
    parts.append(key.name)
    return parts.joined(separator: "+")
  }
}
