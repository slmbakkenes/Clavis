import AppKit
import ClavisCore
import SwiftUI

/// Settings > Scripts.
struct ScriptsSettingsPage: View {
  @Bindable var model: AppModel

  var body: some View {
    SettingsPage {
      SettingsSection {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "terminal")
            .font(.system(size: 24))
            .foregroundStyle(Theme.textMuted)
            .frame(width: 32)
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
              Text(Paths.scriptsDirectory.path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
              Spacer(minLength: 8)
              Button("Open in Finder") {
                NSWorkspace.shared.open(Paths.scriptsDirectory)
              }
              .controlSize(.small)
              .focusable(false)
            }
            SettingsCaption("Place scripts in this folder to have them picked up automatically.")
            SettingsCaption("Supported: .sh and .applescript. Each script can set its name and icon with two comments:")
            Text("# name: Script Name\n# icon: 💻")
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(Theme.textMuted)
              .textSelection(.enabled)
          }
        }
        .padding(12)
      }

      SettingsSection {
        Text("Detected Scripts")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Theme.text)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        if model.scripts.isEmpty {
          SettingsDivider()
          Text("No scripts found.")
            .font(.system(size: 12))
            .italic()
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else {
          ForEach(model.scripts) { script in
            SettingsDivider()
            HStack(spacing: 8) {
              Text(emoji(of: script))
                .frame(width: 20)
              Text(script.name)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
              Spacer(minLength: 8)
              Text(fileName(of: script))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
          }
        }
      }
    }
  }

  private func emoji(of script: Item) -> String {
    if case .emoji(let emoji) = script.icon { return emoji }
    return ScriptMetadata.defaultIcon
  }

  private func fileName(of script: Item) -> String {
    let prefix = "script-"
    return script.id.hasPrefix(prefix) ? String(script.id.dropFirst(prefix.count)) : script.id
  }
}
