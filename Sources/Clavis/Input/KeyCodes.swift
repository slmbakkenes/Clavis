import Carbon
import ClavisCore

/// Maps a `Shortcut` key token ("return", "space", "a", "1", ...) to the
/// virtual keycode Carbon wants. Letters outside the ANSI layout are not
/// supported; the old HotKey pod had the same limitation.
enum KeyCodes {
  static func keyCode(forShortcutToken token: String) -> UInt32? {
    let name = token == "return" ? "enter" : token
    guard let key = Key(rawValue: name) else { return nil }
    return UInt32(key.keyCode)
  }
}
