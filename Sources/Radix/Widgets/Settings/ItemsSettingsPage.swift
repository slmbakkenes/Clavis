import RadixCore
import SwiftUI

/// Settings > Items: enable or disable items and assign their global
/// shortcuts. Port of the previous build's Items page.
struct ItemsSettingsPage: View {
  @Bindable var model: AppModel
  @State private var filterText = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      hyperKeyRow
      Divider()
      filterBar
      if let filter = model.shortcutFilter {
        shortcutFilterStrip(filter)
      }
      list
    }
    .padding(16)
    // The old page cleared its shortcut filter when it went away.
    .onDisappear { model.shortcutFilter = nil }
  }

  // MARK: Sections

  private var header: some View {
    HStack {
      Text("Global Shortcuts")
        .font(.system(size: 13, weight: .semibold))
      Spacer()
      Button("Restore Defaults") {
        model.restoreDefaultShortcuts()
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.accentColor)
      .font(.system(size: 12))
      .focusable(false)
    }
    .padding(.bottom, 10)
  }

  private var hyperKeyRow: some View {
    HStack {
      Text("Enable Hyper Key (Caps Lock into ⌘ + ⌥ + ⌃ + ⇧)")
        .font(.system(size: 12))
      Spacer()
      Toggle(
        "",
        isOn: Binding(
          get: { model.config.hyperKeyEnabled },
          set: { enabled in model.updateConfig { $0.hyperKeyEnabled = enabled } }
        )
      )
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.small)
      .focusable(false)
    }
    .padding(.vertical, 10)
  }

  private var filterBar: some View {
    HStack(spacing: 8) {
      TextField("Type to search...", text: $filterText)
        .textFieldStyle(.roundedBorder)
        .font(.system(size: 12))
      Button {
        model.startRecordingShortcutFilter()
      } label: {
        Text("⌨")
          .font(.system(size: 14))
          .frame(width: 28, height: 22)
          .background(
            model.shortcutFilter == nil ? Color.clear : Color.accentColor.opacity(0.15),
            in: RoundedRectangle(cornerRadius: 5)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 5)
              .stroke(model.shortcutFilter == nil ? Color(nsColor: .separatorColor) : Color.accentColor)
          )
      }
      .buttonStyle(.plain)
      .focusable(false)
      .help("Filter by shortcut")
    }
    .padding(.vertical, 10)
  }

  private func shortcutFilterStrip(_ filter: String) -> some View {
    HStack(spacing: 6) {
      Text("Filtering by shortcut:")
        .font(.system(size: 12))
      HStack(spacing: 3) {
        ForEach(Array(ShortcutFormat.symbols(filter).enumerated()), id: \.offset) { _, symbol in
          KeyCap(symbol: symbol)
        }
      }
      Spacer()
      Button {
        model.shortcutFilter = nil
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.red)
      }
      .buttonStyle(.plain)
      .focusable(false)
    }
    .padding(8)
    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    .padding(.bottom, 8)
  }

  private var list: some View {
    let items = visibleItems
    return ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
          row(item, striped: index % 2 == 1)
        }
      }
    }
    .scrollIndicators(.automatic)
  }

  // MARK: Rows

  private func row(_ item: Item, striped: Bool) -> some View {
    let enabled = model.isItemEnabled(item.id)
    let shortcut = model.config.shortcuts[item.id].flatMap { $0.isEmpty ? nil : $0 }

    return HStack(spacing: 8) {
      Toggle(
        "",
        isOn: Binding(
          get: { model.isItemEnabled(item.id) },
          set: { model.setItem(item.id, enabled: $0) }
        )
      )
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.mini)
      .focusable(false)

      ItemIconView(icon: item.icon)

      Text(item.name)
        .font(.system(size: 12))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

      shortcutArea(for: item, enabled: enabled, shortcut: shortcut)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      striped ? Color(nsColor: .quaternaryLabelColor).opacity(0.25) : Color.clear,
      in: RoundedRectangle(cornerRadius: 4)
    )
    .opacity(enabled ? 1 : 0.5)
  }

  @ViewBuilder
  private func shortcutArea(for item: Item, enabled: Bool, shortcut: String?) -> some View {
    if enabled, let shortcut {
      HStack(spacing: 3) {
        ForEach(Array(ShortcutFormat.symbols(shortcut).enumerated()), id: \.offset) { _, symbol in
          KeyCap(symbol: symbol)
        }
        Button {
          model.clearShortcut(for: item.id)
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.red)
            .padding(.leading, 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
      }
      .contentShape(Rectangle())
      .onTapGesture { model.startRecordingShortcut(for: item.id) }
    } else if enabled {
      Text("Click to set")
        .font(.system(size: 11))
        .foregroundStyle(Color.accentColor)
        .contentShape(Rectangle())
        .onTapGesture { model.startRecordingShortcut(for: item.id) }
    } else {
      Text("Disabled")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }

  // MARK: Filtering

  private var visibleItems: [Item] {
    let text = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
    let shortcuts = model.config.shortcuts
    let shortcutFilter = model.shortcutFilter
    return model.settingsItems.filter { item in
      if !text.isEmpty,
        item.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) == nil
      {
        return false
      }
      if let shortcutFilter, !Self.shortcutMatches(shortcuts[item.id], filter: shortcutFilter) {
        return false
      }
      return true
    }
  }

  /// Port of the previous build's `shortcutMatchesFilter`: an exact match
  /// regardless of token order, or every filter token present in the shortcut.
  static func shortcutMatches(_ shortcut: String?, filter: String) -> Bool {
    guard let shortcut, !shortcut.isEmpty else { return false }
    let shortcutTokens = shortcut.lowercased().split(separator: "+").map(String.init)
    let filterTokens = filter.lowercased().split(separator: "+").map(String.init)
    if shortcutTokens.sorted() == filterTokens.sorted() { return true }
    return filterTokens.allSatisfy(shortcutTokens.contains)
  }
}
