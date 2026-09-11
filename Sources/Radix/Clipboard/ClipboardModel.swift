import AppKit
import Observation
import RadixCore

/// Clipboard history for the clipboard widget. Replaces the previous build's
/// Keychain storage with a JSON file readable only by the user.
@MainActor
@Observable
final class ClipboardModel {
  static let saveDelay: Duration = .seconds(1)
  private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff"]

  private(set) var history: ClipboardHistory {
    didSet { selection.keepValid(in: visibleItems) }
  }
  private(set) var saveHistory: Bool

  /// The widget's filter text, mirrored from the app model's query.
  var query = "" {
    didSet {
      guard query != oldValue else { return }
      selection.select(nil)
      selection.keepValid(in: visibleItems)
    }
  }

  /// Follows the entry, not the row: a copy arriving while the widget is open
  /// or the recency boost reordering results must not make Enter paste, or
  /// ⇧⌫ delete, a different entry than the highlighted one.
  private var selection = Selection<Int64>()

  @ObservationIgnored private let historyFile: URL
  @ObservationIgnored private let imagesDirectory: URL
  @ObservationIgnored private var saveTask: Task<Void, Never>?
  /// With history saving on and no file yet (first launch after the old
  /// build, which kept history in the Keychain), the images on disk belong
  /// to a history this build can't see; they must not be treated as orphans.
  @ObservationIgnored private let historyFileExistedAtLaunch: Bool
  @ObservationIgnored private var suddenTerminationDisabled = false

  init(
    saveHistory: Bool,
    historyFile: URL = Paths.configDirectory.appendingPathComponent("clipboard_history.json"),
    imagesDirectory: URL = Paths.pasteboardImagesDirectory
  ) {
    self.saveHistory = saveHistory
    self.historyFile = historyFile
    self.imagesDirectory = imagesDirectory
    self.historyFileExistedAtLaunch = FileManager.default.fileExists(atPath: historyFile.path)
    self.history = ClipboardHistory()
    if saveHistory {
      history = ClipboardHistory(items: loadItems())
    } else if historyFileExistedAtLaunch {
      // History saving is off (possibly switched off elsewhere): a copy of
      // past clipboard contents must not linger on disk.
      do {
        try FileManager.default.removeItem(at: historyFile)
      } catch {
        NSLog("Could not remove clipboard history file: \(error.localizedDescription)")
      }
    }
  }

  var items: [PasteItem] { history.items }

  var visibleItems: [PasteItem] {
    history.search(query, now: Date())
  }

  var selectedID: Int64? { selection.id }
  var selectedIndex: Int { selection.index(in: visibleItems) }
  var selectedItem: PasteItem? { selection.element(in: visibleItems) }

  func select(id: Int64) {
    selection.select(id)
  }

  /// Pins the highlight to the first visible entry; called when the widget
  /// opens.
  func resetSelection() {
    selection.select(nil)
    selection.keepValid(in: visibleItems)
  }

  func moveSelection(by delta: Int) {
    selection.move(by: delta, in: visibleItems)
  }

  func addText(_ text: String, bundle: String?) {
    apply { $0.addText(text, bundle: bundle, now: Date()) }
  }

  func addFile(name: String, path: String, bundle: String?) {
    apply { $0.addFile(text: name, url: path, bundle: bundle, now: Date()) }
  }

  func delete(_ item: PasteItem) {
    apply { $0.remove(id: item.id) }
  }

  func moveToTop(_ item: PasteItem) {
    history.moveToTop(id: item.id)
    scheduleSave()
  }

  /// Images paste as image data; everything else (including copied files)
  /// pastes its text, as before.
  func paste(_ item: PasteItem) throws {
    if let path = item.url, Self.isImagePath(path) {
      try Paste.image(atPath: path)
    } else {
      try Paste.text(item.text)
    }
  }

  static func isImagePath(_ path: String) -> Bool {
    imageExtensions.contains((path as NSString).pathExtension.lowercased())
  }

  /// Turning history off clears the saved file, as the previous build
  /// cleared its Keychain entry.
  func setSaveHistory(_ enabled: Bool) {
    guard enabled != saveHistory else { return }
    saveHistory = enabled
    saveTask?.cancel()
    saveTask = nil
    if enabled {
      save(history.items)
    } else {
      save([])
    }
  }

