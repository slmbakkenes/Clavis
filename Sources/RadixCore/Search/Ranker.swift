import Foundation

/// What the ranker needs from an item. `localizedName` and `alias` (app
/// initials) are optional secondary match fields.
public protocol Rankable {
  var id: String { get }
  var name: String { get }
  var localizedName: String? { get }
  var alias: String? { get }
}

extension Rankable {
  public var localizedName: String? { nil }
  public var alias: String? { nil }
}

public enum Ranker {
  /// Name-dominant heuristic (not a MiniSearch port): the name scores at
  /// full weight, localizedName and alias at half, and the best field wins.
  /// Result stays in 0...1. Items whose fields all score 0 are dropped.
  public static func score<T: Rankable>(_ item: T, query: String) -> Double {
    var best = FuzzyScore.score(item.name, query: query)
    if let localized = item.localizedName {
      best = max(best, FuzzyScore.score(localized, query: query) * 0.5)
    }
    if let alias = item.alias {
      best = max(best, FuzzyScore.score(alias, query: query) * 0.5)
    }
    return best
  }

  /// Orders `items` for `query`. An empty query keeps every item, ordered by
  /// usage only. `frequencies` may be keyed by id or, for legacy entries, by
  /// name. Timestamps are milliseconds since the epoch as written by the
  /// previous build.
  public static func rank<T: Rankable>(
    _ items: [T],
    query: String,
    frequencies: [String: Int],
    selectionTimestamps: [String: Double]
  ) -> [T] {
    let ranked: [(item: T, score: Double)]
    if query.isEmpty {
      ranked = items.map { ($0, 0) }
    } else {
      ranked = items.compactMap { item in
        let s = score(item, query: query)
        return s > 0 ? (item, s) : nil
      }
    }

    func count(_ item: T) -> Int {
      frequencies[item.id] ?? frequencies[item.name] ?? 0
    }
    func timestamp(_ item: T) -> Double {
      selectionTimestamps[item.id] ?? 0
    }

    return ranked.sorted { left, right in
      let leftCount = count(left.item)
      let rightCount = count(right.item)
      let leftWasSelected = leftCount > 0
      let rightWasSelected = rightCount > 0
      if leftWasSelected != rightWasSelected { return leftWasSelected }

      if left.score != right.score { return left.score > right.score }

      let leftTimestamp = timestamp(left.item)
      let rightTimestamp = timestamp(right.item)
      if leftTimestamp != rightTimestamp { return leftTimestamp > rightTimestamp }

      if leftCount != rightCount { return leftCount > rightCount }

      return left.item.name.compare(
        right.item.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedAscending
    }.map(\.item)
  }
}
