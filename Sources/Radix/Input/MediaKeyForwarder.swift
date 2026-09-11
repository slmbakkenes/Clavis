import AppKit

/// Sends the keyboard's play/pause, next and previous keys to Music, Spotify
/// and Kaset, port of the previous build's MediaKeyForwarder.m.
///
/// Deliberate deviation: when none of those players is running the key is
/// passed through instead of swallowed, so browsers and the system Now
/// Playing controls keep working.
@MainActor
final class MediaKeyForwarder {
  /// NX_SYSDEFINED from IOLLEvent.h; CGEventType has no case for it.
  private static let systemDefinedEventType: UInt32 = 14
  /// NSEvent subtype for auxiliary control buttons (media keys).
  private static let auxControlButtonsSubtype: Int16 = 8

  private enum MediaKey {
    case playPause, next, previous

    /// NX_KEYTYPE_* from ev_keymap.h.
    init?(keyType: Int) {
      switch keyType {
      case 16: self = .playPause  // NX_KEYTYPE_PLAY
      case 17, 19: self = .next  // NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST
      case 18, 20: self = .previous  // NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND
      default: return nil
      }
    }
  }

  private struct Player {
    let bundleIdentifier: String
    let playPause: String
    let next: String
    let previous: String

    func command(for key: MediaKey) -> String {
      switch key {
      case .playPause: playPause
      case .next: next
      case .previous: previous
      }
    }
  }

  private static let players = [
    Player(
      bundleIdentifier: "com.apple.Music", playPause: "playpause", next: "next track", previous: "back track"),
    Player(
      bundleIdentifier: "com.spotify.client", playPause: "playpause", next: "next track",
      previous: "previous track"),
    Player(
      bundleIdentifier: "com.sertacozercan.Kaset", playPause: "playpause", next: "next track",
      previous: "previous track"),
  ]

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var box: TapBox?

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try start()
    } else {
      stop()
    }
  }

  isolated deinit {
    stop()
  }

  private func start() throws {
    guard tap == nil else { return }
    let box = TapBox(forwarder: self)
    let mask = CGEventMask(1) << CGEventMask(Self.systemDefinedEventType)
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
          let box = Unmanaged<TapBox>.fromOpaque(info).takeUnretainedValue()
          // The run loop source is on the main run loop, so this runs on main.
          let swallow = MainActor.assumeIsolated {
            box.forwarder?.shouldSwallow(type: type, event: event) ?? false
          }
          return swallow ? nil : Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(box).toOpaque()
      )
    else {
      throw UserFacingError("Media key forwarding needs Accessibility access")
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
    self.runLoopSource = source
    self.box = box
  }

  private func stop() {
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

  /// Decides the fate of one tapped event and forwards the key when it is
  /// released.
  private func shouldSwallow(type: CGEventType, event: CGEvent) -> Bool {
    if type == .tapDisabledByTimeout {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return false
    }
    guard type.rawValue == Self.systemDefinedEventType,
      let nsEvent = NSEvent(cgEvent: event),
      nsEvent.subtype.rawValue == Self.auxControlButtonsSubtype
    else { return false }

    let data1 = nsEvent.data1
    guard let key = MediaKey(keyType: (data1 & 0xFFFF_0000) >> 16) else { return false }

    let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    let targets = Self.players.filter { running.contains($0.bundleIdentifier) }
    guard !targets.isEmpty else { return false }

    let keyFlags = data1 & 0x0000_FFFF
    let isPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
    if !isPressed {
      for player in targets {
        send(player.command(for: key), to: player.bundleIdentifier)
      }
    }
    // Swallow both press and release so the system doesn't also act on it.
    return true
  }

  private func send(_ command: String, to bundleIdentifier: String) {
    Task {
      do {
        try await AppleScript.run(#"tell application id "\#(bundleIdentifier)" to \#(command)"#)
      } catch {
        NSLog("Media key: \(command) to \(bundleIdentifier) failed: \(error)")
      }
    }
  }
}

/// Handed to the event tap; weak so a late callback finds nil rather than a
/// freed forwarder. The forwarder owns the box and outlives the tap.
@MainActor
private final class TapBox {
  weak var forwarder: MediaKeyForwarder?

  init(forwarder: MediaKeyForwarder) {
    self.forwarder = forwarder
  }
}
