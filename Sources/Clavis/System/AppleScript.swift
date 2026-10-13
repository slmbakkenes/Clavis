import Foundation

/// Runs AppleScript source in-process on a serial background queue, as the
/// previous build did. Scripts such as `tell Finder to empty trash` block
/// until the target app replies, which on the main thread would freeze the
/// panel and the global hotkeys.
enum AppleScript {
  private static let queue = DispatchQueue(label: "clavis.applescript", qos: .userInitiated)

  /// Returns the script result as a string, when it has one.
  @discardableResult
  static func run(_ source: String) async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
      queue.async {
        guard let script = NSAppleScript(source: source) else {
          continuation.resume(throwing: UserFacingError("Invalid AppleScript"))
          return
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
          let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
          continuation.resume(throwing: UserFacingError(message))
        } else {
          continuation.resume(returning: result.stringValue)
        }
      }
    }
  }
}
