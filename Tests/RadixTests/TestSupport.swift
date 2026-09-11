import Foundation
import RadixCore

@testable import Radix

/// All test config directories live under one root that is wiped at the
/// start of each run, so leftovers never outlive the next `swift test`.
private let testRoot: URL = {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("RadixTests", isDirectory: true)
  try? FileManager.default.removeItem(at: root)
  return root
}()

/// A model backed by config files in a fresh temporary directory, so tests
/// never touch ~/.config/radix.
@MainActor
func makeModel(config: Config = Config()) throws -> (model: AppModel, directory: URL) {
  let directory = testRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let store = ConfigStore(
    configURL: directory.appendingPathComponent("config.json"),
    stateURL: directory.appendingPathComponent("state.json"))
  var loaded = try store.load()
  loaded.config = config
  // Clipboard files and translations stay inside the test directory and off
  // the network.
  let clipboard = ClipboardModel(
    saveHistory: false,
    historyFile: directory.appendingPathComponent("clipboard_history.json"),
    imagesDirectory: directory.appendingPathComponent("images_pasteboard", isDirectory: true))
  let translation = TranslationModel { _, languages in
    languages.map { .success("translated to \($0)") }
  }
  let model = AppModel(
    store: store, config: loaded.config, state: loaded.state, clipboard: clipboard, translation: translation)
  return (model, directory)
}

/// Records calls so tests can see which item actually ran.
@MainActor
final class RunLog {
  var ran: [String] = []
}

@MainActor
func item(
  _ id: String, name: String, kind: Item.Kind = .configuration, keepsPanelOpen: Bool = false,
  confirmationTitle: String? = nil, log: RunLog? = nil
) -> Item {
  Item(
    id: id, kind: kind, name: name, keepsPanelOpen: keepsPanelOpen, confirmationTitle: confirmationTitle
  ) { _ in
    log?.ran.append(id)
  }
}
