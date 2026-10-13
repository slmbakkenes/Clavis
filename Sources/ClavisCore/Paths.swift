import Foundation

/// On-disk locations.
public enum Paths {
  public static let configDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config", isDirectory: true)
    .appendingPathComponent("clavis", isDirectory: true)

  public static let configFile = configDirectory.appendingPathComponent("config.json")
  public static let stateFile = configDirectory.appendingPathComponent("state.json")
  public static let scriptsDirectory = configDirectory.appendingPathComponent("scripts", isDirectory: true)
  public static let pasteboardImagesDirectory = configDirectory.appendingPathComponent(
    "images_pasteboard", isDirectory: true)

  /// Where the config lived while the app was called Radix.
  static let legacyConfigDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config", isDirectory: true)
    .appendingPathComponent("radix", isDirectory: true)

  /// Moves a config left at the Radix location to `configDirectory`, once:
  /// only when the new directory doesn't exist yet.
  public static func migrateLegacyConfigDirectory() {
    let fm = FileManager.default
    guard !fm.fileExists(atPath: configDirectory.path),
      fm.fileExists(atPath: legacyConfigDirectory.path)
    else { return }
    do {
      try fm.moveItem(at: legacyConfigDirectory, to: configDirectory)
    } catch {
      NSLog("Moving \(legacyConfigDirectory.path) to \(configDirectory.path): \(error)")
    }
  }
}
