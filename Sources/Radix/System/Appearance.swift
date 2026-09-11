import Foundation

/// System light/dark appearance, via System Events as the previous build did.
enum Appearance {
  private static let prefix = #"tell application "System Events" to tell appearance preferences to"#

  static func toggleDarkMode() async throws {
    try await AppleScript.run("\(prefix) set dark mode to not dark mode")
  }
}
