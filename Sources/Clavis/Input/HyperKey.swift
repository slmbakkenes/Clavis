import AppKit
import Carbon

/// Caps Lock as a hyper key: hidutil remaps Caps Lock to F18, and while F18 is
/// held an event tap adds ⌘⌃⌥⇧ to every other key. Port of the hyperkey
/// feature in the previous build's HotKeyManager.
///
/// Deliberate fix: the previous build reset by writing an empty
/// `UserKeyMapping`, wiping every hidutil remap on the system. This one only
/// adds and removes its own Caps Lock to F18 entry, and never touches hidutil
/// unless it enabled the mapping itself.
@MainActor
final class HyperKey {
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var box: HyperKeyTapBox?
  private var f18Down = false
  /// Set once this process has ensured the mapping exists; disabling removes
  /// it only then.
  private var ownsMapping = false

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try enable()
    } else {
      try disable()
    }
  }

  private func enable() throws {
    guard tap == nil else { return }
    try startTap()
    do {
      try KeyMapping.addCapsLockToF18()
    } catch {
      stopTap()
      throw error
    }
    ownsMapping = true
    // The remap is system-wide; macOS must not kill the process (logout,
    // memory pressure) without running applicationWillTerminate to remove it.
    ProcessInfo.processInfo.disableSuddenTermination()
  }

  private func disable() throws {
    stopTap()
    guard ownsMapping else { return }
    try KeyMapping.removeCapsLockToF18()
    ownsMapping = false
    ProcessInfo.processInfo.enableSuddenTermination()
  }

  private func startTap() throws {
    let box = HyperKeyTapBox(hyperKey: self)
    let mask =
      (CGEventMask(1) << CGEventType.keyDown.rawValue)
      | (CGEventMask(1) << CGEventType.keyUp.rawValue)
      | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        // This closure inherits main-actor isolation and carries a runtime
        // check; it only works because the source is on the main run loop.
        // Moving the tap to another thread would trap (see DirectoryWatcher).
        callback: { _, type, event, info in
          guard let info else { return Unmanaged.passUnretained(event) }
          let box = Unmanaged<HyperKeyTapBox>.fromOpaque(info).takeUnretainedValue()
          // The run loop source is on the main run loop, so this runs on main.
          let swallow = MainActor.assumeIsolated {
            box.hyperKey?.handle(type: type, event: event) ?? false
          }
          return swallow ? nil : Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(box).toOpaque()
      )
    else {
      throw UserFacingError("The hyper key needs Accessibility access")
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
    self.runLoopSource = source
    self.box = box
  }

  private func stopTap() {
    f18Down = false
    guard let tap else { return }
    CGEvent.tapEnable(tap: tap, enable: false)
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CFMachPortInvalidate(tap)
    self.tap = nil
    runLoopSource = nil
    box = nil
  }

  /// Returns whether the event is swallowed. F18 itself never reaches apps;
  /// while it is held, every other key event carries all four modifiers.
  private func handle(type: CGEventType, event: CGEvent) -> Bool {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      // An F18 key-up may have happened while the tap was off; don't let a
      // stale "held" state add all four modifiers to every later keystroke.
      f18Down = false
      if type == .tapDisabledByTimeout, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return false
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    if type == .keyDown || type == .keyUp, keyCode == Int64(kVK_F18) {
      f18Down = type == .keyDown
      return true
    }

    // Secure input (password fields) also hides key-ups from taps, so check
    // the hardware state before trusting the cached flag.
    if f18Down, !CGEventSource.keyState(.hidSystemState, key: CGKeyCode(kVK_F18)) {
      f18Down = false
    }

    // Only hardware events get the hyper modifiers. Synthetic ones, such as
    // the ⌃← that moving a window to another Space posts, must keep theirs.
    let isHardwareEvent = event.getIntegerValueField(.eventSourceUnixProcessID) == 0
    if f18Down, isHardwareEvent, keyCode != Int64(kVK_F18) {
      event.flags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    }
    return false
  }
}

/// Handed to the event tap; weak so a late callback finds nil rather than a
/// freed HyperKey.
@MainActor
private final class HyperKeyTapBox {
  weak var hyperKey: HyperKey?

  init(hyperKey: HyperKey) {
    self.hyperKey = hyperKey
  }
}

/// Reads and writes hidutil's `UserKeyMapping`, preserving entries that
/// belong to anyone else.
private enum KeyMapping {
  typealias Entry = [String: Int64]

  static let sourceKey = "HIDKeyboardModifierMappingSrc"
  static let destinationKey = "HIDKeyboardModifierMappingDst"
  /// HID usage page 7 (keyboard): Caps Lock 0x39, F18 0x6D.
  static let capsLock: Int64 = 0x7_0000_0039
  static let f18: Int64 = 0x7_0000_006D

  static func addCapsLockToF18() throws {
    let current = try readMappings()
    guard !current.contains(where: isCapsLockToF18) else { return }
    try writeMappings(current + [[sourceKey: capsLock, destinationKey: f18]])
  }

  static func removeCapsLockToF18() throws {
    let current = try readMappings()
    let remaining = current.filter { !isCapsLockToF18($0) }
    guard remaining.count != current.count else { return }
    try writeMappings(remaining)
  }

  private static func isCapsLockToF18(_ entry: Entry) -> Bool {
    entry[sourceKey] == capsLock && entry[destinationKey] == f18
  }

  private static func readMappings() throws -> [Entry] {
    let output = try hidutil(["property", "--get", "UserKeyMapping"])
    return try parse(output)
  }

  private static func writeMappings(_ mappings: [Entry]) throws {
    let payload = try JSONSerialization.data(withJSONObject: ["UserKeyMapping": mappings])
    _ = try hidutil(["property", "--set", String(decoding: payload, as: UTF8.self)])
  }

  /// hidutil prints the mapping as an old-style property list, `(null)` when
  /// never set. Anything unrecognised throws, so an unreadable mapping is
  /// never overwritten.
  static func parse(_ output: String) throws -> [Entry] {
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == "(null)" { return [] }
    let unreadable = UserFacingError("Could not read the current key mapping: \(trimmed)")
    guard let entries = try? PropertyListSerialization.propertyList(from: Data(trimmed.utf8), format: nil) as? [Any]
    else { throw unreadable }
    return try entries.map { entry in
      guard let dictionary = entry as? [String: Any] else { throw unreadable }
      return try dictionary.mapValues { value in
        if let number = value as? NSNumber { return number.int64Value }
        if let text = value as? String, let number = Int64(text) { return number }
        throw unreadable
      }
    }
  }

  private static func hidutil(_ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    process.arguments = arguments
    let output = Pipe()
    let errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    do {
      try process.run()
    } catch {
      throw UserFacingError("Could not run hidutil: \(error.localizedDescription)")
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
      throw UserFacingError("hidutil failed (\(process.terminationStatus)): \(message)")
    }
    return String(decoding: data, as: UTF8.self)
  }
}
