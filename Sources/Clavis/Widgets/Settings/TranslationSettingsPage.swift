import ClavisCore
import SwiftUI

/// Settings > Translation.
struct TranslationSettingsPage: View {
  @Bindable var model: AppModel

  private let languages = Languages.sortedByName

  var body: some View {
    SettingsPage {
      SettingsCaption("Select up to 3 languages for translation")
      SettingsSection {
        SettingsRow(title: "First language") {
          Picker("First language", selection: model.configBinding(\.firstTranslationLanguage)) {
            languageOptions
          }
          .settingsMenu()
        }
        SettingsDivider()
        SettingsRow(title: "Second language") {
          Picker("Second language", selection: model.configBinding(\.secondTranslationLanguage)) {
            languageOptions
          }
          .settingsMenu()
        }
        SettingsDivider()
        SettingsRow(title: "Third language") {
          Picker("Third language", selection: model.configBinding(\.thirdTranslationLanguage)) {
            Text("None").tag(String?.none)
            Divider().overlay(Theme.separator)
            ForEach(languages, id: \.code) { language in
              Text(language.name).tag(String?.some(language.code))
            }
          }
          .settingsMenu()
        }
      }
    }
  }

  private var languageOptions: some View {
    ForEach(languages, id: \.code) { language in
      Text(language.name).tag(language.code)
    }
  }
}
