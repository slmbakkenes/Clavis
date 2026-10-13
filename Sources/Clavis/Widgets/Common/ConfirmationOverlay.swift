import SwiftUI

/// Modal "are you sure" card over the panel. Enter and Esc are routed by the
/// InputRouter; the buttons exist for the mouse and never take focus.
struct ConfirmationOverlay: View {
  let confirmation: AppModel.Confirmation
  let onProceed: () -> Void
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      Theme.scrim
        .contentShape(Rectangle())
        .onTapGesture(perform: onCancel)

      VStack(alignment: .leading, spacing: 4) {
        Text(confirmation.title)
          .font(.system(size: 13, weight: .semibold))
        Text("Are you sure you want to proceed?")
          .font(.system(size: 13))
          .padding(.bottom, 8)

        Button(action: onProceed) {
          Text("Proceed")
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Theme.accent, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)

        Button(action: onCancel) {
          Text("Cancel")
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Theme.elevated, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
      }
      .foregroundStyle(Theme.text)
      .padding(24)
      .frame(width: 280)
      .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).stroke(Theme.separator, lineWidth: 1)
      )
    }
  }
}
