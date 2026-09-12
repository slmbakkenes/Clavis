import RadixCore
import SwiftUI

/// Calculator, unit and timezone answers shown inline above the results.
struct TemporaryResultView: View {
  let result: TemporaryResult
  let isSelected: Bool

  var body: some View {
    content
      .padding(.horizontal, 16)
      .padding(.vertical, 24)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isSelected ? Theme.selection : Color.clear,
        in: RoundedRectangle(cornerRadius: 8)
      )
      .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.text)
  }

  @ViewBuilder
  private var content: some View {
    switch result {
    case .text(let value, let secondary):
      HStack {
        Text(value)
          .font(.system(size: 36, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
        Spacer()
        if let secondary, !secondary.isEmpty {
          Text(secondary)
            .foregroundStyle(secondaryStyle)
            .lineLimit(1)
        }
      }
    case .comparison(let left, let right, let footer):
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 16) {
          column(left, alignment: .leading)
          Text("→")
            .font(.system(size: 18))
            .foregroundStyle(secondaryStyle)
          column(right, alignment: .trailing)
        }
        if let footer, !footer.isEmpty {
          Text(footer)
            .font(.system(size: 11))
            .foregroundStyle(secondaryStyle)
        }
      }
    }
  }

  private var secondaryStyle: Color {
    isSelected ? Theme.textOnSelection.opacity(0.85) : Theme.textMuted
  }

  private func column(_ labeled: TemporaryResult.Labeled, alignment: HorizontalAlignment) -> some View {
    VStack(alignment: alignment, spacing: 2) {
      Text(labeled.label.uppercased())
        .font(.system(size: 11))
        .foregroundStyle(secondaryStyle)
      Text(labeled.value)
        .font(.system(size: 24, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
    .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
  }
}
