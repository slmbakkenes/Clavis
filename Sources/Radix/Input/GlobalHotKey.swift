import AppKit
import Carbon

/// Thin wrapper over Carbon's RegisterEventHotKey. Deprecated API, still the
/// only public way to grab a system-wide shortcut without an event tap.
///
/// The registry keeps instances alive so the C callback can reach them, so a
/// hotkey is never released implicitly: call `invalidate()` before dropping
/// the last reference, or the combo stays registered for the process
/// lifetime.
@MainActor
final class GlobalHotKey {
  enum Trigger { case keyDown, keyUp }

  let keyCode: UInt32
  let modifiers: NSEvent.ModifierFlags
  let trigger: Trigger
  var handler: () -> Void

  /// Registration is dropped while paused, so the shortcut falls through to
  /// other apps.
  var isPaused = false {
    didSet {
      guard isPaused != oldValue else { return }
      if isPaused { unregister() } else { register() }
    }
  }

  private var ref: EventHotKeyRef?
  private let id: UInt32

  private static var nextID: UInt32 = 1
  private static var registry: [UInt32: GlobalHotKey] = [:]
  private static var handlerInstalled = false

  init(
    keyCode: UInt32, modifiers: NSEvent.ModifierFlags, trigger: Trigger = .keyDown,
    handler: @escaping () -> Void
  ) {
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.trigger = trigger
    self.handler = handler
    self.id = Self.nextID
    Self.nextID += 1
    Self.installHandlerIfNeeded()
    register()
  }

  private func register() {
    guard ref == nil else { return }
    let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
    let status = RegisterEventHotKey(
      keyCode, Self.carbonModifiers(from: modifiers), hotKeyID,
      GetEventDispatcherTarget(), 0, &ref)
    if status != noErr {
      NSLog("RegisterEventHotKey failed for keyCode \(keyCode): \(status)")
      return
    }
    Self.registry[id] = self
  }

  /// Unregisters and drops the registry reference so the instance can be
  /// released. Callers must discard it afterwards; un-pausing would register
  /// it again.
  func invalidate() {
    unregister()
    isPaused = true
  }

  private func unregister() {
    guard let ref else { return }
    UnregisterEventHotKey(ref)
    self.ref = nil
    Self.registry[id] = nil
  }

  private static let signature: OSType = {
    // 'RDIX' as a four-char code.
    var value: OSType = 0
    for byte in "RDIX".utf8 { value = value << 8 | OSType(byte) }
    return value
  }()

  private static func installHandlerIfNeeded() {
    guard !handlerInstalled else { return }
    var specs = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]
    // The handler closure inherits main-actor isolation; Carbon calls it from
    // the main event dispatcher, so the runtime isolation check passes.
    let status = InstallEventHandler(
      GetEventDispatcherTarget(),
      { _, event, _ -> OSStatus in
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
          nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        guard status == noErr else { return status }
        let kind = GetEventKind(event)
        // Carbon dispatches on the main run loop.
        MainActor.assumeIsolated {
          guard let hotKey = GlobalHotKey.registry[hotKeyID.id] else { return }
          switch (hotKey.trigger, Int(kind)) {
          case (.keyDown, kEventHotKeyPressed), (.keyUp, kEventHotKeyReleased):
            hotKey.handler()
          default:
            break
          }
        }
        return noErr
      },
      specs.count, &specs, nil, nil)
    // Only mark installed on success; otherwise hotkeys would register fine
    // and never fire, with nothing in the log to explain it.
    if status == noErr {
      handlerInstalled = true
    } else {
      NSLog("InstallEventHandler for hotkeys failed: \(status)")
    }
  }

  private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var result: UInt32 = 0
    if flags.contains(.command) { result |= UInt32(cmdKey) }
    if flags.contains(.option) { result |= UInt32(optionKey) }
    if flags.contains(.control) { result |= UInt32(controlKey) }
    if flags.contains(.shift) { result |= UInt32(shiftKey) }
    return result
  }
}
