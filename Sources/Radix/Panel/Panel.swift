import AppKit

/// The launcher window. Non-activating so the frontmost app keeps focus for
/// window-management actions, but `canBecomeKey` is forced on so the panel
/// still receives keyboard input.
@MainActor
final class Panel: NSPanel, NSWindowDelegate {
  var onResignKey: (() -> Void)?

  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    hasShadow = true
    level = .floating
    collectionBehavior.insert(.fullScreenAuxiliary)
    collectionBehavior.insert(.canJoinAllSpaces)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    isReleasedWhenClosed = false
    isOpaque = false
    delegate = self
    backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.2)

    let effectView = NSVisualEffectView(frame: .zero)
    effectView.autoresizingMask = [.width, .height]
    effectView.material = .headerView
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    effectView.wantsLayer = true
    contentView = effectView
  }

  /// AppKit otherwise clamps the frame to the screen the panel currently sits
  /// on, which blocks moving it to another display.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  func windowDidResignKey(_ notification: Notification) {
    DispatchQueue.main.async { [weak self] in
      self?.onResignKey?()
    }
  }
}
