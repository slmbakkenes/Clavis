import ClavisCore
import SwiftUI

/// A scrolling settings page of grouped sections.
struct SettingsPage<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        content
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollIndicators(.hidden)
  }
}

/// A rounded group of rows; place `SettingsDivider()` between rows.
struct SettingsSection<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.separator))
  }
}

/// A title with an optional caption on the left and a control on the right.
struct SettingsRow<Control: View>: View {
  let title: String
  var caption: String?
  @ViewBuilder let control: Control

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13))
          .foregroundStyle(Theme.text)
        if let caption {
          Text(caption)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textMuted)
        }
      }
      Spacer(minLength: 8)
      control
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}

struct SettingsDivider: View {
  var body: some View {
    Divider().overlay(Theme.separator).padding(.leading, 12)
  }
}

/// A caption under or between sections.
struct SettingsCaption: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.system(size: 11))
      .foregroundStyle(Theme.textMuted)
  }
}

extension AppModel {
  /// A binding that reads the live config and writes through `updateConfig`,
  /// so every change is saved merge-safely and re-applied.
  func configBinding<Value>(_ keyPath: WritableKeyPath<Config, Value>) -> Binding<Value> {
    Binding(
      get: { self.config[keyPath: keyPath] },
      set: { newValue in self.updateConfig { $0[keyPath: keyPath] = newValue } }
    )
  }
}

extension View {
  /// Settings switches: compact, and out of the Tab order so Tab only moves
  /// between text fields.
  func settingsSwitch() -> some View {
    toggleStyle(.switch)
      .controlSize(.small)
      .labelsHidden()
      .focusable(false)
  }

  func settingsMenu(width: CGFloat = 180) -> some View {
    pickerStyle(.menu)
      .labelsHidden()
      .frame(width: width)
      .focusable(false)
  }
}
