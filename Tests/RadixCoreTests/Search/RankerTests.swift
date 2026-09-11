import Testing
@testable import RadixCore

struct Item: Rankable, Equatable {
  var id: String
  var name: String
  var localizedName: String? = nil
  var alias: String? = nil
}

@Suite struct RankerTests {
  let items = [
    Item(id: "safari", name: "Safari"),
    Item(id: "slack", name: "Slack"),
    Item(id: "spotify", name: "Spotify"),
    Item(id: "vscode", name: "Visual Studio Code", alias: "VSC"),
    Item(id: "calc", name: "Calculator", localizedName: "Rekenmachine"),
  ]

  func rank(_ query: String, frequencies: [String: Int] = [:], timestamps: [String: Double] = [:]) -> [String] {
    Ranker.rank(items, query: query, frequencies: frequencies, selectionTimestamps: timestamps).map(\.id)
  }

  @Test func emptyQueryKeepsEverythingSortedByUsageThenName() {
    #expect(rank("") == ["calc", "safari", "slack", "spotify", "vscode"])
    #expect(rank("", frequencies: ["spotify": 1]) == ["spotify", "calc", "safari", "slack", "vscode"])
  }

  @Test func nonMatchingItemsAreDropped() {
    #expect(!rank("saf").contains("slack"))
    #expect(rank("zzz").isEmpty)
  }

  @Test func selectedBeforeUnselectedRegardlessOfScore() {
    // "s" matches every s-app; a previously used one goes first.
    #expect(rank("s", frequencies: ["spotify": 3]).first == "spotify")
  }

  @Test func scoreBreaksTiesAmongUnselected() {
    #expect(rank("safari").first == "safari")
    #expect(rank("slac").first == "slack")
  }

  @Test func timestampThenCountThenName() {
    let equalScore = [Item(id: "a", name: "Foo"), Item(id: "b", name: "Foo"), Item(id: "c", name: "Foo")]
    // All three selected with equal score: newest timestamp first.
    var order = Ranker.rank(
      equalScore, query: "foo", frequencies: ["a": 1, "b": 1, "c": 1],
      selectionTimestamps: ["a": 10, "b": 30, "c": 20]
    ).map(\.id)
    #expect(order == ["b", "c", "a"])
    // Equal timestamps: higher count first.
    order = Ranker.rank(
      equalScore, query: "foo", frequencies: ["a": 1, "b": 5, "c": 2],
      selectionTimestamps: [:]
    ).map(\.id)
    #expect(order == ["b", "c", "a"])
    // Everything equal: name, case-insensitive.
    let names = [Item(id: "1", name: "beta"), Item(id: "2", name: "Alpha"), Item(id: "3", name: "álpha2")]
    order = Ranker.rank(names, query: "", frequencies: [:], selectionTimestamps: [:]).map(\.id)
    #expect(order == ["2", "3", "1"])
  }

  @Test func legacyFrequenciesKeyedByNameStillCount() {
    #expect(rank("s", frequencies: ["Slack": 2]).first == "slack")
  }

  @Test func aliasAndLocalizedNameMatch() {
    #expect(rank("vsc").first == "vscode")
    #expect(rank("reken").first == "calc")
  }
}
