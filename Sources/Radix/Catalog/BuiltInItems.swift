import AppKit
import RadixCore

/// The built-in commands from the previous build's `items.tsx` whose
/// dependencies exist in the Swift app so far. Window management, Wi-Fi,
/// appearance and the widget-switching items join in later phases.
@MainActor
enum BuiltInItems {
  static func make() -> [Item] {
    system + radix + folders + generators + utilities + WindowItems.make() + SystemItems.make()
  }

  // MARK: System

  private static var system: [Item] {
    [
      Item(id: "sleep", kind: .configuration, name: "Sleep", icon: .symbol("moon.zzz.fill")) { _ in
        try await AppleScript.run(#"tell application "Finder" to sleep"#)
      },
      Item(
        id: "restart", kind: .configuration, name: "Restart", icon: .symbol("arrow.clockwise"),
        confirmationTitle: "Restart Computer"
      ) { _ in
        try await AppleScript.run(#"tell application "Finder" to restart"#)
        ToastManager.shared.show(text: "Restarting", variant: .success)
      },
      Item(
        id: "shut_down", kind: .configuration, name: "Shut Down", icon: .symbol("power"),
        confirmationTitle: "Shut Down"
      ) { _ in
        try await AppleScript.run(#"tell application "Finder" to shut down"#)
        ToastManager.shared.show(text: "Shutting down", variant: .success)
      },
      Item(id: "airdrop", kind: .configuration, name: "AirDrop", icon: .symbol("dot.radiowaves.up.forward")) { _ in
        try await AppleScript.run(airDropScript)
      },
      Item(id: "lock", kind: .configuration, name: "Lock", icon: .symbol("lock.fill")) { _ in
        try await AppleScript.run(
          #"tell application "System Events" to keystroke "q" using {control down, command down}"#)
      },
      Item(
        id: "empty_trash", kind: .configuration, name: "Empty Trash", alias: "trash", icon: .symbol("trash.fill"),
        confirmationTitle: "Clear Trash"
      ) { _ in
        try await AppleScript.run(#"tell application "Finder" to empty trash"#)
        ToastManager.shared.show(text: "Trash emptied", variant: .success)
      },
      Item(
        id: "kill_all_apps", kind: .configuration, name: "Kill all apps", icon: .symbol("xmark.app"),
        // Not confirmed in the previous build, but fuzzy matching plus
        // usage ranking makes it far easier to hit by accident here.
        confirmationTitle: "Quit All Apps"
      ) { _ in
        do {
          try await AppleScript.run(killAllAppsScript())
        } catch {
          throw UserFacingError("\(error). Be sure to give accessibility access")
        }
      },
      Item(
        id: "hide_notch", kind: .configuration, name: "Hide/Restore Notch",
        icon: .symbol("rectangle.topthird.inset.filled")
      ) { _ in
        NotchHelper.shared.hideNotch()
        ToastManager.shared.show(text: "Notch hidden", variant: .success)
      },
    ]
  }

  // MARK: Radix itself

  private static var radix: [Item] {
    [
      Item(
        id: "settings", kind: .configuration, name: "Radix Settings", alias: "preferences",
        icon: .symbol("gearshape.fill"), keepsPanelOpen: true
      ) { model in
        model.query = ""
        model.focusWidget(.settings)
      },
      Item(
        id: "process_manager", kind: .configuration, name: "Kill process", icon: .symbol("xmark.octagon"),
        keepsPanelOpen: true
      ) { model in
        model.query = ""
        model.focusWidget(.processes)
      },
      Item(
        id: "scratchpad", kind: .configuration, name: "Scratchpad", icon: .symbol("note.text"), keepsPanelOpen: true
      ) { model in
        // From its shortcut this toggles, as the old showScratchpad did.
        model.focusWidget(model.focusedWidget == .scratchpad ? .search : .scratchpad)
      },
      Item(
        id: "clipboard_manager", kind: .configuration, name: "Clipboard Manager", icon: .symbol("clipboard"),
        keepsPanelOpen: true
      ) { model in
        model.query = ""
        model.focusWidget(model.focusedWidget == .clipboard ? .search : .clipboard)
      },
      Item(
        id: "file_search", kind: .configuration, name: "File Search", icon: .symbol("magnifyingglass"),
        keepsPanelOpen: true
      ) { model in
        model.focusWidget(.fileSearch)
        model.query = ""
      },
      Item(
        id: "create_shorcut", kind: .configuration, name: "Create Quick Link", icon: .symbol("link"),
        keepsPanelOpen: true
      ) { model in
        model.editingCustomItem = nil
        model.focusWidget(.createItem)
      },
      Item(
        id: "grant_accessibility_access", kind: .configuration, name: "Grant Accessibility Access",
        alias: "permission", icon: .symbol("accessibility")
      ) { _ in
        Permissions.requestAccessibility()
      },
      Item(
        id: "open_full_disk_access_settings", kind: .configuration, name: "Open Full Disk Access Settings",
        alias: "permission", icon: .symbol("lock.shield.fill")
      ) { _ in
        try Permissions.openFullDiskAccessSettings()
      },
      Item(
        id: "quit_sol", kind: .configuration, name: "Quit/Exit Radix", alias: "exit",
        icon: .symbol("xmark.circle.fill")
      ) { _ in
        NSApp.terminate(nil)
      },
    ]
  }

  // MARK: Folders

  private static var folders: [Item] {
    [
      folder(id: "downloads_folder", name: "Downloads", path: "~/Downloads"),
      folder(id: "desktop_folder", name: "Desktop", path: "~/Desktop"),
      folder(id: "applications_folder", name: "Applications", alias: "application", path: "/Applications"),
      folder(id: "pictures_folder", name: "Pictures", path: "~/Pictures"),
      Item(id: "developer_folder", kind: .configuration, name: "Developer", icon: .file("~/Developer")) { _ in
        guard FileManager.default.fileExists(atPath: Workspace.expandingTilde("~/Developer")) else {
          throw UserFacingError("Developer folder not found, try creating ~/Developer 😉")
        }
        try Workspace.open(path: "~/Developer")
      },
      folder(id: "documents_folder", name: "Documents", path: "~/Documents"),
    ]
  }

  private static func folder(id: String, name: String, alias: String? = nil, path: String) -> Item {
    Item(id: id, kind: .configuration, name: name, alias: alias, icon: .file(path)) { _ in
      try Workspace.open(path: path)
    }
  }

  // MARK: Generators and paste helpers

  private static var generators: [Item] {
    [
      Item(id: "generate_nano_id", kind: .configuration, name: "Generate Nano ID", icon: .symbol("number")) { _ in
        try Paste.text(NanoID.make())
        ToastManager.shared.show(text: "Generated and pasted", variant: .success)
      },
      Item(id: "generate_uuid", kind: .configuration, name: "Generate UUID", icon: .symbol("number.square")) { _ in
        try Paste.text(UUID().uuidString.lowercased())
        ToastManager.shared.show(text: "Generated and pasted", variant: .success)
      },
      Item(
        id: "generate_lorem_ipsum", kind: .configuration, name: "Generate Lorem Ipsum",
        icon: .symbol("text.alignleft")
      ) { _ in
        try Paste.text(LoremIpsum.paragraph())
        ToastManager.shared.show(text: "Generated", variant: .success)
      },
      Item(id: "paste_as_json", kind: .configuration, name: "Paste as JSON", icon: .symbol("curlybraces")) { _ in
        try pasteAsJSON()
      },
    ]
  }

  /// Pretty-prints the pasteboard as JSON and pastes it. Invalid JSON is
  /// pasted unchanged with an error toast, like the previous build.
  private static func pasteAsJSON() throws {
    guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
    guard let pretty = prettyPrintedJSON(text) else {
      try Paste.text(text)
      ToastManager.shared.show(text: "Not a valid JSON", variant: .error)
      return
    }
    try Paste.text(pretty)
    ToastManager.shared.show(text: "Pasted!", variant: .success)
  }

  private static func prettyPrintedJSON(_ text: String) -> String? {
    guard
      let object = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed]),
      let data = try? JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .fragmentsAllowed, .withoutEscapingSlashes])
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  // MARK: Utilities

  private static var utilities: [Item] {
    [
      Item(
        id: "start_google_meet", kind: .configuration, name: "Start Google Meet", icon: .symbol("video.fill")
      ) { _ in
        try await startGoogleMeet()
      }
    ]
  }

  private static let googleMeetNewURL = "https://meet.google.com/new"

  /// Opens a new meeting and, when Safari is the browser, copies the meeting
  /// link once Safari has redirected away from /new. The previous build did
  /// the polling with AppleScript `delay`, which would block the main thread.
  private static func startGoogleMeet() async throws {
    try Workspace.open(urlString: googleMeetNewURL)
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty else {
      return
    }

    for _ in 0..<4 {
      try await Task.sleep(for: .seconds(3))
      let url =
        try await AppleScript.run(#"tell application "Safari" to return URL of front document as string"#) ?? ""
      if !url.contains(googleMeetNewURL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
        ToastManager.shared.show(text: "Google Meet link copied to clipboard", variant: .success)
        return
      }
    }
    throw UserFacingError("Google Meet link could not be copied")
  }

  // MARK: Scripts

  private static let airDropScript = """
    tell application "Finder"
      if exists window "AirDrop" then
        tell application "System Events" to ¬
          tell application process "Finder" to ¬
            perform action "AXRaise" of ¬
              (windows whose title is "AirDrop")
      else if (count Finder windows) > 0 then
        make new Finder window
        tell application "System Events" to ¬
          click menu item "AirDrop" of menu 1 of menu bar item ¬
            "Go" of menu bar 1 of application process "Finder"
      else
        tell application "System Events" to ¬
          click menu item "AirDrop" of menu 1 of menu bar item ¬
            "Go" of menu bar 1 of application process "Finder"
      end if
      activate
    end tell
    """

  /// Quits every foreground app except a few, and Radix itself. Replies are
  /// ignored so an app asking to save a document cannot stall the main
  /// thread until the Apple Event times out.
  private static func killAllAppsScript() -> String {
    let ownName =
      (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? ProcessInfo.processInfo
      .processName)
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return """
      -- get list of open apps
      tell application "System Events"
        set allApps to displayed name of (every process whose background only is false) as list
      end tell

      -- leave some apps open
      set exclusions to {"AppleScript Editor", "Automator", "Finder", "LaunchBar", "\(ownName)"}

      -- quit each app
      repeat with thisApp in allApps
        set thisApp to thisApp as text
        if thisApp is not in exclusions then
          ignoring application responses
            tell application thisApp to quit
          end ignoring
        end if
      end repeat
      """
  }
}
