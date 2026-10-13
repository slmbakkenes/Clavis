import Foundation

/// Display metadata for a user script in ~/.config/clavis/scripts, read from
/// optional `# name:` and `# icon:` comment headers.
public struct ScriptMetadata: Equatable, Sendable {
  public var name: String
  public var icon: String

  public init(name: String, icon: String) {
    self.name = name
    self.icon = icon
  }

  public static let defaultIcon = "💻"
  public static let allowedExtensions = [".sh", ".applescript"]

  /// Case-sensitive suffix match, as the previous build's `endsWith` check.
  public static func isScript(fileName: String) -> Bool {
    allowedExtensions.contains { fileName.hasSuffix($0) }
  }

  // Mirrors /^#\s*name:\s*(.+)$/im. `\s*` may cross line breaks, as in JS.
  private static let namePattern = try! NSRegularExpression(
    pattern: #"^#\s*name:\s*(.+)$"#, options: [.caseInsensitive, .anchorsMatchLines])
  private static let iconPattern = try! NSRegularExpression(
    pattern: #"^#\s*icon:\s*(.+)$"#, options: [.caseInsensitive, .anchorsMatchLines])

  public static func parse(content: String, fileName: String) -> ScriptMetadata {
    // `fileName.replace(/\..*$/, "")`: drop everything from the first dot.
    let defaultName = fileName.firstIndex(of: ".").map { String(fileName[..<$0]) } ?? fileName
    return ScriptMetadata(
      name: firstCapture(of: namePattern, in: content) ?? defaultName,
      icon: firstCapture(of: iconPattern, in: content) ?? defaultIcon)
  }

  private static func firstCapture(of pattern: NSRegularExpression, in content: String) -> String? {
    let range = NSRange(content.startIndex..., in: content)
    guard let match = pattern.firstMatch(in: content, range: range),
      let captureRange = Range(match.range(at: 1), in: content)
    else { return nil }
    return content[captureRange].trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
