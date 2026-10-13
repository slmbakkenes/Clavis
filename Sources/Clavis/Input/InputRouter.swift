import AppKit
import Carbon
import ClavisCore

/// Translates key events into semantic `PanelAction`s and dispatches them to
/// the model. Also decides which keys the panel swallows so they never reach
/// the SwiftUI content (the search field must not see arrow keys, the
/// scratchpad must keep Enter and the vertical arrows, and so on).
@MainActor
final class InputRouter {
  private let model: AppModel
  private static let quickSelectDigits: Set<String> = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

  init(model: AppModel) {
    self.model = model
  }

  /// Returns true when the event was consumed and must not propagate.
  func keyDown(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?, isRepeat: Bool = false) -> Bool {
    // A pending confirmation is modal: Enter proceeds, Esc cancels, and no
    // other key may change what is being confirmed underneath it.
    if model.confirmation != nil {
      return handleConfirmation(keyCode: keyCode, isRepeat: isRepeat)
    }
    // So is the shortcut recorder: every key press is the shortcut.
    if model.shortcutRecording != nil {
      return handleRecording(keyCode: keyCode, flags: flags, isRepeat: isRepeat)
    }

    guard let key = Key(keyCode: keyCode), !key.isModifier else { return false }

    // The event's own flags are authoritative; the old build also OR-ed in
    // sticky state from flagsChanged, which went stale across a hide and
    // could turn plain letters into chords.
    var modifiers: Modifiers = []
    if flags.contains(.command) { modifiers.insert(.command) }
    if flags.contains(.shift) { modifiers.insert(.shift) }
    if flags.contains(.control) { modifiers.insert(.control) }

    // ⌘1…⌘9 are reserved: the previous build swallowed them without an action,
    // so they never typed into the field.
    if modifiers.contains(.command), let digit = characters, Self.quickSelectDigits.contains(digit) {
      return true
    }

    guard let action = model.keymap.action(for: key, modifiers: modifiers) else {
      return false
    }
    guard widgetHandles(action) else {
      return false
    }
    // Holding Enter must never run a second item or accept a confirmation
    // the first press opened; only a fresh press confirms.
    if action == .confirm && isRepeat {
      return true
    }
    return perform(action, modifiers: modifiers)
  }

  private func handleRecording(keyCode: UInt16, flags: NSEvent.ModifierFlags, isRepeat: Bool) -> Bool {
    guard !isRepeat else { return true }
    if model.shortcutRecording?.isFinished == true {
      if Int(keyCode) == kVK_Escape { model.cancelShortcutRecording() }
      return true
    }
    switch Int(keyCode) {
    case kVK_Escape:
      model.cancelShortcutRecording()
      return true
    case kVK_Tab:
      return true
    default:
      break
    }
    model.recordShortcut(keys: Self.shortcutTokens(keyCode: keyCode, flags: flags))
    return true
  }

  /// Tokens in the order the previous recorder produced them.
  static func shortcutTokens(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> [String] {
    var tokens: [String] = []
    if flags.contains(.command) { tokens.append("command") }
    if flags.contains(.option) { tokens.append("option") }
    if flags.contains(.control) { tokens.append("control") }
    if flags.contains(.shift) { tokens.append("shift") }
    switch Int(keyCode) {
    case kVK_RightArrow: tokens.append("right")
    case kVK_LeftArrow: tokens.append("left")
    case kVK_UpArrow: tokens.append("up")
    case kVK_DownArrow: tokens.append("down")
    case kVK_Return: tokens.append("return")
    case kVK_Space: tokens.append("space")
    default:
      // By physical key, as hotkeys are registered: typed characters change
      // with ⌥ (⌥Q types "œ") and with the keyboard layout.
      if let key = Key(keyCode: keyCode), !key.isModifier {
        tokens.append(key.name)
      }
    }
    return tokens
  }

  private func handleConfirmation(keyCode: UInt16, isRepeat: Bool) -> Bool {
    guard !isRepeat, let key = Key(keyCode: keyCode), !key.isModifier else { return true }
    switch model.keymap.action(for: key, modifiers: []) {
    case .confirm:
      Task { await model.acceptConfirmation() }
    case .dismiss:
      model.cancelConfirmation()
    default:
      break
    }
    return true
  }

  /// Per-widget gating, replacing the old turnOn/turnOff*Listeners toggles.
  private func widgetHandles(_ action: PanelAction) -> Bool {
    switch (model.focusedWidget, action) {
    // Text-entry widgets own Enter and the arrows; the editor and form fields
    // need them.
    case (.scratchpad, .confirm), (.scratchpad, .selectNext), (.scratchpad, .selectPrevious),
      (.createItem, .confirm), (.createItem, .selectNext), (.createItem, .selectPrevious):
      return false
    case (.translation, .selectLeft), (.translation, .selectRight):
      return true
    case (_, .selectLeft), (_, .selectRight):
      return false
    case (_, .cycleScratchpadColor):
      // The old scratchpad colour was never rendered; Tab types a tab in the
      // scratchpad and moves focus in forms.
      return false
    default:
      return true
    }
  }

  /// Returns whether the action was handled; unhandled keys reach the view.
  private func perform(_ action: PanelAction, modifiers: Modifiers) -> Bool {
    switch (model.focusedWidget, action) {
    case (.search, .confirm):
      Task { await model.confirmSearch(modifiers: modifiers) }
    case (.search, .selectPrevious):
      model.selectPreviousOrHistory()
    case (.search, .editSelected):
      guard case .item(let item) = model.selectedRow, item.kind == .custom else { return false }
      model.editSelectedCustomItem()
    case (.search, .deleteSelected):
      // Only custom items can be deleted; otherwise ⇧⌫ edits the query.
      guard case .item(let item) = model.selectedRow, item.kind == .custom else { return false }
      model.deleteSelectedCustomItem()
    case (.translation, .confirm):
      model.copySelectedTranslation()
    case (.clipboard, .confirm):
      model.confirmClipboard(modifiers: modifiers)
    case (.clipboard, .deleteSelected):
      model.deleteSelectedClipboardItem()
    case (.fileSearch, .confirm):
      model.openSelectedFile(revealInFinder: modifiers.contains(.shift))
    case (.processes, .confirm):
      model.killSelectedProcess()
    case (.search, .dismiss), (.clipboard, .dismiss), (.scratchpad, .dismiss):
      PanelManager.shared.hideWindow()
    case (_, .dismiss):
      // Widgets without their own dismiss return to search, as before.
      model.editingCustomItem = nil
      model.query = ""
      model.focusWidget(.search)
    case (.translation, .selectNext), (.translation, .selectRight):
      // The old widget wrapped forward through the language boxes.
      let count = max(model.listCount, 1)
      model.selectedIndex = (model.selectedIndex + 1) % count
    case (.translation, .selectLeft):
      model.selectPrevious()
    case (_, .selectNext):
      model.selectNext()
    case (_, .selectPrevious):
      model.selectPrevious()
    default:
      // Remaining handlers land with their widgets (phases 4 to 6).
      return false
    }
    return true
  }
}
