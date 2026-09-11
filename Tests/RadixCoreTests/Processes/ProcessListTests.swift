import Testing

@testable import RadixCore

@Suite struct ProcessListTests {
  static let sample = """
      PID  PPID  %CPU    RSS COMM
        1     0   0,2  12345 /sbin/launchd
      512     1  12.5 204800 /Applications/Safari.app/Contents/MacOS/Safari
      733     1   1,5   8200 /System/Library/PreferencePanes/Displays.prefPane/Contents/MacOS/Displays
      901   512   3.0  40960 /Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer)
      950     1   0.0   1024 mdworker_shared
      999     1   0.0      0 /usr/libexec/
    """

  @Test func parsesColumnsAndSortsByCpu() {
    let entries = ProcessList.parse(Self.sample)
    #expect(entries.map(\.pid) == [512, 901, 733, 1, 950])

    let safari = entries[0]
    #expect(safari.parentPid == 1)
    #expect(safari.cpu == 12.5)
    #expect(safari.memoryKilobytes == 204800)
    #expect(safari.name == "Safari")
    #expect(safari.kind == .application)
  }

  @Test func headerAndNamelessLinesAreDropped() {
    let entries = ProcessList.parse(Self.sample)
    #expect(!entries.contains { $0.pid == 999 })
    #expect(entries.count == 5)
  }

  @Test func commaDecimalsParseFully() {
    let entries = ProcessList.parse(Self.sample)
    #expect(entries.first { $0.pid == 733 }?.cpu == 1.5)
    #expect(entries.first { $0.pid == 1 }?.cpu == 0.2)
  }

  @Test func kindsFollowPathMarkers() {
    let entries = Dictionary(uniqueKeysWithValues: ProcessList.parse(Self.sample).map { ($0.pid, $0) })
    #expect(entries[733]?.kind == .preferencePane)
    #expect(entries[512]?.kind == .application)
    #expect(entries[1]?.kind == .binary)
    #expect(entries[950]?.kind == .binary)
  }

  @Test func pathsWithSpacesAreKeptWhole() {
    let helper = ProcessList.parse(Self.sample).first { $0.pid == 901 }
    #expect(helper?.path.hasSuffix("MacOS/Code Helper (Renderer)") == true)
    #expect(helper?.name == "Code Helper (Renderer)")
  }

  @Test func emptyQueryKeepsOrder() {
    let entries = ProcessList.parse(Self.sample)
    #expect(ProcessList.filter(entries, query: "") == entries)
  }

  @Test func filterMatchesPathAndDropsNonMatches() {
    let entries = ProcessList.parse(Self.sample)
    let results = ProcessList.filter(entries, query: "safari")
    #expect(results.first?.pid == 512)
    #expect(!results.contains { $0.pid == 950 })
    #expect(ProcessList.filter(entries, query: "zzzzqqq").isEmpty)
  }
}
