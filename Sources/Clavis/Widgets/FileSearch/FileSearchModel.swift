import Foundation
import Observation
import ClavisCore
import UniformTypeIdentifiers

/// File search backed by Spotlight (NSMetadataQuery), scoped to the configured
/// search folders. The previous build kept its own SQLite index but only ever
/// searched the first 1000 rows of it.
///
/// Folders excluded from Spotlight (System Settings > Spotlight > Search
/// Privacy) return nothing, and results depend on Spotlight having indexed
/// the files.
@MainActor
@Observable
final class FileSearchModel {
  /// The previous widget waited this long after typing before searching.
  static let debounce: Duration = .milliseconds(150)
  /// Spotlight can match far more than is worth ranking or showing.
  static let gatherLimit = 1000
  static let resultLimit = 200

  private(set) var results: [FileResult] = [] {
    // Results replace each other asynchronously; the selection follows the
    // file's path, falling back to the first result.
    didSet { selection.keepValid(in: results) }
  }
  private var selection = Selection<String>()

  var selectedPath: String? { selection.id }
  var selectedIndex: Int { selection.index(in: results) }
  var selectedResult: FileResult? { selection.element(in: results) }

  func select(path: String) {
    selection.select(path)
  }

  func moveSelection(by delta: Int) {
    selection.move(by: delta, in: results)
  }

  /// Test seam: replaces results without running a Spotlight query.
  func setResultsForTesting(_ results: [FileResult]) {
    self.results = results
  }
  private(set) var isLoading = false

  @ObservationIgnored private var debounceTask: Task<Void, Never>?
  @ObservationIgnored private var metadataQuery: NSMetadataQuery?
  @ObservationIgnored private var gatherObserver: NSObjectProtocol?
  /// Bumped for every search and stop, so a superseded query's results are
  /// ignored.
  @ObservationIgnored private var generation = 0

  func search(query: String, folders: [String]) {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    generation += 1
    let searchGeneration = generation
    debounceTask?.cancel()
    debounceTask = nil
    stopQuery()

    let scopes = folders.map { ($0 as NSString).expandingTildeInPath }.filter {
      FileManager.default.fileExists(atPath: $0)
    }
    guard !text.isEmpty, !scopes.isEmpty else {
      results = []
      isLoading = false
      return
    }

    isLoading = true
    debounceTask = Task { [weak self] in
      try? await Task.sleep(for: Self.debounce)
      guard !Task.isCancelled, let self, searchGeneration == self.generation else { return }
      self.startQuery(text: text, scopes: scopes, generation: searchGeneration)
    }
  }

  func stop() {
    generation += 1
    debounceTask?.cancel()
    debounceTask = nil
    stopQuery()
    isLoading = false
  }

  private func startQuery(text: String, scopes: [String], generation searchGeneration: Int) {
    let query = NSMetadataQuery()
    query.predicate = NSPredicate(
      format: "%K LIKE[cd] %@", NSMetadataItemFSNameKey, FileSearch.likePattern(for: text))
    query.searchScopes = scopes.map { URL(fileURLWithPath: $0, isDirectory: true) }

    gatherObserver = NotificationCenter.default.addObserver(
      forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.finishGathering(text: text, generation: searchGeneration)
      }
    }
    metadataQuery = query

    // Started from the main thread, so gathering notifications arrive on the
    // main run loop.
    guard query.start() else {
      NSLog("Could not start Spotlight query for \"\(text)\"")
      stopQuery()
      results = []
      isLoading = false
      return
    }
  }

  private func finishGathering(text: String, generation searchGeneration: Int) {
    guard searchGeneration == generation, let query = metadataQuery else { return }
    query.disableUpdates()

    var gathered: [FileResult] = []
    let count = min(query.resultCount, Self.gatherLimit)
    gathered.reserveCapacity(count)
    for index in 0..<count {
      guard let item = query.result(at: index) as? NSMetadataItem,
        let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
        let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
        !name.hasPrefix(".")
      else { continue }
      let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
      let isDirectory = contentType.flatMap { UTType($0) }?.conforms(to: .folder) ?? false
      gathered.append(FileResult(path: path, name: name, isDirectory: isDirectory))
    }

    stopQuery()
    results = FileSearch.rank(gathered, query: text, limit: Self.resultLimit)
    isLoading = false
  }

  private func stopQuery() {
    if let gatherObserver {
      NotificationCenter.default.removeObserver(gatherObserver)
      self.gatherObserver = nil
    }
    metadataQuery?.stop()
    metadataQuery = nil
  }
}
