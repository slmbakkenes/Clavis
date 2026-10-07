import AppKit
import SwiftUI

/// Non-activating panel that hosts a `ToastView` or `ShellOutputView`.
@MainActor
final class Toast: NSPanel {
  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    level = .floating
    collectionBehavior.insert(.fullScreenAuxiliary)
    collectionBehavior.insert(.canJoinAllSpaces)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovable = false
    isMovableByWindowBackground = false
    isReleasedWhenClosed = false
    isOpaque = false
    setFrameAutosaveName("")
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

enum ToastVariant: String, Sendable {
  case success
  case error
  case none

  /// Lenient parse of the string the old JS API passed ("error", "success",
  /// anything else -> none).
  init(string: String) {
    self = ToastVariant(rawValue: string) ?? .none
  }

  var gradientColors: [NSColor] {
    switch self {
    case .success: return [NSColor(Theme.success).withAlphaComponent(0.2), .clear]
    case .error: return [NSColor(Theme.danger).withAlphaComponent(0.2), .clear]
    case .none: return [.clear, .clear]
    }
  }

  var dotColor: NSColor {
    switch self {
    case .success: return NSColor(Theme.success)
    case .error: return NSColor(Theme.danger)
    case .none: return .clear
    }
  }
}

@MainActor
final class ToastView: NSView {
  let text: String
  let variant: ToastVariant
  let image: NSImage?
  var dismissCallback: (() -> Void)?

  private var textLabel: NSTextField!
  private var imageView: NSImageView?
  private var gradientLayer: CAGradientLayer?
  private var dotView: NSView?

  init(text: String, variant: ToastVariant, image: NSImage? = nil, dismissCallback: (() -> Void)? = nil) {
    self.text = text
    self.variant = variant
    self.image = image
    self.dismissCallback = dismissCallback
    super.init(frame: .zero)

    wantsLayer = true
    setupView()
    needsLayout = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupView() {
    let gradient = CAGradientLayer()
    // Layers take a resolved CGColor; resolve against the app's gruvbox
    // variant rather than whatever drawing appearance happens to be current.
    NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
      gradient.colors = variant.gradientColors.map { $0.cgColor }
    }
    gradient.startPoint = CGPoint(x: 0, y: 0.5)
    gradient.endPoint = CGPoint(x: 1, y: 0.5)
    gradient.frame = bounds
    layer?.addSublayer(gradient)
    gradientLayer = gradient

    let dot = NSView()
    dot.wantsLayer = true
    dot.layer?.cornerRadius = 5
    NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
      dot.layer?.backgroundColor = variant.dotColor.cgColor
    }
    dot.frame = NSRect(x: 10, y: 20, width: 10, height: 10)
    addSubview(dot)
    dotView = dot

    if let image {
      let view = NSImageView(image: image)
      view.frame = NSRect(x: 0, y: 0, width: 380, height: 380)
      addSubview(view)
      imageView = view
    }

    textLabel = NSTextField(labelWithString: text)
    textLabel.textColor = NSColor(Theme.text)
    textLabel.alignment = .center
    textLabel.lineBreakMode = .byWordWrapping
    textLabel.isEditable = false
    textLabel.isSelectable = false
    addSubview(textLabel)
  }

  override func mouseDown(with event: NSEvent) {
    dismissCallback?()
  }

  override var intrinsicContentSize: NSSize {
    let minWidth: CGFloat = 120
    let padding: CGFloat = 10

    if image != nil {
      return NSSize(width: 400, height: 400)
    }

    let textSize = textLabel.intrinsicContentSize
    return NSSize(
      width: max(minWidth, textSize.width + padding * 2 + 20),
      height: textSize.height + padding * 2)
  }

  override func layout() {
    super.layout()

    gradientLayer?.frame = bounds

    textLabel.frame = NSRect(
      x: 10, y: 10, width: intrinsicContentSize.width, height: textLabel.intrinsicContentSize.height)

    if let dotView {
      dotView.frame.origin = NSPoint(x: 10, y: (bounds.height - dotView.frame.height) / 2)
    }

    if let imageView {
      imageView.frame.origin = NSPoint(x: 10, y: (bounds.height - imageView.frame.height) / 2)
    }
  }

  override func viewDidMoveToSuperview() {
    super.viewDidMoveToSuperview()
    needsLayout = true
  }
}
