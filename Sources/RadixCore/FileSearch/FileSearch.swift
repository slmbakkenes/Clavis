import Foundation

/// A file or folder returned by a file search.
public struct FileResult: Sendable, Equatable, Identifiable {
  public let path: String
  public let name: String
  public let isDirectory: Bool

  public var id: String { path }

  public init(path: String, name: String, isDirectory: Bool) {
    self.path = path
    self.name = name
    self.isDirectory = isDirectory
  }
}

/// Query building and result ranking for Spotlight-backed file search.
public enum FileSearch {
  /// Below any positive fuzzy score, so fuzzy matches still rank first.
  static let literalMatchScore = Double.leastNonzeroMagnitude

  /// A `*query*` pattern for an NSPredicate `LIKE` comparison. `*`, `?` and
  /// `\` are LIKE metacharacters, so they are escaped to match literally.
  public static func likePattern(for query: String) -> String {
    var escaped = ""
    for character in query {
      if character == "*" || character == "?" || character == "\\" {
        escaped.append("\\")
      }
      escaped.append(character)
    }
    return "*\(escaped)*"
  }

  /// Orders results by how well the name matches, then by shorter path (files
  /// nearer the top of a search folder first), then by name. Names that
  /// neither fuzzy-match nor contain the query are dropped.
  ///
  /// FuzzyScore only considers letters and spaces, so a query such as "2024"
  /// or "v1.2" scores 0 against every name. Spotlight has already matched the
  /// name as a substring, so a literal match is kept with the lowest score
  /// rather than discarded.
  public static func rank(_ results: [FileResult], query: String, limit: Int) -> [FileResult] {
    let scored = results.compactMap { result -> (result: FileResult, score: Double)? in
      let fuzzy = FuzzyScore.score(result.name, query: query)
      if fuzzy > 0 { return (result, fuzzy) }
      let literal = result.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
      return literal ? (result, literalMatchScore) : nil
    }
    let sorted = scored.sorted { left, right in
      if left.score != right.score { return left.score > right.score }
      if left.result.path.count != right.result.path.count {
        return left.result.path.count < right.result.path.count
      }
      return left.result.name.localizedStandardCompare(right.result.name) == .orderedAscending
    }
    return sorted.prefix(max(limit, 0)).map(\.result)
  }
}
