import Testing
@testable import RadixCore

@Suite struct UnitConversionTests {
  private func right(_ query: String) -> (label: String, value: String)? {
    guard case .comparison(_, let right, _)? = UnitConversion.parse(query) else { return nil }
    return (right.label, right.value)
  }

  @Test func lengthWithAliases() {
    #expect(right("1 km to m")?.value == "1000")
    #expect(right("10 kilometers to miles")?.value == "6.213712")
    #expect(right("12 inches in feet")?.value == "1")
    #expect(right("1,000 metres to km")?.value == "1")
  }

  @Test func massVolumeDurationStorage() {
    #expect(right("2 lbs to kg")?.value == "0.907184")
    #expect(right("1 kg to grams")?.value == "1000")
    #expect(right("1.5 l to ml")?.value == "1500")
    #expect(right("2 days to hours")?.value == "48")
    #expect(right("90 sec to min")?.value == "1.5")
    #expect(right("1 gb to mb")?.value == "1000")
  }

  @Test func temperature() {
    #expect(right("100 c to f")?.value == "212")
    #expect(right("32 fahrenheit to celsius")?.value == "0")
    #expect(right("0 C in K")?.value == "273.15")
    #expect(right("-40 f to c")?.value == "-40")
  }

  @Test func labelsAreNormalizedSymbols() {
    let result = UnitConversion.parse("3 Kilometres to Miles")
    #expect(
      result
        == .comparison(
          left: .init(label: "km", value: "3"),
          right: .init(label: "mi", value: "1.864114")))
  }

  @Test func invalidInputIsNil() {
    #expect(UnitConversion.parse("km to m") == nil)
    #expect(UnitConversion.parse("5 km to kg") == nil)
    #expect(UnitConversion.parse("5 parsecs to m") == nil)
    #expect(UnitConversion.parse("5 km") == nil)
    #expect(UnitConversion.parse("safari") == nil)
  }

  @Test func clipboardText() {
    #expect(UnitConversion.parse("1 km to m")?.clipboardText == "1 km = 1000 m")
  }
}
