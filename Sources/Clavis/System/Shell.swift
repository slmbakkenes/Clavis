import Foundation
import ClavisCore

/// Runs a shell command in a login zsh and streams its output into the
/// floating shell output panel.
@MainActor
enum Shell {
  /// How long the finished output stays on screen.
  private nonisolated static let closeDelay: DispatchTimeInterval = .seconds(5)

  static func runShowingOutput(_ command: String) throws {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", command]
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = nil

    // A finished run's delayed close must not close a later run's panel or a
    // toast shown since; the toast manager's generation covers both.
    let shownGeneration = ToastManager.shared.showShellOutput()
    ToastManager.shared.appendShellOutput(command + "\n\n")

    let reader = ShellOutputReader(handle: pipe.fileHandleForReading) { text in
      DispatchQueue.main.async {
        MainActor.assumeIsolated { ToastManager.shared.appendShellOutput(text) }
      }
    }
    process.terminationHandler = { process in
      let succeeded = process.terminationStatus == 0
      // Drain on the reader's queue so the last output lands before styling.
      reader.finish {
        DispatchQueue.main.async {
          MainActor.assumeIsolated {
            if succeeded {
              ToastManager.shared.setShellSuccessStyle()
            } else {
              ToastManager.shared.setShellFailedStyle()
            }
          }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay) {
          MainActor.assumeIsolated {
            guard let shownGeneration else { return }
            ToastManager.shared.closeShellOutput(ifGeneration: shownGeneration)
          }
        }
      }
    }

    reader.start()
    do {
      try process.run()
    } catch {
      reader.cancel()
      ToastManager.shared.closeShellOutput()
      throw UserFacingError("Could not run shell command: \(error.localizedDescription)")
    }
  }
}

/// Reads a pipe with a dispatch read source. All mutable state is confined to
/// `queue`, so the final drain after exit can't race a read in progress, and
/// a character split across reads is carried over instead of garbled.
final class ShellOutputReader: @unchecked Sendable {
  private let queue = DispatchQueue(label: "clavis.shell.output")
  private let handle: FileHandle
  private let onText: @Sendable (String) -> Void
  private var source: DispatchSourceRead?
  private var pending: [UInt8] = []
  /// Once set the descriptor is closed; its number may already belong to
  /// another file, so it must never be read again.
  private var isClosed = false

  init(handle: FileHandle, onText: @escaping @Sendable (String) -> Void) {
    self.handle = handle
    self.onText = onText
    let descriptor = handle.fileDescriptor
    let flags = fcntl(descriptor, F_GETFL)
    if flags != -1 {
      _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
    }
  }

  func start() {
    let source = DispatchSource.makeReadSource(fileDescriptor: handle.fileDescriptor, queue: queue)
    source.setEventHandler { [self] in readAvailable() }
    source.setCancelHandler { [handle] in try? handle.close() }
    self.source = source
    source.resume()
  }

  /// Reads whatever is buffered, emits it, then runs `completion`. A
  /// background job started by the script may keep the pipe open; the source
  /// keeps delivering its output until EOF.
  func finish(then completion: @escaping @Sendable () -> Void) {
    queue.async { [self] in
      readAvailable()
      emit(final: true)
      completion()
    }
  }

  func cancel() {
    queue.async { [self] in
      close()
    }
  }

  private func close() {
    guard !isClosed else { return }
    isClosed = true
    source?.cancel()
    source = nil
  }

  private func readAvailable() {
    guard !isClosed else { return }
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = read(handle.fileDescriptor, &buffer, buffer.count)
      if count > 0 {
        pending.append(contentsOf: buffer.prefix(count))
        continue
      }
      if count == 0 {
        // EOF: flush everything and stop watching the descriptor.
        emit(final: true)
        close()
        return
      }
      break  // EAGAIN: nothing more right now.
    }
    emit(final: false)
  }

  private func emit(final: Bool) {
    let length = final ? pending.count : UTF8Boundary.completePrefixLength(pending)
    guard length > 0 else { return }
    let text = String(decoding: pending.prefix(length), as: UTF8.self)
    pending.removeFirst(length)
    onText(text)
  }
}
