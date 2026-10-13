import Testing

@testable import ClavisCore

@Suite struct InitialsTests {
  @Test func takesFirstLetterOfEachWordLowercased() {
    #expect(Initials.of("Visual Studio Code") == "vsc")
    #expect(Initials.of("Safari") == "s")
  }

  @Test func repeatedSpacesAddNothing() {
    #expect(Initials.of("Google  Chrome") == "gc")
    #expect(Initials.of(" Leading") == "l")
  }

  @Test func emptyNameGivesEmptyInitials() {
    #expect(Initials.of("") == "")
  }

  @Test func onlySpacesSplitWords() {
    #expect(Initials.of("Audio-MIDI Setup") == "as")
  }
}
