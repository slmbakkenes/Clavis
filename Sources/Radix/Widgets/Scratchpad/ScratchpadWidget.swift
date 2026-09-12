import SwiftUI

/// A free-form note kept in state.json. Enter, arrows and Tab reach the
/// editor; the input router leaves them alone in this widget.
struct ScratchpadWidget: View {
  @Bindable var model: AppModel
  @FocusState private var editorFocused: Bool

  var body: some View {
    TextEditor(text: Binding(get: { model.state.note }, set: { model.setNote($0) }))
      .font(.system(size: 14))
      .foregroundStyle(Theme.text)
      .tint(Theme.fg1)
      .scrollContentBackground(.hidden)
      .background(.clear)
      .focusEffectDisabled()
      .focused($editorFocused)
      .padding(16)
      .overlay(alignment: .topLeading) {
        if model.state.note.isEmpty {
          Text("Write something...")
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSubtle)
            // TextEditor insets its text by about 5 pt horizontally.
            .padding(.horizontal, 21)
            .padding(.top, 16)
            .allowsHitTesting(false)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear { editorFocused = true }
      // The panel is non-activating and AppKit does not restore the
      // responder, so focus is re-asserted every time the panel comes back.
      .onChange(of: model.isVisible) { _, visible in
        if visible { editorFocused = true }
      }
  }
}
