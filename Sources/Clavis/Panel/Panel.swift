import AppKit
import SwiftUI

/// The launcher window. Non-activating so the frontmost app keeps focus for
/// window-management actions, but `canBecomeKey` is forced on so the panel
/// still receives keyboard input.
@MainActor
final class Panel: NSPanel, NSWindowDelegate {
  var onResignKey: (() -> Void)?

  /// How far the gruvbox wash covers the blur. High enough that the panel
  /// reads as `Theme.background` over a bright desktop, low enough to keep the
  /// depth that makes a floating panel look native.
  private static let tintOpacity: CGFloat = 0.85

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
    backgroundColor = NSColor(Theme.background).withAlphaComponent(0.2)

    let effectView = NSVisualEffectView(frame: .zero)
    effectView.autoresizingMask = [.width, .height]
    // .hudWindow is the material macOS uses for floating panels; .headerView
    // was tuned for a titlebar strip and reads too light behind dark content.
    effectView.material = .hudWindow
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    effectView.wantsLayer = true

    // The material on its own samples the desktop and lands on a neutral grey.
    // A gruvbox wash over it keeps the blur while making the panel the same
    // colour as a terminal window next to it.
    let tint = TintView(color: NSColor(Theme.background).withAlphaComponent(Self.tintOpacity))
    tint.translatesAutoresizingMaskIntoConstraints = false
    effectView.addSubview(tint)
    NSLayoutConstraint.activate([
      tint.topAnchor.constraint(equalTo: effectView.topAnchor),
      tint.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
      tint.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
      tint.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
    ])

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

/// A flat fill whose layer colour follows the view's appearance. A layer only
/// stores a resolved `CGColor`, so the gruvbox wash would otherwise stay in
/// whichever variant was active when the panel was created.
@MainActor
private final class TintView: NSView {
  private let color: NSColor

  init(color: NSColor) {
    self.color = color
    super.init(frame: .zero)
    wantsLayer = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var wantsUpdateLayer: Bool { true }

  /// AppKit calls this with the view's effective appearance current, both on
  /// first display and after every appearance change.
  override func updateLayer() {
    layer?.backgroundColor = color.cgColor
  }
}
