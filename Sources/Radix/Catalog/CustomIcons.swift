import AppKit

/// Icons for custom items (Quick Links). The previous build shipped 114 PNG
/// glyphs; this build uses SF Symbols so the bundle carries no image assets.
/// Items saved by the old build keep their PNG name in `icon`, which is
/// mapped to the closest symbol here.
enum CustomIcons {
  static let fallbackSymbol = "star.fill"
  static let defaultSymbol = "apple.logo"

  /// Swatches offered when creating a custom item, in gruvbox.
  static let colorPalette = [
    "#ebdbb2", "#83a598", "#8ec07c", "#b8bb26", "#fabd2f", "#fb4934", "#d3869b",
    "#458588", "#689d6a", "#98971a", "#d79921", "#cc241d", "#b16286", "#928374",
  ]

  /// Symbols offered in the picker, in display order.
  static let pickerSymbols = [
    "apple.logo", "star.fill", "heart.fill", "bolt.fill", "flame.fill", "sparkles",
    "house.fill", "building.columns.fill", "briefcase.fill", "folder.fill", "doc.fill", "doc.text.fill",
    "book.fill", "bookmark.fill", "tag.fill", "tray.fill", "envelope.fill", "paperplane.fill",
    "bell.fill", "megaphone.fill", "link", "globe", "network", "wifi",
    "magnifyingglass", "lock.fill", "key.fill", "shield.fill", "terminal.fill",
    "chevron.left.forwardslash.chevron.right", "server.rack", "cylinder.split.1x2.fill", "cpu",
    "desktopcomputer", "iphone", "ipad", "applewatch", "keyboard", "printer.fill",
    "gamecontroller.fill", "headphones", "music.note", "video.fill", "film.fill", "camera.fill",
    "photo.fill", "mic.fill", "chart.bar.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis",
    "gauge.with.dots.needle.67percent", "calendar", "clock.fill", "hourglass", "gearshape.2.fill",
    "hammer.fill", "wrench.and.screwdriver.fill", "pencil.and.ruler.fill", "paintbrush.fill",
    "cart.fill", "bag.fill", "basket.fill", "creditcard.fill", "dollarsign.circle.fill",
    "eurosign.circle.fill", "bitcoinsign.circle.fill", "gift.fill", "graduationcap.fill",
    "person.2.fill", "person.3.fill", "bubble.left.and.bubble.right.fill", "phone.fill",
    "airplane", "car.fill", "bicycle", "ferry.fill", "map.fill", "pin.fill", "signpost.right.fill",
    "sun.max.fill", "cloud.fill", "umbrella.fill", "leaf.fill", "tree.fill", "mountain.2.fill",
    "pawprint.fill", "ladybug.fill", "cup.and.saucer.fill", "fork.knife", "lightbulb.fill",
    "puzzlepiece.fill", "flag.fill", "ticket.fill", "trash.fill", "face.smiling",
  ]

