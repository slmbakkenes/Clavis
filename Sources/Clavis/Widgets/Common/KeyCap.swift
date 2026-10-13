import SwiftUI

/// One key symbol in a small rounded box, as the old `Key` component drew it.
struct KeyCap: View {
  let symbol: String
  var primary = false
  /// Rows draw caps on the selection fill, where the neutral fill would vanish.
  var onSelection = false

  var body: some View {
    Text(symbol)
      .font(.system(size: 11))
      .foregroundStyle(foreground)
      .frame(minWidth: 20, minHeight: 20)
      .padding(.horizontal, symbol.count > 1 ? 4 : 0)
      .background(fill, in: RoundedRectangle(cornerRadius: 4))
  }

  private var fill: Color {
    if primary { return Theme.accent }
    if onSelection { return Theme.fg1.opacity(0.15) }
    return Theme.elevated
  }

  /// The primary cap is a filled accent chip, so its glyph has to invert.
  private var foreground: Color {
    if primary { return Theme.background }
    if onSelection { return Theme.textOnSelection }
    return Theme.text
  }
}
