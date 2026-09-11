import AppKit
import CoreServices
import RadixCore

/// An application bundle found on disk.
struct InstalledApp: Sendable, Equatable {
  let name: String
  let localizedName: String
  let fileURL: URL
}

/// Finds installed applications. Port of the old `ApplicationSearcher`
/// scan; runs off the main thread.
enum ApplicationScanner {
  static let searchDepth = 4

  static let ignoredPatterns: Set<String> = [
    "Audio MIDI Setup.app",
    "Script Editor.app",
    "Grapher.app",
    "Airport Utility.app",
    "ColorSync Utility.app",
    "Bluetooth File Exchange.app",
    "Tips",
    "Siri.app",
    ".DS_Store",
    ".localized",
    "Icon",
    "en_US.strings",
    "Tips.app",
  ]

  /// Apps outside the application directories that should still be found.
  static var fixedURLs: [URL] {
    var urls = [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]
    if #available(macOS 15, *) {
      urls.append(URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Keychain Access.app"))
    }
    return urls
  }

  /// The local, system and user application directories that exist.
  static func applicationDirectories() -> [URL] {
    let domains: [FileManager.SearchPathDomainMask] = [.localDomainMask, .systemDomainMask, .userDomainMask]
    return domains.compactMap {
      try? FileManager.default.url(for: .applicationDirectory, in: $0, appropriateFor: nil, create: false)
    }
  }

  static func scan() -> [InstalledApp] {
    let fileManager = FileManager.default
    var candidates = fixedURLs
    for directory in applicationDirectories() {
      candidates.append(contentsOf: applicationURLs(at: directory, depth: 0, fileManager: fileManager))
    }

    var seen = Set<String>()
    var apps: [InstalledApp] = []
    for candidate in candidates {
      var url = candidate
      do {
        if try url.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true {
          url = try URL(resolvingAliasFileAt: url)
        }
      } catch {
        // A dangling alias, typically left by an incomplete uninstall.
        continue
      }

      guard fileManager.fileExists(atPath: url.path) else { continue }

      do {
        let values = try url.resourceValues(forKeys: [.isExecutableKey, .isApplicationKey])
        guard values.isExecutable == true, values.isApplication == true else { continue }
      } catch {
        NSLog("Error resolving info for application at \(url): \(error.localizedDescription)")
        continue
      }

      let key = url.absoluteString
      guard seen.insert(key).inserted else { continue }
      let name = url.deletingPathExtension().lastPathComponent
      apps.append(InstalledApp(name: name, localizedName: displayName(of: url) ?? name, fileURL: url))
    }
    return apps
  }

  /// Spotlight's display name, which is localized ("Rekenmachine" for
  /// Calculator on a Dutch system), without the ".app" suffix.
  private static func displayName(of url: URL) -> String? {
    guard let item = MDItemCreateWithURL(nil, url as CFURL),
      let displayName = MDItemCopyAttribute(item, kMDItemDisplayName) as? String
    else { return nil }
    return displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
  }

  private static func applicationURLs(at url: URL, depth: Int, fileManager: FileManager) -> [URL] {
    guard fileManager.fileExists(atPath: url.path), depth <= searchDepth,
      !ignoredPatterns.contains(url.lastPathComponent)
    else { return [] }

    if url.pathExtension == "app" {
      return [url]
    }

    var resolved = url
    if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
      resolved = url.resolvingSymlinksInPath()
      guard fileManager.fileExists(atPath: resolved.path),
        !ignoredPatterns.contains(resolved.lastPathComponent)
      else { return [] }
      if resolved.pathExtension == "app" {
        return [resolved]
      }
    }

    guard resolved.hasDirectoryPath else { return [] }

    do {
      let contents = try fileManager.contentsOfDirectory(
        at: resolved, includingPropertiesForKeys: [],
        options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants]
      )
      return contents.flatMap { applicationURLs(at: $0, depth: depth + 1, fileManager: fileManager) }
    } catch {
      if isExpectedListingError(error) { return [] }
      NSLog("Could not resolve apps url at \(url): \(error.localizedDescription)")
      return []
    }
  }

  /// Permission errors and files that vanished between listing and access
  /// (broken symlinks, races with uninstalls) are normal and not logged.
  private static func isExpectedListingError(_ error: Error) -> Bool {
    let nsError = error as NSError
    switch (nsError.domain, nsError.code) {
    case (NSCocoaErrorDomain, NSFileReadNoPermissionError),
      (NSCocoaErrorDomain, NSFileReadNoSuchFileError),
      (NSPOSIXErrorDomain, Int(ENOENT)):
      return true
    default:
      return false
    }
  }
}

/// Keeps the application list current: scans at start and again whenever
/// the application directories change or the Mac wakes.
@MainActor
final class ApplicationLoader {
  /// FSEvents coalesces events for this long before delivering them. Kept
  /// short so a freshly installed app is searchable within a couple of
  /// seconds; the debounce absorbs install bursts.
  private static let eventLatency: CFTimeInterval = 1
  private static let debounce: Duration = .seconds(1)
  /// Item changes, plus the flags FSEvents sets when it coalesced or dropped
  /// events, which is exactly when a full rescan is needed.
  private static let relevantFlags = FSEventStreamEventFlags(
    kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRemoved
      | kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemInodeMetaMod
      | kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
      | kFSEventStreamEventFlagKernelDropped)

  private var onChange: (@MainActor ([Item]) -> Void)?
  private var watcher: DirectoryWatcher?
  /// Guards against a slow scan finishing after a newer one.
  private var scanGeneration = 0

  func start(onChange: @escaping @MainActor ([Item]) -> Void) {
    self.onChange = onChange
    let paths = ApplicationScanner.applicationDirectories().map(\.path)
    if paths.isEmpty {
      NSLog("No application directories to watch")
    } else {
      let watcher = DirectoryWatcher(
        paths: paths, label: "applications", latency: Self.eventLatency, debounce: Self.debounce,
        relevantFlags: Self.relevantFlags
      ) { [weak self] in
        self?.rescan()
      }
      watcher.start()
      self.watcher = watcher
    }
    rescan()
  }

  static func items(from apps: [InstalledApp]) -> [Item] {
    let ownBundlePath = Bundle.main.bundleURL.standardizedFileURL.path
    return apps.compactMap { app in
      let path = app.fileURL.path
      guard app.fileURL.standardizedFileURL.path != ownBundlePath else { return nil }
      return Item(
        id: app.fileURL.absoluteString,
        kind: .application,
        name: app.name,
        localizedName: app.localizedName == app.name ? nil : app.localizedName,
        alias: Initials.of(app.name),
        icon: .file(path)
      ) { _ in
        try Workspace.open(path: path)
      }
    }
  }

  private func rescan() {
    scanGeneration += 1
    let generation = scanGeneration
    Task {
      let apps = await Task.detached(priority: .utility) { ApplicationScanner.scan() }.value
      guard generation == scanGeneration else { return }
      onChange?(Self.items(from: apps))
    }
  }
}
