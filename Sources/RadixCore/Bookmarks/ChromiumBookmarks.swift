import Foundation

/// Parses the `Bookmarks` JSON file Chromium browsers (Chrome, Brave,
/// Vivaldi, Edge) keep in their profile directory.
public enum ChromiumBookmarks {
  /// Roots in the order Chromium writes them. The previous build iterated
  /// `Object.values(roots)`, i.e. file order; JSONSerialization loses key
  /// order, so the known roots come first and any others follow sorted.
  /// Bookmark ids include the position in this list, so the order matters.
  static let knownRootOrder = ["bookmark_bar", "other", "synced"]

  public static func parse(_ data: Data) throws -> [Bookmark] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw BookmarkParseError.notAnObject
    }
    let roots = object["roots"] as? [String: Any] ?? [:]
    let unknownRoots = roots.keys.filter { !knownRootOrder.contains($0) }.sorted()

    var bookmarks: [Bookmark] = []
    for key in knownRootOrder + unknownRoots {
      guard let root = roots[key] as? [String: Any], let children = root["children"] as? [Any] else { continue }
      traverse(children, folder: nil, into: &bookmarks)
    }
    return bookmarks
  }

  /// Port of `traverse`: folders pass their own name down to their direct
  /// children; url nodes with a non-empty url become bookmarks. The root
  /// nodes themselves are not folders, so top-level bookmarks have no folder.
  private static func traverse(_ nodes: [Any], folder: String?, into bookmarks: inout [Bookmark]) {
    for case let node as [String: Any] in nodes {
      switch node["type"] as? String {
      case "folder":
        traverse(node["children"] as? [Any] ?? [], folder: node["name"] as? String, into: &bookmarks)
      case "url":
        guard let url = node["url"] as? String, !url.isEmpty else { continue }
        bookmarks.append(Bookmark(title: node["name"] as? String ?? "", url: url, folder: folder))
      default:
        continue
      }
    }
  }
}
