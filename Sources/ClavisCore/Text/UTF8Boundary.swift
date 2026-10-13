/// Streamed output arrives in arbitrary chunks, so a multi-byte character can
/// be split across two reads. Decoding each chunk on its own would replace
/// both halves with U+FFFD.
public enum UTF8Boundary {
  /// Length of the longest prefix of `bytes` that does not end inside an
  /// incomplete UTF-8 sequence. Invalid bytes are not held back; only a
  /// trailing sequence that could still be completed by the next chunk is.
  public static func completePrefixLength(_ bytes: some Collection<UInt8>) -> Int {
    let array = Array(bytes)
    // A UTF-8 sequence is at most 4 bytes, so only the last 3 can be pending.
    var index = array.count - 1
    var continuationBytes = 0
    while index >= 0, continuationBytes < 3, array[index] & 0b1100_0000 == 0b1000_0000 {
      continuationBytes += 1
      index -= 1
    }
    guard index >= 0 else { return array.count }

    let lead = array[index]
    let expectedLength: Int
    switch lead {
    case 0b1100_0000...0b1101_1111: expectedLength = 2
    case 0b1110_0000...0b1110_1111: expectedLength = 3
    case 0b1111_0000...0b1111_0111: expectedLength = 4
    default: return array.count
    }
    let available = continuationBytes + 1
    return available < expectedLength ? index : array.count
  }
}
