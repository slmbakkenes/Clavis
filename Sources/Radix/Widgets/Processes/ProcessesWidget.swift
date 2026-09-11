import RadixCore
import SwiftUI

/// Lists running processes; Enter kills the selected one.
struct ProcessesWidget: View {
  @Bindable var model: AppModel
  let processes: ProcessesModel
  @FocusState private var searchFocused: Bool

  private static let columnWidth: CGFloat = 112
  private static let memoryFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    return formatter
  }()

  var body: some View {
    let rows = processes.visibleEntries

    VStack(spacing: 0) {
      searchField
      header
      list(rows)
      footer
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear {
      searchFocused = true
      processes.startAutoRefresh()
    }
    .onDisappear { processes.stopAutoRefresh() }
    // The panel is non-activating and AppKit does not restore the field
    // responder, so focus is re-asserted every time the panel comes back.
    .onChange(of: model.isVisible) { _, visible in
      if visible { searchFocused = true }
    }
  }

  private var searchField: some View {
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

      TextField("Search processes...", text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 18))
        .focused($searchFocused)
    }
    .padding(.horizontal, 20)
    .frame(height: AppModel.compactHeight)
  }

  private var header: some View {
    HStack(spacing: 0) {
      Text("Process Name").frame(maxWidth: .infinity, alignment: .leading)
      Text("Memory").frame(width: Self.columnWidth, alignment: .leading)
      Text("CPU").frame(width: Self.columnWidth, alignment: .leading)
    }
    .font(.system(size: 13, weight: .semibold))
    .padding(.horizontal, 28)
    .padding(.vertical, 8)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color(nsColor: .separatorColor))
        .frame(height: 1)
    }
  }

  @ViewBuilder
  private func list(_ rows: [ProcessEntry]) -> some View {
    if rows.isEmpty {
      Text("No items")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(rows) { entry in
              row(entry, isSelected: entry.pid == processes.selectedPid)
                .id(entry.id)
                .onTapGesture { processes.select(pid: entry.pid) }
            }
          }
          .padding(8)
        }
        .scrollIndicators(.hidden)
        .onChange(of: processes.selectedPid) { _, pid in
          guard let pid else { return }
          proxy.scrollTo(pid)
        }
      }
    }
  }

  private func row(_ entry: ProcessEntry, isSelected: Bool) -> some View {
    HStack(spacing: 0) {
      Text(entry.name)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(Self.memoryFormatter.string(fromByteCount: Int64(entry.memoryKilobytes) * 1024))
        .frame(width: Self.columnWidth, alignment: .leading)
      Text("\(Int(entry.cpu.rounded()))%")
        .frame(width: Self.columnWidth, alignment: .leading)
    }
    .font(.system(size: 13))
    .foregroundStyle(isSelected ? Color.white : Color.primary)
    .padding(.horizontal, 20)
    .frame(height: 36)
    .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    .contentShape(RoundedRectangle(cornerRadius: 12))
  }

  private var footer: some View {
    HStack(spacing: 4) {
      Spacer()
      Text("Kill process")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.trailing, 4)
      KeyCap(symbol: "⏎", primary: true)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color(nsColor: .separatorColor))
        .frame(height: 1)
    }
  }
}
