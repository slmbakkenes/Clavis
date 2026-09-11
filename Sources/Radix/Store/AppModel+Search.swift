import AppKit
import RadixCore

/// Search widget behaviour: building rows, running items, history, and the
/// usage stats that feed ranking.
extension AppModel {
  /// Every searchable item, before disabled items are filtered out.
  var allItems: [Item] {
    var items =
      applications + builtInItems + SearchResults.customItems(config.customItems) + scripts + preferencePanes
    if config.showInAppBrowserBookMarks {
      items += bookmarks
    }
    return items
  }

  func refreshSearchRows() {
    searchRowsDidChange(
      SearchResults.rows(
        query: query, items: allItems, temporaryResult: temporaryResult, config: config, state: state))
  }

  func refreshRunningApplications() {
    let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.absoluteString })
    let updated = applications.map { app in
      var app = app
      app.isRunning = running.contains(app.id)
      return app
    }
    if updated.map(\.isRunning) != applications.map(\.isRunning) {
      applications = updated
    }
  }

  var selectedRow: SearchRow? {
    searchRows.indices.contains(selectedIndex) ? searchRows[selectedIndex] : nil
  }

  // MARK: Actions

  /// Enter in the search widget. ⌘ (or no results) searches the web.
  func confirmSearch(modifiers: Modifiers) async {
    guard !query.isEmpty else { return }
    addToHistory(query)
    historyPointer = 0

    if modifiers.contains(.shift) {
      translation.translate(query, languages: translationLanguages)
      focusWidget(.translation)
      return
    }

    if searchRows.isEmpty || modifiers.contains(.command) {
      openBrowserSearch()
      return
    }

    switch selectedRow {
    case .temporaryResult(let result):
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(result.clipboardText, forType: .string)
      PanelManager.shared.hideWindow()
      ToastManager.shared.show(text: "Copied to clipboard", variant: .success)
    case .item(let item):
      recordSelection(of: item)
      await run(item)
    case nil:
      return
    }
  }

  /// Runs an item from the panel: asks for confirmation when the item wants
  /// it, hides the panel unless the item keeps it open, and reports errors.
  func run(_ item: Item) async {
    if let title = item.confirmationTitle {
      requestConfirmation(title: title) { [weak self] in
        PanelManager.shared.hideWindow()
        await self?.execute(item)
      }
      return
    }
    if !item.keepsPanelOpen {
      PanelManager.shared.hideWindow()
    }
    await execute(item)
  }

  /// Runs an item from its global shortcut. The panel is usually hidden, so
  /// items that need it (a confirmation, or a widget they switch to) show it.
  func runFromShortcut(itemID: String) async {
    guard let item = allItems.first(where: { $0.id == itemID }) else {
      NSLog("Shortcut for unknown item \(itemID)")
      return
    }
    if let title = item.confirmationTitle {
      PanelManager.shared.showWindow()
      requestConfirmation(title: title) { [weak self] in
        PanelManager.shared.hideWindow()
        await self?.execute(item)
      }
      return
    }
    await execute(item)
    if item.keepsPanelOpen {
      PanelManager.shared.showWindow()
    }
  }

  private func execute(_ item: Item) async {
    do {
      try await item.perform(self)
    } catch {
      NSLog("Item \(item.id) failed: \(error)")
      ToastManager.shared.show(text: "\(item.name): \(error)", variant: .error)
    }
  }

  func openBrowserSearch() {
    guard let url = config.searchEngine.searchURL(for: query, customSearchURL: config.customSearchUrl) else {
      ToastManager.shared.show(
        text: "Invalid search URL. It must contain %s, e.g. https://google.com/search?q=%s", variant: .error)
      return
    }
    PanelManager.shared.hideWindow()
    do {
      try Workspace.open(urlString: url)
    } catch {
      ToastManager.shared.show(text: "\(error)", variant: .error)
    }
  }

  /// ↑ on the first row walks back through previous queries.
  func selectPreviousOrHistory() {
    let history = state.history
    guard selectedIndex == 0, !history.isEmpty else {
      selectPrevious()
      return
    }
    let pointer = min(historyPointer, history.count - 1)
    query = history[history.count - 1 - pointer]
    historyPointer = min(history.count - 1, pointer + 1)
  }

  /// Enter in the process manager. Kills the highlighted process by pid, so
  /// a refresh that re-sorts the list can't redirect it. Unlike the old
  /// build, a failed kill (a system process, say) is reported and the panel
  /// stays open.
  func killSelectedProcess() {
    guard let entry = processes.selectedEntry else {
      PanelManager.shared.hideWindow()
      return
    }
    do {
      try processes.kill(entry)
      PanelManager.shared.hideWindow()
      ToastManager.shared.show(text: "Process \"\(entry.name)\" killed", variant: .success)
    } catch {
      ToastManager.shared.show(text: "\(error)", variant: .error)
    }
  }

  /// Enter in the translation widget copies the selected translation.
  func copySelectedTranslation() {
    guard let text = translation.text(at: selectedIndex) else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    PanelManager.shared.hideWindow()
  }

  /// Enter in the clipboard manager pastes the selected entry into the
  /// frontmost app; ⌘Enter opens its text as a URL. Either way the entry moves
  /// to the top, as before.
  func confirmClipboard(modifiers: Modifiers) {
    guard let item = clipboard.selectedItem else { return }
    do {
      if modifiers.contains(.command) {
        PanelManager.shared.hideWindow()
        try Workspace.open(urlString: item.text)
      } else {
        try clipboard.paste(item)
      }
      // Only after it worked: a failed paste must not reorder the list.
      clipboard.moveToTop(item)
    } catch {
      ToastManager.shared.show(text: "\(error)", variant: .error)
    }
  }

  func deleteSelectedClipboardItem() {
    guard let item = clipboard.selectedItem else { return }
    clipboard.delete(item)
    selectedIndex = clipboard.selectedIndex
  }

  /// Enter in file search opens the file; ⇧Enter reveals it in Finder and
  /// keeps the panel open, as before.
  func openSelectedFile(revealInFinder: Bool) {
    guard let file = fileSearch.selectedResult else { return }
    if revealInFinder {
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
      return
    }
    PanelManager.shared.hideWindow()
    do {
      try Workspace.open(path: file.path)
    } catch {
      ToastManager.shared.show(text: "\(error)", variant: .error)
    }
  }

  /// ⌘E on a custom item opens it in the create-item widget.
  func editSelectedCustomItem() {
    guard case .item(let item) = selectedRow, item.kind == .custom,
      let custom = config.customItems.first(where: { $0.id == item.id })
    else { return }
    editingCustomItem = custom
    focusWidget(.createItem)
  }

  func deleteSelectedCustomItem() {
    guard case .item(let item) = selectedRow, item.kind == .custom else { return }
    updateConfig { $0.customItems.removeAll { $0.id == item.id } }
  }

  // MARK: Stats

  /// Kept bounded: the previous build appended forever to state.json.
  static let historyLimit = 200

  func addToHistory(_ entry: String) {
    updateState { state in
      state.history.append(entry)
      if state.history.count > Self.historyLimit {
        state.history.removeFirst(state.history.count - Self.historyLimit)
      }
    }
  }

  func recordSelection(of item: Item) {
    updateState { state in
      let previous = state.frequencies[item.id] ?? state.frequencies[item.name] ?? 0
      state.frequencies[item.id] = previous + 1
      state.selectionTimestamps[item.id] = (Date().timeIntervalSince1970 * 1000).rounded()
    }
  }
}
