import Foundation

/// Parses queries like `10am EST`, `14:30 PST to CET`, `tomorrow 9am JST to local`
/// and shows the time in the source zone next to the target zone.
public enum TimezoneConversion {
  /// `now` and `localZone` are injectable for tests; production callers use
  /// the defaults.
  public static func parse(
    _ query: String, now: Date = Date(), localZone: TimeZone = .current
  ) -> TemporaryResult? {
    let normalized =
      query
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    guard
      let match = pattern.firstMatch(
        in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
      let expressionRange = Range(match.range(at: 1), in: normalized),
      let sourceRange = Range(match.range(at: 2), in: normalized)
    else { return nil }

    let sourceAbbreviation = normalized[sourceRange].uppercased()
    guard let sourceOffset = abbreviationOffsets[sourceAbbreviation] else { return nil }
    let sourceZone = fixedZone(minutes: sourceOffset)

    var targetZone = localZone
    var targetLabel: String?
    if let targetRange = Range(match.range(at: 3), in: normalized) {
      let target = normalized[targetRange].uppercased()
      if target != "LOCAL" {
        guard let targetOffset = abbreviationOffsets[target] else { return nil }
        targetZone = fixedZone(minutes: targetOffset)
        targetLabel = target
      }
    }

    guard
      let instant = TimeExpression.parse(String(normalized[expressionRange]))?
        .resolve(now: now, in: sourceZone)
    else { return nil }

    if targetLabel == nil {
      let short = localZone.abbreviation(for: instant) ?? ""
      let isGeneric = short.isEmpty || short.uppercased().hasPrefix("GMT") || short.uppercased().hasPrefix("UTC")
      targetLabel = isGeneric ? localZone.identifier : short
    }

    return .comparison(
      left: .init(label: sourceAbbreviation, value: format(instant, in: sourceZone)),
      right: .init(label: targetLabel!, value: format(instant, in: targetZone)))
  }

  private static let pattern = try! NSRegularExpression(
    pattern: #"^(.+?)\s+([A-Za-z]{2,5})(?:\s+to\s+([A-Za-z]{2,10}))?$"#, options: .caseInsensitive)

  static let abbreviationOffsets: [String: Int] = [
    "UTC": 0, "GMT": 0,
    "EST": -300, "EDT": -240, "CST": -360, "CDT": -300,
    "MST": -420, "MDT": -360, "PST": -480, "PDT": -420,
    "CET": 60, "CEST": 120, "EET": 120, "EEST": 180, "BST": 60,
    "IST": 330, "JST": 540,
    "AEST": 600, "AEDT": 660, "ACST": 570, "ACDT": 630, "AWST": 480,
  ]

  private static func fixedZone(minutes: Int) -> TimeZone {
    TimeZone(secondsFromGMT: minutes * 60)!
  }

  private static let posix = Locale(identifier: "en_US_POSIX")

  /// "Thu 11 Sep 14:30". A value-type format style instead of a DateFormatter
  /// per call; this runs on every keystroke.
  private static func format(_ date: Date, in zone: TimeZone) -> String {
    let style = Date.VerbatimFormatStyle(
      format: """
        \(weekday: .abbreviated) \(day: .twoDigits) \(month: .abbreviated) \
        \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)
        """,
      locale: posix, timeZone: zone, calendar: Calendar(identifier: .gregorian))
    return date.formatted(style)
  }
}

/// The subset of natural-language time the old chrono-node integration was
/// used for: `now`, `10am`, `10:30pm`, `22:15`, optionally prefixed with
/// `today`, `tomorrow` or `yesterday`.
struct TimeExpression: Equatable {
  var dayOffset: Int
  var hour: Int
  var minute: Int
  /// `now` keeps the current wall-clock time instead of a fixed hour.
  var isNow: Bool

  static func parse(_ text: String) -> TimeExpression? {
    let lowered = text.lowercased().trimmingCharacters(in: .whitespaces)
    if lowered == "now" { return TimeExpression(dayOffset: 0, hour: 0, minute: 0, isNow: true) }

    guard let match = pattern.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered))
    else { return nil }

    func group(_ index: Int) -> String? {
      Range(match.range(at: index), in: lowered).map { String(lowered[$0]) }
    }

    let dayOffset: Int
    switch group(1) {
    case "tomorrow": dayOffset = 1
    case "yesterday": dayOffset = -1
    default: dayOffset = 0
    }

    guard var hour = group(2).flatMap(Int.init) else { return nil }
    let minute = group(3).flatMap(Int.init) ?? 0
    guard minute < 60 else { return nil }

    switch group(4) {
    case "am":
      guard (1...12).contains(hour) else { return nil }
      if hour == 12 { hour = 0 }
    case "pm":
      guard (1...12).contains(hour) else { return nil }
      if hour != 12 { hour += 12 }
    default:
      guard hour < 24 else { return nil }
    }

    return TimeExpression(dayOffset: dayOffset, hour: hour, minute: minute, isNow: false)
  }

  private static let pattern = try! NSRegularExpression(
    pattern: #"^(?:(today|tomorrow|yesterday)\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$"#)

  /// The instant this expression denotes when read as wall-clock time in `zone`.
  func resolve(now: Date, in zone: TimeZone) -> Date? {
    if isNow { return now }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
    var components = calendar.dateComponents([.year, .month, .day], from: day)
    components.hour = hour
    components.minute = minute
    components.second = 0
    return calendar.date(from: components)
  }
}
