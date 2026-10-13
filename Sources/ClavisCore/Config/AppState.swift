import Foundation

/// Runtime state, persisted as `~/.config/clavis/state.json`.
public struct AppState: Codable, Equatable, Sendable {
  /// Item id (legacy: item name) → selection count, normalised to ≤ 100.
  public var frequencies: [String: Int]
  /// Item id → last selection time in epoch milliseconds (`Date.now()`).
  public var selectionTimestamps: [String: Double]
  /// Previously executed queries, oldest first.
  public var history: [String]
  /// Scratchpad contents.
  public var note: String
  public var clipboard: ClipboardState

  public init(
    frequencies: [String: Int] = [:],
    selectionTimestamps: [String: Double] = [:],
    history: [String] = [],
    note: String = "",
    clipboard: ClipboardState = ClipboardState()
  ) {
    self.frequencies = frequencies
    self.selectionTimestamps = selectionTimestamps
    self.history = history
    self.note = note
    self.clipboard = clipboard
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = AppState()
    // The TS store rescales counts to 0...100 when any exceed 100; the JS
    // writer may also have stored fractional numbers, so accept Double.
    let rawFrequencies = try c.decodeIfPresent([String: Double].self, forKey: .frequencies) ?? [:]
    frequencies = AppState.normalise(rawFrequencies)
    selectionTimestamps =
      try c.decodeIfPresent([String: Double].self, forKey: .selectionTimestamps) ?? d.selectionTimestamps
    history = try c.decodeIfPresent([String].self, forKey: .history) ?? d.history
    note = try c.decodeIfPresent(String.self, forKey: .note) ?? d.note
    clipboard = try c.decodeIfPresent(ClipboardState.self, forKey: .clipboard) ?? d.clipboard
  }

  /// Rescales counts to 0...100 when any exceed 100 (as the TS hydrate did)
  /// and clamps everything else, so a state.json written by another process
  /// can never trap the Int conversion.
  static func normalise(_ raw: [String: Double]) -> [String: Int] {
    let upper = raw.values.max() ?? 0
    let scale = upper > 100 ? 100 / upper : 1
    return raw.mapValues { value in
      let scaled = (value * scale).rounded(.down)
      return Int(exactly: min(max(scaled, 0), 100)) ?? 0
    }
  }
}

public struct ClipboardState: Codable, Equatable, Sendable {
  public var saveHistory: Bool

  public init(saveHistory: Bool = false) {
    self.saveHistory = saveHistory
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    saveHistory = try c.decodeIfPresent(Bool.self, forKey: .saveHistory) ?? false
  }
}
