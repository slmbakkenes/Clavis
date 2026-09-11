import AppKit
import Observation
import RadixCore

/// Central observable state, the Swift counterpart of `ui.store`. Widgets
/// render from it; the input router mutates it.
@MainActor
@Observable
final class AppModel {
  /// Height of the panel when only the search field is showing.
  static let compactHeight: CGFloat = 60
  static let permissionsBarHeight: CGFloat = 32

  private(set) var config: Config
  private(set) var state: AppState
  private(set) var keymap: Keymap

  var focusedWidget: Widget = .search {
    didSet {
      if focusedWidget == .search && oldValue != .search {
        refreshSearchRows()
      }
      if focusedWidget == .clipboard && oldValue != .clipboard {
        clipboard.resetSelection()
      }
      panelLayoutMayHaveChanged()
    }
  }
  var query = "" {
    didSet { queryChanged(from: oldValue) }
  }
  var selectedIndex = 0
  var isVisible = false
  private(set) var isAccessibilityTrusted = Permissions.isAccessibilityTrusted

  // MARK: Search sources, replaced wholesale by their loaders.

  var applications: [Item] = [] {
    didSet { refreshSearchRows() }
  }
  var builtInItems: [Item] = [] {
    didSet { refreshSearchRows() }
  }
  var preferencePanes: [Item] = [] {
    didSet { refreshSearchRows() }
  }
  var bookmarks: [Item] = [] {
    didSet { refreshSearchRows() }
  }
  var scripts: [Item] = [] {
    didSet { refreshSearchRows() }
  }

  private(set) var temporaryResult: TemporaryResult?
  private(set) var searchRows: [SearchRow] = []

  /// Only the search extension writes rows; `private(set)` does not reach
  /// across files.
  func searchRowsDidChange(_ rows: [SearchRow]) {
    searchRows = rows
    if selectedIndex >= rows.count {
      selectedIndex = max(rows.count - 1, 0)
    }
  }
  /// How far ↑ has walked back through query history.
  @ObservationIgnored var historyPointer = 0

  /// Process list for the process manager widget.
  let processes = ProcessesModel()
  /// Spotlight results for the file search widget.
  let fileSearch = FileSearchModel()
  /// Copied text, images and files for the clipboard manager.
  let clipboard: ClipboardModel
  /// Results for the translation widget.
  let translation: TranslationModel

  /// Target languages in box order; the third is optional.
  var translationLanguages: [String] {
    [config.firstTranslationLanguage, config.secondTranslationLanguage]
      + [config.thirdTranslationLanguage]
      .compactMap { $0 }
  }

  /// The custom item the create-item widget is editing; nil creates a new one.
  var editingCustomItem: CustomItem?

  /// A shortcut being recorded in settings, and what it is for.
  var shortcutRecording: ShortcutRecording?
  /// Settings > Items filter: only items whose shortcut contains these keys.
  var shortcutFilter: String?

  /// A pending "are you sure" for destructive items.
  private(set) var confirmation: Confirmation?

  @ObservationIgnored private let store: ConfigStore
  /// Called with the previous and the new config after every change. `old`
  /// is nil after a reload from disk, meaning re-apply everything (the
  /// recovery path when shortcuts or hooks are in a bad state).
  @ObservationIgnored var onConfigChanged: ((_ old: Config?, _ new: Config) -> Void)?
  @ObservationIgnored var onPreferredHeightChanged: ((CGFloat) -> Void)?
  @ObservationIgnored private var lastPreferredHeight: CGFloat?

  /// What state.json holds as far as this process knows. Saves diff against
  /// it, so a debounced note edit is still written correctly.
  @ObservationIgnored private var savedState: AppState
  @ObservationIgnored private var noteSaveTask: Task<Void, Never>?
  static let noteSaveDelay: Duration = .milliseconds(500)

  init(
    store: ConfigStore, config: Config, state: AppState, clipboard: ClipboardModel? = nil,
    translation: TranslationModel = TranslationModel()
  ) {
    self.store = store
    self.config = config
    self.state = state
    self.savedState = state
    self.clipboard = clipboard ?? ClipboardModel(saveHistory: state.clipboard.saveHistory)
    self.translation = translation
    self.keymap = config.resolvedKeymap(onInvalid: Self.logInvalidKeymapEntry)
  }

  private static func logInvalidKeymapEntry(chord: String, action: String) {
    NSLog("config.json keymap: unknown action \"\(action)\" for \"\(chord)\"")
  }

  // MARK: Config

  func updateConfig(_ mutate: (inout Config) -> Void) {
    let previous = config
    var next = config
    mutate(&next)
    guard next != previous else { return }
    config = next
    keymap = next.resolvedKeymap(onInvalid: Self.logInvalidKeymapEntry)
    do {
      try store.save(next, changedFrom: previous)
    } catch {
      NSLog("Failed to save config.json: \(error)")
      ToastManager.shared.show(text: "Could not save config.json", variant: .error)
    }
    refreshSearchRows()
    onConfigChanged?(previous, next)
  }

  /// Re-reads config.json and state.json, e.g. after editing them by hand.
  func reloadFromDisk() {
    flushPendingSaves()
    do {
      let loaded = try store.load()
      config = loaded.config
      keymap = loaded.config.resolvedKeymap(onInvalid: Self.logInvalidKeymapEntry)
      state = loaded.state
      savedState = loaded.state
      clipboard.setSaveHistory(loaded.state.clipboard.saveHistory)
      refreshSearchRows()
      onConfigChanged?(nil, config)
      ToastManager.shared.show(text: "Config reloaded", variant: .success)
    } catch {
      NSLog("Reloading config failed: \(error)")
      ToastManager.shared.show(text: "Could not reload config: \(error)", variant: .error)
    }
  }

