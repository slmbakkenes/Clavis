import AppKit
import CoreServices

/// Watches directories with FSEvents and calls `onChange` on the main actor,
/// debounced. The stream is restarted after wake, since FSEvents streams can
/// stop delivering across sleep, and `onChange` runs then too.
@MainActor
final class DirectoryWatcher {
  private let paths: [String]
  private let label: String
  private let latency: CFTimeInterval
  private let debounce: Duration
  private let relevantFlags: FSEventStreamEventFlags?
  private let onChange: @MainActor () -> Void

  private var stream: FSEventStreamRef?
  private var wakeObserver: NSObjectProtocol?
  private var debounceTask: Task<Void, Never>?

  /// - Parameter relevantFlags: only events carrying one of these flags
  ///   count; nil means every event does.
  init(
    paths: [String], label: String, latency: CFTimeInterval, debounce: Duration,
    relevantFlags: FSEventStreamEventFlags? = nil, onChange: @escaping @MainActor () -> Void
  ) {
    self.paths = paths
    self.label = label
    self.latency = latency
    self.debounce = debounce
    self.relevantFlags = relevantFlags
    self.onChange = onChange
  }

  func start() {
    startStream()
    guard wakeObserver == nil else { return }
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.stopStream()
        self.startStream()
        self.onChange()
      }
    }
  }

  func stop() {
    stopStream()
    if let wakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
      self.wakeObserver = nil
    }
    debounceTask?.cancel()
    debounceTask = nil
  }

  isolated deinit {
    stop()
  }

  fileprivate func eventsArrived() {
    debounceTask?.cancel()
    debounceTask = Task { [weak self, debounce] in
      try? await Task.sleep(for: debounce)
      guard !Task.isCancelled else { return }
      self?.onChange()
    }
  }

  private func startStream() {
    guard stream == nil, !paths.isEmpty else { return }

    let context = WatcherContext(watcher: self, relevantFlags: relevantFlags)
    var streamContext = FSEventStreamContext(
      version: 0, info: Unmanaged.passUnretained(context).toOpaque(),
      retain: watcherContextRetain, release: watcherContextRelease, copyDescription: nil)

    guard
      let stream = FSEventStreamCreate(
        kCFAllocatorDefault, watcherCallback, &streamContext, paths as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
        FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents))
    else {
      NSLog("Could not create FSEvents stream for \(label)")
      return
    }

    FSEventStreamSetDispatchQueue(stream, DispatchQueue(label: "radix.fsevents.\(label)", qos: .utility))
    guard FSEventStreamStart(stream) else {
      NSLog("Could not start FSEvents stream for \(label)")
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
      return
    }
    self.stream = stream
  }

  private func stopStream() {
    guard let stream else { return }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    self.stream = nil
  }
}

/// The stream's context object. The stream retains it and it only weakly
/// references the watcher, so an event or the final release arriving while
/// the watcher goes away finds nil instead of a dangling pointer. `watcher` is
/// assigned once at init and only read on the main actor.
private final class WatcherContext: @unchecked Sendable {
  weak var watcher: DirectoryWatcher?
  let relevantFlags: FSEventStreamEventFlags?

  init(watcher: DirectoryWatcher, relevantFlags: FSEventStreamEventFlags?) {
    self.watcher = watcher
    self.relevantFlags = relevantFlags
  }
}

// FSEvents calls these on its own dispatch queue. They are top-level
// functions on purpose: a closure written inside main-actor code inherits
// main-actor isolation, and Swift 6 then traps on its runtime isolation check
// the moment FSEvents invokes it off the main thread.

private func watcherContextRetain(_ info: UnsafeRawPointer?) -> UnsafeRawPointer? {
  guard let info else { return nil }
  _ = Unmanaged<WatcherContext>.fromOpaque(info).retain()
  return info
}

private func watcherContextRelease(_ info: UnsafeRawPointer?) {
  guard let info else { return }
  Unmanaged<WatcherContext>.fromOpaque(info).release()
}

private func watcherCallback(
  _ stream: ConstFSEventStreamRef, _ info: UnsafeMutableRawPointer?, _ eventCount: Int,
  _ eventPaths: UnsafeMutableRawPointer, _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
  _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
  guard let info else { return }
  let context = Unmanaged<WatcherContext>.fromOpaque(info).takeUnretainedValue()
  if let relevant = context.relevantFlags {
    var anyRelevant = false
    for index in 0..<eventCount where eventFlags[index] & relevant != 0 {
      anyRelevant = true
      break
    }
    guard anyRelevant else { return }
  }
  Task { @MainActor in context.watcher?.eventsArrived() }
}
