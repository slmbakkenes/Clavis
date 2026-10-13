import AppKit

@MainActor
func screenWithMouse() -> NSScreen? {
  let mouseLocation = NSEvent.mouseLocation
  return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
}
