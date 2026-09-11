import Foundation
import Testing

@testable import RadixCore

@Suite struct SafariBookmarksTests {
  static func leaf(_ title: String?, _ url: String) -> [String: Any] {
    var node: [String: Any] = ["WebBookmarkType": "WebBookmarkTypeLeaf", "URLString": url]
    if let title { node["URIDictionary"] = ["title": title] }
    return node
  }

  static func plistData(_ object: [String: Any]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
  }

  static var root: [String: Any] {
    [
      "Title": "",
      "WebBookmarkType": "WebBookmarkTypeList",
      "Children": [
        [
          "Title": "BookmarksBar", "WebBookmarkType": "WebBookmarkTypeList",
          "Children": [leaf("Apple", "https://apple.com"), leaf(nil, "https://untitled.example")],
        ] as [String: Any],
        [
          "Title": "BookmarksMenu", "WebBookmarkType": "WebBookmarkTypeList",
          "Children": [
            [
              "Title": "Dev", "WebBookmarkType": "WebBookmarkTypeList",
              "Children": [leaf("Swift", "https://swift.org")],
            ]
              as [String: Any]
          ],
        ],
        [
          "Title": "com.apple.ReadingList", "WebBookmarkType": "WebBookmarkTypeList",
          "Children": [leaf("Article", "https://read.example")],
        ],
        ["WebBookmarkType": "WebBookmarkTypeProxy", "Title": "History"],
      ],
    ]
  }

  @Test func collectsLeavesDepthFirstIncludingReadingList() throws {
    let bookmarks = try SafariBookmarks.parse(try Self.plistData(Self.root))
    #expect(
      bookmarks == [
        Bookmark(title: "Apple", url: "https://apple.com"),
        Bookmark(title: "Swift", url: "https://swift.org"),
        Bookmark(title: "Article", url: "https://read.example"),
      ])
  }

  @Test func parsesXMLPlistToo() throws {
    let xml = try PropertyListSerialization.data(fromPropertyList: Self.root, format: .xml, options: 0)
    #expect(try SafariBookmarks.parse(xml).count == 3)
  }

  @Test func childrenWinOverURLString() throws {
    let node: [String: Any] = [
      "URLString": "https://ignored.example", "Children": [Self.leaf("Kept", "https://kept.example")],
    ]
    #expect(try SafariBookmarks.parse(try Self.plistData(node)).map(\.title) == ["Kept"])
  }

  @Test func nonDictionaryRootThrows() throws {
    let data = try PropertyListSerialization.data(fromPropertyList: ["a", "b"], format: .binary, options: 0)
    #expect(throws: BookmarkParseError.notAnObject) {
      try SafariBookmarks.parse(data)
    }
  }
}
