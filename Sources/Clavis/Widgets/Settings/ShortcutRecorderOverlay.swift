import ClavisCore
import SwiftUI

/// Shown while a shortcut is being recorded. Key presses are captured by the
/// input router; this view only reflects `ShortcutRecording`.
struct ShortcutRecorderOverlay: View {
  let recording: ShortcutRecording
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      Theme.scrim
        .contentShape(Rectangle())
        .onTapGesture(perform: onCancel)

      VStack(spacing: 10) {
        Text(title)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(Theme.text)

        keys
          .frame(minHeight: 24)

        if let error = recording.error {
          Text(error)
            .font(.system(size: 11))
            .foregroundStyle(Theme.danger)
        }

        Text("Esc to cancel")
          .font(.system(size: 10))
          .foregroundStyle(Theme.textMuted)
      }
      .padding(18)
      .frame(width: 320)
      .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
      .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
  }

  private var title: String {
    switch recording.target {
    case .item: "Enter Key Combination"
    case .filter: "Press a shortcut to filter by"
    }
  }

  @ViewBuilder
  private var keys: some View {
    if recording.keys.isEmpty {
      Text("waiting...")
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(Theme.textMuted)
    } else {
      HStack(spacing: 4) {
        ForEach(Array(ShortcutFormat.symbols(recording.keys.joined(separator: "+")).enumerated()), id: \.offset) {
          _, symbol in
          KeyCap(symbol: symbol)
        }
      }
    }
  }
}
