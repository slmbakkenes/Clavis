import Foundation

/// App initials used as a secondary search field ("vsc" for "Visual Studio
/// Code").
public enum Initials {
  /// Port of `getInitials`: lowercase, split on single spaces, first
  /// character of each piece. Empty pieces from repeated spaces contribute
  /// nothing, like JavaScript's `"".charAt(0)`. Characters are Swift
  /// grapheme clusters rather than UTF-16 code units, so an emoji is kept
  /// whole instead of being cut in half.
  public static func of(_ name: String) -> String {
    name.lowercased()
      .split(separator: " ", omittingEmptySubsequences: false)
      .compactMap { $0.first.map(String.init) }
      .joined()
  }
}
