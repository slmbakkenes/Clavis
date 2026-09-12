import SwiftUI

/// Gruvbox dark, the palette this machine's terminal and editor already use.
///
/// Every value is taken from Ghostty's shipped "Gruvbox Dark" theme file, so a
/// Radix row and a terminal line on the same screen are literally the same
/// colour. The app pins itself to `.darkAqua` in `AppDelegate`, so there is no
/// light variant to keep in sync.
///
/// AppKit call sites wrap these with `NSColor(...)` rather than duplicating the
/// palette in a second form.
enum Theme {

  // MARK: - Palette
  //
  // Only the shades the roles below actually use. The full gruvbox set is in
  // Ghostty's "Gruvbox Dark" theme file if another one is ever needed; the
  // custom-item swatches in `CustomIcons` carry their own hex strings because
  // config stores them as text.

  static let bg0Hard = Color(hex: 0x1D2021)
  static let bg0 = Color(hex: 0x282828)
  static let bg1 = Color(hex: 0x3C3836)
  static let bg3 = Color(hex: 0x665C54)
  static let bg4 = Color(hex: 0x7C6F64)
  static let gray = Color(hex: 0x928374)
  static let fg1 = Color(hex: 0xEBDBB2)
  static let fg0 = Color(hex: 0xFBF1C7)

  static let brightRed = Color(hex: 0xFB4934)
  static let brightGreen = Color(hex: 0xB8BB26)
  static let brightBlue = Color(hex: 0x83A598)

  // MARK: - Roles

  /// The panel's own colour. Applied as a tint over the window's vibrancy, so
  /// it is never painted fully opaque.
  static let background = bg0
  /// Footers, icon tiles and cards that need to lift off `background`.
  static let elevated = bg1
  /// Selected row fill. Ghostty uses this exact value for its text selection.
  static let selection = bg3
  static let separator = bg1

  static let text = fg1
  /// Text drawn on top of `selection`, which needs to out-contrast `text`.
  static let textOnSelection = fg0
  static let textMuted = gray
  static let textSubtle = bg4

  /// Small active states: key caps, focus rings, toggles.
  static let accent = brightBlue
  static let success = brightGreen
  static let danger = brightRed

  /// Dimming behind a modal overlay.
  static let scrim = bg0Hard.opacity(0.6)
}

extension Color {
  /// `0xRRGGBB`, opaque. The palette above is written in the same notation the
  /// Ghostty theme file uses, so the two can be diffed by eye.
  fileprivate init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1
    )
  }
}
