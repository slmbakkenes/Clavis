import Foundation
import Testing

@testable import ClavisCore

/// SplitMix64: deterministic, so generated text can be compared across runs.
struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

@Suite struct NanoIDTests {
  @Test func defaultLengthIs21() {
    #expect(NanoID.make().count == 21)
  }

  @Test func customLength() {
    #expect(NanoID.make(size: 8).count == 8)
    #expect(NanoID.make(size: 0).isEmpty)
  }

  @Test func usesOnlyTheURLSafeAlphabet() {
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
    #expect(NanoID.alphabet.count == 64)
    for _ in 0..<50 {
      #expect(NanoID.make(size: 64).allSatisfy(allowed.contains))
    }
  }

  @Test func seededGeneratorIsDeterministic() {
    var first = SeededGenerator(state: 42)
    var second = SeededGenerator(state: 42)
    #expect(NanoID.make(using: &first) == NanoID.make(using: &second))
  }
}

@Suite struct LoremIpsumTests {
  private func sentences(of paragraph: String) -> [String] {
    paragraph.split(separator: ".").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  @Test func sentenceAndWordCountsStayInRange() {
    var generator = SeededGenerator(state: 7)
    for _ in 0..<200 {
      let paragraph = LoremIpsum.paragraph(using: &generator)
      #expect(paragraph.hasSuffix("."))
      let parts = sentences(of: paragraph)
      #expect(LoremIpsum.sentenceCountRange.contains(parts.count))
      for sentence in parts {
        #expect(LoremIpsum.wordCountRange.contains(sentence.split(separator: " ").count))
        #expect(sentence.first?.isUppercase == true)
      }
    }
  }

  @Test func seededGeneratorIsDeterministic() {
    var first = SeededGenerator(state: 1234)
    var second = SeededGenerator(state: 1234)
    #expect(LoremIpsum.paragraph(using: &first) == LoremIpsum.paragraph(using: &second))
  }
}
