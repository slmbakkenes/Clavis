import AppKit

/// Moves and resizes the frontmost window of the frontmost app through the
/// Accessibility API. Ported from the previous build's WindowManager.
@MainActor
final class WindowManager {
  static let shared = WindowManager()

  enum Half { case top, bottom, left, right }
  enum Quarter { case topLeft, topRight, bottomLeft, bottomRight }
  enum Third { case left, center, right }
  enum TwoThirds { case left, right }
  enum SpaceDirection { case previous, next }

  /// The last layout applied per window, so repeating left/right half cycles
  /// through half, third and two-thirds.
  private enum LastAction {
    case leftHalf, leftThird, leftTwoThirds
    case rightHalf, rightThird, rightTwoThirds
    case top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
    case fullScreen, center
  }

  private let screenDetector = ScreenDetector()
  private var lastActions: [Int: LastAction] = [:]

  private init() {}

  /// The frontmost window with its id and the screen it is on, or nil after
  /// a beep when there is no window or no usable screen (as before).
  private struct Target {
    let window: AccessibilityElement
    let identifier: Int
    let screens: UsableScreens
    /// The current screen's frame in Accessibility (top-left) coordinates.
    let screenFrame: CGRect
  }

  private func target() throws -> Target? {
    try requireAccessibility()
    guard let window = AccessibilityElement.frontmostWindow() else {
      NSSound.beep()
      return nil
    }
    guard let screens = screenDetector.detectScreens(using: window) else {
      NSSound.beep()
      NSLog("Unable to obtain usable screens")
      return nil
    }
    guard let identifier = window.getIdentifier() else { return nil }
    return Target(
      window: window, identifier: identifier, screens: screens,
      screenFrame: AccessibilityElement.normalizeCoordinatesOf(screens.frameOfCurrentScreen))
  }

  /// Without Accessibility access every AX call fails silently, which used
  /// to look like the shortcut did nothing.
  private func requireAccessibility() throws {
    guard Permissions.isAccessibilityTrusted else {
      throw UserFacingError("Radix needs Accessibility access to manage windows")
    }
  }

  // MARK: Layouts

  func moveHalf(_ half: Half) throws {
    guard let target = try target() else { return }
    let frame = target.screenFrame
    let id = target.identifier
    var origin = CGPoint(x: frame.origin.x + frame.width / 2, y: frame.origin.y)
    var size = CGSize(width: frame.width / 2, height: frame.height)

    switch half {
    case .top:
      origin = CGPoint(x: frame.origin.x, y: frame.origin.y)
      size = CGSize(width: frame.width, height: frame.height / 2)
      lastActions[id] = .top

    case .bottom:
      origin = CGPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height / 2)
      size = CGSize(width: frame.width, height: frame.height / 2)
      lastActions[id] = .bottom

    case .right:
      let screenHalf = frame.width / 2
      let screenThird = frame.width / 3
      let screenTwoThirds = screenThird * 2

      var targetWidth = screenHalf
      var targetX = frame.origin.x + screenHalf

      switch lastActions[id] {
      case .rightHalf:
        targetWidth = screenThird
        targetX = frame.origin.x + screenTwoThirds
        lastActions[id] = .rightThird
      case .rightThird:
        targetWidth = screenTwoThirds
        targetX = frame.origin.x + screenThird
        lastActions[id] = .rightTwoThirds
      default:
        lastActions[id] = .rightHalf
      }

      origin = CGPoint(x: targetX, y: frame.origin.y)
      size = CGSize(width: targetWidth, height: frame.height)

    case .left:
      let screenThird = frame.width / 3
      var targetWidth = frame.width / 2

      switch lastActions[id] {
      case .leftHalf:
        targetWidth = screenThird
        lastActions[id] = .leftThird
      case .leftThird:
        targetWidth = screenThird * 2
        lastActions[id] = .leftTwoThirds
      default:
        lastActions[id] = .leftHalf
      }

      origin = CGPoint(x: frame.origin.x, y: frame.origin.y)
      size = CGSize(width: targetWidth, height: frame.height)
    }

