enum PreferredScreen {
  case frontmost
  case withMouse
}

@objc class PanelManager: NSObject {
  let baseSize = NSSize(width: 700, height: 450)
  public var preferredScreen: PreferredScreen = .withMouse
  private let mainWindow: Panel = Panel(contentRect: .zero)
  private var rootView: NSView?
  private let screenDetector = ScreenDetector()
  /// Screen the panel was last shown on, kept so that resizes triggered after
  /// the panel is up don't drag it back to another display.
  private var targetScreen: NSScreen?

  @objc static public let shared = PanelManager()

  public func setRootView(_ rootView: NSView) {
    mainWindow.contentView!.addSubview(rootView)
    self.rootView = rootView
  }

  @objc func showWindow(target: String? = nil) {
    HotKeyManager.shared.settingsHotKey.isPaused = false

    guard let screen = resolveScreen() else {
      return
    }

    targetScreen = screen
    mainWindow.setFrame(frameFor(screen: screen, size: mainWindow.frame.size), display: false)

    mainWindow.setIsVisible(true)

    mainWindow.makeKeyAndOrderFront(self)

    SolEmitter.sharedInstance.onShow(target: nil)
  }

  @objc func hideWindow() {
    mainWindow.setIsVisible(false)
    targetScreen = nil
    SolEmitter.sharedInstance.onHide()
    HotKeyManager.shared.settingsHotKey.isPaused = true
  }

  @objc func resetSize() {
    guard let screen = getPreferredScreen() else {
      return
    }

    mainWindow.setFrame(frameFor(screen: screen, size: baseSize), display: false)
  }

  @objc func setHeight(_ height: Int) {
    var finalHeight = height
    if height == 0 {
      finalHeight = Int(baseSize.height)
    }

    let size = NSSize(width: baseSize.width, height: CGFloat(finalHeight))
    guard let screen = getPreferredScreen() else {
      return
    }

    // Preserve a horizontal drag by the user, but only while the panel is
    // still on the screen we're positioning against.
    var frame = frameFor(screen: screen, size: size)
    if screen.frame.intersects(mainWindow.frame) {
      frame.origin.x = mainWindow.frame.minX
    }

    self.mainWindow.setFrame(frame, display: true)

    self.rootView?.setFrameSize(size)

    self.rootView?.setFrameOrigin(NSPoint(x: 0, y: 0))
  }

  @objc func setRelativeSize(_ proportion: Double) {
    guard let screen = getPreferredScreen() else {
      return
    }

    let screenSize = screen.frame.size
    let size = CGSize(
      width: screenSize.width * CGFloat(proportion),
      height: screenSize.height * CGFloat(proportion)
    )

    mainWindow.setFrame(frameFor(screen: screen, size: size), display: false)
  }

  func toggle() {
    if mainWindow.isVisible {
      hideWindow()
    } else {
      showWindow()
    }
  }

  func setPreferredScreen(_ preferredScreen: PreferredScreen) {
    self.preferredScreen = preferredScreen
  }

  func getPreferredScreen() -> NSScreen? {
    return targetScreen ?? resolveScreen()
  }

  func getFrontmostScreen() -> NSScreen? {
    let screens = NSScreen.screens
    if screens.count <= 1 {
      return screens.first
    }

    // While the panel is up it is the frontmost window, so asking the
    // accessibility API would just point back at ourselves.
    if mainWindow.isVisible,
      NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid()
    {
      return mainWindow.screen ?? NSScreen.main
    }

    if let frontmostWindow = AccessibilityElement.frontmostWindow() {
      let rect = frontmostWindow.rectOfElement()
      if !rect.isEmpty,
        let screen = screenDetector.screenContaining(rect, screens: screens)
      {
        return screen
      }
    }

    // No accessibility permission or no window to go by.
    return NSScreen.main ?? getScreenWithMouse() ?? screens.first
  }

  private func resolveScreen() -> NSScreen? {
    switch preferredScreen {
    case .withMouse:
      return getScreenWithMouse() ?? getFrontmostScreen()
    case .frontmost:
      return getFrontmostScreen()
    }
  }

  /// Panel frame for `size`, horizontally centered and slightly above the
  /// vertical center of `screen`.
  private func frameFor(screen: NSScreen, size: NSSize) -> NSRect {
    let yOffset = screen.visibleFrame.height * 0.3
    let x = screen.visibleFrame.midX - size.width / 2
    let y = screen.visibleFrame.midY - size.height + yOffset
    return NSRect(x: floor(x), y: floor(y), width: size.width, height: size.height)
  }
}
