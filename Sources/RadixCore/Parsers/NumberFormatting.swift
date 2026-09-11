import Foundation

private let expressionResultDecimals = 12

/// Formats a calculator result: rounded to 12 decimals, then printed like
/// `Number.prototype.toString()`. Deliberate divergence from the old
/// JavaScript: whole numbers skip the rounding step (see `roundedJS`).
public func formatExpressionResult(_ value: Double) -> String {
  jsNumberString(roundedJS(value, decimals: expressionResultDecimals))
}

/// Six-decimal variant used for converted unit values.
func formatConvertedValue(_ value: Double) -> String {
  jsNumberString(roundedJS(value, decimals: 6))
}

/// `Math.round((value + Number.EPSILON) * scale) / scale`. JS Math.round is
/// round-half-up, hence `floor(x + 0.5)` rather than Swift's `rounded()`.
private func roundedJS(_ value: Double, decimals: Int) -> Double {
  // Whole numbers are returned as-is: pushing them through the scale loses
  // precision past 2^53 (the JS original printed 123456789012345.02).
  guard value.isFinite, value != value.rounded() else { return value }
  let scale = pow(10.0, Double(decimals))
  return ((value + Double.ulpOfOne) * scale + 0.5).rounded(.down) / scale
}

/// Approximates JavaScript's `Number.prototype.toString()`: integers without a
/// fractional part, shortest round-trip digits otherwise, `Infinity`/`NaN`
/// spelled out, and `-0` printed as `0`.
func jsNumberString(_ value: Double) -> String {
  if value.isNaN { return "NaN" }
  if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
  if value == 0 { return "0" }
  if value == value.rounded(), abs(value) < 1e21 {
    return String(format: "%.0f", value)
  }
  // Swift's description is shortest-round-trip like JS, but writes exponents
  // as e-07 where JS writes e-7, and switches to exponent form below 1e-4
  // where JS only does so below 1e-6.
  var text = value.description
  if let range = text.range(of: "e[+-]0+", options: .regularExpression) {
    let exponentPrefix = text[range].prefix(2)
    text.replaceSubrange(range, with: exponentPrefix)
  }
  if abs(value) >= 1e-6, abs(value) < 1e-4, let fixed = fixedNotation(fromExponential: text) {
    return fixed
  }
  return text
}

/// "1.2345e-6" -> "0.0000012345". Only handles negative exponents, which is
/// all the 1e-6...1e-4 band needs.
private func fixedNotation(fromExponential text: String) -> String? {
  let parts = text.split(separator: "e")
  guard parts.count == 2, let exponent = Int(parts[1]), exponent < 0 else { return nil }
  var mantissa = String(parts[0])
  let negative = mantissa.hasPrefix("-")
  if negative { mantissa.removeFirst() }
  let pieces = mantissa.split(separator: ".", omittingEmptySubsequences: false)
  let integerDigits = String(pieces[0])
  let fractionDigits = pieces.count > 1 ? String(pieces[1]) : ""
  let zeros = String(repeating: "0", count: -exponent - integerDigits.count)
  return (negative ? "-" : "") + "0." + zeros + integerDigits + fractionDigits
}
