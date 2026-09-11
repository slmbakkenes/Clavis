import AppKit

/// Shows transient toasts and the live script-output panel. One shared
/// `Toast` window is reused; showing anything replaces what was there.
@MainActor
final class ToastManager {
  static let shared = ToastManager()

  private let toastWindow = Toast(contentRect: .zero)
  private var shellOutputView: ShellOutputView?
  /// Bumped on every show so a timer from an earlier toast can't dismiss a
  /// later one (the old build had that race).
  private var generation = 0

  private init() {}

  // MARK: Toasts

  func show(
    text: String, variant: ToastVariant = .none, timeout: TimeInterval? = nil, image: NSImage? = nil,
    on screen: NSScreen? = nil
  ) {
    guard let screen = screen ?? PanelManager.shared.getPreferredScreen() else { return }

    generation += 1
    let shownGeneration = generation

    let toastView = ToastView(
      text: text, variant: variant, image: image,
      dismissCallback: { [weak self] in self?.dismiss() })
    toastView.layoutSubtreeIfNeeded()

    let contentSize = toastView.intrinsicContentSize
    present(toastView, contentSize: contentSize)

    // Screen origins are relative to the main screen, so x can be negative.
    let x = screen.frame.origin.x + (screen.frame.size.width / 2 - contentSize.width / 2)
    var y = screen.frame.origin.y + screen.frame.size.height * 0.1
    if image != nil {
      y = screen.frame.origin.y + toastWindow.frame.height
    }
    toastWindow.setFrameOrigin(NSPoint(x: x, y: y))
    toastWindow.orderFront(nil)

    let delay = timeout ?? 2
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.generation == shownGeneration else { return }
        self.dismiss()
      }
    }
  }

  func dismiss() {
    toastWindow.orderOut(nil)
  }

  // MARK: Script output

  /// Returns the generation of the panel it showed, for `closeShellOutput(ifGeneration:)`.
  @discardableResult
  func showShellOutput(on screen: NSScreen? = nil) -> Int? {
    guard let screen = screen ?? PanelManager.shared.getPreferredScreen() else { return nil }

    generation += 1
    let view = ShellOutputView()
    view.layoutSubtreeIfNeeded()

    let contentSize = NSSize(width: 500, height: 200)
    present(view, contentSize: contentSize)
    // After present(), which clears any previous output view.
    shellOutputView = view

    // Bottom right corner of the screen.
    let x = screen.frame.origin.x + screen.frame.size.width - contentSize.width - 20
    let y = screen.frame.origin.y + 20
    toastWindow.setFrameOrigin(NSPoint(x: x, y: y))
    toastWindow.orderFront(nil)
    return generation
  }

  var isShowingShellOutput: Bool { shellOutputView != nil }

  func appendShellOutput(_ text: String) {
    shellOutputView?.appendOutput(text)
  }

  func setShellSuccessStyle() {
    shellOutputView?.setSuccessStyle()
  }

  func setShellFailedStyle() {
    shellOutputView?.setFailedStyle()
  }

  /// Closes the output panel only if nothing (another run or a toast) has
  /// been shown since that panel appeared.
  func closeShellOutput(ifGeneration shownGeneration: Int) {
    guard generation == shownGeneration else { return }
    closeShellOutput()
  }

  func closeShellOutput() {
    shellOutputView?.removeFromSuperview()
    shellOutputView = nil
    toastWindow.orderOut(nil)
  }

  // MARK: Private

  private func present(_ view: NSView, contentSize: NSSize) {
    let frame = NSRect(origin: .zero, size: contentSize)
    view.frame = frame

    let effectView = NSVisualEffectView(frame: frame)
    effectView.autoresizingMask = [.width, .height]
    effectView.material = .hudWindow
    effectView.blendingMode = .behindWindow
    effectView.state = .active

    // A toast replaces whatever is showing, including a live shell output view.
    shellOutputView = nil
    toastWindow.contentView = effectView
    effectView.addSubview(view)
    toastWindow.setFrame(frame, display: true)
    toastWindow.setContentSize(contentSize)
  }
}
