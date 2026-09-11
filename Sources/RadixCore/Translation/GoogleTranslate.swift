import Foundation

public enum GoogleTranslateError: Error, Equatable, CustomStringConvertible {
  /// The body did not start with the batchexecute length-prefixed envelope.
  case missingLengthPrefix
  /// The envelope or the nested payload was not the JSON shape expected.
  case unexpectedShape(String)

  public var description: String {
    switch self {
    case .missingLengthPrefix: "Unexpected translation response (no length prefix)"
    case .unexpectedShape(let detail): "Unexpected translation response (\(detail))"
    }
  }
}

/// The pure parts of the unofficial Google Translate web client the previous
/// build used (`translator.ts`): token scraping, request building and response
/// parsing. Networking lives in the app target.
public enum GoogleTranslate {
  static let rpcID = "MkEWBc"

  /// The TS `extract`: the first `"key":"…"` value in the start page, or ""
  /// when absent.
  public static func extractToken(_ key: String, from page: String) -> String {
    let pattern = "\"\(NSRegularExpression.escapedPattern(for: key))\":\".*?\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: page, range: NSRange(page.startIndex..., in: page)),
      let range = Range(match.range, in: page)
    else { return "" }
    let found = page[range]
    return String(found.dropFirst(key.count + 4).dropLast())
  }

  /// Same parameters, in the same order and unencoded, as the TS
  /// `objToQueryString`.
  public static func batchExecuteURL(tld: String, sid: String, bl: String, requestID: Int) -> URL {
    let parameters: [(String, String)] = [
      ("rpcids", rpcID),
      ("f.sid", sid),
      ("bl", bl),
      ("hl", "en-US"),
      ("soc-app", "1"),
      ("soc-platform", "1"),
      ("soc-device", "1"),
      ("_reqid", String(requestID)),
      ("rt", "c"),
    ]
    let query = parameters.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    let base = "https://translate.google.\(tld)/_/TranslateWebserverUi/data/batchexecute?"
    if let url = URL(string: base + query) { return url }
    // Scraped tokens are normally URL-safe; encode only if they are not.
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    return URL(string: base + encoded)!
  }

  /// `f.req=` + encodeURIComponent(JSON.stringify(...)) + `&`, byte for byte.
  public static func requestBody(text: String, from: String, to: String) -> String {
    let inner = "[[\(jsonString(text)),\(jsonString(from)),\(jsonString(to)),true],[null]]"
    let outer = "[[[\(jsonString(rpcID)),\(jsonString(inner)),null,\(jsonString("generic"))]]]"
    return "f.req=" + encodeURIComponent(outer) + "&"
  }

  /// Extracts the translated text from a batchexecute response.
  public static func parseResponse(_ body: String) throws -> String {
    // `)]}'` plus two newlines, then a length-prefixed chunk.
    let bodyUnits = Array(body.utf16)
    guard bodyUnits.count > 6 else { throw GoogleTranslateError.missingLengthPrefix }
    let afterPrefix = String(decoding: bodyUnits[6...], as: UTF16.self)
    let digits = afterPrefix.prefix { $0.isASCII && $0.isNumber }
    guard !digits.isEmpty, let length = Int(digits) else {
      throw GoogleTranslateError.missingLengthPrefix
    }

    let envelope = try parseEnvelope(afterPrefix, digitCount: digits.count, length: length)
    guard let outer = envelope as? [Any], let first = outer.first as? [Any], first.count > 2,
      let payloadText = first[2] as? String
    else { throw GoogleTranslateError.unexpectedShape("envelope") }

    guard let payload = try? JSONSerialization.jsonObject(with: Data(payloadText.utf8), options: .fragmentsAllowed)
    else { throw GoogleTranslateError.unexpectedShape("payload is not JSON") }
    guard let root = payload as? [Any], root.count > 1, let second = root[1] as? [Any],
      let level2 = second.first as? [Any], let level3 = level2.first as? [Any], !level3.isEmpty
    else { throw GoogleTranslateError.unexpectedShape("translation node") }

    if level3.count > 5, let parts = level3[5] as? [Any] {
      return parts.compactMap { ($0 as? [Any])?.first as? String }.filter { !$0.isEmpty }.joined()
    }
    guard let text = level3[0] as? String else {
      throw GoogleTranslateError.unexpectedShape("translation text")
    }
    return text
  }

  // MARK: Private

  /// The TS slices by UTF-16 code units after the digits. If that slice does
  /// not parse (a length counted differently), fall back to the chunk's line.
  private static func parseEnvelope(_ text: String, digitCount: Int, length: Int) throws -> Any {
    let units = Array(text.utf16)
    let start = min(digitCount, units.count)
    let end = min(digitCount + length, units.count)
    let sliced = String(decoding: units[start..<end], as: UTF16.self)
    if let object = try? JSONSerialization.jsonObject(with: Data(sliced.utf8), options: .fragmentsAllowed) {
      return object
    }
    let remainder = text.dropFirst(digitCount).drop { $0 == "\n" }
    let line = remainder.prefix { $0 != "\n" }
    guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8), options: .fragmentsAllowed) else {
      throw GoogleTranslateError.unexpectedShape("envelope is not JSON")
    }
    return object
  }

  /// JSON.stringify for a string: escapes `"`, `\`, the short control escapes
  /// and other C0 controls as lowercase `\u00xx`; leaves `/` and non-ASCII.
  static func jsonString(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
      switch scalar {
      case "\"": result += "\\\""
      case "\\": result += "\\\\"
      case "\n": result += "\\n"
      case "\r": result += "\\r"
      case "\t": result += "\\t"
      case "\u{08}": result += "\\b"
      case "\u{0C}": result += "\\f"
      case _ where scalar.value < 0x20:
        result += String(format: "\\u%04x", scalar.value)
      default:
        result.unicodeScalars.append(scalar)
      }
    }
    return result + "\""
  }

  /// JavaScript's encodeURIComponent leaves only these unescaped.
  private static let uriComponentAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")

  static func encodeURIComponent(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed) ?? value
  }
}
