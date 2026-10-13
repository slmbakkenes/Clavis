import ClavisCore
import SwiftUI

/// The 24pt leading icon of a search row.
struct ItemIconView: View {
  let icon: Item.Icon
  var isSelected = false

  var body: some View {
    Group {
      switch icon {
      case .file(let path):
        Image(nsImage: IconCache.shared.icon(forPath: path))
          .resizable()
          .interpolation(.high)
      case .application(let bundleIdentifier):
        if let image = IconCache.shared.icon(forBundleIdentifier: bundleIdentifier) {
          Image(nsImage: image)
            .resizable()
            .interpolation(.high)
        } else {
          symbol("globe")
        }
      case .symbol(let name):
        symbol(name)
      case .customSymbol(let name, let colorHex):
        // As the old custom items: a tinted glyph on a small plain tile.
        Image(systemName: name)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(colorHex.flatMap(HexColor.init).map(Color.init) ?? Theme.text)
          .frame(width: 24, height: 24)
          .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 5))
      case .emoji(let emoji):
        Text(emoji)
          .font(.system(size: 16))
      case .none:
        Color.clear
      }
    }
    .frame(width: 24, height: 24)
  }

  private func symbol(_ name: String) -> some View {
    Image(systemName: name)
      .font(.system(size: 16))
      .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.text)
  }
}

extension Color {
  init(_ hex: HexColor) {
    self.init(red: hex.red, green: hex.green, blue: hex.blue)
  }
}
