import Foundation
import Testing

@testable import RadixCore

@Suite struct FileSearchTests {
  @Test func plainQueryIsWrappedInWildcards() {
    #expect(FileSearch.likePattern(for: "report") == "*report*")
  }

  @Test func likeMetacharactersAreEscaped() {
    #expect(FileSearch.likePattern(for: "a*b") == #"*a\*b*"#)
    #expect(FileSearch.likePattern(for: "what?") == #"*what\?*"#)
    #expect(FileSearch.likePattern(for: #"c:\dir"#) == #"*c:\\dir*"#)
  }

  @Test func escapedPatternMatchesLiterallyInAPredicate() {
    let predicate = NSPredicate(format: "SELF LIKE[cd] %@", FileSearch.likePattern(for: "a*b"))
    #expect(predicate.evaluate(with: "xa*by"))
    #expect(!predicate.evaluate(with: "xaZZby"))
  }

  private func file(_ path: String) -> FileResult {
    FileResult(path: path, name: (path as NSString).lastPathComponent, isDirectory: false)
  }

  @Test func betterNameMatchesComeFirst() {
    let results = [file("/u/Documents/old-report-draft.txt"), file("/u/Documents/report.txt")]
    let ranked = FileSearch.rank(results, query: "report", limit: 10)
    #expect(ranked.map(\.name) == ["report.txt", "old-report-draft.txt"])
  }

  @Test func equalScoresPreferShorterPaths() {
    let results = [file("/u/Documents/a/b/c/notes.txt"), file("/u/Desktop/notes.txt")]
    let ranked = FileSearch.rank(results, query: "notes", limit: 10)
    #expect(ranked.map(\.path) == ["/u/Desktop/notes.txt", "/u/Documents/a/b/c/notes.txt"])
  }

  @Test func nonMatchingNamesAreDroppedAndLimitApplies() {
    let results = (0..<5).map { file("/u/Documents/invoice-\($0).pdf") } + [file("/u/Documents/zzz.png")]
    let ranked = FileSearch.rank(results, query: "invoice", limit: 3)
    #expect(ranked.count == 3)
    #expect(!ranked.contains { $0.name == "zzz.png" })
  }

  @Test func queriesWithoutLettersKeepLiteralMatches() {
    // Spotlight only returns names containing the query, as here.
    let years = [file("/u/Documents/invoice-2024.pdf"), file("/u/Documents/2024")]
    #expect(Set(FileSearch.rank(years, query: "2024", limit: 10).map(\.name)) == ["invoice-2024.pdf", "2024"])
    let versions = [file("/u/Documents/v1.2-notes.md"), file("/u/Downloads/app-v1.2.zip")]
    #expect(FileSearch.rank(versions, query: "v1.2", limit: 10).count == 2)
  }

  @Test func fuzzyMatchesOutrankLiteralOnlyMatches() {
    let results = [file("/u/a/2024.txt"), file("/u/report 2024.txt")]
    // "report" fuzzy-matches one name; "2024.txt" has no letters in common.
    let ranked = FileSearch.rank(results, query: "r 2024", limit: 10)
    #expect(ranked.first?.name == "report 2024.txt")
  }

  @Test func zeroLimitReturnsNothing() {
    #expect(FileSearch.rank([file("/u/a.txt")], query: "a", limit: 0).isEmpty)
  }
}
