import Foundation
import ClavisCore

/// The unofficial Google Translate web client the previous build used. It
/// scrapes two tokens from the start page and posts to the batchexecute RPC,
/// so it can break whenever Google changes that page.
enum Translator {
  static func translate(_ text: String, to language: String, from: String = "auto", tld: String = "com")
    async throws -> String
  {
    let startURL = URL(string: "https://translate.google.\(tld)")!
    let page = try await fetchText(URLRequest(url: startURL))

    let url = GoogleTranslate.batchExecuteURL(
      tld: tld,
      sid: GoogleTranslate.extractToken("FdrFJe", from: page),
      bl: GoogleTranslate.extractToken("cfb2h", from: page),
      requestID: Int.random(in: 1000...9999))
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(GoogleTranslate.requestBody(text: text, from: from, to: language).utf8)

    let body = try await fetchText(request)
    do {
      return try GoogleTranslate.parseResponse(body)
    } catch {
      throw UserFacingError("\(error)")
    }
  }

  /// Translates into every language concurrently; results keep the input order.
  static func translate(_ text: String, into languages: [String]) async -> [Result<String, Error>] {
    await withTaskGroup(of: (Int, Result<String, Error>).self) { group in
      for (index, language) in languages.enumerated() {
        group.addTask {
          // Build the result first, then the tuple. Returning
          // `(index, .success(try await ...))` straight from do/catch made
          // every child report index 0 in release (-O) builds on Swift 6.3,
          // so only one translation survived. Verified against the live
          // endpoint with an optimized build.
          let result: Result<String, Error>
          do {
            result = .success(try await translate(text, to: language))
          } catch {
            result = .failure(error)
          }
          return (index, result)
        }
      }
      var results = [Result<String, Error>?](repeating: nil, count: languages.count)
      for await (index, result) in group {
        results[index] = result
      }
      return results.map { $0 ?? .failure(CancellationError()) }
    }
  }

  private static func fetchText(_ request: URLRequest) async throws -> String {
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw UserFacingError("Translation request failed: \(error.localizedDescription)")
    }
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw UserFacingError("Translation request failed with HTTP \(http.statusCode)")
    }
    return String(decoding: data, as: UTF8.self)
  }
}
