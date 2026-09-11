import AppKit

/// Change counts of pasteboard writes Radix made to re-paste an entry, so the
/// clipboard monitor doesn't record them as new copies.
@MainActor
enum PasteboardWrites {
  static var lastRadixChangeCount: Int?
}

/// Puts content on the pasteboard and sends ⌘V to the frontmost app.
@MainActor
enum Paste {
  static func text(_ content: String) throws {
    try requireAccessibility()
    PanelManager.shared.hideWindow()
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(content, forType: .string)
    PasteboardWrites.lastRadixChangeCount = pasteboard.changeCount
    postCommandV()
  }

  /// Pastes an image file as image data (png, jpg/jpeg, tif/tiff).
  static func image(atPath path: String) throws {
    try requireAccessibility()
    let url = URL(fileURLWithPath: path)
    let type: NSPasteboard.PasteboardType
    switch url.pathExtension.lowercased() {
    case "png": type = .png
    case "jpg", "jpeg": type = NSPasteboard.PasteboardType("public.jpeg")
    case "tif", "tiff": type = .tiff
    default:
      throw UserFacingError("Unsupported image type: \(url.lastPathComponent)")
    }
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw UserFacingError("Could not read image \(url.lastPathComponent): \(error.localizedDescription)")
    }
    PanelManager.shared.hideWindow()
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.declareTypes([type], owner: nil)
    pasteboard.setData(data, forType: type)
    PasteboardWrites.lastRadixChangeCount = pasteboard.changeCount
    postCommandV()
  }

  /// Posting synthetic key events silently does nothing without
  /// Accessibility access, so fail loudly instead.
  private static func requireAccessibility() throws {
    guard Permissions.isAccessibilityTrusted else {
      throw UserFacingError("Radix needs Accessibility access to paste")
    }
  }

  private static func postCommandV() {
    let vKey: CGKeyCode = 0x09
    let down = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true)
    down?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false)
    up?.post(tap: .cghidEventTap)
  }
}
