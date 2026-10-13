import Foundation
import ClavisCore
import Testing

@testable import Clavis

@MainActor
@Suite struct ClipboardSelectionTests {
  /// Regression: Enter pasted whatever sat at the row index, and a copy
  /// arriving while the widget was open shifted every row down by one.
  @Test func selectionStaysOnTheEntryWhenACopyArrives() throws {
    let (model, _) = try makeModel()
    model.clipboard.addText("older", bundle: nil)
    model.clipboard.addText("newer", bundle: nil)
    model.focusWidget(.clipboard)
    #expect(model.clipboard.selectedItem?.text == "newer")
    model.selectNext()
    #expect(model.clipboard.selectedItem?.text == "older")

    model.clipboard.addText("arrived while open", bundle: nil)
    #expect(model.clipboard.selectedItem?.text == "older")
    #expect(model.clipboard.selectedIndex == 2)
  }

  @Test func deletingRemovesTheHighlightedEntry() throws {
    let (model, _) = try makeModel()
    model.clipboard.addText("keep", bundle: nil)
    model.clipboard.addText("delete me", bundle: nil)
    model.clipboard.addText("keep too", bundle: nil)
    model.focusWidget(.clipboard)
    model.selectNext()
    #expect(model.clipboard.selectedItem?.text == "delete me")
    model.clipboard.addText("late arrival", bundle: nil)
    model.deleteSelectedClipboardItem()
    #expect(model.clipboard.items.map(\.text) == ["late arrival", "keep too", "keep"])
  }

  @Test func openingTheWidgetHighlightsTheNewestEntry() throws {
    let (model, _) = try makeModel()
    model.clipboard.addText("first", bundle: nil)
    model.clipboard.addText("second", bundle: nil)
    model.focusWidget(.clipboard)
    #expect(model.clipboard.selectedItem?.text == "second")
  }
}

@MainActor
@Suite struct FileSearchSelectionTests {
  @Test func selectionFollowsThePathWhenResultsChange() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.fileSearch)
    let a = FileResult(path: "/tmp/a.txt", name: "a.txt", isDirectory: false)
    let b = FileResult(path: "/tmp/b.txt", name: "b.txt", isDirectory: false)
    let c = FileResult(path: "/tmp/c.txt", name: "c.txt", isDirectory: false)
    model.fileSearch.setResultsForTesting([a, b])
    model.selectNext()
    #expect(model.fileSearch.selectedResult == b)

    model.fileSearch.setResultsForTesting([c, b, a])
    #expect(model.fileSearch.selectedResult == b)

    model.fileSearch.setResultsForTesting([c])
    #expect(model.fileSearch.selectedResult == c)
  }
}

@MainActor
@Suite struct ClipboardMonitorFileTests {
  /// Regression: copied non-image files were copied into the temporary
  /// directory after deleting anything with the same name there; a copied
  /// volume root resolved to the temporary directory itself.
  @Test func nonImageFilesAreRecordedInPlaceWithoutCopying() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ClavisMonitor-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "hello".write(to: document, atomically: true, encoding: .utf8)

    let monitor = ClipboardMonitor(imagesDirectory: directory.appendingPathComponent("images"))
    var recorded: [(name: String, path: String)] = []
    monitor.onFile = { name, path, _ in recorded.append((name, path)) }

    monitor.handleFileURL(document.dataRepresentation, bundle: nil)
    monitor.handleFileURL(URL(fileURLWithPath: "/").dataRepresentation, bundle: nil)

    #expect(recorded.map(\.path) == [document.path, "/"])
    #expect(FileManager.default.fileExists(atPath: FileManager.default.temporaryDirectory.path))
    let images = directory.appendingPathComponent("images")
    #expect((try? FileManager.default.contentsOfDirectory(atPath: images.path))?.isEmpty ?? true)
  }
}

@MainActor
@Suite struct ClipboardHistoryFileTests {
  @Test func historyFileIsRemovedWhenSavingIsOff() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ClavisHistory-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("clipboard_history.json")
    try "[]".write(to: file, atomically: true, encoding: .utf8)

    _ = ClipboardModel(saveHistory: false, historyFile: file, imagesDirectory: directory)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func firstLaunchWithSavingOnLeavesExistingImagesAlone() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ClavisImages-\(UUID().uuidString)", isDirectory: true)
    let images = directory.appendingPathComponent("images_pasteboard", isDirectory: true)
    try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let image = images.appendingPathComponent("img_old.png")
    try Data([0x89]).write(to: image)

    let model = ClipboardModel(
      saveHistory: true, historyFile: directory.appendingPathComponent("clipboard_history.json"),
      imagesDirectory: images)
    model.cleanUpOrphanedImages()
    #expect(FileManager.default.fileExists(atPath: image.path))
  }
}

@MainActor
@Suite struct TranslationStubTests {
  @Test func translationUsesTheInjectedTranslator() async throws {
    let (model, _) = try makeModel()
    model.query = "hello"
    await model.confirmSearch(modifiers: [.shift])
    for _ in 0..<50 where model.translation.rows.isEmpty {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.translation.text(at: 0) == "translated to \(model.config.firstTranslationLanguage)")
  }
}
