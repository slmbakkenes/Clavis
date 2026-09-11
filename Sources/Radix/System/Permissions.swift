import AppKit
import ApplicationServices

@MainActor
enum Permissions {
  static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

  /// Shows the system prompt that deep-links to the Accessibility list.
  static func requestAccessibility() {
    // The constant kAXTrustedCheckOptionPrompt is a mutable global, which Swift 6
    // rejects; this is its value.
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  static func openFullDiskAccessSettings() throws {
    try Workspace.open(
      urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
  }
}
