import Testing
@testable import RadixCore

@Suite struct KeyTests {
  @Test func keyCodesRoundTrip() {
    for key in Key.allCases {
      #expect(Key(keyCode: key.keyCode) == key)
    }
    #expect(Key(keyCode: 36) == .enter)
    #expect(Key(keyCode: 999) == nil)
    #expect(Key.digit0.name == "0")
    #expect(Key.command.isModifier)
    #expect(!Key.a.isModifier)
  }
}

@Suite struct ChordTests {
  @Test func modifiersSerialiseInFixedOrder() {
    #expect(Chord(.enter).string == "enter")
    #expect(Chord(.enter, modifiers: [.shift]).string == "shift+enter")
    #expect(Chord(.j, modifiers: [.control]).string == "control+j")
    #expect(Chord(.digit1, modifiers: [.shift, .command, .control]).string == "control+command+shift+1")
  }

  @Test func optionIsDropped() {
    let chord = Chord(.enter, modifiers: [.option, .shift])
    #expect(chord.modifiers == [.shift])
    #expect(chord.string == "shift+enter")
    #expect(Chord(.j, modifiers: [.option]) == Chord(.j))
  }
}

@Suite struct KeymapTests {
  @Test func defaultsResolve() {
    let map = Keymap.default
    #expect(map.action(for: .enter, modifiers: []) == .confirm)
    #expect(map.action(for: .down, modifiers: []) == .selectNext)
    #expect(map.action(for: .j, modifiers: [.control]) == .selectNext)
    #expect(map.action(for: .delete, modifiers: [.shift]) == .deleteSelected)
    #expect(map.action(for: .delete, modifiers: []) == nil)
    #expect(map.action(for: .n, modifiers: []) == nil)
  }

  @Test func fullChordFallsBackToBareKey() {
    let map = Keymap.default
    // "shift+enter" is unbound, so it falls back to "enter".
    #expect(map.action(for: .enter, modifiers: [.shift]) == .confirm)
    // An explicit full-chord entry wins over the bare key.
    let overridden = Keymap.resolve(overrides: ["shift+enter": "selectPrevious"])
    #expect(overridden.action(for: .enter, modifiers: [.shift]) == .selectPrevious)
    #expect(overridden.action(for: .enter, modifiers: []) == .confirm)
  }

  @Test func overridesMergeUnbindAndRejectUnknown() {
    var invalid: [(String, String)] = []
    let map = Keymap.resolve(
      overrides: [" Control+N ": "selectNext", "tab": nil, "up": "", "down": "bogus", "  ": "confirm"],
      onInvalid: { invalid.append(($0, $1)) })
    #expect(map.action(for: .n, modifiers: [.control]) == .selectNext)
    #expect(map.action(for: .tab, modifiers: []) == nil)
    #expect(map.action(for: .up, modifiers: []) == nil)
    // Unknown action leaves the default in place.
    #expect(map.action(for: .down, modifiers: []) == .selectNext)
    #expect(invalid.count == 1)
    #expect(invalid.first?.0 == "down")
    #expect(Keymap.resolve(overrides: nil) == .default)
  }
}
