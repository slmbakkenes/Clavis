import SwiftUI

/// Gruvbox, the palette this machine's terminal and editor already use, in
/// its dark and light variants.
///
/// Dark values are taken from Ghostty's shipped "Gruvbox Dark" theme file, so
/// a Clavis row and a terminal line on the same screen are literally the same
/// colour. Light values are the matching shades from the gruvbox light
/// palette: the same names, with the background and foreground ramps swapped
/// and the darker "faded" accents that stay readable on cream.
///
/// Every colour resolves against the appearance it is drawn in. `AppDelegate`
/// sets `NSApp.appearance` from `Config.appearance`, so switching between
/// `.darkAqua` and `.aqua` retints SwiftUI, the vibrancy material and AppKit
/// controls together.
///
/// AppKit call sites wrap these with `NSColor(...)` rather than duplicating the
/// palette in a second form. Layer colours (`cgColor`) are a snapshot, so a
/// layer that outlives an appearance change has to re-resolve them, as
/// `Panel`'s tint does.
enum Theme {

  // MARK: - Palette
  //
  // Only the shades the roles below actually use. The custom-item swatches in
  // `CustomIcons` carry their own hex strings because config stores them as
  // text.

  static let bg0Hard = shade(dark: 0x1D2021, light: 0xF9F5D7)
  static let bg0 = shade(dark: 0x282828, light: 0xFBF1C7)
  static let bg1 = shade(dark: 0x3C3836, light: 0xEBDBB2)
  static let bg3 = shade(dark: 0x665C54, light: 0xBDAE93)
  static let bg4 = shade(dark: 0x7C6F64, light: 0xA89984)
  static let gray = shade(dark: 0x928374, light: 0x928374)
  static let fg1 = shade(dark: 0xEBDBB2, light: 0x3C3836)
  static let fg0 = shade(dark: 0xFBF1C7, light: 0x282828)

  /// The bright accents in dark, the faded ones in light.
  static let red = shade(dark: 0xFB4934, light: 0x9D0006)
  static let green = shade(dark: 0xB8BB26, light: 0x79740E)
  static let blue = shade(dark: 0x83A598, light: 0x076678)

  // MARK: - Roles

  /// The panel's own colour. Applied as a tint over the window's vibrancy, so
  /// it is never painted fully opaque.
  static let background = bg0
  /// Footers, icon tiles and cards that need to lift off `background`.
  static let elevated = bg1
  /// Selected row fill. Ghostty uses the dark value for its text selection.
  static let selection = bg3
  static let separator = bg1

  static let text = fg1
  /// Text drawn on top of `selection`, which needs to out-contrast `text`.
  static let textOnSelection = fg0
  static let textMuted = gray
  static let textSubtle = bg4

  /// Small active states: key caps, focus rings, toggles.
  static let accent = blue
  static let success = green
  static let danger = red

  /// Dimming behind a modal overlay.
  static let scrim = bg0Hard.opacity(0.6)

  /// A colour that picks its value from the appearance it is resolved in.
  private static func shade(dark: UInt32, light: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
      })
  }
}

extension NSColor {
  /// `0xRRGGBB`, opaque. The palette above is written in the same notation the
  /// Ghostty theme file uses, so the two can be diffed by eye.
  fileprivate convenience init(hex: UInt32) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}
