import AppKit
import CoreServices
import ClavisCore

/// A script file found in the scripts directory, with its parsed metadata.
struct ScannedScript: Sendable, Equatable {
  let fileName: String
  let fileURL: URL
  let metadata: ScriptMetadata
}

enum ScriptScanner {
  /// Lists and parses scripts in `directory`, sorted by file name. A missing
  /// directory yields no scripts; unreadable files are logged and skipped.
  nonisolated static func scan(directory: URL) -> [ScannedScript] {
    let fileNames: [String]
    do {
      fileNames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    } catch {
      NSLog("Could not list scripts in \(directory.path): \(error.localizedDescription)")
      return []
    }

    return fileNames.filter(ScriptMetadata.isScript(fileName:)).sorted().compactMap { fileName in
      let fileURL = directory.appendingPathComponent(fileName)
      do {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return ScannedScript(
          fileName: fileName, fileURL: fileURL,
          metadata: ScriptMetadata.parse(content: content, fileName: fileName))
      } catch {
        NSLog("Skipping unreadable script \(fileName): \(error.localizedDescription)")
        return nil
      }
    }
  }
}

/// Loads user scripts from ~/.config/clavis/scripts as search items and
/// reloads them whenever the directory changes.
@MainActor
final class ScriptLoader {
  /// The previous build's watcher used 0.5 s; edits should show up quickly.
  private static let eventLatency: CFTimeInterval = 0.5
  private static let debounce: Duration = .milliseconds(500)

  private let directory: URL
  private var onChange: (@MainActor ([Item]) -> Void)?
  private var watcher: DirectoryWatcher?
  /// Guards against a slow scan finishing after a newer one.
  private var scanGeneration = 0

  init(directory: URL = Paths.scriptsDirectory) {
    self.directory = directory
  }

  func start(onChange: @escaping @MainActor ([Item]) -> Void) {
    self.onChange = onChange
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      NSLog("Could not create scripts directory \(directory.path): \(error.localizedDescription)")
    }
    let watcher = DirectoryWatcher(
      paths: [directory.path], label: "scripts", latency: Self.eventLatency, debounce: Self.debounce
    ) { [weak self] in
      self?.rescan()
    }
    watcher.start()
    self.watcher = watcher
    rescan()
  }

  static func items(from scripts: [ScannedScript]) -> [Item] {
    scripts.map { script in
      let fileName = script.fileName
      let fileURL = script.fileURL
      return Item(
        id: "script-\(fileName)",
        kind: .script,
        name: script.metadata.name,
        subtitle: "Script",
        icon: .emoji(script.metadata.icon)
      ) { _ in
        // Re-read so an edit applies even before the watcher reloads.
        let content: String
        do {
          content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
          throw UserFacingError("Could not read \(fileName): \(error.localizedDescription)")
        }
        if fileName.hasSuffix(".applescript") {
          try await AppleScript.run(content)
        } else {
          try Shell.runShowingOutput(content)
        }
      }
    }
  }

  private func rescan() {
    scanGeneration += 1
    let generation = scanGeneration
    let directory = directory
    Task {
      let scripts = await Task.detached(priority: .utility) { ScriptScanner.scan(directory: directory) }.value
      guard generation == scanGeneration else { return }
      onChange?(Self.items(from: scripts))
    }
  }
}
