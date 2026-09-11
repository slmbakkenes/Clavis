/// Which content the panel is showing. Raw values match the old `Widget`
/// enum so log lines and any persisted references stay comparable.
enum Widget: String, CaseIterable, Sendable {
  case search = "SEARCH"
  case translation = "TRANSLATION"
  case settings = "SETTINGS"
  case createItem = "CREATE_ITEM"
  case scratchpad = "SCRATCHPAD"
  case clipboard = "CLIPBOARD"
  case processes = "PROCESSES"
  case fileSearch = "FILE_SEARCH"
}

/// What the panel was asked to open with. `onShow(target: "SETTINGS")` in the
/// old build.
enum ShowTarget: Sendable {
  case `default`
  case settings
}
