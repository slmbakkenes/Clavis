import Foundation
import Testing
@testable import ClavisCore

private func tempStore() throws -> (ConfigStore, URL) {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("clavis-tests-\(UUID().uuidString)", isDirectory: true)
  let store = ConfigStore(
    configURL: dir.appendingPathComponent("config.json"),
    stateURL: dir.appendingPathComponent("state.json"))
  return (store, dir)
}

private func write(_ json: String, to url: URL) throws {
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try json.write(to: url, atomically: true, encoding: .utf8)
}

private let fullConfigJSON = """
  {
    "firstTranslationLanguage": "nl",
    "secondTranslationLanguage": "fr",
    "thirdTranslationLanguage": null,
    "globalShortcut": "command",
    "showWindowOn": "screenWithFrontmost",
    "appearance": "light",
    "launchAtLogin": false,
    "mediaKeyForwardingEnabled": false,
    "scratchPadColor": "BLUE",
    "searchFolders": ["/tmp/a", "/tmp/b"],
    "searchEngine": "custom",
    "customSearchUrl": "https://example.com/?q=%s",
    "shortcuts": { "lock": "command+option+l" },
    "showInAppBrowserBookMarks": false,
    "hyperKeyEnabled": true,
    "customItems": [
      { "id": "abc", "name": "Mail", "icon": "Apple", "color": "#ff0000", "text": "open -a Mail", "type": "CUSTOM" }
    ],
    "disabledItemIds": ["lock"],
    "keymap": { "command+j": "next", "tab": null },
    "someFutureKey": { "nested": true }
  }
  """

private let fullStateJSON = """
  {
    "frequencies": { "lock": 3, "Old Name": 1 },
    "selectionTimestamps": { "lock": 1757577600000 },
    "history": ["ls", "cd"],
    "note": "hello",
    "clipboard": { "saveHistory": true },
    "unknown": 1
  }
  """

@Test func decodesEveryKeyAndIgnoresUnknownOnes() throws {
  let config = try JSONDecoder().decode(Config.self, from: Data(fullConfigJSON.utf8))
  #expect(config.firstTranslationLanguage == "nl")
  #expect(config.secondTranslationLanguage == "fr")
  #expect(config.thirdTranslationLanguage == nil)
  #expect(config.globalShortcut == .command)
  #expect(config.showWindowOn == .screenWithFrontmost)
  #expect(config.appearance == .light)
  #expect(config.launchAtLogin == false)
  #expect(config.mediaKeyForwardingEnabled == false)
  #expect(config.scratchPadColor == .blue)
  #expect(config.searchFolders == ["/tmp/a", "/tmp/b"])
  #expect(config.searchEngine == .custom)
  #expect(config.customSearchUrl == "https://example.com/?q=%s")
  #expect(config.shortcuts == ["lock": "command+option+l"])
  #expect(config.showInAppBrowserBookMarks == false)
  #expect(config.hyperKeyEnabled == true)
  #expect(
    config.customItems == [CustomItem(id: "abc", name: "Mail", icon: "Apple", color: "#ff0000", text: "open -a Mail")])
  #expect(config.disabledItemIds == ["lock"])
  #expect(config.keymap == ["command+j": "next", "tab": nil])

  let state = try JSONDecoder().decode(AppState.self, from: Data(fullStateJSON.utf8))
  #expect(state.frequencies == ["lock": 3, "Old Name": 1])
  #expect(state.selectionTimestamps == ["lock": 1_757_577_600_000])
  #expect(state.history == ["ls", "cd"])
  #expect(state.note == "hello")
  #expect(state.clipboard.saveHistory == true)
}

@Test func roundTripsThroughJSON() throws {
  let config = try JSONDecoder().decode(Config.self, from: Data(fullConfigJSON.utf8))
  let state = try JSONDecoder().decode(AppState.self, from: Data(fullStateJSON.utf8))
  let config2 = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
  let state2 = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
  #expect(config == config2)
  #expect(state == state2)

  // JSON keys are the ones the RN build reads.
  let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as! [String: Any]
  #expect(
    Set(object.keys) == [
      "firstTranslationLanguage", "secondTranslationLanguage", "globalShortcut", "showWindowOn",
      "appearance", "launchAtLogin", "mediaKeyForwardingEnabled", "scratchPadColor", "searchFolders", "searchEngine",
      "customSearchUrl", "shortcuts", "showInAppBrowserBookMarks", "hyperKeyEnabled", "customItems",
      "disabledItemIds", "keymap",
    ])
  #expect(object["scratchPadColor"] as? String == "BLUE")
}

