import Testing

@testable import ClavisCore

@Suite struct HexColorTests {
  @Test func parsesWithAndWithoutHash() {
    #expect(HexColor("#ff0000") == HexColor("FF0000"))
    let color = HexColor("#5e6ad2")
    #expect(color?.red == 0x5E / 255.0)
    #expect(color?.green == 0x6A / 255.0)
    #expect(color?.blue == 0xD2 / 255.0)
  }

  @Test func rejectsOtherFormats() {
    #expect(HexColor("#fff") == nil)
    #expect(HexColor("red") == nil)
    #expect(HexColor("#gggggg") == nil)
    #expect(HexColor("") == nil)
  }
}
