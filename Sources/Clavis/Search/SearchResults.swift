import Foundation
import ClavisCore

/// Builds the search widget's rows for a query. Pure apart from reading the
/// items passed in, so the ordering rules live in one place.
@MainActor
enum SearchResults {
  static func temporaryResult(for query: String) -> TemporaryResult? {
    if query == "ip" {
      return Network.localIPv4Address().map { .text(value: $0, secondary: "IP") }
    }
    if let result = TimezoneConversion.parse(query) { return result }
    if let result = UnitConversion.parse(query) { return result }
    guard let value = try? Calculator.evaluate(query), !value.isNaN else { return nil }
    return .text(value: formatExpressionResult(value), secondary: query)
  }

  static func rows(
    query: String,
    items: [Item],
    temporaryResult: TemporaryResult?,
    config: Config,
    state: AppState
  ) -> [SearchRow] {
    guard !query.isEmpty else { return [] }

    let disabled = Set(config.disabledItemIds)
    let candidates = items.filter { !disabled.contains($0.id) }
    let ranked = Ranker.rank(
      candidates, query: query, frequencies: state.frequencies, selectionTimestamps: state.selectionTimestamps)

    var rows: [SearchRow] = []
    if URLDetection.isLooseURL(query) {
      rows.append(.item(openURLItem(for: query)))
    }
    if let temporaryResult {
      rows.append(.temporaryResult(temporaryResult))
    }
    rows.append(contentsOf: ranked.map(SearchRow.item))
    return rows
  }

  static func openURLItem(for query: String) -> Item {
    Item(id: "open_url", kind: .configuration, name: "Open URL", icon: .emoji("🌎")) { _ in
      let hasScheme = query.lowercased().hasPrefix("http://") || query.lowercased().hasPrefix("https://")
      try Workspace.open(urlString: hasScheme ? query : "https://\(query)")
    }
  }

  static func customItems(_ items: [CustomItem]) -> [Item] {
    items.map { custom in
      Item(
        id: custom.id, kind: .custom, name: custom.name, subtitle: "Custom",
        icon: .customSymbol(CustomIcons.symbolName(for: custom.icon), colorHex: custom.color)
      ) { _ in
        guard !custom.text.isEmpty else { return }
        // The previous build's opener accepted plain paths as well as URLs.
        if custom.text.hasPrefix("/") || custom.text.hasPrefix("~") {
          try Workspace.open(path: custom.text)
        } else {
          try Workspace.open(urlString: custom.text)
        }
      }
    }
  }
}
