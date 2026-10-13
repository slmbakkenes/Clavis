import AppKit
import Carbon
import ClavisCore
import Testing

@testable import Clavis

@MainActor
@Suite struct InputRouterTests {
  @Test func arrowsMoveSelectionAndAreSwallowed() throws {
    let (model, _) = try makeModel()
    model.builtInItems = [item("sleep", name: "Sleep"), item("settings", name: "Settings")]
    model.query = "s"
    let router = InputRouter(model: model)

    #expect(router.keyDown(keyCode: UInt16(kVK_DownArrow), flags: [], characters: nil))
    #expect(model.selectedIndex == 1)
    #expect(router.keyDown(keyCode: UInt16(kVK_UpArrow), flags: [], characters: nil))
    #expect(model.selectedIndex == 0)
  }

  @Test func lettersReachTheSearchField() throws {
    let (model, _) = try makeModel()
    let router = InputRouter(model: model)
    #expect(!router.keyDown(keyCode: UInt16(kVK_ANSI_J), flags: [], characters: "j"))
    #expect(!router.keyDown(keyCode: UInt16(kVK_LeftArrow), flags: [], characters: nil))
  }

  @Test func shiftDeletePassesThroughUnlessCustomItemSelected() throws {
    let (model, _) = try makeModel()
    model.builtInItems = [item("sleep", name: "Sleep")]
    model.query = "sleep"
    let router = InputRouter(model: model)
    #expect(!router.keyDown(keyCode: UInt16(kVK_Delete), flags: [.shift], characters: nil))
  }

  @Test func confirmationIsModal() throws {
    let (model, _) = try makeModel()
    model.builtInItems = [item("sleep", name: "Sleep"), item("settings", name: "Settings")]
    model.query = "s"
    model.requestConfirmation(title: "Sure?") {}
    let router = InputRouter(model: model)

    #expect(router.keyDown(keyCode: UInt16(kVK_DownArrow), flags: [], characters: nil))
    #expect(model.selectedIndex == 0)
    #expect(router.keyDown(keyCode: UInt16(kVK_ANSI_A), flags: [], characters: "a"))
    #expect(router.keyDown(keyCode: UInt16(kVK_Escape), flags: [], characters: nil))
    #expect(model.confirmation == nil)
  }

  @Test func escapeFromUnportedWidgetReturnsToSearch() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.settings)
    let router = InputRouter(model: model)
    #expect(router.keyDown(keyCode: UInt16(kVK_Escape), flags: [], characters: nil))
    #expect(model.focusedWidget == .search)
  }

  @Test func heldEnterDoesNotAcceptConfirmation() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.requestConfirmation(title: "Clear Trash") { log.ran.append("empty_trash") }
    let router = InputRouter(model: model)

    #expect(router.keyDown(keyCode: UInt16(kVK_Return), flags: [], characters: "\r", isRepeat: true))
    await Task.yield()
    #expect(log.ran.isEmpty)
    #expect(model.confirmation != nil)

    #expect(router.keyDown(keyCode: UInt16(kVK_Return), flags: [], characters: "\r"))
    for _ in 0..<5 { await Task.yield() }
    #expect(log.ran == ["empty_trash"])
  }

  @Test func heldEnterDoesNotRunItems() async throws {
    let (model, _) = try makeModel()
    let log = RunLog()
    model.builtInItems = [item("sleep", name: "Sleep", log: log)]
    model.query = "sleep"
    let router = InputRouter(model: model)

    #expect(router.keyDown(keyCode: UInt16(kVK_Return), flags: [], characters: "\r", isRepeat: true))
    for _ in 0..<5 { await Task.yield() }
    #expect(log.ran.isEmpty)
  }

  @Test func commandDigitsAreReserved() throws {
    let (model, _) = try makeModel()
    let router = InputRouter(model: model)
    #expect(router.keyDown(keyCode: UInt16(kVK_ANSI_1), flags: [.command], characters: "1"))
  }
}
