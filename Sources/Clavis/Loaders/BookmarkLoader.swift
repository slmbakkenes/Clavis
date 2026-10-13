import Foundation
import ClavisCore

/// Loads bookmarks from Safari and the Chromium browsers into search items.
@MainActor
enum BookmarkLoader {
  struct Source: Sendable {
    let id: String
    let bundleIdentifier: String
    let file: URL
    let format: Format
  }

  enum Format: Sendable {
    case safari
    case chromium
  }

  /// Safari first, then the Chromium browsers; ids keep the first
  /// occurrence, as the previous build did.
  static var sources: [Source] {
    let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
    let support = library.appendingPathComponent("Application Support")
    func chromium(_ id: String, _ bundleIdentifier: String, _ profile: String) -> Source {
      Source(
        id: id, bundleIdentifier: bundleIdentifier,
        file: support.appendingPathComponent(profile).appendingPathComponent("Default/Bookmarks"), format: .chromium)
    }
    return [
      Source(
        id: "safari", bundleIdentifier: "com.apple.Safari",
        file: library.appendingPathComponent("Safari/Bookmarks.plist"), format: .safari),
      chromium("brave", "com.brave.Browser", "BraveSoftware/Brave-Browser"),
      chromium("chrome", "com.google.Chrome", "Google/Chrome"),
      chromium("vivaldi", "com.vivaldi.Vivaldi", "Vivaldi"),
      chromium("edge", "com.microsoft.edgemac", "Microsoft Edge"),
    ]
  }

  static func load() async -> [Item] {
    let sources = sources
    let loaded = await Task.detached(priority: .utility) {
      sources.map { ($0, readBookmarks(from: $0)) }
    }.value

    var seen = Set<String>()
    var items: [Item] = []
    for (source, bookmarks) in loaded {
      for (index, bookmark) in bookmarks.enumerated() {
        let id = "\(bookmark.title)_\(source.id)_\(index)"
        guard seen.insert(id).inserted else { continue }
        let url = bookmark.url
        items.append(
          Item(
            id: id, kind: .bookmark, name: bookmark.title, subtitle: subtitle(forFolder: bookmark.folder),
            icon: .application(bundleIdentifier: source.bundleIdentifier)
          ) { _ in
            try Workspace.open(urlString: url)
          })
      }
    }
    return items
  }

  /// Folder names are cut to 16 characters, as the old row did.
  static func subtitle(forFolder folder: String?) -> String? {
    guard let folder, !folder.isEmpty else { return nil }
    return folder.count > 16 ? "\(folder.prefix(16))..." : folder
  }

  /// A missing file means the browser isn't installed, and an unreadable
  /// Safari file means no Full Disk Access; both are normal and quiet.
  /// Anything else is logged and the source skipped.
  nonisolated private static func readBookmarks(from source: Source) -> [Bookmark] {
    let data: Data
    do {
      data = try Data(contentsOf: source.file)
    } catch {
      if !isExpectedReadError(error) {
        NSLog("Could not read \(source.id) bookmarks at \(source.file.path): \(error.localizedDescription)")
      }
      return []
    }

    do {
      switch source.format {
      case .safari: return try SafariBookmarks.parse(data)
      case .chromium: return try ChromiumBookmarks.parse(data)
      }
    } catch {
      NSLog("Could not parse \(source.id) bookmarks at \(source.file.path): \(error)")
      return []
    }
  }

  nonisolated private static func isExpectedReadError(_ error: Error) -> Bool {
    let nsError = error as NSError
    switch (nsError.domain, nsError.code) {
    case (NSCocoaErrorDomain, NSFileReadNoSuchFileError),
      (NSCocoaErrorDomain, NSFileReadNoPermissionError),
      (NSPOSIXErrorDomain, Int(ENOENT)),
      (NSPOSIXErrorDomain, Int(EPERM)),
      (NSPOSIXErrorDomain, Int(EACCES)):
      return true
    default:
      if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
        return isExpectedReadError(underlying)
      }
      return false
    }
  }
}
