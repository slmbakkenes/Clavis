import SwiftUI

/// Shown under the empty search field while Accessibility access is missing.
struct PermissionsBar: View {
  var body: some View {
    HStack {
      Spacer()
      Text("Window management needs Accessibility access — click to grant")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .frame(height: AppModel.permissionsBarHeight)
    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
    .contentShape(Rectangle())
    .onTapGesture {
      Permissions.requestAccessibility()
      PanelManager.shared.hideWindow()
    }
  }
}
