import Foundation

/// A browser bookmark, independent of the browser it came from.
public struct Bookmark: Sendable, Equatable {
  public let title: String
  public let url: String
  /// The name of the folder directly containing the bookmark, if any.
  public let folder: String?

  public init(title: String, url: String, folder: String? = nil) {
    self.title = title
    self.url = url
    self.folder = folder
  }
}

public enum BookmarkParseError: Error, Equatable {
  /// The top level of the file is not a dictionary.
  case notAnObject
}
