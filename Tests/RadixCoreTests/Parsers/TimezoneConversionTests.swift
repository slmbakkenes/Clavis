import Foundation
import Testing
@testable import RadixCore

@Suite struct TimezoneConversionTests {
  // Monday 2026-09-07 12:00:00 UTC.
  private let now = Date(timeIntervalSince1970: 1_788_782_400)
  private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!

  private func parse(_ query: String) -> TemporaryResult? {
    TimezoneConversion.parse(query, now: now, localZone: amsterdam)
  }

  @Test func sourceToLocal() {
    #expect(
      parse("10am EST")
        == .comparison(
          left: .init(label: "EST", value: "Mon 07 Sep 10:00"),
          right: .init(label: "CEST", value: "Mon 07 Sep 17:00")))
  }

  @Test func sourceToExplicitTarget() {
    #expect(
      parse("14:30 PST to CET")
        == .comparison(
          left: .init(label: "PST", value: "Mon 07 Sep 14:30"),
          right: .init(label: "CET", value: "Mon 07 Sep 23:30")))
    #expect(
      parse("11pm jst to utc")
        == .comparison(
          left: .init(label: "JST", value: "Mon 07 Sep 23:00"),
          right: .init(label: "UTC", value: "Mon 07 Sep 14:00")))
  }

  @Test func dayWordsAndLocalKeyword() {
    #expect(
      parse("tomorrow 9am JST to local")
        == .comparison(
          left: .init(label: "JST", value: "Tue 08 Sep 09:00"),
          right: .init(label: "CEST", value: "Tue 08 Sep 02:00")))
    #expect(
      parse("yesterday 12am UTC")
        == .comparison(
          left: .init(label: "UTC", value: "Sun 06 Sep 00:00"),
          right: .init(label: "CEST", value: "Sun 06 Sep 02:00")))
  }

  @Test func nowKeyword() {
    #expect(
      parse("now UTC")
        == .comparison(
          left: .init(label: "UTC", value: "Mon 07 Sep 12:00"),
          right: .init(label: "CEST", value: "Mon 07 Sep 14:00")))
  }

  @Test func localZoneWithoutAbbreviationFallsBackToIdentifier() {
    let result = TimezoneConversion.parse("10am EST", now: now, localZone: TimeZone(secondsFromGMT: 3600)!)
    guard case .comparison(_, let right, _)? = result else { Issue.record("no result"); return }
    #expect(right.label == "GMT+0100")
  }

  @Test func rejectsUnknownZonesAndPlainText() {
    #expect(parse("10am XYZ") == nil)
    #expect(parse("10am EST to XYZ") == nil)
    #expect(parse("13pm EST") == nil)
    #expect(parse("10:75 EST") == nil)
    #expect(parse("open safari") == nil)
    #expect(parse("safari") == nil)
  }

  @Test func timeExpressionParsing() {
    #expect(TimeExpression.parse("12am") == TimeExpression(dayOffset: 0, hour: 0, minute: 0, isNow: false))
    #expect(TimeExpression.parse("12pm") == TimeExpression(dayOffset: 0, hour: 12, minute: 0, isNow: false))
    #expect(TimeExpression.parse("22:15") == TimeExpression(dayOffset: 0, hour: 22, minute: 15, isNow: false))
    #expect(TimeExpression.parse("24:00") == nil)
  }
}
