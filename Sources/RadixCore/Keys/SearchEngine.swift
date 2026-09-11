import Foundation

public enum SearchEngine: String, CaseIterable, Sendable, Codable {
  case google, bing, duckduckgo, perplexity, custom

  private static let customPattern = try! NSRegularExpression(
    pattern:
      #"^https?://(?:(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?|localhost|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?(/[^\s?#]*)?\?[\w-]+=%s$"#
  )

  /// A custom engine URL must be http(s), have a host, and end in `?<param>=%s`.
  public static func isValidCustomURL(_ url: String) -> Bool {
    if url.trimmingCharacters(in: .whitespaces).isEmpty { return false }
    return customPattern.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
  }

  /// Characters JavaScript's `encodeURI` leaves untouched.
  private static let encodeURIAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789;,/?:@&=+$-_.!~*'()#")

  static func encodeURI(_ text: String) -> String {
    text.addingPercentEncoding(withAllowedCharacters: encodeURIAllowed) ?? text
  }

  /// The URL to open for a web search, or nil when the custom URL is invalid.
  public func searchURL(for query: String, customSearchURL: String = "") -> String? {
    let encoded = Self.encodeURI(query)
    switch self {
    case .google: return "https://google.com/search?q=\(encoded)"
    case .duckduckgo: return "https://duckduckgo.com/?q=\(encoded)"
    case .bing: return "https://bing.com/search?q=\(encoded)"
    case .perplexity: return "https://perplexity.ai/search/new?q=\(encoded)"
    case .custom:
      guard Self.isValidCustomURL(customSearchURL) else { return nil }
      return customSearchURL.replacingOccurrences(of: "%s", with: encoded)
    }
  }
}
