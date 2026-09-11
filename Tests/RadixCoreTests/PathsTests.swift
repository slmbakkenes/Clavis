import Testing
@testable import RadixCore

@Test func configLivesUnderDotConfigRadix() {
  #expect(Paths.configDirectory.path.hasSuffix("/.config/radix"))
  #expect(Paths.configFile.lastPathComponent == "config.json")
  #expect(Paths.stateFile.lastPathComponent == "state.json")
}
