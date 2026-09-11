import Foundation

/// Parses queries like `12 km to miles`, `3.5kg in lbs`, `100 f to c`.
public enum UnitConversion {
  public static func parse(_ query: String) -> TemporaryResult? {
    let normalized =
      query
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: ",", with: "")
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    guard
      let match = pattern.firstMatch(
        in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
      let valueRange = Range(match.range(at: 1), in: normalized),
      let fromRange = Range(match.range(at: 2), in: normalized),
      let toRange = Range(match.range(at: 3), in: normalized),
      let value = Double(normalized[valueRange])
    else { return nil }

    let fromSymbol = normalizeUnit(String(normalized[fromRange]))
    let toSymbol = normalizeUnit(String(normalized[toRange]))
    guard let from = units[fromSymbol], let to = units[toSymbol],
      from.category == to.category
    else { return nil }

    let converted = Measurement(value: value, unit: from.unit).converted(to: to.unit).value
    return .comparison(
      left: .init(label: fromSymbol, value: formatConvertedValue(value)),
      right: .init(label: toSymbol, value: formatConvertedValue(converted)))
  }

  private static let pattern = try! NSRegularExpression(
    pattern: #"^(-?\d*\.?\d+)\s*([a-zA-Z]+)\s*(?:to|in)\s*([a-zA-Z]+)$"#, options: .caseInsensitive)

  private static func normalizeUnit(_ raw: String) -> String {
    let normalized = raw.trimmingCharacters(in: .whitespaces).lowercased()
      .replacingOccurrences(of: " ", with: "")
    if let alias = aliases[normalized] { return alias }
    switch normalized {
    case "c": return "C"
    case "f": return "F"
    case "k": return "K"
    default: return normalized
    }
  }

  private static let aliases: [String: String] = [
    "meter": "m", "meters": "m", "metre": "m", "metres": "m",
    "kilometer": "km", "kilometers": "km", "kilometre": "km", "kilometres": "km",
    "centimeter": "cm", "centimeters": "cm", "centimetre": "cm", "centimetres": "cm",
    "millimeter": "mm", "millimeters": "mm", "millimetre": "mm", "millimetres": "mm",
    "inch": "in", "inches": "in",
    "foot": "ft", "feet": "ft",
    "yard": "yd", "yards": "yd",
    "mile": "mi", "miles": "mi",
    "gram": "g", "grams": "g",
    "kilogram": "kg", "kilograms": "kg",
    "mg": "mg", "milligram": "mg", "milligrams": "mg",
    "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb",
    "oz": "oz", "ounce": "oz", "ounces": "oz",
    "liter": "l", "liters": "l", "litre": "l", "litres": "l",
    "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml",
    "second": "s", "seconds": "s", "sec": "s",
    "minute": "min", "minutes": "min",
    "hour": "h", "hours": "h",
    "day": "d", "days": "d",
    "celsius": "C", "fahrenheit": "F", "kelvin": "K",
  ]

  private struct Entry {
    let category: String
    let unit: Dimension
  }

  /// Conversions only happen within a category; Foundation traps when asked to
  /// convert across dimensions.
  private static let units: [String: Entry] = {
    var table: [String: Entry] = [:]
    func add(_ category: String, _ entries: [(String, Dimension)]) {
      for (symbol, unit) in entries { table[symbol] = Entry(category: category, unit: unit) }
    }
    add(
      "length",
      [
        ("m", UnitLength.meters), ("km", UnitLength.kilometers), ("cm", UnitLength.centimeters),
        ("mm", UnitLength.millimeters), ("in", UnitLength.inches), ("ft", UnitLength.feet),
        ("yd", UnitLength.yards), ("mi", UnitLength.miles),
      ])
    add(
      "mass",
      [
        ("g", UnitMass.grams), ("kg", UnitMass.kilograms), ("mg", UnitMass.milligrams),
        ("lb", UnitMass.pounds), ("oz", UnitMass.ounces),
      ])
    add("volume", [("l", UnitVolume.liters), ("ml", UnitVolume.milliliters)])
    add(
      "duration",
      [
        ("s", UnitDuration.seconds), ("min", UnitDuration.minutes), ("h", UnitDuration.hours),
        // Foundation has no day unit.
        ("d", UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))),
      ])
    add(
      "temperature",
      [
        ("C", UnitTemperature.celsius), ("F", UnitTemperature.fahrenheit), ("K", UnitTemperature.kelvin),
      ])
    // Deliberate divergence from the RN build: convert-units rejected these
    // lowercase symbols, and Foundation's kilobyte is decimal (1000 bytes).
    add(
      "storage",
      [
        ("b", UnitInformationStorage.bytes), ("kb", UnitInformationStorage.kilobytes),
        ("mb", UnitInformationStorage.megabytes), ("gb", UnitInformationStorage.gigabytes),
        ("tb", UnitInformationStorage.terabytes),
      ])
    return table
  }()
}
