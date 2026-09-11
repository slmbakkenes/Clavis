import SwiftUI

/// Key hints under the result list, with the old widget's conditions.
struct SearchFooter: View {
  let hasRows: Bool
  let selectedIsCustom: Bool

  var body: some View {
    HStack(spacing: 4) {
      Spacer()

      if selectedIsCustom {
        hint("Edit")
        KeyCap(symbol: "⌘")
        KeyCap(symbol: "E")
        gap
        hint("Delete")
        KeyCap(symbol: "⇧")
        KeyCap(symbol: "⌫")
        gap
      }

      hint("Translate")
      KeyCap(symbol: "⇧")
      KeyCap(symbol: "⏎")

      if !hasRows {
        gap
        hint("Search", emphasised: true)
        KeyCap(symbol: "⌘")
        KeyCap(symbol: "⏎")
      }

      gap
      hint("Browser Search", emphasised: !hasRows)
      if hasRows {
        KeyCap(symbol: "⌘")
      }
      KeyCap(symbol: "⏎", primary: !hasRows)

      if hasRows {
        gap
        Text("Select")
          .font(.system(size: 11, weight: .semibold))
          .padding(.trailing, 4)
        KeyCap(symbol: "⏎", primary: true)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color(nsColor: .separatorColor))
        .frame(height: 1)
    }
  }

  private var gap: some View {
    Color.clear.frame(width: 16, height: 1)
  }

  private func hint(_ text: String, emphasised: Bool = false) -> some View {
    Text(text)
      .font(.system(size: 11, weight: emphasised ? .semibold : .regular))
      .foregroundStyle(.secondary)
      .padding(.trailing, 4)
  }
}
