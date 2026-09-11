/// macOS virtual key codes for the keys the panel reacts to while it is open.
/// These are not the global hotkeys (see `Shortcut`).
public enum Key: String, CaseIterable, Sendable, Hashable {
  // Navigation / editing
  case enter, escape, tab, delete, forwarddelete, space, left, right, up, down
  case home, end, pageup, pagedown
  // Letters
  case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
  // Digits
  case digit0 = "0", digit1 = "1", digit2 = "2", digit3 = "3", digit4 = "4"
  case digit5 = "5", digit6 = "6", digit7 = "7", digit8 = "8", digit9 = "9"
  // Modifiers
  case command, shift, control

  /// The chord token, e.g. "enter", "a", "0".
  public var name: String { rawValue }

  public var keyCode: UInt16 {
    switch self {
    case .enter: 36
    case .escape: 53
    case .tab: 48
    case .delete: 51
    case .forwarddelete: 117
    case .space: 49
    case .left: 123
    case .right: 124
    case .up: 126
    case .down: 125
    case .home: 115
    case .end: 119
    case .pageup: 116
    case .pagedown: 121
    case .a: 0
    case .b: 11
    case .c: 8
    case .d: 2
    case .e: 14
    case .f: 3
    case .g: 5
    case .h: 4
    case .i: 34
    case .j: 38
    case .k: 40
    case .l: 37
    case .m: 46
    case .n: 45
    case .o: 31
    case .p: 35
    case .q: 12
    case .r: 15
    case .s: 1
    case .t: 17
    case .u: 32
    case .v: 9
    case .w: 13
    case .x: 7
    case .y: 16
    case .z: 6
    case .digit0: 29
    case .digit1: 18
    case .digit2: 19
    case .digit3: 20
    case .digit4: 21
    case .digit5: 23
    case .digit6: 22
    case .digit7: 26
    case .digit8: 28
    case .digit9: 25
    case .command: 55
    case .shift: 60
    case .control: 59
    }
  }

  /// Keys that only set modifier state and never resolve to an action.
  public var isModifier: Bool {
    switch self {
    case .command, .shift, .control: true
    default: false
    }
  }

  private static let byCode: [UInt16: Key] = Dictionary(
    uniqueKeysWithValues: allCases.map { ($0.keyCode, $0) })

  public init?(keyCode: UInt16) {
    guard let key = Self.byCode[keyCode] else { return nil }
    self = key
  }
}