  /// Writes a pending debounced save now (on quit).
  func flushPendingSave() {
    guard saveTask != nil else { return }
    saveTask?.cancel()
    saveTask = nil
    save(history.items)
  }

  /// Deletes image files no history entry references. Every Radix build
  /// writes into the same images directory, so only call this when no other
  /// Radix build is running.
  func cleanUpOrphanedImages() {
    guard !saveHistory || historyFileExistedAtLaunch else { return }
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: imagesDirectory.path) else { return }
    let referenced = Set(history.items.compactMap { $0.url.map(Self.standardizedPath) })
    let fileNames: [String]
    do {
      fileNames = try fileManager.contentsOfDirectory(atPath: imagesDirectory.path)
    } catch {
      NSLog("Could not list pasteboard images: \(error.localizedDescription)")
      return
    }
    for fileName in fileNames {
      let path = Self.standardizedPath(imagesDirectory.appendingPathComponent(fileName).path)
      guard !referenced.contains(path) else { continue }
      do {
        try fileManager.removeItem(atPath: path)
      } catch {
        NSLog("Could not delete orphaned pasteboard image \(fileName): \(error.localizedDescription)")
      }
    }
  }

  // MARK: Private

  private func apply(_ change: (inout ClipboardHistory) -> [PasteItem]) {
    let removed = change(&history)
    removed.forEach(deleteManagedImage)
    scheduleSave()
  }

  /// Only files Radix created in the images directory are deleted; copied
  /// files elsewhere belong to the user.
  private func deleteManagedImage(of item: PasteItem) {
    guard let url = item.url else { return }
    let path = Self.standardizedPath(url)
    let directory = Self.standardizedPath(imagesDirectory.path)
    guard path.hasPrefix(directory + "/"), FileManager.default.fileExists(atPath: path) else { return }
    do {
      try FileManager.default.removeItem(atPath: path)
    } catch {
      NSLog("Could not delete pasteboard image \(path): \(error.localizedDescription)")
    }
  }

  private static func standardizedPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
  }

  private func scheduleSave() {
    guard saveHistory else { return }
    saveTask?.cancel()
    setSuddenTermination(allowed: false)
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: Self.saveDelay)
      guard !Task.isCancelled, let self else { return }
      saveTask = nil
      save(history.items)
    }
  }

  /// A pending save must not be dropped by a logout or memory-pressure kill
  /// that skips applicationWillTerminate.
  private func setSuddenTermination(allowed: Bool) {
    guard suddenTerminationDisabled == allowed else { return }
    suddenTerminationDisabled = !allowed
    if allowed {
      ProcessInfo.processInfo.enableSuddenTermination()
    } else {
      ProcessInfo.processInfo.disableSuddenTermination()
    }
  }

  private func loadItems() -> [PasteItem] {
    guard FileManager.default.fileExists(atPath: historyFile.path) else { return [] }
    do {
      let data = try Data(contentsOf: historyFile)
      return try JSONDecoder().decode([PasteItem].self, from: data)
    } catch {
      // Keep the unreadable file for inspection instead of overwriting it
      // with the next save.
      let aside = historyFile.appendingPathExtension("corrupt")
      NSLog("Could not read clipboard history, moved it to \(aside.path): \(error)")
      try? FileManager.default.removeItem(at: aside)
      do {
        try FileManager.default.moveItem(at: historyFile, to: aside)
      } catch {
        NSLog("Could not move unreadable clipboard history aside: \(error.localizedDescription)")
      }
      return []
    }
  }

  /// Written to a 0600 temporary file and renamed into place, so the
  /// history is never briefly readable by other users or half-written.
  private func save(_ items: [PasteItem]) {
    defer { setSuddenTermination(allowed: saveTask == nil) }
    let fileManager = FileManager.default
    let directory = historyFile.deletingLastPathComponent()
    let temporary = directory.appendingPathComponent(".\(historyFile.lastPathComponent).tmp")
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(items)
      try? fileManager.removeItem(at: temporary)
      guard fileManager.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600])
      else {
        throw UserFacingError("could not create \(temporary.path)")
      }
      guard rename(temporary.path, historyFile.path) == 0 else {
        throw UserFacingError(String(cString: strerror(errno)))
      }
    } catch {
      NSLog("Could not save clipboard history: \(error)")
    }
  }
}
