import Carbon
import Foundation
import RadixCore
import Testing

@testable import Radix

@MainActor
@Suite struct NoteSavingTests {
  private func savedNote(in directory: URL) throws -> String? {
    let object =
      try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("state.json")))
      as? [String: Any]
    return object?["note"] as? String
  }

  @Test func typingDoesNotWriteUntilFlushed() throws {
    let (model, directory) = try makeModel()
    model.setNote("draft")
    #expect(model.state.note == "draft")
    #expect(try savedNote(in: directory) == "")
    model.flushPendingSaves()
    #expect(try savedNote(in: directory) == "draft")
  }

  @Test func noteIsSavedAfterTypingPauses() async throws {
    let (model, directory) = try makeModel()
    model.setNote("a")
    model.setNote("ab")
    try await Task.sleep(for: AppModel.noteSaveDelay + .milliseconds(300))
    #expect(try savedNote(in: directory) == "ab")
  }

  @Test func hidingThePanelFlushesTheNote() throws {
    let (model, directory) = try makeModel()
    model.setNote("before hide")
    model.onHide()
    #expect(try savedNote(in: directory) == "before hide")
  }
}

@MainActor
@Suite struct TextEntryRoutingTests {
  @Test func scratchpadAndCreateItemOwnEnterArrowsAndTab() throws {
    let (model, _) = try makeModel()
    let router = InputRouter(model: model)
    for widget in [Widget.scratchpad, .createItem] {
      model.focusWidget(widget)
      #expect(!router.keyDown(keyCode: UInt16(kVK_Return), flags: [], characters: "\r"), "\(widget) enter")
      #expect(!router.keyDown(keyCode: UInt16(kVK_DownArrow), flags: [], characters: nil), "\(widget) down")
      #expect(!router.keyDown(keyCode: UInt16(kVK_UpArrow), flags: [], characters: nil), "\(widget) up")
      #expect(!router.keyDown(keyCode: UInt16(kVK_Tab), flags: [], characters: "\t"), "\(widget) tab")
    }
  }

  @Test func escapeFromCreateItemDropsTheEdit() throws {
    var config = Config()
    config.customItems = [CustomItem(id: "c1", name: "Docs", text: "https://example.com")]
    let (model, _) = try makeModel(config: config)
    model.editingCustomItem = config.customItems[0]
    model.focusWidget(.createItem)
    let router = InputRouter(model: model)
    #expect(router.keyDown(keyCode: UInt16(kVK_Escape), flags: [], characters: nil))
    #expect(model.focusedWidget == .search)
    #expect(model.editingCustomItem == nil)
  }
}

@MainActor
@Suite struct TranslationSelectionTests {
  @Test func selectionWrapsForwardAcrossLanguageBoxes() throws {
    var config = Config()
    config.thirdTranslationLanguage = "fr"
    let (model, _) = try makeModel(config: config)
    model.focusWidget(.translation)
    let router = InputRouter(model: model)
    #expect(model.listCount == 3)
    for expected in [1, 2, 0] {
      #expect(router.keyDown(keyCode: UInt16(kVK_RightArrow), flags: [], characters: nil))
      #expect(model.selectedIndex == expected)
    }
    #expect(router.keyDown(keyCode: UInt16(kVK_LeftArrow), flags: [], characters: nil))
    #expect(model.selectedIndex == 0)
  }

  @Test func shiftEnterOpensTranslation() async throws {
    let (model, _) = try makeModel()
    model.query = "good morning"
    await model.confirmSearch(modifiers: [.shift])
    #expect(model.focusedWidget == .translation)
    #expect(model.query == "good morning")
    model.translation.clear()
  }
}

@MainActor
@Suite struct CustomItemEditingTests {
  @Test func commandEOpensTheSelectedCustomItem() throws {
    var config = Config()
    config.customItems = [CustomItem(id: "c1", name: "Docs", text: "https://example.com")]
    let (model, _) = try makeModel(config: config)
    model.query = "docs"
    let router = InputRouter(model: model)
    #expect(router.keyDown(keyCode: UInt16(kVK_ANSI_E), flags: [.command], characters: "e"))
    #expect(model.focusedWidget == .createItem)
    #expect(model.editingCustomItem?.id == "c1")
  }

  @Test func commandEOnOtherItemsReachesTheField() throws {
    let (model, _) = try makeModel()
    model.builtInItems = [item("sleep", name: "Sleep")]
    model.query = "sleep"
    let router = InputRouter(model: model)
    #expect(!router.keyDown(keyCode: UInt16(kVK_ANSI_E), flags: [.command], characters: "e"))
  }
}

@MainActor
@Suite struct ClipboardIntegrationTests {
  @Test func deletingKeepsSelectionInBounds() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.clipboard)
    model.clipboard.addText("first", bundle: nil)
    model.clipboard.addText("second", bundle: nil)
    model.selectNext()
    #expect(model.selectedIndex == 1)
    model.deleteSelectedClipboardItem()
    #expect(model.clipboard.items.map(\.text) == ["second"])
    #expect(model.selectedIndex == 0)
  }
}

@MainActor
@Suite struct Phase5CatalogTests {
  @Test func widgetItemsExistAndKeepThePanelOpen() {
    let items = Dictionary(uniqueKeysWithValues: BuiltInItems.make().map { ($0.id, $0) })
    for id in ["scratchpad", "clipboard_manager", "file_search", "create_shorcut", "process_manager"] {
      #expect(items[id]?.keepsPanelOpen == true, "\(id)")
    }
  }

  @Test func scratchpadShortcutToggles() async throws {
    let (model, _) = try makeModel()
    model.builtInItems = BuiltInItems.make()
    await model.runFromShortcut(itemID: "scratchpad")
    #expect(model.focusedWidget == .scratchpad)
    await model.runFromShortcut(itemID: "scratchpad")
    #expect(model.focusedWidget == .search)
    PanelManager.shared.hideWindow()
  }
}
