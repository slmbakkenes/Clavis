import Foundation
import Testing

@testable import ClavisCore

@Suite struct ClipboardHistoryTests {
  let now = Date(timeIntervalSince1970: 1_700_000_000)

  @Test func addsTextNewestFirstAndIgnoresEmpty() {
    var history = ClipboardHistory()
    history.addText("first", bundle: nil, now: now)
    history.addText("", bundle: nil, now: now)
    history.addText("second", bundle: "file:///Applications/Safari.app/", now: now.addingTimeInterval(1))
    #expect(history.items.map(\.text) == ["second", "first"])
    #expect(history.items.first?.bundle == "file:///Applications/Safari.app/")
    #expect(history.items.first?.datetime == 1_700_000_001_000)
  }

  @Test func duplicateTextMovesToTopWithoutDuplicating() {
    var history = ClipboardHistory()
    history.addText("a", bundle: nil, now: now)
    history.addText("b", bundle: nil, now: now.addingTimeInterval(1))
    let originalID = history.items[1].id
    let removed = history.addText("a", bundle: nil, now: now.addingTimeInterval(2))
    #expect(removed.isEmpty)
    #expect(history.items.map(\.text) == ["a", "b"])
    #expect(history.items.first?.id == originalID)
  }

  @Test func filesAreNotDeduplicated() {
    var history = ClipboardHistory()
    history.addFile(text: "img.png", url: "/tmp/img.png", bundle: nil, now: now)
    history.addFile(text: "img.png", url: "/tmp/img.png", bundle: nil, now: now)
    #expect(history.items.count == 2)
    #expect(history.items.first?.url == "/tmp/img.png")
  }

  @Test func idsStayUniqueWithinOneMillisecond() {
    var history = ClipboardHistory()
    history.addText("a", bundle: nil, now: now)
    history.addText("b", bundle: nil, now: now)
    history.addFile(text: "c", url: "/c", bundle: nil, now: now)
    #expect(Set(history.items.map(\.id)).count == 3)
  }

  @Test func trimsToLimitAndReturnsDroppedItems() {
    var history = ClipboardHistory()
    for index in 0..<ClipboardHistory.maxItems {
      history.addFile(text: "f\(index)", url: "/f\(index)", bundle: nil, now: now)
    }
    let removed = history.addText("newest", bundle: nil, now: now)
    #expect(history.items.count == ClipboardHistory.maxItems)
    #expect(removed.map(\.text) == ["f0"])
    #expect(history.items.first?.text == "newest")
  }

  @Test func removeReturnsTheItemAndMoveToTopReorders() {
    var history = ClipboardHistory()
    history.addText("a", bundle: nil, now: now)
    history.addText("b", bundle: nil, now: now)
    history.addText("c", bundle: nil, now: now)
    let a = history.items.last!
    history.moveToTop(id: a.id)
    #expect(history.items.map(\.text) == ["a", "c", "b"])
    #expect(history.remove(id: a.id) == [a])
    #expect(history.remove(id: 12345).isEmpty)
    #expect(history.items.map(\.text) == ["c", "b"])
  }

  @Test func emptyQueryReturnsEverything() {
    var history = ClipboardHistory()
    history.addText("a", bundle: nil, now: now)
    #expect(history.search("", now: now) == history.items)
  }

  @Test func substringMatchesDigitsAndPunctuation() {
    var history = ClipboardHistory()
    history.addText("server at 192.168.1.20", bundle: nil, now: now)
    history.addText("unrelated", bundle: nil, now: now)
    #expect(history.search("192.168", now: now).map(\.text) == ["server at 192.168.1.20"])
  }

  @Test func fuzzyMatchesAbbreviations() {
    var history = ClipboardHistory()
    history.addText("hello world", bundle: nil, now: now)
    history.addText("zzz", bundle: nil, now: now)
    #expect(history.search("hw", now: now).map(\.text) == ["hello world"])
  }

  @Test func recentCopiesAreBoosted() {
    let old = PasteItem(id: 1, text: "note alpha", datetime: (now.timeIntervalSince1970 - 3 * 86_400) * 1000)
    let recent = PasteItem(id: 2, text: "note beta", datetime: (now.timeIntervalSince1970 - 60) * 1000)
    // History order puts the old one first; the boost must reorder.
    let history = ClipboardHistory(items: [old, recent])
    #expect(history.search("note", now: now).map(\.id) == [2, 1])
    #expect(ClipboardHistory.recencyBoost(datetime: 0, now: 1) == 1)
    #expect(ClipboardHistory.recencyBoost(datetime: 1, now: 1 + 2 * 3_600_000) == 1.1)
  }

  @Test func tiesKeepHistoryOrder() {
    let items = (1...3).map { PasteItem(id: Int64($0), text: "same text", datetime: 1) }
    let history = ClipboardHistory(items: items)
    #expect(history.search("same", now: now).map(\.id) == [1, 2, 3])
  }

  @Test func decodesPreviousBuildJSONAndBackfillsDatetime() throws {
    let json = #"[{"id":1700000000000,"text":"a","url":null,"bundle":"file:///x/"},{"id":5,"text":"b","datetime":7}]"#
    let items = try JSONDecoder().decode([PasteItem].self, from: Data(json.utf8))
    #expect(items[0].datetime == 1_700_000_000_000)
    #expect(items[0].bundle == "file:///x/")
    #expect(items[0].url == nil)
    #expect(items[1].datetime == 7)
    let roundTripped = try JSONDecoder().decode([PasteItem].self, from: JSONEncoder().encode(items))
    #expect(roundTripped == items)
  }
}
