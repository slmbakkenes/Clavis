import AppKit
import SwiftUI

/// Settings > About.
struct AboutSettingsPage: View {
  private static let upstreamURL = URL(string: "https://github.com/ospfranco/sol")!

  private var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development"
  }

  var body: some View {
    VStack(spacing: 8) {
      Spacer()
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 128, height: 128)
      Text("Radix")
        .font(.system(size: 28, weight: .semibold))
      Text(version)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      Text("Based on Sol by ospfranco (MIT)")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
      Button("Upstream Project") {
        NSWorkspace.shared.open(Self.upstreamURL)
      }
      .controlSize(.regular)
      .focusable(false)
      .padding(.top, 20)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
