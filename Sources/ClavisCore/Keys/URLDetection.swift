import Foundation

/// Decides whether a query looks like a URL. `isLooseURL` accepts a bare host
/// ("github.com/foo"); `isStrictURL` requires an http(s)/ftp scheme.
public enum URLDetection {
  private static let hostAndPath =
    // user:pass authentication
    #"(?:\S+(?::\S*)?@)?"# + #"(?:"#
    // private & local networks excluded
    + #"(?!(?:10|127)(?:\.\d{1,3}){3})"# + #"(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})"#
    + #"(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})"#
    // IP address dotted notation octets
    + #"(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])"# + #"(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}"#
    + #"(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))"# + #"|"#
    // host name
    + #"(?:(?:[a-z¡-￿0-9]-*)*[a-z¡-￿0-9]+)"#
    // domain name
    + #"(?:\.(?:[a-z¡-￿0-9]-*)*[a-z¡-￿0-9]+)*"#
    // TLD identifier, may end with a dot
    + #"(?:\.(?:[a-z¡-￿]{2,}))"# + #"\.?"# + #")"#
    // port number
    + #"(?::\d{2,5})?"#
    // resource path
    + #"(?:[/?#]\S*)?"#

  private static let strict = try! NSRegularExpression(
    pattern: "^(?:(?:https?|ftp)://)" + hostAndPath + "$", options: [.caseInsensitive])
  private static let loose = try! NSRegularExpression(
    pattern: "^" + hostAndPath + "$", options: [.caseInsensitive])

  public static func isStrictURL(_ text: String) -> Bool { matches(strict, text) }
  public static func isLooseURL(_ text: String) -> Bool { matches(loose, text) }

  private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
    let range = NSRange(text.startIndex..., in: text)
    return regex.firstMatch(in: text, range: range) != nil
  }
}
