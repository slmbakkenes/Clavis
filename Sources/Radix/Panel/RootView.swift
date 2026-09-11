import SwiftUI

/// Switches the panel content on the focused widget, with the confirmation
/// dialog layered over whichever widget asked for it.
struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    content
      .overlay {
        if let confirmation = model.confirmation {
          ConfirmationOverlay(
            confirmation: confirmation,
            onProceed: { Task { await model.acceptConfirmation() } },
            onCancel: { model.cancelConfirmation() }
          )
        }
      }
  }

  @ViewBuilder
  private var content: some View {
    switch model.focusedWidget {
    case .search:
      SearchWidget(model: model)
    case .settings:
      SettingsWidget(model: model)
    case .translation:
      TranslationWidget(model: model, translation: model.translation)
    case .clipboard:
      ClipboardWidget(model: model, clipboard: model.clipboard) {
        model.confirmClipboard(modifiers: [])
      }
    case .scratchpad:
      ScratchpadWidget(model: model)
    case .createItem:
      CreateItemWidget(model: model)
    case .fileSearch:
      FileSearchWidget(model: model, fileSearch: model.fileSearch)
    case .processes:
      ProcessesWidget(model: model, processes: model.processes)
    }
  }

}
