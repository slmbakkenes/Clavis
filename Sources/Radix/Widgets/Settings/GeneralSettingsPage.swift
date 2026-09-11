import RadixCore
import SwiftUI

/// Settings > General.
struct GeneralSettingsPage: View {
  @Bindable var model: AppModel
  @FocusState private var customURLFocused: Bool

  var body: some View {
    SettingsPage {
      SettingsSection {
        SettingsRow(title: "Open at Login", caption: "Launch Radix when your computer starts") {
          Toggle("Open at Login", isOn: model.configBinding(\.launchAtLogin))
            .settingsSwitch()
        }
      }

      SettingsSection {
        SettingsRow(title: "Global Shortcut") {
          Picker("Global Shortcut", selection: model.configBinding(\.globalShortcut)) {
            Text("⌘ + ␣").tag(Config.GlobalShortcut.command)
            Text("⌥ + ␣").tag(Config.GlobalShortcut.option)
            Text("⌃ + ␣").tag(Config.GlobalShortcut.control)
          }
          .settingsMenu()
        }
        SettingsDivider()
        SettingsRow(title: "Search Engine") {
          Picker("Search Engine", selection: model.configBinding(\.searchEngine)) {
            Text("Google").tag(SearchEngine.google)
            Text("DuckDuckGo").tag(SearchEngine.duckduckgo)
            Text("Bing").tag(SearchEngine.bing)
            Text("Perplexity").tag(SearchEngine.perplexity)
            Text("Custom").tag(SearchEngine.custom)
          }
          .settingsMenu()
        }
        if model.config.searchEngine == .custom {
          customSearchURL
        }
      }

      SettingsSection {
        SettingsRow(title: "File Search Paths", caption: "Folders searched by File Search (uses Spotlight)") {
          Button("Add Folder…") { model.addSearchFolders() }
            .controlSize(.small)
            .focusable(false)
        }
        ForEach(model.config.searchFolders, id: \.self) { folder in
          SettingsDivider()
          HStack(spacing: 8) {
            Text(folder)
              .font(.system(size: 12))
              .lineLimit(1)
              .truncationMode(.middle)
              .frame(maxWidth: .infinity, alignment: .leading)
            Button {
              model.removeSearchFolder(folder)
            } label: {
              Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Remove \(folder)")
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
        }
      }

      SettingsSection {
        SettingsRow(title: "Show Window on Screen with") {
          Picker("Show Window on Screen with", selection: model.configBinding(\.showWindowOn)) {
            Text("Cursor Screen").tag(Config.ShowWindowOn.screenWithCursor)
            Text("Frontmost Window").tag(Config.ShowWindowOn.screenWithFrontmost)
          }
          .settingsMenu()
        }
        SettingsDivider()
        SettingsRow(title: "Show Browser Bookmarks") {
          Toggle("Show Browser Bookmarks", isOn: model.configBinding(\.showInAppBrowserBookMarks))
            .settingsSwitch()
        }
        SettingsDivider()
        SettingsRow(title: "Save Clipboard History") {
          Toggle(
            "Save Clipboard History",
            isOn: Binding(
              get: { model.state.clipboard.saveHistory },
              set: { model.setSaveClipboardHistory($0) }
            )
          )
          .settingsSwitch()
        }
        SettingsDivider()
        SettingsRow(title: "Forward Media Keys to Music Player") {
          Toggle("Forward Media Keys to Music Player", isOn: model.configBinding(\.mediaKeyForwardingEnabled))
            .settingsSwitch()
        }
      }

      SettingsSection {
        SettingsRow(title: "Reload Config", caption: "Re-read ~/.config/radix/config.json") {
          Button("Reload") { model.reloadFromDisk() }
            .controlSize(.small)
            .focusable(false)
        }
      }

      SettingsCaption("Custom keymaps (keymap in config.json) are edited by hand.")
    }
    // The panel's key view loop would otherwise hand focus to the first text
    // field as soon as the page appears.
    .onAppear { customURLFocused = false }
  }

  private var customSearchURL: some View {
    VStack(alignment: .trailing, spacing: 4) {
      HStack(spacing: 6) {
        Circle()
          .fill(SearchEngine.isValidCustomURL(model.config.customSearchUrl) ? Color.green : Color.red)
          .frame(width: 8, height: 8)
        TextField("https://google.com/search?q=%s", text: model.configBinding(\.customSearchUrl))
          .textFieldStyle(.roundedBorder)
          .font(.system(size: 12))
          .focused($customURLFocused)
          .frame(width: 320)
      }
      SettingsCaption("Use %s in place of the search term")
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(.horizontal, 12)
    .padding(.bottom, 10)
  }
}
