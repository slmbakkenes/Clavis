import Foundation
import Testing

@testable import ClavisCore

@Suite struct ChromiumBookmarksTests {
  static let json = """
    {
      "checksum": "abc",
      "roots": {
        "synced": {
          "type": "folder", "name": "Mobile bookmarks",
          "children": [{ "type": "url", "name": "Synced", "url": "https://synced.example" }]
        },
        "other": {
          "type": "folder", "name": "Other bookmarks",
          "children": [{ "type": "url", "name": "Other", "url": "https://other.example" }]
        },
        "bookmark_bar": {
          "type": "folder", "name": "Bookmarks bar",
          "children": [
            { "type": "url", "name": "Top", "url": "https://top.example" },
            { "type": "url", "name": "No URL", "url": "" },
            {
              "type": "folder", "name": "Work",
              "children": [
                { "type": "url", "name": "Jira", "url": "https://jira.example" },
                { "type": "folder", "name": "Deep", "children": [
                  { "type": "url", "name": "Nested", "url": "https://nested.example" }
                ]}
              ]
            },
            { "type": "folder", "name": "Empty" },
            42
          ]
        },
        "sync_transaction_version": "7"
      },
      "version": 1
    }
    """

  @Test func walksRootsInChromiumOrderAndPropagatesDirectFolder() throws {
    let bookmarks = try ChromiumBookmarks.parse(Data(Self.json.utf8))
    #expect(
      bookmarks == [
        Bookmark(title: "Top", url: "https://top.example", folder: nil),
        Bookmark(title: "Jira", url: "https://jira.example", folder: "Work"),
        Bookmark(title: "Nested", url: "https://nested.example", folder: "Deep"),
        Bookmark(title: "Other", url: "https://other.example", folder: nil),
        Bookmark(title: "Synced", url: "https://synced.example", folder: nil),
      ])
  }

  @Test func missingRootsGiveNoBookmarks() throws {
    #expect(try ChromiumBookmarks.parse(Data(#"{"version": 1}"#.utf8)) == [])
  }

  @Test func unknownRootsFollowKnownOnesSorted() throws {
    let json = """
      {"roots": {
        "zeta": {"children": [{"type": "url", "name": "Z", "url": "https://z.example"}]},
        "alpha": {"children": [{"type": "url", "name": "A", "url": "https://a.example"}]},
        "other": {"children": [{"type": "url", "name": "O", "url": "https://o.example"}]}
      }}
      """
    #expect(try ChromiumBookmarks.parse(Data(json.utf8)).map(\.title) == ["O", "A", "Z"])
  }

  @Test func nonObjectTopLevelThrows() {
    #expect(throws: BookmarkParseError.notAnObject) {
      try ChromiumBookmarks.parse(Data("[1, 2]".utf8))
    }
  }

  @Test func invalidJSONThrows() {
    #expect(throws: (any Error).self) {
      try ChromiumBookmarks.parse(Data("{not json".utf8))
    }
  }
}
