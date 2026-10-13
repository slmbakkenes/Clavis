import Testing

@testable import ClavisCore

@Suite struct UTF8BoundaryTests {
  @Test func asciiIsAlwaysComplete() {
    #expect(UTF8Boundary.completePrefixLength(Array("hello".utf8)) == 5)
    #expect(UTF8Boundary.completePrefixLength([UInt8]()) == 0)
  }

  @Test func completeMultiByteCharactersAreKept() {
    let bytes = Array("añ€😀".utf8)
    #expect(UTF8Boundary.completePrefixLength(bytes) == bytes.count)
  }

  @Test func trailingPartialSequenceIsHeldBack() {
    let emoji = Array("😀".utf8)  // 4 bytes
    for cut in 1..<emoji.count {
      let bytes = Array("ok".utf8) + emoji.prefix(cut)
      #expect(UTF8Boundary.completePrefixLength(bytes) == 2, "cut after \(cut) bytes")
    }
    let euro = Array("€".utf8)  // 3 bytes
    #expect(UTF8Boundary.completePrefixLength(Array("x".utf8) + euro.prefix(2)) == 1)
  }

  @Test func invalidBytesAreNotHeldBack() {
    #expect(UTF8Boundary.completePrefixLength([0x61, 0xFF]) == 2)
    #expect(UTF8Boundary.completePrefixLength([0x80, 0x80, 0x80, 0x80]) == 4)
  }
}
