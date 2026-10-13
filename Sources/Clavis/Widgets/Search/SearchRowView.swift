import ClavisCore
import SwiftUI

/// One item row: icon, name, and trailing details in the old widget's order.
struct SearchRowView: View {
  let item: Item
  let isSelected: Bool
  /// The item's global shortcut string from config, if any.
  let shortcut: String?

  var body: some View {
    HStack(spacing: 0) {
      ItemIconView(icon: item.icon, isSelected: isSelected)
        .overlay(alignment: .bottom) {
          if item.isRunning {
            Circle()
              .fill(isSelected ? Theme.textOnSelection : Theme.textMuted)
              .frame(width: 3, height: 3)
              .offset(y: 5)
          }
        }

      Text(item.name)
        .lineLimit(1)
        .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.text)
        .padding(.leading, 12)
        .frame(maxWidth: 576, alignment: .leading)

      Spacer(minLength: 8)

      trailing
    }
    .padding(.horizontal, 12)
    .frame(height: 48)
    .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    .contentShape(RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  private var trailing: some View {
    HStack(spacing: 4) {
      switch item.kind {
      case .bookmark:
        detail("Browser Bookmark")
      case .custom:
        detail("Custom")
      default:
        EmptyView()
      }

      // The item's own subtitle is the bookmark folder for bookmarks; "Custom"
      // is already shown for custom items, so skip it there.
      if item.kind != .bookmark, item.kind != .custom, let subtitle = item.subtitle, !subtitle.isEmpty {
        detail(subtitle)
      }

      if let shortcut, !shortcut.isEmpty {
        HStack(spacing: 4) {
          ForEach(Array(ShortcutFormat.symbols(shortcut).enumerated()), id: \.offset) { _, symbol in
            KeyCap(symbol: symbol, onSelection: isSelected)
          }
        }
      }

      if item.kind == .bookmark, let folder = item.subtitle, !folder.isEmpty {
        Text(folder.count > 16 ? "\(folder.prefix(16))..." : folder)
          .font(.system(size: 13))
          .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.text)
          .lineLimit(1)
      }
    }
  }

  private func detail(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11))
      .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.textMuted)
      .lineLimit(1)
  }
}
