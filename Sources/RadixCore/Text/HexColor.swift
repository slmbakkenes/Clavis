/// `#rrggbb` colours as stored in custom items (`color` in config.json).
public struct HexColor: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double

  /// Accepts `#rrggbb` or `rrggbb`, case-insensitive; anything else is nil.
  public init?(_ text: String) {
    var hex = Substring(text)
    if hex.hasPrefix("#") { hex = hex.dropFirst() }
    guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
    red = Double((value >> 16) & 0xFF) / 255
    green = Double((value >> 8) & 0xFF) / 255
    blue = Double(value & 0xFF) / 255
  }
}
