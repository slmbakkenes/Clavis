import AppKit

// Programmatic entry point: no storyboard, no @main attribute (top-level code
// in main.swift is the entry point for a SwiftPM executable).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement in Info.plist hides the Dock icon; this does the same when run
// straight from `swift build` without a bundle.
app.setActivationPolicy(.accessory)
app.run()
