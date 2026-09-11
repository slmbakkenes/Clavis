import Foundation

/// Port of Sol's `NSString+Score` (itself a port of string_score). Scores how
/// well `query` abbreviates `candidate`, 0...1. Characters must match in
/// order; a query character that never matches scores 0 unless `fuzziness`
/// is given (0...1, higher is more forgiving).
public enum FuzzyScore {
  public struct Options: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let favorSmallerWords = Options(rawValue: 1 << 1)
    public static let reducedLongStringPenalty = Options(rawValue: 1 << 2)
  }

  public static func score(
    _ candidate: String, query: String, fuzziness: Double? = nil, options: Options = []
  ) -> Double {
    var string = clean(candidate)
    let other = clean(query)

    if string == other { return 1 }
    if other.isEmpty { return 0 }
    // The original fell through to a divide-by-zero (float, so inf) when the
    // candidate cleaned to nothing; nothing can match an empty candidate.
    if string.isEmpty { return 0 }

    let otherLength = Double(other.count)
    let stringLength = Double(string.count)
    var totalCharacterScore = 0.0
    var startOfStringBonus = false
    var fuzzies = 1.0

    for (index, chr) in other.enumerated() {
      var characterScore = 0.1
      let lower = singleCharacter(String(chr).lowercased()) ?? chr
      let upper = singleCharacter(String(chr).uppercased()) ?? chr
      let lowerIndex = string.firstIndex(of: lower)
      let upperIndex = string.firstIndex(of: upper)

      let indexInString: Int?
      switch (lowerIndex, upperIndex) {
      case (nil, nil):
        if let fuzziness {
          fuzzies += 1 - fuzziness
          indexInString = nil
        } else {
          return 0
        }
      case let (l?, u?): indexInString = min(l, u)
      case let (l?, nil): indexInString = l
      case let (nil, u?): indexInString = u
      }

      if let i = indexInString {
        // Same case bonus.
        if string[i] == chr { characterScore += 0.1 }

        if i == 0 {
          // Matching the first character of the remainder of the string.
          characterScore += 0.6
          // First character of both string and abbreviation.
          if index == 0 { startOfStringBonus = true }
        } else if string[i - 1] == " " {
          // Acronym bonus: typing the first character of a word is as if you
          // preceded it with two perfect character matches.
          characterScore += 0.8
        }

        // Left-trim the matched part (forces sequential matching).
        string.removeFirst(i + 1)
      }

      totalCharacterScore += characterScore
    }

    if options.contains(.favorSmallerWords) {
      return totalCharacterScore / stringLength
    }

    let otherStringScore = totalCharacterScore / otherLength
    var finalScore: Double
    if options.contains(.reducedLongStringPenalty) {
      // The original used integer division here (NSUInteger / NSUInteger), so
      // the "percentage" was 0 unless the strings had equal length. Kept as-is
      // for parity; the option is unused by Radix.
      let percentageOfMatchedString = Double(Int(otherLength) / Int(stringLength))
      let wordScore = otherStringScore * percentageOfMatchedString
      finalScore = (wordScore + otherStringScore) / 2
    } else {
      finalScore = ((otherStringScore * (otherLength / stringLength)) + otherStringScore) / 2
    }

    finalScore /= fuzzies

    if startOfStringBonus && finalScore + 0.15 < 1 {
      finalScore += 0.15
    }
    return finalScore
  }

  /// Case mapping can expand ("ß" -> "SS"); treat those as having no
  /// other-case form rather than trapping in `Character.init`.
  private static func singleCharacter(_ text: String) -> Character? {
    text.count == 1 ? text.first : nil
  }

  private static let allowed = CharacterSet.lowercaseLetters
    .union(.uppercaseLetters)
    .union(CharacterSet(charactersIn: " "))

  /// Canonical decomposition, then keep only letters and spaces, so "é"
  /// becomes "e" and punctuation/digits vanish. Yields one Character per
  /// remaining scalar.
  static func clean(_ text: String) -> [Character] {
    text.decomposedStringWithCanonicalMapping.unicodeScalars
      .filter { allowed.contains($0) }
      .map { Character($0) }
  }
}
