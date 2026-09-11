import Foundation

/// Parses Safari's `~/Library/Safari/Bookmarks.plist` (readable only with
/// Full Disk Access).
public enum SafariBookmarks {
  public static func parse(_ data: Data) throws -> [Bookmark] {
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let root = plist as? [String: Any] else {
      throw BookmarkParseError.notAnObject
    }
    return extract(root)
  }

  /// Port of `BookmarkHelper.extractBookmarksFrom`: a node with `Children`
  /// is walked (this includes the Reading List, as before); otherwise a node
  /// with `URLString` is a bookmark titled by `URIDictionary.title`. Folder
  /// names are not recorded, matching the previous build. Leaves without a
  /// title are skipped; the previous build force-unwrapped and crashed.
  private static func extract(_ node: [String: Any]) -> [Bookmark] {
    if let children = node["Children"] as? [Any] {
      return children.compactMap { $0 as? [String: Any] }.flatMap(extract)
    }
    guard let url = node["URLString"] as? String else { return [] }
    guard let title = (node["URIDictionary"] as? [String: Any])?["title"] as? String else { return [] }
    return [Bookmark(title: title, url: url)]
  }
}
