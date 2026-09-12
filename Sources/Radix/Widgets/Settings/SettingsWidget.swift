import SwiftUI

/// Settings: a sidebar of pages, with the shortcut recorder layered on top
/// while it is capturing.
struct SettingsWidget: View {
  enum Page: String, CaseIterable, Identifiable {
    case general = "General"
    case translation = "Translation"
    case items = "Items"
    case scripts = "Scripts"
    case about = "About"

    var id: String { rawValue }

    var symbol: String {
      switch self {
      case .general: "gearshape"
      case .translation: "character.bubble"
      case .items: "command"
      case .scripts: "terminal"
      case .about: "info.circle"
      }
    }
  }

  @Bindable var model: AppModel
  @State private var page: Page = .general

  var body: some View {
    HStack(spacing: 0) {
      SettingsSidebar(page: $page) {
        model.query = ""
        model.focusWidget(.search)
      }
      .frame(width: 180)

      Divider().overlay(Theme.separator)

      Group {
        switch page {
        case .general: GeneralSettingsPage(model: model)
        case .translation: TranslationSettingsPage(model: model)
        case .items: ItemsSettingsPage(model: model)
        case .scripts: ScriptsSettingsPage(model: model)
        case .about: AboutSettingsPage()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .overlay {
      if let recording = model.shortcutRecording {
        ShortcutRecorderOverlay(recording: recording) {
          model.cancelShortcutRecording()
        }
      }
    }
  }
}

private struct SettingsSidebar: View {
  @Binding var page: SettingsWidget.Page
  let onBack: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Button(action: onBack) {
        Label("Back", systemImage: "chevron.left")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Theme.textMuted)
      }
      .buttonStyle(.plain)
      .focusable(false)
      .padding(.bottom, 10)

      ForEach(SettingsWidget.Page.allCases) { candidate in
        Button {
          page = candidate
        } label: {
          Label(candidate.rawValue, systemImage: candidate.symbol)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(page == candidate ? Theme.textOnSelection : Theme.text)
            .background(
              page == candidate ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
      }
      Spacer()
    }
    .padding(12)
  }
}
