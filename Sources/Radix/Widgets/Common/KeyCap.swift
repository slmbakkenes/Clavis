import SwiftUI

/// One key symbol in a small rounded box, as the old `Key` component drew it.
struct KeyCap: View {
  let symbol: String
  var primary = false
  /// Rows draw caps on the accent background, where the neutral fill would vanish.
  var onAccent = false

  var body: some View {
    Text(symbol)
      .font(.system(size: 11))
      .foregroundStyle(primary || onAccent ? Color.white : Color.primary)
      .frame(minWidth: 20, minHeight: 20)
      .padding(.horizontal, symbol.count > 1 ? 4 : 0)
      .background(fill, in: RoundedRectangle(cornerRadius: 4))
  }

  private var fill: Color {
    if primary { return .accentColor }
    if onAccent { return Color.white.opacity(0.2) }
    return Color(nsColor: .quaternaryLabelColor).opacity(0.6)
  }
}
