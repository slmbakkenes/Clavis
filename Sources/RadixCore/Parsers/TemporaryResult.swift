import Foundation

/// An inline answer shown above the search results (calculator, unit and
/// timezone conversion). Mirrors the `TemporaryResult` union of the old
/// TypeScript store, minus the flight lookup.
public enum TemporaryResult: Equatable, Sendable {
  public struct Labeled: Equatable, Sendable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
      self.label = label
      self.value = value
    }
  }

  case text(value: String, secondary: String? = nil)
  case comparison(left: Labeled, right: Labeled, footer: String? = nil)

  /// The plain-text form used when the result is copied to the pasteboard.
  public var clipboardText: String {
    switch self {
    case .text(let value, let secondary):
      return secondary.map { "\(value) (\($0))" } ?? value
    case .comparison(let left, let right, let footer):
      let suffix = footer.map { " | \($0)" } ?? ""
      return "\(left.value) \(left.label) = \(right.value) \(right.label)\(suffix)"
    }
  }
}
