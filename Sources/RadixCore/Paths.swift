import Foundation

/// On-disk locations. They are the ones the React Native version used, so an
/// existing configuration carries over unchanged.
public enum Paths {
  public static let configDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config", isDirectory: true)
    .appendingPathComponent("radix", isDirectory: true)

  public static let configFile = configDirectory.appendingPathComponent("config.json")
  public static let stateFile = configDirectory.appendingPathComponent("state.json")
  public static let scriptsDirectory = configDirectory.appendingPathComponent("scripts", isDirectory: true)
  public static let pasteboardImagesDirectory = configDirectory.appendingPathComponent(
    "images_pasteboard", isDirectory: true)
}
