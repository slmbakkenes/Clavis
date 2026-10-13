import Testing
@testable import ClavisCore

@Test func configLivesUnderDotConfigClavis() {
  #expect(Paths.configDirectory.path.hasSuffix("/.config/clavis"))
  #expect(Paths.configFile.lastPathComponent == "config.json")
  #expect(Paths.stateFile.lastPathComponent == "state.json")
}
