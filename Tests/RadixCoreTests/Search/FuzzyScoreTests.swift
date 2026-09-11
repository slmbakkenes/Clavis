import Testing
@testable import RadixCore

@Suite struct FuzzyScoreTests {
  @Test func emptyCandidateScoresZeroEvenWithFuzziness() {
    #expect(FuzzyScore.score("123", query: "a") == 0)
    #expect(FuzzyScore.score("123", query: "a", fuzziness: 0.5) == 0)
    #expect(FuzzyScore.score("", query: "") == 1)
  }

  @Test func exactMatchIsOne() {
    #expect(FuzzyScore.score("Safari", query: "Safari") == 1)
    // Equality is case-sensitive; a case-mismatched full match still scores high.
    let mismatched = FuzzyScore.score("Safari", query: "safari")
    #expect(mismatched > 0.5 && mismatched < 1)
  }

  @Test func caseAndDiacriticsAreIgnoredForMatching() {
    #expect(FuzzyScore.score("Safari", query: "saf") > 0)
    #expect(FuzzyScore.score("Safari", query: "SAF") > 0)
    #expect(FuzzyScore.score("Café Noir", query: "cafe") > 0)
    #expect(FuzzyScore.score("Café", query: "Cafe") == 1, "decomposition strips the accent")
    #expect(FuzzyScore.score("Café", query: "Café") == 1)
  }

  @Test func emptyAndGarbage() {
    #expect(FuzzyScore.score("Safari", query: "") == 0)
    #expect(FuzzyScore.score("Safari", query: "xyz") == 0)
    #expect(FuzzyScore.score("Safari", query: "sfx") == 0, "one unmatched char kills the score without fuzziness")
    #expect(FuzzyScore.score("Safari", query: "sfx", fuzziness: 0.5) > 0)
    #expect(FuzzyScore.score("Safari", query: "sfx", fuzziness: 0.5) < FuzzyScore.score("Safari", query: "sf"))
  }

  @Test func prefixBeatsSubstring() {
    let prefix = FuzzyScore.score("Terminal", query: "term")
    let middle = FuzzyScore.score("Determinant", query: "term")
    #expect(prefix > middle)
    #expect(prefix > 0.5, "file search threshold in FileSearchIndex is 0.5")
  }

  @Test func sequentialMatchingOnly() {
    // "ri" appears in order in Safari; "ir" does not.
    #expect(FuzzyScore.score("Safari", query: "ri") > 0)
    #expect(FuzzyScore.score("Safari", query: "ir") == 0)
  }

  @Test func acronymBonus() {
    let initials = FuzzyScore.score("Visual Studio Code", query: "vsc")
    let scattered = FuzzyScore.score("Visualstudiocode", query: "vsc")
    #expect(initials > scattered)
  }

  @Test func sameCaseBonus() {
    #expect(FuzzyScore.score("Safari", query: "Saf") > FuzzyScore.score("Safari", query: "saf"))
  }

  @Test func scoresStayInRange() {
    for (c, q) in [
      ("Terminal", "t"), ("a", "a"), ("Long Application Name Here", "lanh"), ("ßeta", "SS"), ("ßeta", "ß"),
      ("Straße", "straße"),
    ] {
      let s = FuzzyScore.score(c, query: q)
      #expect(s >= 0 && s <= 1, "\(c) / \(q) -> \(s)")
    }
  }

  @Test func favorSmallerWordsOption() {
    let short = FuzzyScore.score("Term", query: "te", options: .favorSmallerWords)
    let long = FuzzyScore.score("Terminal", query: "te", options: .favorSmallerWords)
    #expect(short > long)
  }
}