  /// Old PNG icon names (src/assets/customIcons) with a clear SF Symbol
  /// counterpart. Names without one (Android, Anchor, Bucket, Dna, Ethereum,
  /// Feather, Github, Gitlab, Robot, Rocket, Skull) fall back to a star.
  private static let legacyNames: [String: String] = [
    "Africa": "globe.europe.africa.fill",
    "Airplane": "airplane",
    "Alert": "exclamationmark.triangle.fill",
    "Apple": "apple.logo",
    "Asia": "globe.asia.australia.fill",
    "Australia": "globe.asia.australia.fill",
    "Bank": "building.columns.fill",
    "BarChart": "chart.bar.fill",
    "Basket": "basket.fill",
    "Battery": "battery.100percent",
    "Bike": "bicycle",
    "Bitcoin": "bitcoinsign.circle.fill",
    "Bolt": "bolt.fill",
    "Book": "book.fill",
    "Bookmark": "bookmark.fill",
    "Briefcase": "briefcase.fill",
    "Brush": "paintbrush.fill",
    "Bug": "ladybug.fill",
    "Calendar": "calendar",
    "Camera": "camera.fill",
    "Car": "car.fill",
    "Cart": "cart.fill",
    "Chart": "chart.line.uptrend.xyaxis",
    "Chat": "bubble.left.and.bubble.right.fill",
    "Chip": "cpu",
    "Clock": "clock.fill",
    "Cloud": "cloud.fill",
    "Compass": "safari.fill",
    "Computer": "desktopcomputer",
    "Cone": "cone.fill",
    "CreditCard": "creditcard.fill",
    "Cross": "cross.fill",
    "Crown": "crown.fill",
    "Cube": "cube.fill",
    "Dashboard": "gauge.with.dots.needle.67percent",
    "Database": "cylinder.split.1x2.fill",
    "DesignTools": "pencil.and.ruler.fill",
    "Dollar": "dollarsign.circle.fill",
    "Education": "graduationcap.fill",
    "Euro": "eurosign.circle.fill",
    "Europe": "globe.europe.africa.fill",
    "Face": "face.smiling",
    "FaceFlatSmile": "face.smiling",
    "FaceHeartEyes": "face.smiling",
    "FaceMask": "facemask.fill",
    "FaceMonocle": "eyeglasses",
    "FaceStarEyes": "face.smiling",
    "FaceSunglasses": "sunglasses.fill",
    "FaceSurprise": "face.smiling",
    "FaceTired": "face.dashed",
    "FaceTongue": "face.smiling",
    "Favorite": "star.fill",
    "Fire": "flame.fill",
    "Flower": "camera.macro",
    "Folder": "folder.fill",
    "Gears": "gearshape.2.fill",
    "Heart": "heart.fill",
    "Home": "house.fill",
    "Image": "photo.fill",
    "Inbox": "tray.fill",
    "Joystick": "gamecontroller.fill",
    "Label": "tag.fill",
    "Leaf": "leaf.fill",
    "LightBulb": "lightbulb.fill",
    "Link": "link",
    "Lock": "lock.fill",
    "Megaphone": "megaphone.fill",
    "MobilePhone": "iphone",
    "Mountain": "mountain.2.fill",
    "NorthAmerica": "globe.americas.fill",
    "Page": "doc.fill",
    "Phone": "phone.fill",
    "PieChart": "chart.pie.fill",
    "Pin": "pin.fill",
    "Present": "gift.fill",
    "Project": "list.bullet.clipboard.fill",
    "Radar": "dot.radiowaves.left.and.right",
    "Recycle": "arrow.3.trianglepath",
    "Search": "magnifyingglass",
    "Send": "paperplane.fill",
    "Server": "server.rack",
    "Shield": "shield.fill",
    "Ship": "ferry.fill",
    "Shop": "storefront.fill",
    "Sign": "signpost.right.fill",
    "Sound": "speaker.wave.2.fill",
    "SouthAmerica": "globe.americas.fill",
    "Subscribe": "bell.fill",
    "Sun": "sun.max.fill",
    "Tablet": "ipad",
    "Team": "person.3.fill",
    "TeeShirt": "tshirt.fill",
    "Terminal": "terminal.fill",
    "ThumbsDown": "hand.thumbsdown.fill",
    "ThumbsUp": "hand.thumbsup.fill",
    "Trash": "trash.fill",
    "Tree": "tree.fill",
    "Umbrella": "umbrella.fill",
    "UnhappyFace": "face.dashed",
    "Users": "person.2.fill",
    "Video": "video.fill",
    "Watch": "applewatch",
    "World": "globe",
  ]

  static var legacyMappedSymbols: [String] { Array(Set(legacyNames.values)) }

  /// The symbol to draw for a stored `icon`: an old PNG name, an SF Symbol
  /// name saved by this build, or anything else (the fallback).
  @MainActor static func symbolName(for icon: String) -> String {
    if let mapped = legacyNames[icon] { return mapped }
    if let known = resolved[icon] { return known }
    // Search rows call this on every keystroke; the symbol lookup is cached.
    let symbol =
      !icon.isEmpty && NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil ? icon : fallbackSymbol
    resolved[icon] = symbol
    return symbol
  }

  @MainActor private static var resolved: [String: String] = [:]
}
