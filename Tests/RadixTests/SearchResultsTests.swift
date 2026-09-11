import RadixCore
import Testing

@testable import Radix

@MainActor
@Suite struct SearchResultsTests {
  let items = [item("sleep", name: "Sleep"), item("restart", name: "Restart"), item("lock", name: "Lock")]

  @Test func emptyQueryHasNoRows() {
    let rows = SearchResults.rows(
      query: "", items: items, temporaryResult: nil, config: Config(), state: AppState())
    #expect(rows.isEmpty)
  }

  @Test func matchingItemsAreRanked() {
    let rows = SearchResults.rows(
      query: "sle", items: items, temporaryResult: nil, config: Config(), state: AppState())
    #expect(rows.first?.id == "sleep")
    #expect(!rows.contains { $0.id == "lock" })
  }

  @Test func urlQueryPutsOpenURLFirst() {
    let rows = SearchResults.rows(
      query: "github.com", items: items, temporaryResult: nil, config: Config(), state: AppState())
    #expect(rows.first?.id == "open_url")
  }

  @Test func temporaryResultComesBeforeItems() {
    let result = SearchResults.temporaryResult(for: "2+2")
    #expect(result == .text(value: "4", secondary: "2+2"))
    let rows = SearchResults.rows(
      query: "2+2", items: items, temporaryResult: result, config: Config(), state: AppState())
    #expect(rows.first?.id == "temporary_result")
  }

  @Test func ipQueryShowsLocalAddressWhenConnected() {
    let result = SearchResults.temporaryResult(for: "ip")
    if let address = Network.localIPv4Address() {
      #expect(result == .text(value: address, secondary: "IP"))
    } else {
      #expect(result == nil)
    }
  }

  @Test func plainWordsHaveNoTemporaryResult() {
    #expect(SearchResults.temporaryResult(for: "safari") == nil)
  }

  @Test func disabledItemsAreHidden() {
    var config = Config()
    config.disabledItemIds = ["sleep"]
    let rows = SearchResults.rows(
      query: "sle", items: items, temporaryResult: nil, config: config, state: AppState())
    #expect(!rows.contains { $0.id == "sleep" })
  }

  @Test func frequentlySelectedItemsRankFirst() {
    var state = AppState()
    state.frequencies = ["restart": 3]
    // "re" matches both names; restart has usage, so it wins.
    let candidates = [item("reload", name: "Reload"), item("restart", name: "Restart")]
    let rows = SearchResults.rows(
      query: "re", items: candidates, temporaryResult: nil, config: Config(), state: state)
    #expect(rows.first?.id == "restart")
  }
}
