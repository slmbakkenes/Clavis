import Foundation
import Testing

@testable import Clavis

@MainActor
@Suite struct ScriptLoaderTests {
  /// Exercises the real FSEvents watcher: a script dropped into the folder
  /// after start must show up without a restart.
  @Test func picksUpScriptsAddedAfterStart() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ClavisScripts-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let loader = ScriptLoader(directory: directory)
    var latest: [Item] = []
    var callbacks = 0
    loader.start { items in
      latest = items
      callbacks += 1
    }

    // Wait for the initial (empty) scan so the file below can only be found
    // through the watcher.
    let initialDeadline = Date().addingTimeInterval(10)
    while callbacks == 0 && Date() < initialDeadline {
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(latest.isEmpty)

    try "# name: Hello\n# icon: 👋\necho hi\n".write(
      to: directory.appendingPathComponent("hello.sh"), atomically: true, encoding: .utf8)
    try "ignored".write(to: directory.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

    let deadline = Date().addingTimeInterval(10)
    while latest.isEmpty && Date() < deadline {
      try await Task.sleep(for: .milliseconds(100))
    }

    #expect(latest.map(\.id) == ["script-hello.sh"])
    #expect(latest.first?.name == "Hello")
    #expect(latest.first?.icon == .emoji("👋"))
    #expect(latest.first?.kind == .script)
  }
}