@Test func emptyObjectsYieldDefaults() throws {
  let config = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
  #expect(config == Config())
  #expect(config.globalShortcut == .option)
  #expect(config.appearance == .dark)
  #expect(config.shortcuts == Config.defaultShortcuts)
  #expect(config.searchFolders.last?.hasSuffix("/Music") == true)

  let state = try JSONDecoder().decode(AppState.self, from: Data("{}".utf8))
  #expect(state == AppState())
}

@Test func frequenciesAreRescaledWhenAnyExceeds100() throws {
  let state = try JSONDecoder().decode(AppState.self, from: Data(#"{"frequencies":{"a":200,"b":50}}"#.utf8))
  #expect(state.frequencies == ["a": 100, "b": 25])
}

@Test func frequenciesOutsideIntRangeAreClampedNotTrapped() throws {
  let state = try JSONDecoder().decode(
    AppState.self, from: Data(#"{"frequencies":{"neg":-1e300,"huge":1e300,"ok":7}}"#.utf8))
  #expect(state.frequencies["neg"] == 0)
  #expect(state.frequencies["huge"] == 100)
  #expect(state.frequencies["ok"] == 0, "rescaled against 1e300 and floored")
}

@Test func shortcutsAreNormalisedOnDecode() throws {
  let config = try JSONDecoder().decode(Config.self, from: Data(#"{"shortcuts":{"lock":"⌘+⌥+l"}}"#.utf8))
  #expect(config.shortcuts["lock"] == "command+option+l")
}

@Test func saveKeepsKeysTheModelDoesNotOwn() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  try write(fullConfigJSON, to: store.configURL)
  try write(fullStateJSON, to: store.stateURL)

  var (config, state) = try store.load()
  config.launchAtLogin = true
  config.keymap = nil  // model omits it: the hand-edited value must still survive
  state.note = "changed"
  try store.save(config)
  try store.save(state)

  let rawConfig = try JSONSerialization.jsonObject(with: Data(contentsOf: store.configURL)) as! [String: Any]
  #expect(rawConfig["launchAtLogin"] as? Bool == true)
  #expect((rawConfig["someFutureKey"] as? [String: Any])?["nested"] as? Bool == true)
  #expect((rawConfig["keymap"] as? [String: Any])?["command+j"] as? String == "next")
  #expect((rawConfig["keymap"] as? [String: Any])?["tab"] is NSNull)

  let rawState = try JSONSerialization.jsonObject(with: Data(contentsOf: store.stateURL)) as! [String: Any]
  #expect(rawState["note"] as? String == "changed")
  #expect(rawState["unknown"] as? Int == 1)

  // An owned optional the model drops is removed, not left stale.
  config.thirdTranslationLanguage = "fr"
  try store.save(config)
  config.thirdTranslationLanguage = nil
  try store.save(config)
  let again = try JSONSerialization.jsonObject(with: Data(contentsOf: store.configURL)) as! [String: Any]
  #expect(again["thirdTranslationLanguage"] == nil)
}

@Test func saveChangedFromOnlyTouchesKeysThatChanged() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  let (config, state) = try store.load()

  // Another process (the RN build) edits unrelated keys after we loaded.
  var rawState = try JSONSerialization.jsonObject(with: Data(contentsOf: store.stateURL)) as! [String: Any]
  rawState["note"] = "written by the other build"
  rawState["frequencies"] = ["other": 5]
  try JSONSerialization.data(withJSONObject: rawState).write(to: store.stateURL)
  var rawConfig = try JSONSerialization.jsonObject(with: Data(contentsOf: store.configURL)) as! [String: Any]
  rawConfig["launchAtLogin"] = !config.launchAtLogin
  try JSONSerialization.data(withJSONObject: rawConfig).write(to: store.configURL)

  var nextState = state
  nextState.history = ["query"]
  try store.save(nextState, changedFrom: state)
  var nextConfig = config
  nextConfig.disabledItemIds = ["sleep"]
  try store.save(nextConfig, changedFrom: config)

  let savedState = try JSONSerialization.jsonObject(with: Data(contentsOf: store.stateURL)) as! [String: Any]
  #expect(savedState["history"] as? [String] == ["query"])
  #expect(savedState["note"] as? String == "written by the other build")
  #expect((savedState["frequencies"] as? [String: Int])?["other"] == 5)

  let savedConfig = try JSONSerialization.jsonObject(with: Data(contentsOf: store.configURL)) as! [String: Any]
  #expect(savedConfig["disabledItemIds"] as? [String] == ["sleep"])
  #expect(savedConfig["launchAtLogin"] as? Bool == !config.launchAtLogin)
}

@Test func saveChangedFromWithoutChangesLeavesFileAlone() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  let (_, state) = try store.load()
  try write(#"{"note":"hand edited"}"#, to: store.stateURL)
  try store.save(state, changedFrom: state)
  #expect(try String(contentsOf: store.stateURL, encoding: .utf8) == #"{"note":"hand edited"}"#)
}

@Test func loadCreatesDefaultFilesWhenMissing() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  let (config, state) = try store.load()
  #expect(config == Config())
  #expect(state == AppState())
  #expect(FileManager.default.fileExists(atPath: store.configURL.path))
  #expect(FileManager.default.fileExists(atPath: store.stateURL.path))
}

@Test func loadMigratesRuntimeKeysOutOfConfig() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  try write(
    """
    {"globalShortcut":"control","frequencies":{"x":2},"history":["old"],"note":"legacy","clipboard":{"saveHistory":true}}
    """, to: store.configURL)
  try write(#"{"history":["new"]}"#, to: store.stateURL)

  let (config, state) = try store.load()
  #expect(config.globalShortcut == .control)
  #expect(state.frequencies == ["x": 2])
  #expect(state.history == ["new"], "existing state.json values win over legacy config keys")
  #expect(state.note == "legacy")
  #expect(state.clipboard.saveHistory == true)

  let rawConfig = try JSONSerialization.jsonObject(with: Data(contentsOf: store.configURL)) as! [String: Any]
  for key in ConfigStore.runtimeKeys { #expect(rawConfig[key] == nil, "\(key) still in config.json") }
  let rawState = try JSONSerialization.jsonObject(with: Data(contentsOf: store.stateURL)) as! [String: Any]
  #expect(rawState["note"] as? String == "legacy")
}

@Test func saveWritesPrettyJSONThatLoadsBack() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  var config = Config()
  config.customSearchUrl = "https://x.y/?q=%s"
  config.customItems = [CustomItem(id: "1", name: "n", text: "t")]
  try store.save(config)
  var state = AppState()
  state.note = "n"
  try store.save(state)

  let text = try String(contentsOf: store.configURL, encoding: .utf8)
  #expect(text.contains("\n  \"customSearchUrl\" : \"https://x.y/?q=%s\""), "pretty printed, slashes unescaped")
  let loaded = try store.load()
  #expect(loaded.config == config)
  #expect(loaded.state == state)
}

@Test func nonObjectFileIsAnError() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  try write("[1,2]", to: store.configURL)
  #expect(throws: ConfigStoreError.notAnObject(store.configURL)) { try store.load() }
}

@Test func fixtureFilesMirroringTheRNWriterLoad() throws {
  let (store, dir) = try tempStore()
  defer { try? FileManager.default.removeItem(at: dir) }
  let fixtures = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  try FileManager.default.copyItem(at: fixtures.appendingPathComponent("config.json"), to: store.configURL)
  try FileManager.default.copyItem(at: fixtures.appendingPathComponent("state.json"), to: store.stateURL)

  let (config, state) = try store.load()
  #expect(config.secondTranslationLanguage == "nl")
  #expect(config.shortcuts == Config.defaultShortcuts)
  #expect(config.keymap?["tab"] == .some(nil))
  #expect(config.resolvedKeymap().bindings["tab"] == nil, "null unbinds the default")
  #expect(state.frequencies == ["Safari": 12, "lock": 3])
  #expect(state.history == ["safari", "2+2"])
  #expect(state.note == "shopping list")
}
