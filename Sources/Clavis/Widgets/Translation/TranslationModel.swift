import Foundation
import Observation

/// Translations of the query into the configured languages, one row each.
@MainActor
@Observable
final class TranslationModel {
  struct Row: Identifiable {
    let id: Int
    let language: String
    let result: Result<String, Error>
  }

  enum State {
    case idle
    case loading
    case loaded([Row])
  }

  typealias Translate = @Sendable (_ text: String, _ languages: [String]) async -> [Result<String, Error>]

  private(set) var state: State = .idle
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private let translateTexts: Translate

  /// Tests inject a stub so they never reach the network.
  init(translate: @escaping Translate = { text, languages in await Translator.translate(text, into: languages) }) {
    self.translateTexts = translate
  }

  var rows: [Row] {
    if case .loaded(let rows) = state { return rows }
    return []
  }

  /// Starts translating, cancelling any translation still running.
  func translate(_ text: String, languages: [String]) {
    task?.cancel()
    state = .loading
    let translateTexts = translateTexts
    task = Task { [weak self] in
      let results = await translateTexts(text, languages)
      guard !Task.isCancelled, let self else { return }
      state = .loaded(
        zip(languages, results).enumerated().map { index, pair in
          Row(id: index, language: pair.0, result: pair.1)
        })
    }
  }

  /// The translated text at `index`, or nil for a failed or missing row.
  func text(at index: Int) -> String? {
    let rows = rows
    guard rows.indices.contains(index), case .success(let text) = rows[index].result else { return nil }
    return text
  }

  func clear() {
    task?.cancel()
    task = nil
    state = .idle
  }
}
