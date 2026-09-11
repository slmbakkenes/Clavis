import RadixCore
import SwiftUI

/// The main widget: search field, results, and key hints.
struct SearchWidget: View {
  @Bindable var model: AppModel
  @FocusState private var searchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      searchField

      if model.query.isEmpty {
        if !model.isAccessibilityTrusted {
          PermissionsBar()
        }
      } else {
        results
        SearchFooter(hasRows: !model.searchRows.isEmpty, selectedIsCustom: selectedIsCustom)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear { searchFocused = true }
    // The panel is non-activating and AppKit does not restore the field
    // responder, so focus is re-asserted every time the panel comes back.
    .onChange(of: model.isVisible) { _, visible in
      if visible { searchFocused = true }
    }
  }

  private var searchField: some View {
    TextField("Search your mac...", text: $model.query)
      .textFieldStyle(.plain)
      .font(.system(size: 18))
      .focused($searchFocused)
      .padding(.horizontal, 20)
      .frame(height: AppModel.compactHeight)
  }

  private var selectedIsCustom: Bool {
    if case .item(let item) = model.selectedRow { return item.kind == .custom }
    return false
  }

  @ViewBuilder
  private var results: some View {
    if model.searchRows.isEmpty {
      Text("[ ]")
        .font(.system(size: 48, weight: .thin))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(model.searchRows.enumerated()), id: \.element.id) { index, row in
              rowView(row, index: index)
                .id(row.id)
                .onTapGesture {
                  model.selectedIndex = index
                  Task { await model.confirmSearch(modifiers: []) }
                }
            }
          }
          .padding(8)
        }
        .scrollIndicators(.hidden)
        .onChange(of: model.selectedIndex) { _, index in
          guard model.searchRows.indices.contains(index) else { return }
          proxy.scrollTo(model.searchRows[index].id)
        }
      }
    }
  }

  @ViewBuilder
  private func rowView(_ row: SearchRow, index: Int) -> some View {
    let isSelected = index == model.selectedIndex
    switch row {
    case .temporaryResult(let result):
      TemporaryResultView(result: result, isSelected: isSelected)
    case .item(let item):
      SearchRowView(item: item, isSelected: isSelected, shortcut: model.config.shortcuts[item.id])
    }
  }
}
