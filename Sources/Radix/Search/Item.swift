import RadixCore

/// Something the search widget can list and run: an application, a built-in
/// command, a preference pane, a bookmark, a custom item.
struct Item: Identifiable, Rankable {
  enum Kind: Sendable {
    case application
    case configuration
    case preferencePane
    case bookmark
    case custom
    /// A user script from ~/.config/radix/scripts.
    case script
  }

  enum Icon: Equatable, Sendable {
    /// The Finder icon of a path (apps, folders, preference panes). `~` is expanded.
    case file(String)
    /// An SF Symbol name.
    case symbol(String)
    /// A custom item's SF Symbol, tinted with its chosen `#rrggbb` colour.
    case customSymbol(String, colorHex: String?)
    case emoji(String)
    /// The icon of the app with this bundle identifier (bookmark sources).
    case application(bundleIdentifier: String)
    case none
  }

  /// Runs the item. Thrown errors are shown to the user as an error toast.
  typealias Action = @MainActor (AppModel) async throws -> Void

  /// Stable across launches: frequencies and shortcuts in config are keyed
  /// by it. Apps use their file URL string, as the previous build did.
  let id: String
  let kind: Kind
  let name: String
  var localizedName: String?
  /// Secondary match field, e.g. app initials ("vsc" for Visual Studio Code).
  var alias: String?
  /// Trailing detail text: bookmark folder, "Custom", and so on.
  var subtitle: String?
  var icon: Icon = .none
  var isRunning = false
  /// Leave the panel open after running (the action changes widget, say).
  var keepsPanelOpen = false
  /// When set, a confirmation with this title is shown before running.
  var confirmationTitle: String?
  let perform: Action
}

/// An error whose message is meant for the user as-is.
struct UserFacingError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}
