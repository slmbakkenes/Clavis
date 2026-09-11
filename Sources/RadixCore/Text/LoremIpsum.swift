/// Placeholder text roughly shaped like `chance.paragraph()`: 3 to 7
/// sentences of 12 to 18 lowercase pseudo-latin words, each sentence
/// capitalised and ending in a period.
public enum LoremIpsum {
  public static let sentenceCountRange = 3...7
  public static let wordCountRange = 12...18

  static let words = [
    "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit", "sed", "do", "eiusmod",
    "tempor", "incididunt", "ut", "labore", "et", "dolore", "magna", "aliqua", "enim", "ad", "minim",
    "veniam", "quis", "nostrud", "exercitation", "ullamco", "laboris", "nisi", "aliquip", "ex", "ea",
    "commodo", "consequat", "duis", "aute", "irure", "in", "reprehenderit", "voluptate", "velit", "esse",
    "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint", "occaecat", "cupidatat", "non", "proident",
    "sunt", "culpa", "qui", "officia", "deserunt", "mollit", "anim", "id", "est", "laborum", "vitae",
    "semper", "porta", "mauris", "lectus", "nunc", "gravida", "tellus", "vel", "felis", "morbi", "tristique",
  ]

  public static func paragraph() -> String {
    var generator = SystemRandomNumberGenerator()
    return paragraph(using: &generator)
  }

  public static func paragraph<G: RandomNumberGenerator>(using generator: inout G) -> String {
    let sentenceCount = Int.random(in: sentenceCountRange, using: &generator)
    return (0..<sentenceCount).map { _ in sentence(using: &generator) }.joined(separator: " ")
  }

  static func sentence<G: RandomNumberGenerator>(using generator: inout G) -> String {
    let wordCount = Int.random(in: wordCountRange, using: &generator)
    let text = (0..<wordCount).map { _ in words.randomElement(using: &generator)! }.joined(separator: " ")
    return text.prefix(1).uppercased() + text.dropFirst() + "."
  }
}
