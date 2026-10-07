import Foundation

/// Window management commands. They act on the frontmost window of the
/// frontmost app, which stays frontmost because the panel is non-activating.
@MainActor
enum WindowItems {
  static func make() -> [Item] {
    let manager = WindowManager.shared
    return [
      item("resize_fullscreen", "Toggle window full-screen", "arrow.up.left.and.arrow.down.right") {
        try manager.toggleFullScreen()
      },
      item("resize_maximize", "Maximize window", "macwindow") {
        try manager.maximize()
      },
      item("resize_right_half", "Resize window to right-half", "rectangle.righthalf.inset.filled") {
        try manager.moveHalf(.right)
      },
      item("resize_left_half", "Resize window to left-half", "rectangle.lefthalf.inset.filled") {
        try manager.moveHalf(.left)
      },
      item("resize_top_half", "Resize window to top-half", "rectangle.tophalf.inset.filled") {
        try manager.moveHalf(.top)
      },
      item("resize_bottom_half", "Resize window to bottom-half", "rectangle.bottomhalf.inset.filled") {
        try manager.moveHalf(.bottom)
      },
      item("resize_top_left", "Resize window to top-left", "rectangle.inset.topleft.filled") {
        try manager.moveQuarter(.topLeft)
      },
      item("resize_top_right", "Resize window to top-right", "rectangle.inset.topright.filled") {
        try manager.moveQuarter(.topRight)
      },
      item("resize_bottom_left", "Resize window to bottom-left", "rectangle.inset.bottomleft.filled") {
        try manager.moveQuarter(.bottomLeft)
      },
      item("resize_bottom_right", "Resize window to bottom-right", "rectangle.inset.bottomright.filled") {
        try manager.moveQuarter(.bottomRight)
      },
      item("resize_left_third", "Resize window to left third", "rectangle.leadingthird.inset.filled") {
        try manager.moveThird(.left)
      },
      item("resize_center_third", "Resize window to center third", "rectangle.split.3x1") {
        try manager.moveThird(.center)
      },
      item("resize_right_third", "Resize window to right third", "rectangle.trailingthird.inset.filled") {
        try manager.moveThird(.right)
      },
      item(
        "resize_left_two_thirds", "Resize window to left two-thirds", "rectangle.lefthalf.inset.filled.arrow.left"
      ) {
        try manager.moveTwoThirds(.left)
      },
      item(
        "resize_right_two_thirds", "Resize window to right two-thirds",
        "rectangle.righthalf.inset.filled.arrow.right"
      ) {
        try manager.moveTwoThirds(.right)
      },
      item("move_next_screen", "Move window to next screen", "arrow.right.to.line") {
        try manager.moveToNextScreen()
      },
      item("move_previous_screen", "Move window to previous screen", "arrow.left.to.line") {
        try manager.moveToPreviousScreen()
      },
      item("move_to_previous_space", "Move window to previous space", "arrow.left.square") {
        try await manager.moveToSpace(.previous)
      },
      item("move_to_next_space", "Move window to next space", "arrow.right.square") {
        try await manager.moveToSpace(.next)
      },
      item("move_center", "Move window to center", "rectangle.center.inset.filled") {
        try manager.center()
      },
    ]
  }

  private static func item(
    _ id: String, _ name: String, _ symbol: String, action: @escaping @MainActor () async throws -> Void
  ) -> Item {
    Item(id: id, kind: .configuration, name: name, icon: .symbol(symbol)) { _ in
      try await action()
    }
  }
}
