import AppKit

/// Finder icons are expensive to fetch and the list re-renders on every
/// keystroke, so icons are cached by path or bundle identifier.
@MainActor
final class IconCache {
  static let shared = IconCache()

  private let cache = NSCache<NSString, NSImage>()
  /// Bundle ids with no installed app (a browser that left its bookmarks
  /// behind), so rows don't repeat the Launch Services lookup on every render.
  private var missingBundleIdentifiers: Set<String> = []

  private init() {
    cache.countLimit = 1000
  }

  func icon(forPath path: String) -> NSImage {
    let expanded = Workspace.expandingTilde(path)
    let key = "path:\(expanded)" as NSString
    if let cached = cache.object(forKey: key) { return cached }
    let image = NSWorkspace.shared.icon(forFile: expanded)
    cache.setObject(image, forKey: key)
    return image
  }

  func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
    let key = "bundle:\(bundleIdentifier)" as NSString
    if let cached = cache.object(forKey: key) { return cached }
    guard !missingBundleIdentifiers.contains(bundleIdentifier) else { return nil }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
      missingBundleIdentifiers.insert(bundleIdentifier)
      return nil
    }
    let image = NSWorkspace.shared.icon(forFile: url.path)
    cache.setObject(image, forKey: key)
    return image
  }
}
