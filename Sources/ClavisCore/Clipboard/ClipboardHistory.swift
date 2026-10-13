import Foundation

/// One clipboard history entry. JSON keys match the previous build's
/// `PasteItem`, so its persisted history decodes unchanged.
public struct PasteItem: Codable, Equatable, Sendable, Identifiable {
  /// Epoch milliseconds when copied, unique within a history.
  public var id: Int64
  /// The copied text, or the file name for copied files and images.
  public var text: String
  /// Path of the copied file or persisted image, if any.
  public var url: String?
  /// File URL string of the app that was frontmost when the copy happened.
  public var bundle: String?
  /// Epoch milliseconds when copied.
  public var datetime: Double

  public init(id: Int64, text: String, url: String? = nil, bundle: String? = nil, datetime: Double) {
    self.id = id
    self.text = text
    self.url = url
    self.bundle = bundle
    self.datetime = datetime
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int64.self, forKey: .id)
    text = try container.decode(String.self, forKey: .text)
    url = try container.decodeIfPresent(String.self, forKey: .url)
    bundle = try container.decodeIfPresent(String.self, forKey: .bundle)
    // The previous build back-filled a missing datetime from the id.
    datetime = try container.decodeIfPresent(Double.self, forKey: .datetime) ?? Double(id)
  }
}

/// The clipboard history, newest first. Mirrors the previous build's
/// clipboard store. Mutations return the items they dropped so the caller can
/// delete files that belonged to them.
public struct ClipboardHistory: Equatable, Sendable {
  public static let maxItems = 1000
  /// Text beyond this is not scored: searching a thousand large pastes on
  /// every keystroke would otherwise be slow.
  static let scoredPrefixLength = 2000

  public private(set) var items: [PasteItem]

  public init(items: [PasteItem] = []) {
    self.items = Array(items.prefix(Self.maxItems))
  }

  /// Ignores empty text. Copying text that is already in the history moves
  /// that entry to the top instead of adding a duplicate.
  @discardableResult
  public mutating func addText(_ text: String, bundle: String?, now: Date) -> [PasteItem] {
    guard !text.isEmpty else { return [] }
    if let existing = items.firstIndex(where: { $0.text == text }) {
      items.insert(items.remove(at: existing), at: 0)
      return []
    }
    items.insert(makeItem(text: text, url: nil, bundle: bundle, now: now), at: 0)
    return trimToLimit()
  }

  /// Files and images are never deduplicated, as before.
  @discardableResult
  public mutating func addFile(text: String, url: String, bundle: String?, now: Date) -> [PasteItem] {
    items.insert(makeItem(text: text, url: url, bundle: bundle, now: now), at: 0)
    return trimToLimit()
  }

  @discardableResult
  public mutating func remove(id: Int64) -> [PasteItem] {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return [] }
    return [items.remove(at: index)]
  }

  public mutating func moveToTop(id: Int64) {
    guard let index = items.firstIndex(where: { $0.id == id }), index != 0 else { return }
    items.insert(items.remove(at: index), at: 0)
  }

  /// An empty query returns everything. Otherwise matching items, best first,
  /// with recent copies boosted as before (x1.2 within an hour, x1.1 within a
  /// day). Ties keep history order.
  public func search(_ query: String, now: Date) -> [PasteItem] {
    guard !query.isEmpty else { return items }
    let nowMilliseconds = now.timeIntervalSince1970 * 1000
    let matches = items.enumerated().compactMap { offset, item -> (offset: Int, item: PasteItem, score: Double)? in
      let score = Self.matchScore(item.text, query: query)
      guard score > 0 else { return nil }
      return (offset, item, score * Self.recencyBoost(datetime: item.datetime, now: nowMilliseconds))
    }
    return matches.sorted { left, right in
      left.score != right.score ? left.score > right.score : left.offset < right.offset
    }.map(\.item)
  }

  /// A plain substring match counts fully. The fuzzy scorer ignores digits and
  /// punctuation, which clipboard searches ("192.168", "#42") need.
  static func matchScore(_ text: String, query: String) -> Double {
    let scored = String(text.prefix(scoredPrefixLength))
    if scored.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
      return 1
    }
    return FuzzyScore.score(scored, query: query)
  }

  static func recencyBoost(datetime: Double, now: Double) -> Double {
    guard datetime > 0 else { return 1 }
    let hoursAgo = (now - datetime) / 3_600_000
    if hoursAgo < 1 { return 1.2 }
    if hoursAgo < 24 { return 1.1 }
    return 1
  }

  private func makeItem(text: String, url: String?, bundle: String?, now: Date) -> PasteItem {
    let milliseconds = Int64((now.timeIntervalSince1970 * 1000).rounded(.down))
    // Two copies in the same millisecond must still get distinct ids.
    let newestID = items.map(\.id).max() ?? Int64.min
    let id = milliseconds > newestID ? milliseconds : newestID + 1
    return PasteItem(id: id, text: text, url: url, bundle: bundle, datetime: Double(milliseconds))
  }

  private mutating func trimToLimit() -> [PasteItem] {
    guard items.count > Self.maxItems else { return [] }
    let removed = Array(items[Self.maxItems...])
    items.removeLast(items.count - Self.maxItems)
    return removed
  }
}
