/// URL-safe random identifiers in the style of the `nanoid` package.
public enum NanoID {
  /// The 64 URL-safe symbols. A power-of-two alphabet means masking a random
  /// byte to 6 bits picks every symbol with equal probability.
  static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

  public static func make(size: Int = 21) -> String {
    var generator = SystemRandomNumberGenerator()
    return make(size: size, using: &generator)
  }

  public static func make<G: RandomNumberGenerator>(size: Int = 21, using generator: inout G) -> String {
    precondition(size >= 0, "NanoID size must not be negative")
    var characters: [Character] = []
    characters.reserveCapacity(size)
    for _ in 0..<size {
      let index = Int(UInt8.random(in: .min ... .max, using: &generator) & 63)
      characters.append(alphabet[index])
    }
    return String(characters)
  }
}
