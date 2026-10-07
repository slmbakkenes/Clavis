import AppKit
import SwiftUI

/// Transparent view on top of the output that swallows clicks, so a click on
/// the toast can be routed to a handler without the text view eating it.
@MainActor
final class ClickableOverlayView: NSView {
  var onClick: (() -> Void)?

  override func mouseDown(with event: NSEvent) {
    onClick?()
  }
}

/// Scrolling monospaced output for user scripts, shown inside a `Toast`.
@MainActor
final class ShellOutputView: NSView {
  private var gradientLayer: CAGradientLayer?
  private let textView = NSTextView()
  private let scrollView = NSScrollView()

  init() {
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
    gradient.colors = [NSColor.clear.cgColor, NSColor.clear.cgColor]
    gradient.startPoint = CGPoint(x: 0.5, y: 0)
    gradient.endPoint = CGPoint(x: 0.5, y: 1)
    gradient.frame = bounds
    layer?.addSublayer(gradient)
    gradientLayer = gradient

    textView.isEditable = false
    textView.isSelectable = false
    textView.drawsBackground = false
    textView.textColor = NSColor(Theme.text)
    textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.autoresizingMask = [.width]

    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autoresizingMask = [.width, .height]
    scrollView.frame = bounds
    scrollView.backgroundColor = .clear
    scrollView.drawsBackground = false
    scrollView.contentView.backgroundColor = .clear
    scrollView.contentView.drawsBackground = false
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInsets = NSEdgeInsets()
    addSubview(scrollView)

    let overlay = ClickableOverlayView(frame: bounds)
    overlay.autoresizingMask = [.width, .height]
    overlay.wantsLayer = true
    overlay.layer?.backgroundColor = NSColor.clear.cgColor
    addSubview(overlay)
  }

  func setSuccessStyle() {
    setGradient(NSColor(Theme.success))
  }

  func setFailedStyle() {
    setGradient(NSColor(Theme.danger))
  }

  /// Layers take a resolved CGColor, so resolve against the app's gruvbox
  /// variant rather than whatever drawing appearance happens to be current.
  private func setGradient(_ color: NSColor) {
    NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
      gradientLayer?.colors = [
        color.withAlphaComponent(0.15).cgColor,
        color.withAlphaComponent(0.02).cgColor,
      ]
    }
  }

  func appendOutput(_ text: String) {
    textView.string += text
    textView.scrollToEndOfDocument(nil)
  }

  override func layout() {
    super.layout()
    gradientLayer?.frame = bounds
    scrollView.frame = bounds
  }
}
