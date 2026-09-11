import SwiftUI

/// Modal "are you sure" card over the panel. Enter and Esc are routed by the
/// InputRouter; the buttons exist for the mouse and never take focus.
struct ConfirmationOverlay: View {
  let confirmation: AppModel.Confirmation
  let onProceed: () -> Void
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.5)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color.accentColor, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)

        Button(action: onCancel) {
          Text("Cancel")
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color(nsColor: .quaternaryLabelColor), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
      }
      .padding(24)
      .frame(width: 280)
      .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1)
      )
    }
  }
}