  func updateState(_ mutate: (inout AppState) -> Void) {
    var next = state
    mutate(&next)
    guard next != state else { return }
    state = next
    saveState()
  }

  /// The scratchpad writes on every keystroke; the file is written once
  /// typing pauses, and on hide or quit (`flushPendingSaves`).
  func setNote(_ note: String) {
    guard note != state.note else { return }
    state.note = note
    if noteSaveTask == nil {
      // Logout or a memory-pressure kill would otherwise drop the edit
      // without running applicationWillTerminate.
      ProcessInfo.processInfo.disableSuddenTermination()
    }
    noteSaveTask?.cancel()
    noteSaveTask = Task { [weak self] in
      try? await Task.sleep(for: Self.noteSaveDelay)
      guard !Task.isCancelled else { return }
      self?.saveState()
    }
  }

  func flushPendingSaves() {
    guard noteSaveTask != nil else { return }
    noteSaveTask?.cancel()
    saveState()
  }

  private func saveState() {
    if noteSaveTask != nil {
      noteSaveTask = nil
      ProcessInfo.processInfo.enableSuddenTermination()
    }
    guard state != savedState else { return }
    do {
      try store.save(state, changedFrom: savedState)
      savedState = state
    } catch {
      NSLog("Failed to save state.json: \(error)")
      ToastManager.shared.show(text: "Could not save state.json", variant: .error)
    }
  }

  // MARK: Panel lifecycle

  func onShow(target: ShowTarget) {
    isVisible = true
    isAccessibilityTrusted = Permissions.isAccessibilityTrusted
    refreshRunningApplications()
    if target == .settings {
      query = ""
      focusWidget(.settings)
    }
    panelLayoutMayHaveChanged()
  }

  func onHide() {
    flushPendingSaves()
    translation.clear()
    // A recording left open would keep every item shortcut unregistered.
    if shortcutRecording != nil {
      cancelShortcutRecording()
    }
    shortcutFilter = nil
    isVisible = false
    focusedWidget = .search
    confirmation = nil
    // A calculator or conversion answer survives a hide, so reopening shows
    // it again (as the previous build did).
    if temporaryResult == nil {
      query = ""
    }
    selectedIndex = 0
    historyPointer = 0
  }

  func focusWidget(_ widget: Widget) {
    selectedIndex = 0
    focusedWidget = widget
  }

  // MARK: Selection

  /// Number of selectable rows in the focused widget.
  var listCount: Int {
    switch focusedWidget {
    case .search: searchRows.count
    case .processes: processes.visibleEntries.count
    case .translation: translationLanguages.count
    case .fileSearch: fileSearch.results.count
    case .clipboard: clipboard.visibleItems.count
    default: 0
    }
  }

  func selectNext() {
    moveSelection(by: 1)
  }

  func selectPrevious() {
    moveSelection(by: -1)
  }

  /// Lists that change while visible select by identity (see `Selection`);
  /// `selectedIndex` mirrors the row for widgets that still read it.
  private func moveSelection(by delta: Int) {
    switch focusedWidget {
    case .processes:
      processes.moveSelection(by: delta)
      selectedIndex = processes.selectedIndex
    case .clipboard:
      clipboard.moveSelection(by: delta)
      selectedIndex = clipboard.selectedIndex
    case .fileSearch:
      fileSearch.moveSelection(by: delta)
      selectedIndex = fileSearch.selectedIndex
    default:
      selectedIndex = min(max(selectedIndex + delta, 0), max(listCount - 1, 0))
    }
  }

  // MARK: Confirmation

  struct Confirmation {
    let title: String
    let proceed: @MainActor () async -> Void
  }

  func requestConfirmation(title: String, proceed: @escaping @MainActor () async -> Void) {
    confirmation = Confirmation(title: title, proceed: proceed)
  }

  func acceptConfirmation() async {
    guard let confirmation else { return }
    self.confirmation = nil
    await confirmation.proceed()
  }

  func cancelConfirmation() {
    confirmation = nil
  }

  // MARK: Layout

  var preferredPanelHeight: CGFloat {
    guard focusedWidget == .search, query.isEmpty else { return PanelManager.baseSize.height }
    return Self.compactHeight + (isAccessibilityTrusted ? 0 : Self.permissionsBarHeight)
  }

  private func panelLayoutMayHaveChanged() {
    let height = preferredPanelHeight
    guard height != lastPreferredHeight else { return }
    lastPreferredHeight = height
    onPreferredHeightChanged?(height)
  }

  // MARK: Query

  private func queryChanged(from oldValue: String) {
    if query.contains("\n") {
      // Pasted multi-line text; re-entering didSet with the cleaned value.
      query = query.replacingOccurrences(of: "\n", with: " ")
      return
    }
    guard query != oldValue else { return }
    selectedIndex = 0
    processes.query = query
    clipboard.query = query
    temporaryResult = focusedWidget == .search && !query.isEmpty ? SearchResults.temporaryResult(for: query) : nil
    // Other widgets filter their own lists from the query; rebuilding search
    // rows for them is wasted work.
    if focusedWidget == .search {
      refreshSearchRows()
    }
    panelLayoutMayHaveChanged()
  }
}
