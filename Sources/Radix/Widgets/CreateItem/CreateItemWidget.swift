import RadixCore
import SwiftUI

/// Creates or edits a custom item (Quick Link): an icon, a name and a link.
struct CreateItemWidget: View {
  @Bindable var model: AppModel
  @Environment(\.colorScheme) private var colorScheme

  @State private var symbol = CustomIcons.defaultSymbol
  @State private var color = CustomIcons.colorPalette[0]
  @State private var name = ""
  @State private var link = ""
  @State private var isPickingIcon = false
  @State private var error: String?
  @State private var didLoad = false
  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case name
    case link
  }

  private static let labelWidth: CGFloat = 96
  private static let pickerColumns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 12)

  var body: some View {
    VStack(spacing: 0) {
      header
      if isPickingIcon {
        picker
      } else {
        form
      }
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear(perform: load)
    .onChange(of: model.isVisible) { _, visible in
      if visible, !isPickingIcon { focusedField = focusedField ?? .name }
    }
  }

  private var isEditing: Bool { model.editingCustomItem != nil }

  // MARK: Sections

  private var header: some View {
    HStack {
      Button(action: close) {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .focusable(false)
      Spacer()
    }
    .padding(16)
  }

  private var form: some View {
    VStack(spacing: 12) {
      row("Icon") {
        Button {
          isPickingIcon = true
        } label: {
          iconTile(symbol, size: 24)
        }
        .buttonStyle(.plain)
        .focusable(false)
        Spacer()
      }
      row("Name") {
        TextField("My Quick Link", text: $name)
          .textFieldStyle(.roundedBorder)
          .focused($focusedField, equals: .name)
          .onSubmit(commit)
      }
      row("Link") {
        TextField("https://google.com", text: $link)
          .textFieldStyle(.roundedBorder)
          .focused($focusedField, equals: .link)
          .onSubmit(commit)
      }
      if let error {
        row("") {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
          Spacer()
        }
      }
      Spacer()
    }
    .padding(.horizontal, 48)
    .padding(.top, 16)
  }

  private var picker: some View {
    VStack(spacing: 12) {
      HStack(spacing: 4) {
        ForEach(CustomIcons.colorPalette, id: \.self) { hex in
          Button {
            color = hex
          } label: {
            Circle()
              .fill(HexColor(hex).map(Color.init) ?? .gray)
              .frame(width: 16, height: 16)
              .padding(8)
              .background(
                hex == color ? Color(nsColor: .quaternaryLabelColor) : .clear,
                in: RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .focusable(false)
        }
      }
      ScrollView {
        LazyVGrid(columns: Self.pickerColumns, spacing: 4) {
          ForEach(CustomIcons.pickerSymbols, id: \.self) { candidate in
            Button {
              symbol = candidate
              isPickingIcon = false
              focusedField = .name
            } label: {
              Image(systemName: candidate)
                .font(.system(size: 16))
                .foregroundStyle(HexColor(color).map(Color.init) ?? .primary)
                .frame(width: 32, height: 32)
                .background(
                  candidate == symbol ? Color(nsColor: .quaternaryLabelColor) : .clear,
                  in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .focusable(false)
          }
        }
        .padding(8)
      }
      .scrollIndicators(.hidden)
    }
    .padding(.horizontal, 24)
  }

  private var footer: some View {
    HStack {
      Spacer()
      Button(isEditing ? "Update" : "Create", action: commit)
        .buttonStyle(.borderedProminent)
        .focusable(false)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color(nsColor: .separatorColor))
        .frame(height: 1)
    }
  }

  private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.system(size: 13, weight: .bold))
        .frame(width: Self.labelWidth, alignment: .trailing)
      content()
    }
  }

  private func iconTile(_ name: String, size: CGFloat) -> some View {
    Image(systemName: name)
      .font(.system(size: size * 0.55, weight: .semibold))
      .foregroundStyle(HexColor(color).map(Color.init) ?? .primary)
      .frame(width: size, height: size)
      .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
      .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor)))
  }

  // MARK: Actions

  private func load() {
    guard !didLoad else { return }
    didLoad = true
    if let item = model.editingCustomItem {
      symbol = CustomIcons.symbolName(for: item.icon)
      color = item.color ?? defaultColor
      name = item.name
      link = item.text
    } else {
      color = defaultColor
    }
    focusedField = .name
  }

  private var defaultColor: String {
    colorScheme == .dark ? CustomIcons.colorPalette[1] : CustomIcons.colorPalette[0]
  }

  private func commit() {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      error = "Give the link a name."
      focusedField = .name
      return
    }
    guard !trimmedLink.isEmpty else {
      error = "Enter a URL or a path."
      focusedField = .link
      return
    }

    if let editing = model.editingCustomItem {
      guard model.config.customItems.contains(where: { $0.id == editing.id }) else {
        error = "This link no longer exists."
        return
      }
      // An untouched legacy icon ("Github") keeps its stored name, so the
      // previous build still shows it; only a newly picked symbol replaces it.
      let icon = symbol == CustomIcons.symbolName(for: editing.icon) ? editing.icon : symbol
      model.updateConfig { config in
        guard let index = config.customItems.firstIndex(where: { $0.id == editing.id }) else { return }
        config.customItems[index].name = trimmedName
        config.customItems[index].icon = icon
        config.customItems[index].color = color
        config.customItems[index].text = trimmedLink
      }
    } else {
      model.updateConfig { config in
        config.customItems.append(CustomItem(name: trimmedName, icon: symbol, color: color, text: trimmedLink))
      }
    }
    close()
  }

  private func close() {
    model.editingCustomItem = nil
    model.query = ""
    model.focusWidget(.search)
  }
}
