import AppKit
import SwiftUI

enum PreferredScreen {
  case frontmost
  case withMouse
}

@MainActor
final class PanelManager {
  static let shared = PanelManager()

  static let baseSize = NSSize(width: 700, height: 450)
  var preferredScreen: PreferredScreen = .withMouse
  var onShow: ((ShowTarget) -> Void)?
  var onHide: (() -> Void)?

  private let panel = Panel(contentRect: .zero)
  private var hostingView: NSHostingView<RootView>?
  private let screenDetector = ScreenDetector()
  /// Screen the panel was last shown on, kept so that resizes triggered after
  /// the panel is up don't drag it back to another display.
  private var targetScreen: NSScreen?

  private init() {
    panel.setContentSize(Self.baseSize)
    panel.onResignKey = { [weak self] in self?.hideWindow() }
  }

  /// Installs the SwiftUI content. Called once from the app delegate after
  /// the model exists.
  func setRootView(_ view: RootView) {
    hostingView?.removeFromSuperview()
    let hosting = NSHostingView(rootView: view)
    hosting.autoresizingMask = [.width, .height]
    hosting.frame = NSRect(origin: .zero, size: panel.contentView!.bounds.size)
    panel.contentView!.addSubview(hosting)
    hostingView = hosting
  }

  var isVisible: Bool { panel.isVisible }

  func owns(_ window: NSWindow?) -> Bool {
    window === panel
  }

  func showWindow(target: ShowTarget = .default) {
    guard let screen = resolveScreen() else { return }
    targetScreen = screen
    panel.setFrame(frameFor(screen: screen, size: panel.frame.size), display: false)
    panel.setIsVisible(true)
    panel.makeKeyAndOrderFront(nil)
    onShow?(target)
  }

  func hideWindow() {
    guard panel.isVisible else { return }
    panel.setIsVisible(false)
    targetScreen = nil
    onHide?()
  }

  func toggle() {
    if panel.isVisible { hideWindow() } else { showWindow() }
  }

  func resetSize() {
    guard let screen = getPreferredScreen() else { return }
    panel.setFrame(frameFor(screen: screen, size: Self.baseSize), display: false)
  }

  func setHeight(_ height: CGFloat) {
    let finalHeight = height == 0 ? Self.baseSize.height : height
    let size = NSSize(width: Self.baseSize.width, height: finalHeight)
    guard let screen = getPreferredScreen() else { return }

    // Preserve a horizontal drag by the user, but only while the panel is
    // still on the screen we're positioning against.
    var frame = frameFor(screen: screen, size: size)
    if screen.frame.intersects(panel.frame) {
      frame.origin.x = panel.frame.minX
    }
    panel.setFrame(frame, display: true)
    hostingView?.setFrameSize(size)
    hostingView?.setFrameOrigin(.zero)
  }

  func setRelativeSize(_ proportion: CGFloat) {
    guard let screen = getPreferredScreen() else { return }
    let screenSize = screen.frame.size
    let size = CGSize(width: screenSize.width * proportion, height: screenSize.height * proportion)
    panel.setFrame(frameFor(screen: screen, size: size), display: false)
  }

  /// The screen the panel is on, or would appear on. Toasts use it too.
  func getPreferredScreen() -> NSScreen? {
    targetScreen ?? resolveScreen()
  }

  private func resolveScreen() -> NSScreen? {
    switch preferredScreen {
    case .withMouse: return screenWithMouse() ?? frontmostScreen()
    case .frontmost: return frontmostScreen()
    }
  }

  private func frontmostScreen() -> NSScreen? {
    let screens = NSScreen.screens
    if screens.count <= 1 { return screens.first }

    // While the panel is up it is the frontmost window, so asking the
    // accessibility API would just point back at ourselves.
    if panel.isVisible, NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid() {
      return panel.screen ?? NSScreen.main
    }

    if let frontmostWindow = AccessibilityElement.frontmostWindow() {
      let rect = frontmostWindow.rectOfElement()
      if !rect.isEmpty, let screen = screenDetector.screenContaining(rect, screens: screens) {
        return screen
      }
    }

    // No accessibility permission or no window to go by.
    return NSScreen.main ?? screenWithMouse() ?? screens.first
  }

  /// Panel frame for `size`, horizontally centered and slightly above the
  /// vertical center of `screen`.
  private func frameFor(screen: NSScreen, size: NSSize) -> NSRect {
    let yOffset = screen.visibleFrame.height * 0.3
    let x = screen.visibleFrame.midX - size.width / 2
    let y = screen.visibleFrame.midY - size.height + yOffset
    return NSRect(x: floor(x), y: floor(y), width: size.width, height: size.height)
  }
}
