import Darwin
import Foundation
import Observation
import RadixCore

/// Running processes for the process manager widget, refreshed from `ps`.
@MainActor
@Observable
final class ProcessesModel {
  private static let refreshInterval: Duration = .seconds(5)

  private(set) var entries: [ProcessEntry] = [] {
    didSet { keepSelectionValid() }
  }

  /// The widget's filter text, mirrored from the app model's query.
  var query = "" {
    didSet {
      guard query != oldValue else { return }
      selection.select(nil)
      keepSelectionValid()
    }
  }

  /// Selection is tracked by pid, not by row (see `Selection`): Enter sends
  /// SIGKILL.
  private var selection = Selection<Int32>()

  var selectedPid: Int32? { selection.id }

  var visibleEntries: [ProcessEntry] {
    ProcessList.filter(entries, query: query)
  }

  var selectedIndex: Int { selection.index(in: visibleEntries) }

  var selectedEntry: ProcessEntry? { selection.element(in: visibleEntries) }

  func select(pid: Int32) {
    selection.select(pid)
  }

  func moveSelection(by delta: Int) {
    selection.move(by: delta, in: visibleEntries)
  }

  private func keepSelectionValid() {
    selection.keepValid(in: visibleEntries)
  }

  /// Test seam: replaces the list without running `ps`.
  func setEntriesForTesting(_ entries: [ProcessEntry]) {
    self.entries = entries
  }

  @ObservationIgnored private var autoRefreshTask: Task<Void, Never>?

  func refresh() async {
    do {
      let output = try await Task.detached(priority: .userInitiated) { try Self.runPs() }.value
      entries = ProcessList.parse(output)
    } catch {
      NSLog("Could not list processes: \(error)")
    }
  }

  /// Refreshes now and then every few seconds until `stopAutoRefresh()`.
  func startAutoRefresh() {
    autoRefreshTask?.cancel()
    autoRefreshTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        try? await Task.sleep(for: Self.refreshInterval)
      }
    }
  }

  func stopAutoRefresh() {
    autoRefreshTask?.cancel()
    autoRefreshTask = nil
  }

  /// Sends SIGKILL, as the previous build's `kill -9` did. Failures such as
  /// EPERM for system processes are thrown rather than ignored.
  func kill(_ entry: ProcessEntry) throws {
    guard Darwin.kill(entry.pid, SIGKILL) == 0 else {
      let reason = String(cString: strerror(errno))
      throw UserFacingError("Could not kill \(entry.name): \(reason)")
    }
    entries.removeAll { $0.pid == entry.pid }
  }

  nonisolated private static func runPs() throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-eo", "pid,ppid,pcpu,rss,comm"]
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw UserFacingError("ps exited with status \(process.terminationStatus)")
    }
    return String(decoding: data, as: UTF8.self)
  }
}
