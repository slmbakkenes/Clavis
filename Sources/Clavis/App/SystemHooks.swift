import AppKit

/// Decides whether this process may install system-wide hooks: per-item
/// global shortcuts, the hyperkey remap, and the media key tap.
///
/// Two running Clavis builds would conflict on all of them. Carbon lets both
/// register the same combo, both event taps see media keys, and the hyperkey
/// remap is global state. So hooks are installed only while no other Clavis
/// process is running, such as a second copy started from `make debug` or an
/// old React Native build.
@MainActor
final class SystemHooks {
  nonisolated static let finalBundleIdentifier = "com.svenbakkenes.clavis"
  /// The old React Native debug build registered the same hooks.
  nonisolated static let bundleIdentifiers: Set<String> = [finalBundleIdentifier, "\(finalBundleIdentifier).debug"]

  static var areAllowed: Bool {
    !bundleIdentifiers.contains { identifier in
      // A quitting app can still be listed while its terminate notification
      // is delivered, so terminated instances don't count.
      NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        .contains { $0.processIdentifier != getpid() && !$0.isTerminated }
    }
  }

  private var observers: [NSObjectProtocol] = []

  /// Calls `onChange` whenever another Clavis build launches or quits.
  func observe(onChange: @escaping @MainActor () -> Void) {
    let center = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { notification in
          let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
          guard let identifier = app?.bundleIdentifier, Self.bundleIdentifiers.contains(identifier) else { return }
          MainActor.assumeIsolated { onChange() }
        })
    }
  }
}
