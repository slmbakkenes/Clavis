import Foundation
import ClavisCore
import Testing

@testable import Clavis

@MainActor
@Suite struct AppModelTests {
  @Test func typingBuildsRowsAndResetsSelection() throws {
    let (model, _) = try makeModel()
    model.builtInItems = [item("sleep", name: "Sleep"), item("settings", name: "Settings")]
    model.query = "s"
    #expect(model.searchRows.count == 2)
    model.selectNext()
    #expect(model.selectedIndex == 1)
    model.query = "sl"
    #expect(model.selectedIndex == 0)
  }

  @Test func selectionStaysInBounds() throws {
    let (model, _) = try makeModel()
    model.builtInItems = [item("sleep", name: "Sleep")]
    model.query = "sleep"
    model.selectNext()
    model.selectNext()
    #expect(model.selectedIndex == 0)
    model.selectPrevious()
    #expect(model.selectedIndex == 0)
  }

  @Test func newlinesInQueryBecomeSpaces() throws {
    let (model, _) = try makeModel()
    model.query = "a\nb"
    #expect(model.query == "a b")
  }

  @Test func panelIsCompactOnlyForAnEmptySearch() throws {
    let (model, _) = try makeModel()
    let compact = model.preferredPanelHeight
    #expect(compact < PanelManager.baseSize.height)
    model.query = "x"
    #expect(model.preferredPanelHeight == PanelManager.baseSize.height)
    model.query = ""
    model.focusWidget(.settings)
    #expect(model.preferredPanelHeight == PanelManager.baseSize.height)
  }

  @Test func confirmingRunsItemAndRecordsUsage() async throws {
    let (model, directory) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("sleep", name: "Sleep", log: log)]
    model.query = "sleep"
    await model.confirmSearch(modifiers: [])

    #expect(log.ran == ["sleep"])
    #expect(model.state.frequencies["sleep"] == 1)
    #expect((model.state.selectionTimestamps["sleep"] ?? 0) > 0)
    #expect(model.state.history == ["sleep"])

    let saved =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: directory.appendingPathComponent("state.json"))) as? [String: Any]
    #expect((saved?["frequencies"] as? [String: Any])?["sleep"] as? Int == 1)
  }

  @Test func confirmingWithEmptyQueryDoesNothing() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("sleep", name: "Sleep", log: log)]
    await model.confirmSearch(modifiers: [])
    #expect(log.ran.isEmpty)
    #expect(model.state.history.isEmpty)
  }

  @Test func destructiveItemsWaitForConfirmation() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("restart", name: "Restart", confirmationTitle: "Restart Computer", log: log)]
    model.query = "restart"
    await model.confirmSearch(modifiers: [])
    #expect(log.ran.isEmpty)
    #expect(model.confirmation?.title == "Restart Computer")

    await model.acceptConfirmation()
    #expect(log.ran == ["restart"])
    #expect(model.confirmation == nil)
  }

  @Test func cancelledConfirmationNeverRuns() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("restart", name: "Restart", confirmationTitle: "Restart Computer", log: log)]
    model.query = "restart"
    await model.confirmSearch(modifiers: [])
    model.cancelConfirmation()
    await model.acceptConfirmation()
    #expect(log.ran.isEmpty)
  }

  @Test func upOnFirstRowWalksHistoryNewestFirst() throws {
    let (model, _) = try makeModel()
    model.addToHistory("first")
    model.addToHistory("second")
    model.selectPreviousOrHistory()
    #expect(model.query == "second")
    model.selectPreviousOrHistory()
    #expect(model.query == "first")
    // Past the oldest entry it stays on the oldest.
    model.selectPreviousOrHistory()
    #expect(model.query == "first")
  }

  @Test func historyIsBounded() throws {
    let (model, _) = try makeModel()
    for index in 0..<(AppModel.historyLimit + 5) {
      model.addToHistory("q\(index)")
    }
    #expect(model.state.history.count == AppModel.historyLimit)
    #expect(model.state.history.last == "q\(AppModel.historyLimit + 4)")
  }

  @Test func hideKeepsAnswerButClearsPlainQuery() throws {
    let (model, _) = try makeModel()
    model.query = "safari"
    model.onHide()
    #expect(model.query == "")

    model.query = "2*3"
    model.onHide()
    #expect(model.query == "2*3")
  }

  @Test func deletingSelectedCustomItemUpdatesConfig() throws {
    var config = Config()
    config.customItems = [CustomItem(id: "c1", name: "Docs", text: "https://example.com")]
    let (model, _) = try makeModel(config: config)
    model.query = "docs"
    model.deleteSelectedCustomItem()
    #expect(model.config.customItems.isEmpty)
  }
}

@MainActor
@Suite struct ShortcutRunTests {
  @Test func shortcutRunsItemWithoutRecordingUsage() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("lock", name: "Lock", log: log)]
    await model.runFromShortcut(itemID: "lock")
    #expect(log.ran == ["lock"])
    #expect(model.state.frequencies.isEmpty)
  }

  @Test func shortcutToDestructiveItemAsksFirst() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("restart", name: "Restart", confirmationTitle: "Restart Computer", log: log)]
    await model.runFromShortcut(itemID: "restart")
    #expect(log.ran.isEmpty)
    #expect(model.confirmation?.title == "Restart Computer")
    PanelManager.shared.hideWindow()
  }

  @Test func unknownShortcutIsIgnored() async throws {
    let (model, _) = try makeModel()
    await model.runFromShortcut(itemID: "missing")
    #expect(model.confirmation == nil)
  }
}
