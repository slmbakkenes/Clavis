public struct Modifiers: OptionSet, Sendable, Hashable {
  public let rawValue: UInt8
  public init(rawValue: UInt8) { self.rawValue = rawValue }

  public static let control = Modifiers(rawValue: 1 << 0)
  public static let command = Modifiers(rawValue: 1 << 1)
  public static let shift = Modifiers(rawValue: 1 << 2)
  public static let option = Modifiers(rawValue: 1 << 3)
}
