import SwiftUI

/// Shows the query translated into each configured language.
struct TranslationWidget: View {
  @Bindable var model: AppModel
  let translation: TranslationModel
  @FocusState private var fieldFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      field
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear { fieldFocused = true }
    // The panel is non-activating and AppKit does not restore the field
    // responder, so focus is re-asserted every time the panel comes back.
    .onChange(of: model.isVisible) { _, visible in
      if visible { fieldFocused = true }
    }
  }

  private var field: some View {
    HStack(spacing: 12) {
      Button {
        model.query = ""
        model.focusWidget(.search)
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .focusable(false)

      TextField("Translate...", text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 18))
        .focused($fieldFocused)
    }
    .padding(.horizontal, 20)
    .frame(height: AppModel.compactHeight)
  }

  @ViewBuilder
  private var content: some View {
    switch translation.state {
    case .idle, .loading:
      Text("Translating...")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .loaded(let rows):
      VStack(spacing: 0) {
        ForEach(rows) { row in
          box(row, isSelected: row.id == model.selectedIndex)
        }
      }
      .padding(4)
    }
  }

  private func box(_ row: TranslationModel.Row, isSelected: Bool) -> some View {
    ZStack(alignment: .bottomTrailing) {
      Group {
        switch row.result {
        case .success(let text):
          Text(text)
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .textSelection(.enabled)
        case .failure(let error):
          Text(verbatim: String(describing: error))
            .font(.system(size: 12))
            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      Text(row.language)
        .font(.system(size: 12))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .opacity(0.5)
    }
    .padding(12)
    .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    .padding(4)
  }
}
