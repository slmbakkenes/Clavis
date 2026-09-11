import Foundation
import Testing

@testable import RadixCore

@Suite struct GoogleTranslateTests {
  // MARK: Tokens and URL

  @Test func extractsTokensFromTheStartPage() {
    let page = #"var x={"FdrFJe":"-123456789","cfb2h":"boq_translate-webserver_20260901.08_p0","other":"y"};"#
    #expect(GoogleTranslate.extractToken("FdrFJe", from: page) == "-123456789")
    #expect(GoogleTranslate.extractToken("cfb2h", from: page) == "boq_translate-webserver_20260901.08_p0")
    #expect(GoogleTranslate.extractToken("missing", from: page) == "")
    #expect(GoogleTranslate.extractToken("empty", from: #"{"empty":""}"#) == "")
  }

  @Test func batchExecuteURLKeepsTheOriginalParameterOrder() {
    let url = GoogleTranslate.batchExecuteURL(tld: "com", sid: "-42", bl: "boq_x_1.0", requestID: 1234)
    #expect(
      url.absoluteString
        == "https://translate.google.com/_/TranslateWebserverUi/data/batchexecute?rpcids=MkEWBc&f.sid=-42&bl=boq_x_1.0&hl=en-US&soc-app=1&soc-platform=1&soc-device=1&_reqid=1234&rt=c"
    )
  }

  // MARK: Request body (expected values produced by node's JSON.stringify + encodeURIComponent)

  @Test func requestBodyMatchesJavaScriptEncoding() {
    #expect(
      GoogleTranslate.requestBody(text: "good morning", from: "auto", to: "de")
        == "f.req=%5B%5B%5B%22MkEWBc%22%2C%22%5B%5B%5C%22good%20morning%5C%22%2C%5C%22auto%5C%22%2C%5C%22de%5C%22%2Ctrue%5D%2C%5Bnull%5D%5D%22%2Cnull%2C%22generic%22%5D%5D%5D&"
    )
    #expect(
      GoogleTranslate.requestBody(text: #"say "hi" & bye"#, from: "auto", to: "en")
        == "f.req=%5B%5B%5B%22MkEWBc%22%2C%22%5B%5B%5C%22say%20%5C%5C%5C%22hi%5C%5C%5C%22%20%26%20bye%5C%22%2C%5C%22auto%5C%22%2C%5C%22en%5C%22%2Ctrue%5D%2C%5Bnull%5D%5D%22%2Cnull%2C%22generic%22%5D%5D%5D&"
    )
    #expect(
      GoogleTranslate.requestBody(text: "café 日本 😀 a/b\\c\nnew\u{01}", from: "nl", to: "fr")
        == "f.req=%5B%5B%5B%22MkEWBc%22%2C%22%5B%5B%5C%22caf%C3%A9%20%E6%97%A5%E6%9C%AC%20%F0%9F%98%80%20a%2Fb%5C%5C%5C%5Cc%5C%5Cnnew%5C%5Cu0001%5C%22%2C%5C%22nl%5C%22%2C%5C%22fr%5C%22%2Ctrue%5D%2C%5Bnull%5D%5D%22%2Cnull%2C%22generic%22%5D%5D%5D&"
    )
  }

  // MARK: Response parsing

  /// Wraps a payload the way batchexecute does: `)]}'`, a UTF-16 length
  /// prefix, the envelope, and a trailing status chunk.
  private func response(payload: Any, lengthOverride: Int? = nil) throws -> String {
    let payloadJSON = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
    let envelope: [Any] = [["wrb.fr", "MkEWBc", payloadJSON, NSNull(), NSNull(), NSNull(), "generic"], ["di", 38]]
    let envelopeJSON = String(decoding: try JSONSerialization.data(withJSONObject: envelope), as: UTF8.self)
    let chunk = "\n" + envelopeJSON + "\n"
    let length = lengthOverride ?? chunk.utf16.count
    return ")]}'\n\n\(length)\(chunk)25\n[[\"e\",4,null,null,123]]\n"
  }

  private func payload(node: [Any]) -> [Any] {
    [NSNull(), [[node], "de", 1, "auto", ["good morning", "auto", "de", true]], "en"]
  }

  @Test func joinsTranslationParts() throws {
    let node: [Any] = [
      "Guten Morgen", NSNull(), NSNull(), true, NSNull(),
      [["Guten ", NSNull(), NSNull(), NSNull()], ["", NSNull()], ["Morgen", NSNull()]],
    ]
    #expect(try GoogleTranslate.parseResponse(response(payload: payload(node: node))) == "Guten Morgen")
  }

  @Test func fallsBackToTheFirstFieldWithoutParts() throws {
    let node: [Any] = ["https://example.com", NSNull()]
    #expect(try GoogleTranslate.parseResponse(response(payload: payload(node: node))) == "https://example.com")
  }

  @Test func handlesNonASCIIWhenTheLengthIsCountedDifferently() throws {
    let node: [Any] = ["Café 日本", NSNull(), NSNull(), NSNull(), NSNull(), [["Café 日本"]]]
    let payloadObject = payload(node: node)
    // A byte-counted length overshoots the UTF-16 slice into the next chunk.
    let body = try response(payload: payloadObject, lengthOverride: 10_000)
    #expect(try GoogleTranslate.parseResponse(body) == "Café 日本")
  }

  @Test func rejectsMalformedResponses() throws {
    #expect(throws: GoogleTranslateError.missingLengthPrefix) {
      try GoogleTranslate.parseResponse("<html>blocked</html>")
    }
    #expect(throws: GoogleTranslateError.missingLengthPrefix) {
      try GoogleTranslate.parseResponse("")
    }
    #expect(throws: GoogleTranslateError.self) {
      try GoogleTranslate.parseResponse(")]}'\n\n12\nnot json at all\n")
    }
    #expect(throws: GoogleTranslateError.self) {
      try GoogleTranslate.parseResponse(response(payload: ["unexpected"]))
    }
  }
}

@Suite struct LanguagesTests {
  @Test func containsTheOldTable() {
    #expect(Languages.names.count == 108)
    #expect(Languages.names["de"] == "German")
    #expect(Languages.names["zu"] == "Zulu")
  }

  @Test func sortedByNameIsAlphabetical() {
    let names = Languages.sortedByName.map(\.name)
    #expect(names.first == "Afrikaans")
    #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
  }
}
