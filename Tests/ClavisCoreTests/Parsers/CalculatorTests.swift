import Foundation
import Testing
@testable import ClavisCore

@Suite struct CalculatorTests {
  @Test func precedenceAndAssociativity() throws {
    #expect(try Calculator.evaluate("1 + 2 * 3") == 7)
    #expect(try Calculator.evaluate("(1 + 2) * 3") == 9)
    #expect(try Calculator.evaluate("10 - 4 - 3") == 3)
    #expect(try Calculator.evaluate("2 ^ 3 ^ 2") == 512)
    #expect(try Calculator.evaluate("-2 ^ 2") == -4)
    #expect(try Calculator.evaluate("-2 * 3") == -6)
    #expect(try Calculator.evaluate("10 % 3") == 1)
    #expect(try Calculator.evaluate("7 / 2") == 3.5)
  }

  @Test func literals() throws {
    #expect(try Calculator.evaluate(".5 + .5") == 1)
    #expect(try Calculator.evaluate("1e3") == 1000)
    #expect(try Calculator.evaluate("2.5e-1") == 0.25)
    #expect(try Calculator.evaluate("42") == 42)
  }

  @Test func constantsAndFunctions() throws {
    #expect(try Calculator.evaluate("pi") == .pi)
    #expect(try Calculator.evaluate("E") == M_E)
    #expect(try Calculator.evaluate("sqrt(16)") == 4)
    #expect(try Calculator.evaluate("abs(-3)") == 3)
    #expect(try Calculator.evaluate("floor(2.7) + ceil(2.2)") == 5)
    #expect(try Calculator.evaluate("round(2.5)") == 3)
    #expect(try Calculator.evaluate("max(1, 5, 3) - min(4, 2)") == 3)
    #expect(try Calculator.evaluate("log(e)") == 1)
    #expect(try Calculator.evaluate("log10(1000)") == 3)
    #expect(try Calculator.evaluate("log2(8)") == 3)
    #expect(try Calculator.evaluate("cos(0)") == 1)
  }

  @Test func divisionByZeroIsInfinity() throws {
    #expect(try Calculator.evaluate("1 / 0") == .infinity)
  }

  @Test func errors() {
    #expect(throws: CalculatorError.empty) { try Calculator.evaluate("   ") }
    #expect(throws: CalculatorError.unknownIdentifier("foo")) { try Calculator.evaluate("foo + 1") }
    #expect(throws: CalculatorError.unexpectedToken(position: 4)) { try Calculator.evaluate("(1 +") }
    #expect(throws: CalculatorError.unexpectedToken(position: 2)) { try Calculator.evaluate("1 )") }
    #expect(throws: CalculatorError.wrongArgumentCount(function: "sqrt")) { try Calculator.evaluate("sqrt(1, 2)") }
    #expect(throws: CalculatorError.unexpectedToken(position: 1)) { try Calculator.evaluate("1$2") }
  }

  @Test func plainTextIsRejectedCheaply() {
    for query in ["safari", "open finder", "hello world", "settings", "https://example.com"] {
      #expect(throws: CalculatorError.notAnExpression, "\(query)") { try Calculator.evaluate(query) }
    }
    // A URL with digits fails at the lexer instead, still no result.
    #expect(throws: CalculatorError.self) { try Calculator.evaluate("web.dev/2024") }
  }
}
