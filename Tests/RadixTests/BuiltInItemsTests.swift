import Testing

@testable import Radix

@MainActor
@Suite struct BuiltInItemsTests {
  @Test func destructiveItemsRequireConfirmation() {
    let items = Dictionary(uniqueKeysWithValues: BuiltInItems.make().map { ($0.id, $0) })
    for id in ["restart", "shut_down", "empty_trash", "kill_all_apps"] {
      #expect(items[id] != nil, "missing \(id)")
      #expect(items[id]?.confirmationTitle != nil, "\(id) runs without confirmation")
    }
  }

  @Test func idsAreUnique() {
    let ids = BuiltInItems.make().map(\.id)
    #expect(Set(ids).count == ids.count)
  }
}
