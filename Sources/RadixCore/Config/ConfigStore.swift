import Foundation

public enum ConfigStoreError: Error, Equatable {
  /// A file exists but is not a JSON object.
  case notAnObject(URL)
}

/// Loads and saves `config.json` and `state.json`.
///
/// Reads go through the raw JSON dictionaries first so the same one-way
/// migration as `persisted-config.ts` can run: runtime keys that still live
/// in `config.json` are moved into `state.json` and removed from the config.
/// Decode errors propagate; nothing is silently replaced by defaults.
///
/// Saves re-read the file and replace only the keys the model owns, so keys
/// written by the RN build or edited by hand (`keymap`, anything newer than
/// this model) survive. Passing the value the caller last loaded or saved
/// (`changedFrom:`) narrows that further to the keys whose values actually
/// changed, so a save cannot revert an edit another process made to an
/// unrelated key since launch. Output formatting differs from `JSON.stringify`:
/// Foundation writes `"key" : value` with sorted keys. Both builds parse
/// either form; the whole-file diff on the first Swift save is accepted.
public final class ConfigStore: Sendable {
  static let runtimeKeys = ["frequencies", "selectionTimestamps", "history", "note", "clipboard"]

  public let configURL: URL
  public let stateURL: URL

  public init(configURL: URL = Paths.configFile, stateURL: URL = Paths.stateFile) {
    self.configURL = configURL
    self.stateURL = stateURL
  }

  /// Creates the config directory and default files when missing, migrates
  /// legacy runtime keys, and returns both decoded values.
  public func load() throws -> (config: Config, state: AppState) {
    try ensureDirectory(configURL.deletingLastPathComponent())
    try ensureDirectory(stateURL.deletingLastPathComponent())

    var rawConfig = try readObject(configURL) ?? [:]
    var rawState = try readObject(stateURL) ?? [:]

    let legacy = rawConfig.filter { Self.runtimeKeys.contains($0.key) }
    if !legacy.isEmpty {
      // Existing state.json values win over the legacy copy, as in the TS.
      rawState.merge(legacy) { current, _ in current }
      for key in Self.runtimeKeys { rawConfig.removeValue(forKey: key) }
      try writeObject(rawState, to: stateURL)
      try writeObject(rawConfig, to: configURL)
    }

    let config = try decode(Config.self, from: rawConfig)
    let state = try decode(AppState.self, from: rawState)

    if !FileManager.default.fileExists(atPath: configURL.path) { try save(config) }
    if !FileManager.default.fileExists(atPath: stateURL.path) { try save(state) }
    return (config, state)
  }

  public func save(_ config: Config, changedFrom previous: Config? = nil) throws {
    try write(config, previous: previous, owning: Config.ownedKeys, to: configURL)
  }

  public func save(_ state: AppState, changedFrom previous: AppState? = nil) throws {
    try write(state, previous: previous, owning: Self.runtimeKeys, to: stateURL)
  }

  // MARK: - Private

  private func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  private func readObject(_ url: URL) throws -> [String: Any]? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else { throw ConfigStoreError.notAnObject(url) }
    return object
  }

  private func decode<T: Decodable>(_ type: T.Type, from object: [String: Any]) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: object)
    return try JSONDecoder().decode(type, from: data)
  }

  /// Merges `value` into the file's current contents. Without `previous`,
  /// keys in `ownedKeys` are replaced (or removed when the model omits them)
  /// and every other model key is written. With `previous`, only keys whose
  /// encoded value differs from it are touched. Everything else is left as
  /// found on disk.
  private func write<T: Encodable>(_ value: T, previous: T?, owning ownedKeys: [String], to url: URL) throws {
    try ensureDirectory(url.deletingLastPathComponent())
    let modelObject = try encodeObject(value, url: url)
    var object = try readObject(url) ?? [:]

    guard let previous else {
      for key in ownedKeys { object.removeValue(forKey: key) }
      object.merge(modelObject) { _, new in new }
      try writeObject(object, to: url)
      return
    }

    let previousObject = try encodeObject(previous, url: url)
    let candidates = Set(ownedKeys).union(modelObject.keys).union(previousObject.keys)
    let changed = candidates.filter { !Self.jsonEqual(modelObject[$0], previousObject[$0]) }
    guard !changed.isEmpty else { return }
    for key in changed {
      object[key] = modelObject[key]
    }
    try writeObject(object, to: url)
  }

  private func encodeObject<T: Encodable>(_ value: T, url: URL) throws -> [String: Any] {
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    guard let object = encoded as? [String: Any] else { throw ConfigStoreError.notAnObject(url) }
    return object
  }

  /// JSONSerialization produces Foundation collections and NSNumber, whose
  /// `isEqual` compares deeply.
  private static func jsonEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): true
    case (let lhs as NSObject, let rhs as NSObject): lhs.isEqual(rhs)
    default: false
    }
  }

  private func writeObject(_ object: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(
      withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try data.write(to: url, options: .atomic)
  }
}
