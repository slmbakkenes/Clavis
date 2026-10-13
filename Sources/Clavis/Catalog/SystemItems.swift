import AppKit

/// Appearance and Wi-Fi commands from the previous build's `items.tsx`.
@MainActor
enum SystemItems {
  static func make() -> [Item] {
    [
      Item(
        id: "toggle_appearance", kind: .configuration, name: "Toggle system appearance", alias: "dark",
        icon: .symbol("circle.lefthalf.filled")
      ) { _ in
        try await Appearance.toggleDarkMode()
      },
      Item(
        id: "copy_wifi_password", kind: .configuration, name: "Copy Wi-Fi Password to Clipboard", alias: "wifi",
        icon: .symbol("key.fill")
      ) { _ in
        let network = try await WiFi.currentNetworkPassword()
        copyToPasteboard(network.password)
        ToastManager.shared.show(text: "Password copied to clipboard", variant: .success)
      },
      Item(
        id: "reveal_wifi_password", kind: .configuration, name: "Reveal Wi-Fi Password", alias: "wifi",
        icon: .symbol("qrcode")
      ) { _ in
        let network = try await WiFi.currentNetworkPassword()
        copyToPasteboard(network.password)
        ToastManager.shared.show(
          text: "SSID: \(network.ssid)\nPassword: \(network.password)",
          variant: .none,
          timeout: 30,
          image: QRCode.wifi(ssid: network.ssid, password: network.password)
        )
      },
    ]
  }

  private static func copyToPasteboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}
