import RadixCore

/// One row in the search widget. The temporary result (calculator, unit or
/// timezone conversion) is not an item, but it is selectable like one.
enum SearchRow: Identifiable {
  case temporaryResult(TemporaryResult)
  case item(Item)

  var id: String {
    switch self {
    case .temporaryResult: "temporary_result"
    case .item(let item): item.id
    }
  }
}
