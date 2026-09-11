import AppKit

/// Opening files, folders and URLs, with failures surfaced instead of the
/// `Bool` NSWorkspace returns being ignored.
@MainActor
enum Workspace {
  static func expandingTilde(_ path: String) -> String {
    (path as NSString).expandingTildeInPath
  }

  static func open(path: String) throws {
    let expanded = expandingTilde(path)
    guard FileManager.default.fileExists(atPath: expanded) else {
      throw UserFacingError("\(path) does not exist")
    }
    guard NSWorkspace.shared.open(URL(fileURLWithPath: expanded)) else {
      throw UserFacingError("Could not open \(path)")
    }
  }

  static func open(urlString: String) throws {
    guard let url = URL(string: urlString), url.scheme != nil else {
      throw UserFacingError("Not a valid URL: \(urlString)")
    }
    guard NSWorkspace.shared.open(url) else {
      throw UserFacingError("Could not open \(urlString)")
    }
  }
}
