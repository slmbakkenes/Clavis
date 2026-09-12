import RadixCore
import SwiftUI

/// Searches files in the configured folders; Enter opens, ⇧Enter reveals the
/// containing folder.
struct FileSearchWidget: View {
  @Bindable var model: AppModel
  let fileSearch: FileSearchModel
  @FocusState private var searchFocused: Bool

  /// The previous widget showed the first 45 characters of the path.
  private static let pathPreviewLength = 45

  var body: some View {
    VStack(spacing: 0) {
      searchField
      loadingBar
      list
      if !fileSearch.results.isEmpty {
        footer
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear {
      searchFocused = true
      runSearch()
    }
    .onChange(of: model.query) { _, _ in runSearch() }
    .onDisappear { fileSearch.stop() }
    // The panel is non-activating and AppKit does not restore the field
    // responder, so focus is re-asserted every time the panel comes back.
    .onChange(of: model.isVisible) { _, visible in
      if visible { searchFocused = true }
    }
  }

  private func runSearch() {
    fileSearch.search(query: model.query, folders: model.config.searchFolders)
  }

  private var searchField: some View {
    HStack(spacing: 12) {
      Button {
        model.query = ""
        model.focusWidget(.search)
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Theme.textMuted)
      }
      .buttonStyle(.plain)
      .focusable(false)

      TextField("Search for files...", text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 18))
        .foregroundStyle(Theme.text)
        .tint(Theme.fg1)
        .focused($searchFocused)
    }
    .padding(.horizontal, 20)
    .frame(height: AppModel.compactHeight)
  }

  /// A 2 pt strip that is always laid out, so the list doesn't jump when
  /// loading starts or stops.
  private var loadingBar: some View {
    ZStack {
      if fileSearch.isLoading {
        ProgressView()
          .progressViewStyle(.linear)
          .controlSize(.mini)
          .labelsHidden()
      }
    }
    .frame(height: 2)
    .frame(maxWidth: .infinity)
    .clipped()
  }

  @ViewBuilder
  private var list: some View {
    let rows = fileSearch.results
    if rows.isEmpty {
      Text("No items")
        .font(.system(size: 13))
        .foregroundStyle(Theme.textMuted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(rows) { result in
              row(result, isSelected: result.path == fileSearch.selectedPath)
                .id(result.id)
                .onTapGesture { fileSearch.select(path: result.path) }
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .onChange(of: fileSearch.selectedPath) { _, path in
          guard let path else { return }
          proxy.scrollTo(path)
        }
      }
    }
  }

  private func row(_ result: FileResult, isSelected: Bool) -> some View {
    HStack(spacing: 0) {
      Image(nsImage: IconCache.shared.icon(forPath: result.path))
        .resizable()
        .interpolation(.high)
        .frame(width: 24, height: 24)

      Text(result.name)
        .lineLimit(1)
        .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.text)
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(String(result.path.prefix(Self.pathPreviewLength)))
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(isSelected ? Theme.textOnSelection : Theme.textMuted)
        .padding(.leading, 8)
    }
    .padding(.horizontal, 24)
    .frame(height: 48)
    .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    .contentShape(RoundedRectangle(cornerRadius: 12))
  }

  private var footer: some View {
    HStack(spacing: 4) {
      Spacer()
      hint("Open Folder")
      KeyCap(symbol: "⇧")
      KeyCap(symbol: "⏎")
      hint("Open")
        .padding(.leading, 8)
      KeyCap(symbol: "⏎", primary: true)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Theme.elevated.opacity(0.6))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Theme.separator)
        .frame(height: 1)
    }
  }

  private func hint(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11))
      .foregroundStyle(Theme.textMuted)
      .padding(.trailing, 4)
  }
}
