import AppKit
import ImageIO
import RadixCore
import SwiftUI

/// Clipboard history: a list of copies on the left, a preview of the
/// selected one on the right. Enter pastes, ⇧⌫ deletes.
struct ClipboardWidget: View {
  @Bindable var model: AppModel
  let clipboard: ClipboardModel
  let onConfirm: () -> Void
  @FocusState private var searchFocused: Bool

  static let listWidth: CGFloat = 256
  static let maxPreviewLength = 5000

  var body: some View {
    let items = clipboard.visibleItems
    let selected = clipboard.selectedItem

    VStack(spacing: 0) {
      searchField
      HStack(spacing: 0) {
        list(items)
          .frame(width: Self.listWidth)
        preview(selected)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
      }
      .frame(maxHeight: .infinity)
      footer
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

      TextField("Search Pasteboard...", text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 18))
        .focused($searchFocused)
    }
    .padding(.horizontal, 20)
    .frame(height: AppModel.compactHeight)
  }

  @ViewBuilder
  private func list(_ items: [PasteItem]) -> some View {
    if items.isEmpty {
      Text("[ ]")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(items) { item in
              row(item, isSelected: item.id == clipboard.selectedID)
                .id(item.id)
                .onTapGesture {
                  clipboard.select(id: item.id)
                  onConfirm()
                }
            }
          }
          .padding(.vertical, 6)
          .padding(.leading, 8)
        }
        .scrollIndicators(.hidden)
        .onChange(of: clipboard.selectedID) { _, id in
          guard let id else { return }
          proxy.scrollTo(id)
        }
      }
    }
  }

  private func row(_ item: PasteItem, isSelected: Bool) -> some View {
    HStack(spacing: 8) {
      rowIcon(item)
        .frame(width: 24, height: 24)
      // A one-line title; entries can be megabytes of text, so only the start
      // is ever trimmed.
      Text(item.text.prefix(300).trimmingCharacters(in: .whitespacesAndNewlines))
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
    .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4))
    .opacity(isSelected ? 1 : 0.8)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private func rowIcon(_ item: PasteItem) -> some View {
    if let path = item.url, ClipboardModel.isImagePath(path), let image = ImageFileCache.shared.image(atPath: path) {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    } else if let iconPath = Self.iconPath(for: item) {
      Image(nsImage: IconCache.shared.icon(forPath: iconPath))
        .resizable()
        .interpolation(.high)
    } else {
      Image(systemName: "doc.on.clipboard")
        .foregroundStyle(.secondary)
    }
  }

  /// The source app's icon, else the copied file's, as the old row did.
  static func iconPath(for item: PasteItem) -> String? {
    for candidate in [item.bundle, item.url].compactMap({ $0 }) {
      if let url = URL(string: candidate), url.isFileURL {
        return url.path
      }
      if candidate.hasPrefix("/") {
        return candidate
      }
    }
    return nil
  }

  @ViewBuilder
  private func preview(_ item: PasteItem?) -> some View {
    if let item {
      ScrollView {
        previewContent(item)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(12)
      }
      .background(Color(nsColor: .textBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    } else {
      Color.clear
    }
  }

  @ViewBuilder
  private func previewContent(_ item: PasteItem) -> some View {
    if let path = item.url {
      if ClipboardModel.isImagePath(path), let image = ImageFileCache.shared.image(atPath: path) {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: 360)
      } else {
        VStack(spacing: 8) {
          Image(nsImage: IconCache.shared.icon(forPath: path))
            .resizable()
            .interpolation(.high)
            .frame(width: 80, height: 80)
          Text(item.text)
            .font(.system(size: 12, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
      }
    } else {
      Text(Self.truncated(item.text))
        .font(.system(size: 11))
        .textSelection(.enabled)
    }
  }

  static func truncated(_ text: String) -> String {
    // Counting a huge string walks all of it; check the cheap prefix first.
    guard text.prefix(maxPreviewLength + 1).count > maxPreviewLength else { return text }
    let total = text.count.formatted()
    return "\(text.prefix(maxPreviewLength))\n\n... (\(total) chars total)"
  }

  private var footer: some View {
    HStack(spacing: 4) {
      Spacer()
      Text("Delete Item")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.trailing, 4)
      KeyCap(symbol: "⇧")
      KeyCap(symbol: "⌫")
      Spacer().frame(width: 16)
      Text("Paste")
        .font(.system(size: 11))
        .padding(.trailing, 4)
      KeyCap(symbol: "⏎", primary: true)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color(nsColor: .underPageBackgroundColor).opacity(0.4))
    .overlay(alignment: .top) {
      Divider()
    }
  }
}

/// Downscaled clipboard images, decoded off the main thread. A full-size
/// screenshot must not be decoded on every render just to draw a 24 pt
/// thumbnail or a 360 pt preview.
@MainActor
@Observable
final class ImageFileCache {
  static let shared = ImageFileCache()
  /// Large enough for the preview; thumbnails reuse it.
  nonisolated static let maxPixelSize = 1024

  @ObservationIgnored private let cache = NSCache<NSString, NSImage>()
  @ObservationIgnored private var missing: Set<String> = []
  @ObservationIgnored private var loading: Set<String> = []
  /// Bumped when an image finishes loading so views re-read the cache.
  private(set) var revision = 0

  private init() {
    cache.countLimit = 100
  }

  /// The cached image, or nil while it loads (a load is started) or when the
  /// file can't be read.
  func image(atPath path: String) -> NSImage? {
    if let cached = cache.object(forKey: path as NSString) { return cached }
    _ = revision
    guard !missing.contains(path), !loading.contains(path) else { return nil }
    loading.insert(path)
    Task { [weak self] in
      let image = await Task.detached(priority: .userInitiated) { Self.thumbnail(atPath: path) }.value
      guard let self else { return }
      loading.remove(path)
      if let image {
        cache.setObject(image, forKey: path as NSString)
      } else {
        missing.insert(path)
      }
      revision += 1
    }
    return nil
  }

  nonisolated private static func thumbnail(atPath path: String) -> NSImage? {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
  }
}
