import CoreLocation
import CoreWLAN
import Foundation
import Security

/// The connected Wi-Fi network's password from the system keychain.
@MainActor
enum WiFi {
  /// Kept for the app's lifetime: a location manager released right after
  /// requesting authorization tears the prompt down with it. macOS only
  /// reveals the SSID to apps with location authorization.
  private static let locationManager = CLLocationManager()

  /// The location checks stay on the main actor; the SSID and keychain lookup
  /// run detached because the keychain call blocks until the user answers the
  /// admin prompt, which on main would freeze the panel, hotkeys and taps.
  static func currentNetworkPassword() async throws -> (ssid: String, password: String) {
    guard CLLocationManager.locationServicesEnabled() else {
      throw UserFacingError("Location services are not enabled")
    }
    if locationManager.authorizationStatus == .denied {
      throw UserFacingError("App doesn't have location access")
    }
    locationManager.requestAlwaysAuthorization()

    return try await Task.detached(priority: .userInitiated) { try lookUpPassword() }.value
  }

  nonisolated private static func lookUpPassword() throws -> (ssid: String, password: String) {
    guard let ssid = CWWiFiClient.shared().interface()?.ssid() else {
      throw UserFacingError("Could not get connected network info")
    }

    var password: NSString?
    let status = CWKeychainFindWiFiPassword(.system, Data(ssid.utf8), &password)
    guard status == errSecSuccess else {
      throw UserFacingError("OS error code: \(status)")
    }
    guard let password else {
      throw UserFacingError("No password found")
    }
    return (ssid, password as String)
  }
}
