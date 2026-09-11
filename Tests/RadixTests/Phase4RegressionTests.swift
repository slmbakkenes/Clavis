import Foundation
import RadixCore
import Testing

@testable import Radix

@MainActor
@Suite struct ProcessSelectionTests {
  private func entry(_ pid: Int32, cpu: Double, name: String) -> ProcessEntry {
    ProcessEntry(pid: pid, parentPid: 1, cpu: cpu, memoryKilobytes: 1024, path: "/usr/bin/\(name)")
  }

  /// Regression: selection was a row index, and a refresh re-sorting by CPU
  /// moved a different process under it before Enter sent SIGKILL.
  @Test func selectionFollowsThePidAcrossARefresh() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.processes)
    model.processes.setEntriesForTesting([
      entry(10, cpu: 50, name: "busy"), entry(20, cpu: 10, name: "target"), entry(30, cpu: 5, name: "idle"),
    ])
    model.selectNext()
    #expect(model.processes.selectedEntry?.pid == 20)

    // The next refresh re-sorts: "target" is now first and "idle" second.
    model.processes.setEntriesForTesting([
      entry(20, cpu: 90, name: "target"), entry(30, cpu: 40, name: "idle"), entry(10, cpu: 1, name: "busy"),
    ])
    #expect(model.processes.selectedEntry?.pid == 20)
    #expect(model.processes.selectedIndex == 0)
  }

  @Test func selectionMovesToFirstRowWhenTheProcessExits() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.processes)
    model.processes.setEntriesForTesting([entry(10, cpu: 5, name: "a"), entry(20, cpu: 1, name: "b")])
    model.selectNext()
    model.processes.setEntriesForTesting([entry(10, cpu: 5, name: "a")])
    #expect(model.processes.selectedEntry?.pid == 10)
  }

  @Test func filteringResetsSelectionToTheFirstMatch() throws {
    let (model, _) = try makeModel()
    model.focusWidget(.processes)
    model.processes.setEntriesForTesting([
      entry(10, cpu: 5, name: "safari"), entry(20, cpu: 4, name: "finder"), entry(30, cpu: 3, name: "mail"),
    ])
    model.selectNext()
    model.query = "mail"
    #expect(model.processes.selectedEntry?.pid == 30)
  }
}

@MainActor
@Suite struct ShellOutputTests {
  /// Regression: present() cleared the output view that showShellOutput had
  /// just stored, so script output never appeared.
  @Test func outputPanelKeepsItsView() {
    ToastManager.shared.showShellOutput()
    #expect(ToastManager.shared.isShowingShellOutput)
    ToastManager.shared.show(text: "replaced")
    #expect(!ToastManager.shared.isShowingShellOutput)
    ToastManager.shared.dismiss()
  }

  @Test func readerJoinsCharactersSplitAcrossWrites() async throws {
    let pipe = Pipe()
    let collected = Collected()
    let reader = ShellOutputReader(handle: pipe.fileHandleForReading) { text in collected.append(text) }
    reader.start()

    let euro = Array("€".utf8)
    try pipe.fileHandleForWriting.write(contentsOf: Data([0x61] + euro.prefix(1)))
    try await Task.sleep(for: .milliseconds(100))
    try pipe.fileHandleForWriting.write(contentsOf: Data(euro.dropFirst() + Array("\nend".utf8)))
    try pipe.fileHandleForWriting.close()

    await withCheckedContinuation { continuation in
      reader.finish { continuation.resume() }
    }
    // EOF may be read by the source or by finish; give either path a moment.
    try await Task.sleep(for: .milliseconds(100))
    #expect(collected.text == "a€\nend")
  }
}

private final class Collected: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = ""

  func append(_ text: String) {
    lock.withLock { storage += text }
  }

  var text: String {
    lock.withLock { storage }
  }
}
