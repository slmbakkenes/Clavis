import Testing
@testable import ClavisCore

@Suite struct NumberFormattingTests {
  @Test func integers() {
    #expect(formatExpressionResult(4) == "4")
    #expect(formatExpressionResult(-12) == "-12")
    #expect(formatExpressionResult(0.1 + 0.2) == "0.3")
  }

  @Test func twelveDecimalRounding() {
    #expect(formatExpressionResult(1.0 / 3.0) == "0.333333333333")
    #expect(formatExpressionResult(2.0 / 3.0) == "0.666666666667")
    #expect(formatExpressionResult(1.5) == "1.5")
  }

  @Test func largeAndSmall() {
    #expect(formatExpressionResult(1e21) == "1e+21")
    #expect(formatExpressionResult(123456789012345) == "123456789012345")
    #expect(formatExpressionResult(1e-7) == "1e-7")
    // JS stays in fixed notation down to 1e-6; Double.description does not.
    #expect(formatExpressionResult(0.00001) == "0.00001")
    #expect(formatExpressionResult(0.000001) == "0.000001")
    #expect(formatExpressionResult(0.0000012345) == "0.0000012345")
    #expect(formatExpressionResult(-0.0000012345) == "-0.0000012345")
    #expect(formatExpressionResult(0.0001) == "0.0001")
    #expect(formatExpressionResult(0.000123) == "0.000123")
    #expect(formatConvertedValue(0.000001) == "0.000001")
    #expect(formatExpressionResult(1e-13) == "0")
  }

  @Test func specialValues() {
    #expect(formatExpressionResult(-0.0) == "0")
    #expect(formatExpressionResult(.infinity) == "Infinity")
    #expect(formatExpressionResult(-.infinity) == "-Infinity")
    #expect(formatExpressionResult(.nan) == "NaN")
  }

  @Test func convertedValuesUseSixDecimals() {
    #expect(formatConvertedValue(1.0 / 3.0) == "0.333333")
    #expect(formatConvertedValue(10) == "10")
  }
}
