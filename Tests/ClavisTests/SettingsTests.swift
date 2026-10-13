import AppKit
import Carbon
import ClavisCore
import Testing

@testable import Clavis

@MainActor
@Suite struct ShortcutFilterTests {
  @Test func exactMatchIgnoresTokenOrder() {
    #expect(ItemsSettingsPage.shortcutMatches("control+option+k", filter: "option+control+k"))
  }

  @Test func filterTokensContainedInShortcutMatch() {
    #expect(ItemsSettingsPage.shortcutMatches("control+option+right", filter: "control+option"))
  }

  @Test func differentShortcutDoesNotMatch() {
    #expect(!ItemsSettingsPage.shortcutMatches("command+shift+space", filter: "control+k"))
  }

  @Test func missingShortcutNeverMatches() {
    #expect(!ItemsSettingsPage.shortcutMatches(nil, filter: "control+k"))
    #expect(!ItemsSettingsPage.shortcutMatches("", filter: "control+k"))
  }
}

@MainActor
@Suite struct ItemSettingsTests {
  @Test func disablingRemovesTheShortcutAndEnablingRestoresTheItem() throws {
    var config = Config()
    config.shortcuts = ["lock": "command+option+q"]
    let (model, _) = try makeModel(config: config)

    model.setItem("lock", enabled: false)
    #expect(model.config.disabledItemIds == ["lock"])
    #expect(model.config.shortcuts["lock"] == nil)
    #expect(!model.isItemEnabled("lock"))

    model.setItem("lock", enabled: true)
    #expect(model.config.disabledItemIds.isEmpty)
    #expect(model.isItemEnabled("lock"))
  }

  @Test func duplicateShortcutsAreRejected() throws {
    var config = Config()
    config.shortcuts = ["lock": "command+option+q"]
    let (model, _) = try makeModel(config: config)

    #expect(!model.setShortcut("command+option+q", for: "sleep"))
    #expect(model.config.shortcuts["sleep"] == nil)
    #expect(model.setShortcut("command+option+q", for: "lock"))
    #expect(model.config.shortcuts["lock"] == "command+option+q")
  }

  @Test func restoreDefaultsResetsShortcuts() throws {
    var config = Config()
    config.shortcuts = ["lock": "command+option+x"]
    let (model, _) = try makeModel(config: config)
    model.restoreDefaultShortcuts()
    #expect(model.config.shortcuts == Config.defaultShortcuts)
  }
}

@MainActor
@Suite struct ShortcutRecordingTests {
  @Test func recordedCombinationIsStoredForTheItem() throws {
    var config = Config()
    config.shortcuts = [:]
    let (model, _) = try makeModel(config: config)
    model.focusWidget(.settings)
    let router = InputRouter(model: model)

    model.startRecordingShortcut(for: "lock")
    #expect(router.keyDown(keyCode: UInt16(kVK_ANSI_K), flags: [.control, .option], characters: "k"))
    #expect(model.config.shortcuts["lock"] == "option+control+k")
    #expect(model.shortcutRecording?.keys == ["option", "control", "k"])
    #expect(model.shortcutRecording?.error == nil)
    model.cancelShortcutRecording()
  }

  @Test func combinationWithoutModifiersIsRejected() throws {
    var config = Config()
    config.shortcuts = [:]
    let (model, _) = try makeModel(config: config)
    model.focusWidget(.settings)
    let router = InputRouter(model: model)

    model.startRecordingShortcut(for: "lock")
    #expect(router.keyDown(keyCode: UInt16(kVK_ANSI_K), flags: [], characters: "k"))
    #expect(model.config.shortcuts["lock"] == nil)
    #expect(model.shortcutRecording?.error != nil)
    model.cancelShortcutRecording()
  }

  @Test func escapeCancelsWithoutStoring() throws {
    var config = Config()
    config.shortcuts = [:]
    let (model, _) = try makeModel(config: config)
    model.focusWidget(.settings)
    let router = InputRouter(model: model)

    model.startRecordingShortcut(for: "lock")
    #expect(router.keyDown(keyCode: UInt16(kVK_Escape), flags: [], characters: nil))
    #expect(model.shortcutRecording == nil)
    #expect(model.config.shortcuts.isEmpty)
    #expect(model.focusedWidget == .settings)
  }

