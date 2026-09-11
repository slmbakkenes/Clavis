import Testing

@testable import RadixCore

private struct Row: Identifiable, Equatable {
  let id: Int
}

@Suite struct SelectionTests {
  @Test func followsItsElementWhenRowsReorder() {
    var selection = Selection<Int>()
    selection.keepValid(in: [Row(id: 1), Row(id: 2), Row(id: 3)])
    selection.move(by: 1, in: [Row(id: 1), Row(id: 2), Row(id: 3)])
    #expect(selection.id == 2)

    let reordered = [Row(id: 2), Row(id: 3), Row(id: 1)]
    selection.keepValid(in: reordered)
    #expect(selection.id == 2)
    #expect(selection.index(in: reordered) == 0)
    #expect(selection.element(in: reordered) == Row(id: 2))
  }

  @Test func fallsBackToFirstWhenElementDisappears() {
    var selection = Selection(id: 9)
    selection.keepValid(in: [Row(id: 4), Row(id: 5)])
    #expect(selection.id == 4)
    selection.keepValid(in: [Row]())
    #expect(selection.id == nil)
  }

  @Test func moveClampsToTheList() {
    let rows = [Row(id: 1), Row(id: 2)]
    var selection = Selection(id: 2)
    selection.move(by: 5, in: rows)
    #expect(selection.id == 2)
    selection.move(by: -5, in: rows)
    #expect(selection.id == 1)
    selection.move(by: 1, in: [Row]())
    #expect(selection.id == nil)
  }
}
