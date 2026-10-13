/// A list selection that follows an element's identity instead of its row.
///
/// Lists here change while they are on screen: processes re-sort on refresh,
/// clipboard entries arrive or move to the top, Spotlight results replace
/// each other. A row index would silently point at a different element, and
/// Enter would then kill, paste or open the wrong one.
public struct Selection<ID: Hashable & Sendable>: Equatable, Sendable {
  public private(set) var id: ID?

  public init(id: ID? = nil) {
    self.id = id
  }

  public mutating func select(_ id: ID?) {
    self.id = id
  }

  /// Keeps the selection on its element while that element is listed, and
  /// otherwise pins it to the first one (nil for an empty list).
  public mutating func keepValid<Element: Identifiable>(in elements: [Element]) where Element.ID == ID {
    if let id, elements.contains(where: { $0.id == id }) { return }
    self.id = elements.first?.id
  }

  /// Row of the selected element, 0 when it is not listed.
  public func index<Element: Identifiable>(in elements: [Element]) -> Int where Element.ID == ID {
    elements.firstIndex { $0.id == id } ?? 0
  }

  public func element<Element: Identifiable>(in elements: [Element]) -> Element? where Element.ID == ID {
    elements.first { $0.id == id }
  }

  /// Moves by `delta` rows, clamped to the list.
  public mutating func move<Element: Identifiable>(by delta: Int, in elements: [Element]) where Element.ID == ID {
    guard !elements.isEmpty else {
      id = nil
      return
    }
    let target = min(max(index(in: elements) + delta, 0), elements.count - 1)
    id = elements[target].id
  }
}
