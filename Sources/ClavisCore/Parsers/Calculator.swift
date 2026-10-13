import Foundation

public enum CalculatorError: Error, Equatable {
  case empty
  /// The input is plainly not arithmetic (no digits, no known names). Cheap
  /// rejection so the search store can try every keystroke.
  case notAnExpression
  case unexpectedToken(position: Int)
  case unknownIdentifier(String)
  case wrongArgumentCount(function: String)
}

/// Replaces expr-eval: `+ - * / % ^`, unary minus, parentheses, `pi`/`e`, and
/// the common math functions. Precedence-climbing parser over Double.
/// Division by zero yields infinity, as expr-eval did.
public enum Calculator {
  public static func evaluate(_ expression: String) throws -> Double {
    let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CalculatorError.empty }
    guard looksLikeExpression(trimmed) else { throw CalculatorError.notAnExpression }
    var parser = Parser(tokens: try Lexer.tokenize(trimmed))
    let value = try parser.parseExpression(minPrecedence: 0)
    guard parser.atEnd else { throw CalculatorError.unexpectedToken(position: parser.currentPosition) }
    return value
  }

  // Deliberate divergence from expr-eval, which only knew uppercase PI and E.
  static let constants: [String: Double] = ["pi": .pi, "e": M_E]

  static let unaryFunctions: [String: @Sendable (Double) -> Double] = [
    "sqrt": sqrt, "abs": abs, "floor": { $0.rounded(.down) }, "ceil": { $0.rounded(.up) },
    "round": { $0.rounded(.toNearestOrAwayFromZero) },
    "sin": sin, "cos": cos, "tan": tan,
    "log": log, "ln": log, "log10": log10, "log2": log2, "exp": exp,
  ]

  static let variadicFunctions: [String: @Sendable ([Double]) -> Double] = [
    "min": { $0.min()! }, "max": { $0.max()! },
  ]

  private static func looksLikeExpression(_ text: String) -> Bool {
    if text.contains(where: \.isNumber) { return true }
    let words = text.split { !($0.isLetter || $0 == "_") }.map { $0.lowercased() }
    return words.contains { constants[$0] != nil || unaryFunctions[$0] != nil || variadicFunctions[$0] != nil }
  }
}

enum Token: Equatable {
  case number(Double)
  case identifier(String)
  case op(Character)
  case lparen, rparen, comma
}

struct Lexer {
  static func tokenize(_ text: String) throws -> [(token: Token, position: Int)] {
    let chars = Array(text)
    var tokens: [(Token, Int)] = []
    var i = 0
    while i < chars.count {
      let c = chars[i]
      let start = i
      if c.isWhitespace {
        i += 1
      } else if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
        var j = i
        while j < chars.count, chars[j].isNumber { j += 1 }
        if j < chars.count, chars[j] == "." {
          j += 1
          while j < chars.count, chars[j].isNumber { j += 1 }
        }
        if j < chars.count, chars[j] == "e" || chars[j] == "E" {
          var k = j + 1
          if k < chars.count, chars[k] == "+" || chars[k] == "-" { k += 1 }
          if k < chars.count, chars[k].isNumber {
            while k < chars.count, chars[k].isNumber { k += 1 }
            j = k
          }
        }
        guard let value = Double(String(chars[i..<j])) else { throw CalculatorError.unexpectedToken(position: start) }
        tokens.append((.number(value), start))
        i = j
      } else if c.isLetter || c == "_" {
        var j = i
        while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
        tokens.append((.identifier(String(chars[i..<j]).lowercased()), start))
        i = j
      } else {
        switch c {
        case "+", "-", "*", "/", "%", "^": tokens.append((.op(c), start))
        case "(": tokens.append((.lparen, start))
        case ")": tokens.append((.rparen, start))
        case ",": tokens.append((.comma, start))
        default: throw CalculatorError.unexpectedToken(position: start)
        }
        i += 1
      }
    }
    return tokens.map { (token: $0.0, position: $0.1) }
  }
}

struct Parser {
  let tokens: [(token: Token, position: Int)]
  var index = 0

  init(tokens: [(token: Token, position: Int)]) {
    self.tokens = tokens
  }

  var atEnd: Bool { index >= tokens.count }
  var currentPosition: Int { atEnd ? (tokens.last.map { $0.position + 1 } ?? 0) : tokens[index].position }
  private var current: Token? { atEnd ? nil : tokens[index].token }

  private static let unaryMinusPrecedence = 25

  private static func precedence(of op: Character) -> Int {
    switch op {
    case "+", "-": return 10
    case "*", "/", "%": return 20
    case "^": return 30
    default: return 0
    }
  }

  mutating func parseExpression(minPrecedence: Int) throws -> Double {
    var left = try parsePrefix()
    while case .op(let op)? = current {
      let precedence = Self.precedence(of: op)
      guard precedence >= minPrecedence else { break }
      index += 1
      // `^` is right-associative: 2^3^2 == 2^(3^2).
      let right = try parseExpression(minPrecedence: op == "^" ? precedence : precedence + 1)
      left = Self.apply(op, left, right)
    }
    return left
  }

  private mutating func parsePrefix() throws -> Double {
    guard let token = current else { throw CalculatorError.unexpectedToken(position: currentPosition) }
    let position = currentPosition
    index += 1
    switch token {
    case .number(let value):
      return value
    case .op("-"):
      // Binds tighter than * but looser than ^: -2^2 == -(2^2).
      return -(try parseExpression(minPrecedence: Self.unaryMinusPrecedence))
    case .op("+"):
      return try parseExpression(minPrecedence: Self.unaryMinusPrecedence)
    case .lparen:
      let value = try parseExpression(minPrecedence: 0)
      try expect(.rparen)
      return value
    case .identifier(let name):
      if current == .lparen {
        index += 1
        return try parseCall(name, position: position)
      }
      guard let constant = Calculator.constants[name] else { throw CalculatorError.unknownIdentifier(name) }
      return constant
    default:
      throw CalculatorError.unexpectedToken(position: position)
    }
  }

  private mutating func parseCall(_ name: String, position: Int) throws -> Double {
    var arguments: [Double] = []
    if current != .rparen {
      repeat {
        arguments.append(try parseExpression(minPrecedence: 0))
        guard current == .comma else { break }
        index += 1
      } while true
    }
    try expect(.rparen)

    if let function = Calculator.unaryFunctions[name] {
      guard arguments.count == 1 else { throw CalculatorError.wrongArgumentCount(function: name) }
      return function(arguments[0])
    }
    if let function = Calculator.variadicFunctions[name] {
      guard !arguments.isEmpty else { throw CalculatorError.wrongArgumentCount(function: name) }
      return function(arguments)
    }
    throw CalculatorError.unknownIdentifier(name)
  }

  private mutating func expect(_ token: Token) throws {
    guard current == token else { throw CalculatorError.unexpectedToken(position: currentPosition) }
    index += 1
  }

  private static func apply(_ op: Character, _ a: Double, _ b: Double) -> Double {
    switch op {
    case "+": return a + b
    case "-": return a - b
    case "*": return a * b
    case "/": return a / b
    case "%": return a.truncatingRemainder(dividingBy: b)
    case "^": return pow(a, b)
    default: return .nan
    }
  }
}
