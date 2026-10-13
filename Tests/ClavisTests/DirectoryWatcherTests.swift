import CoreServices
import Foundation
import Testing

@testable import Clavis

@MainActor
@Suite struct DirectoryWatcherTests {
  /// Regression: FSEvents calls the stream callbacks on its own queue. The
  /// callbacks used to be closures inheriting main-actor isolation, which
  /// trapped on the first event and again when the stream was released.
  @Test func deliversEventsAndSurvivesRelease() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ClavisWatcher-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    var changes = 0
    var watcher: DirectoryWatcher? = DirectoryWatcher(
      paths: [directory.path], label: "test", latency: 0.1, debounce: .milliseconds(100),
      // Same filtering path the application loader uses.
      relevantFlags: FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)
    ) {
      changes += 1
    }
    watcher?.start()

    try "a".write(to: directory.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    let deadline = Date().addingTimeInterval(10)
    while changes == 0 && Date() < deadline {
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(changes > 0)

    // Dropping the watcher releases the stream; FSEvents runs the release
    // callback on its queue shortly after.
    watcher = nil
    try "b".write(to: directory.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
    try await Task.sleep(for: .milliseconds(500))
    _ = watcher
  }
}