  @Test func filterTargetSetsTheShortcutFilter() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.settings)
    let router = InputRouter(model: model)

    model.startRecordingShortcutFilter()
    #expect(router.keyDown(keyCode: UInt16(kVK_ANSI_K), flags: [.control], characters: "k"))
    #expect(model.shortcutFilter == "control+k")
    model.cancelShortcutRecording()
  }
}

@MainActor
@Suite struct ShortcutReviewRegressionTests {
  private func record(_ keyCode: Int, _ flags: NSEvent.ModifierFlags, on model: AppModel) {
    _ = InputRouter(model: model).keyDown(keyCode: UInt16(keyCode), flags: flags, characters: nil)
  }

  /// Regression: the recorder writes "option+control+k" while defaults use
  /// "control+option+k"; string comparison let the same combination be
  /// assigned to two items.
  @Test func duplicateDetectionIgnoresTokenOrder() throws {
    let (model, _) = try makeModel()
    model.updateConfig { $0.shortcuts = ["resize_bottom_right": "control+option+k"] }
    model.startRecordingShortcut(for: "lock")
    record(kVK_ANSI_K, [.control, .option], on: model)
    #expect(model.config.shortcuts["lock"] == nil)
    #expect(model.shortcutRecording?.error?.hasPrefix("Already used by") == true)
    model.cancelShortcutRecording()
  }

  @Test func launcherCombinationsAreReserved() throws {
    let (model, _) = try makeModel()
    for flags: NSEvent.ModifierFlags in [.command, .option, .control] {
      model.startRecordingShortcut(for: "lock")
      let before = model.config.shortcuts["lock"]
      record(kVK_Space, flags, on: model)
      #expect(model.config.shortcuts["lock"] == before)
      #expect(model.shortcutRecording?.error == "Reserved for opening Clavis")
      model.cancelShortcutRecording()
    }
  }

  @Test func shiftOnlyShortcutsAreRejected() throws {
    let (model, _) = try makeModel()
    let before = model.config.shortcuts["lock"]
    model.startRecordingShortcut(for: "lock")
    record(kVK_ANSI_K, [.shift], on: model)
    #expect(model.config.shortcuts["lock"] == before)
    #expect(model.shortcutRecording?.error == "Add ⌘, ⌥ or ⌃")
    model.cancelShortcutRecording()
  }

  @Test func keysAfterASuccessfulRecordingAreIgnored() throws {
    let (model, _) = try makeModel()
    model.updateConfig { $0.shortcuts = [:] }
    model.startRecordingShortcut(for: "lock")
    record(kVK_ANSI_L, [.control, .option], on: model)
    #expect(model.config.shortcuts["lock"] == "option+control+l")
    #expect(model.shortcutRecording?.isFinished == true)
    #expect(HotKeyManager.shared.itemHotKeysPaused)

    record(kVK_ANSI_M, [.control, .option], on: model)
    #expect(model.config.shortcuts["lock"] == "option+control+l")

    record(kVK_Escape, [], on: model)
    #expect(model.shortcutRecording == nil)
    #expect(!HotKeyManager.shared.itemHotKeysPaused)
  }

  @Test func shortcutsResumeOnEveryExitPath() async throws {
    let (model, _) = try makeModel()
    model.updateConfig { $0.shortcuts = [:] }

    model.startRecordingShortcut(for: "lock")
    #expect(HotKeyManager.shared.itemHotKeysPaused)
    model.onHide()
    #expect(model.shortcutRecording == nil)
    #expect(!HotKeyManager.shared.itemHotKeysPaused)

    model.startRecordingShortcut(for: "lock")
    record(kVK_ANSI_J, [.command, .option], on: model)
    try await Task.sleep(for: AppModel.recordedShortcutDisplay + .milliseconds(300))
    #expect(model.shortcutRecording == nil)
    #expect(!HotKeyManager.shared.itemHotKeysPaused)
  }
}
