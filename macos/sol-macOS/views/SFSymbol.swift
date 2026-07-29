import Cocoa

class SFSymbol: NSView {
  private let imageView = NSImageView()

  @objc var name: NSString = "" {
    didSet { updateImage() }
  }

  /// Point size of the symbol. Defaults to 16.
  @objc var size: NSNumber = 16 {
    didSet { updateImage() }
  }

  /// One of: ultraLight, thin, light, regular, medium, semibold, bold, heavy, black.
  @objc var weight: NSString = "regular" {
    didSet { updateImage() }
  }

  /// Hex colour (#RRGGBB or #RRGGBBAA). Falls back to labelColor, which
  /// follows the system light/dark appearance.
  @objc var color: NSString = "" {
    didSet { updateTint() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.autoresizingMask = [.width, .height]
    imageView.frame = bounds
    addSubview(imageView)
    updateTint()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  private func symbolWeight() -> NSFont.Weight {
    switch (weight as String).lowercased() {
    case "ultralight": return .ultraLight
    case "thin": return .thin
    case "light": return .light
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    case "heavy": return .heavy
    case "black": return .black
    default: return .regular
    }
  }

  private func updateImage() {
    let symbolName = name as String

    guard !symbolName.isEmpty else {
      imageView.image = nil
      return
    }

    // Unknown symbol names return nil rather than throwing, so an outdated or
    // misspelled name renders empty instead of crashing.
    guard
      let image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: symbolName
      )
    else {
      imageView.image = nil
      return
    }

    let configuration = NSImage.SymbolConfiguration(
      pointSize: CGFloat(size.doubleValue),
      weight: symbolWeight()
    )

    image.isTemplate = true
    imageView.image = image.withSymbolConfiguration(configuration) ?? image
  }

  private func updateTint() {
    let hex = color as String
    if hex.isEmpty {
      imageView.contentTintColor = .labelColor
    } else {
      imageView.contentTintColor = NSColor(hex: color) ?? .labelColor
    }
  }
}

@objc(SFSymbolManager)
class SFSymbolManager: RCTViewManager {

  override static func requiresMainQueueSetup() -> Bool {
    return true
  }

  override func view() -> NSView! {
    return SFSymbol()
  }

}