    target.window.setRectOf(CGRect(origin: origin, size: size))
  }

  func moveQuarter(_ corner: Quarter) throws {
    guard let target = try target() else { return }
    let frame = target.screenFrame
    let origin: CGPoint

    switch corner {
    case .bottomLeft:
      origin = CGPoint(x: frame.origin.x, y: frame.origin.y + frame.height / 2)
      lastActions[target.identifier] = .bottomLeft
    case .bottomRight:
      origin = CGPoint(x: frame.origin.x + frame.width / 2, y: frame.origin.y + frame.height / 2)
      lastActions[target.identifier] = .bottomRight
    case .topLeft:
      origin = CGPoint(x: frame.origin.x, y: frame.origin.y)
      lastActions[target.identifier] = .topLeft
    case .topRight:
      origin = CGPoint(x: frame.origin.x + frame.width / 2, y: frame.origin.y)
      lastActions[target.identifier] = .topRight
    }

    let size = CGSize(width: frame.width / 2, height: frame.height / 2)
    target.window.setRectOf(CGRect(origin: origin, size: size))
  }

  func moveThird(_ third: Third) throws {
    guard let target = try target() else { return }
    let frame = target.screenFrame
    let origin: CGPoint

    switch third {
    case .left:
      origin = CGPoint(x: frame.origin.x, y: frame.origin.y)
      lastActions[target.identifier] = .leftThird
    case .center:
      origin = CGPoint(x: frame.origin.x + frame.width / 3, y: frame.origin.y)
      lastActions[target.identifier] = .center
    case .right:
      origin = CGPoint(x: frame.origin.x + (frame.width / 3) * 2, y: frame.origin.y)
      lastActions[target.identifier] = .rightThird
    }

    let size = CGSize(width: frame.width / 3, height: frame.height)
    target.window.setRectOf(CGRect(origin: origin, size: size))
  }

  func moveTwoThirds(_ twoThirds: TwoThirds) throws {
    guard let target = try target() else { return }
    let frame = target.screenFrame
    let origin: CGPoint

    switch twoThirds {
    case .left:
      origin = CGPoint(x: frame.origin.x, y: frame.origin.y)
      lastActions[target.identifier] = .leftTwoThirds
    case .right:
      origin = CGPoint(x: frame.origin.x + frame.width / 3, y: frame.origin.y)
      lastActions[target.identifier] = .rightTwoThirds
    }

    let size = CGSize(width: frame.width / 3 * 2, height: frame.height)
    target.window.setRectOf(CGRect(origin: origin, size: size))
  }

  func fullscreen() throws {
    guard let target = try target() else { return }
    lastActions[target.identifier] = .fullScreen
    target.window.setRectOf(target.screenFrame)
  }

  /// Fills the next screen (as ordered by the screen detector).
  func moveToNextScreen() throws {
    try moveToAdjacentScreen { $0.next }
  }

  func moveToPreviousScreen() throws {
    try moveToAdjacentScreen { $0.prev }
  }

  private func moveToAdjacentScreen(_ pick: (AdjacentScreens) -> NSScreen) throws {
    guard let target = try target() else { return }
    guard let adjacent = target.screens.adjacentScreens else {
      NSSound.beep()
      return
    }
    let frame = AccessibilityElement.normalizeCoordinatesOf(pick(adjacent).frame)
    lastActions[target.identifier] = nil
    target.window.setRectOf(frame)
  }

  /// Centers the window on its screen without resizing it.
  func center() throws {
    guard let target = try target() else { return }
    let frame = target.screenFrame
    let windowRect = target.window.rectOfElement()
    let origin = CGPoint(
      x: frame.origin.x + (frame.width - windowRect.width) / 2,
      y: frame.origin.y + (frame.height - windowRect.height) / 2)
    target.window.setRectOf(CGRect(origin: origin, size: windowRect.size))
    lastActions[target.identifier] = .center
  }

  // MARK: Spaces

  /// There is no public API to move a window between Spaces, so this holds
  /// the window by its title bar with a synthetic mouse-down, switches Space
  /// with ⌃← / ⌃→, and releases. The mouse is released and put back even
  /// when the switch fails.
  func moveToSpace(_ direction: SpaceDirection) async throws {
    try requireAccessibility()
    PanelManager.shared.hideWindow()
    guard let window = AccessibilityElement.frontmostWindow() else {
      NSSound.beep()
      return
    }

    let originalMouseLocation = CGEvent(source: nil)?.location
    let windowFrame = window.rectOfElement()
    let titleBarPosition = CGPoint(x: windowFrame.origin.x + windowFrame.width / 2, y: windowFrame.origin.y + 5)

    CGEvent(
      mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: titleBarPosition, mouseButton: .left
    )?.post(tap: .cghidEventTap)

    defer {
      CGEvent(
        mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: titleBarPosition, mouseButton: .left
      )?.post(tap: .cghidEventTap)
      if let originalMouseLocation {
        CGWarpMouseCursorPosition(originalMouseLocation)
      }
    }

    // Give the window server time to register the grab.
    try await Task.sleep(for: .milliseconds(100))

    let arrowKeyCode = direction == .previous ? 123 : 124
    try await AppleScript.run(
      """
      tell application "System Events"
          key code \(arrowKeyCode) using control down
      end tell
      """)

    // Let the Space switch finish before releasing the window.
    try await Task.sleep(for: .milliseconds(300))
  }
}
