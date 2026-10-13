import Foundation
import Testing
@testable import ClavisCore

@Suite struct ShortcutTests {
  /// Every string in the real config.json at the time of the port, plus the
  /// defaults. Parsing then formatting must reproduce them byte-for-byte.
  static let realShortcuts = [
    "control+option+return", "command+option+q", "control+option+right",
    "control+option+left", "control+option+up", "control+option+down",
    "control+option+u", "control+option+i", "control+option+j", "control+option+k",
    "control+option+command+right", "control+option+command+left",
    "command+shift+space", "command+option+v",
  ]

  @Test(arguments: realShortcuts + Array(Shortcut.defaults.values))
  func roundTrip(_ raw: String) throws {
    let shortcut = try #require(Shortcut(parsing: raw))
    #expect(shortcut.string == raw)
    #expect(ShortcutFormat.normalize(raw) == raw)
  }

  @Test func parsesModifiersAndKey() throws {
    let s = try #require(Shortcut(parsing: "control+option+command+right"))
    #expect(s.modifiers == [.control, .option, .command])
    #expect(s.key == "right")
    let q = try #require(Shortcut(parsing: "command+option+q"))
    #expect(q.modifiers == [.command, .option])
    #expect(q.key == "q")
  }

  @Test func normalisesSymbolsAndAliases() {
    #expect(ShortcutFormat.normalize("⌘+⇧+␣") == "command+shift+space")
    #expect(ShortcutFormat.normalize("Cmd + Option + \u{f703}") == "command+option+right")
    #expect(ShortcutFormat.normalize("⌃+⌥+↩") == "control+option+return")
    #expect(ShortcutFormat.normalize("control++Q") == "control+q")
    // Same as the JS: trim() ate "\r" before the alias table could see it.
    #expect(ShortcutFormat.normalize("\r") == "")
    #expect(Shortcut(parsing: "cmd+k")?.string == "command+k")
    #expect(Shortcut(parsing: "cmd+k")?.modifiers == [.command])
    #expect(ShortcutFormat.normalize(["a": "⌘+K"]) == ["a": "command+k"])
  }

  @Test func rejectsInvalid() {
    #expect(Shortcut(parsing: "control+option") == nil, "no key")
    #expect(Shortcut(parsing: "control+a+b") == nil, "two keys")
    #expect(Shortcut(parsing: "control+f18") == nil, "unknown token")
    #expect(Shortcut(parsing: "") == nil)
    #expect(ShortcutFormat.isValidToken("ú"))
    #expect(ShortcutFormat.isValidToken("cmd"))
    #expect(!ShortcutFormat.isValidToken("esc"))
    #expect(!ShortcutFormat.isValidToken("ab"))
  }

  @Test func symbols() {
    #expect(ShortcutFormat.symbols("control+option+return") == ["⌃", "⌥", "↩"])
    #expect(ShortcutFormat.symbols("command+shift+space") == ["⌘", "⇧", "␣"])
    #expect(ShortcutFormat.symbols("cmd+option+v") == ["⌘", "⌥", "v"])
  }
}

@Suite struct URLDetectionTests {
  @Test func looseAcceptsBareHosts() {
    #expect(URLDetection.isLooseURL("github.com"))
    #expect(URLDetection.isLooseURL("github.com/ospfranco/sol"))
    #expect(URLDetection.isLooseURL("Docs.Example.co.uk:8080/path?x=1#frag"))
    #expect(URLDetection.isLooseURL("mailto:a@b.co"), "auth-prefix branch, same as the JS regex")
    #expect(URLDetection.isLooseURL("user:pw@example.com"))
    #expect(URLDetection.isLooseURL("8.8.8.8"))
    #expect(URLDetection.isLooseURL("example.com."))
  }

  @Test func looseRejectsPlainQueries() {
    #expect(!URLDetection.isLooseURL("hello world"))
    #expect(!URLDetection.isLooseURL("visual studio code"))
    #expect(!URLDetection.isLooseURL("2+2"))
    #expect(!URLDetection.isLooseURL("localhost"), "no TLD")
    #expect(!URLDetection.isLooseURL("192.168.1.1"), "private range excluded")
    #expect(!URLDetection.isLooseURL("10.0.0.1"))
    #expect(!URLDetection.isLooseURL("example.c"), "TLD too short")
    #expect(!URLDetection.isLooseURL(""))
    // The scheme is not part of the loose pattern; callers check for it first.
    #expect(!URLDetection.isLooseURL("https://example.com"))
  }

  @Test func strictNeedsScheme() {
    #expect(URLDetection.isStrictURL("https://example.com/a?b=c"))
    #expect(URLDetection.isStrictURL("ftp://files.example.org"))
    #expect(URLDetection.isStrictURL("HTTP://EXAMPLE.COM"))
    #expect(!URLDetection.isStrictURL("example.com"))
    #expect(!URLDetection.isStrictURL("mailto:a@b.co"))
  }
}

@Suite struct SearchEngineTests {
  @Test func builtInEngines() {
    #expect(SearchEngine.google.searchURL(for: "swift pm") == "https://google.com/search?q=swift%20pm")
    #expect(SearchEngine.duckduckgo.searchURL(for: "a&b") == "https://duckduckgo.com/?q=a&b")
    #expect(SearchEngine.bing.searchURL(for: "x") == "https://bing.com/search?q=x")
    #expect(SearchEngine.perplexity.searchURL(for: "café") == "https://perplexity.ai/search/new?q=caf%C3%A9")
  }

  @Test func customEngine() {
    #expect(SearchEngine.isValidCustomURL("https://kagi.com/search?q=%s"))
    #expect(SearchEngine.isValidCustomURL("http://localhost:3000/s?query=%s"))
    #expect(SearchEngine.isValidCustomURL("https://10.0.0.5/search?q=%s"))
    #expect(!SearchEngine.isValidCustomURL(""))
    #expect(!SearchEngine.isValidCustomURL("   "))
    #expect(!SearchEngine.isValidCustomURL("kagi.com/search?q=%s"), "scheme required")
    #expect(!SearchEngine.isValidCustomURL("https://kagi.com/search?q=%s&x=1"), "%s must be last")
    #expect(!SearchEngine.isValidCustomURL("https://kagi.com/search"), "placeholder required")
    #expect(
      SearchEngine.custom.searchURL(for: "hi there", customSearchURL: "https://kagi.com/search?q=%s")
        == "https://kagi.com/search?q=hi%20there")
    #expect(SearchEngine.custom.searchURL(for: "hi", customSearchURL: "nope") == nil)
  }
}
