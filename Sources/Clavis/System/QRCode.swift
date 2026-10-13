import AppKit
import CoreImage

enum QRCode {
  /// A QR code for `string`, each module `scale` points wide.
  static func image(from string: String, scale: CGFloat) -> NSImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(string.utf8), forKey: "inputMessage")
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
      return nil
    }
    let representation = NSCIImageRep(ciImage: output)
    let image = NSImage(size: representation.size)
    image.addRepresentation(representation)
    return image
  }

  /// The `WIFI:` payload phone cameras offer to join.
  static func wifi(ssid: String, password: String, scale: CGFloat = 10) -> NSImage? {
    image(from: "WIFI:T:WPA;S:\(escape(ssid));P:\(escape(password));;", scale: scale)
  }

  /// The Wi-Fi QR format reserves `\ ; , : "`; unescaped, a password
  /// containing one of them produces a code that joins with the wrong password.
  private static func escape(_ value: String) -> String {
    var escaped = ""
    for character in value {
      if #"\;,:""#.contains(character) {
        escaped.append("\\")
      }
      escaped.append(character)
    }
    return escaped
  }
}
