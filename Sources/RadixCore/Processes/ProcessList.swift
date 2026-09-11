import Foundation

/// One running process, as listed by `ps -eo pid,ppid,pcpu,rss,comm`.
public struct ProcessEntry: Sendable, Equatable, Identifiable {
  public enum Kind: Sendable, Equatable {
    case preferencePane
    case application
    case binary
  }

  public let pid: Int32
  public let parentPid: Int32
  /// CPU usage in percent, as `ps` reports it (can exceed 100 on multiple cores).
  public let cpu: Double
  /// Resident set size (`rss`), in kilobytes.
  public let memoryKilobytes: Int
  public let path: String
  /// The last path component of `path`.
  public let name: String
  public let kind: Kind

  public var id: Int32 { pid }

  public init(pid: Int32, parentPid: Int32, cpu: Double, memoryKilobytes: Int, path: String) {
    self.pid = pid
    self.parentPid = parentPid
    self.cpu = cpu
    self.memoryKilobytes = memoryKilobytes
    self.path = path
    self.name = path.split(separator: "/", omittingEmptySubsequences: false).last.map(String.init) ?? path
    if path.contains(".prefPane") {
      kind = .preferencePane
    } else if path.contains(".app/") {
      kind = .application
    } else {
      kind = .binary
    }
  }
}

public enum ProcessList {
  /// Same shape as the previous build's regex: pid, parent pid, cpu with a
  /// decimal separator, rss, then the rest of the line as the path. The
  /// header line has no digits, so it never matches.
  private static let linePattern = try! NSRegularExpression(
    pattern: #"(\d+)\s+(\d+)\s+(\d+[.,]\d+)\s+(\d+)\s+(.*)"#)

  /// Parses `ps -eo pid,ppid,pcpu,rss,comm` output, dropping lines without a
  /// process name, ordered by CPU usage (highest first).
  public static func parse(_ psOutput: String) -> [ProcessEntry] {
    let entries = psOutput.split(whereSeparator: \.isNewline).compactMap { parseLine(String($0)) }
    return entries.enumerated()
      .sorted { left, right in
        left.element.cpu != right.element.cpu ? left.element.cpu > right.element.cpu : left.offset < right.offset
      }
      .map(\.element)
  }

  /// Fuzzy-matches `query` against each process path. An empty query keeps
  /// every entry in its current order.
  public static func filter(_ entries: [ProcessEntry], query: String) -> [ProcessEntry] {
    guard !query.isEmpty else { return entries }
    var scored: [(offset: Int, entry: ProcessEntry, score: Double)] = []
    for (offset, entry) in entries.enumerated() {
      let score = FuzzyScore.score(entry.path, query: query)
      if score > 0 {
        scored.append((offset, entry, score))
      }
    }
    scored.sort { left, right in
      left.score != right.score ? left.score > right.score : left.offset < right.offset
    }
    return scored.map(\.entry)
  }

  private static func parseLine(_ line: String) -> ProcessEntry? {
    let range = NSRange(line.startIndex..., in: line)
    guard let match = linePattern.firstMatch(in: line, range: range) else { return nil }

    func group(_ index: Int) -> String? {
      Range(match.range(at: index), in: line).map { String(line[$0]) }
    }

    guard let pid = group(1).flatMap({ Int32($0) }),
      let parentPid = group(2).flatMap({ Int32($0) }),
      // ps writes the locale's decimal separator; the old parseFloat read
      // "1,5" as 1, which ranked such processes wrongly.
      let cpu = group(3).flatMap({ Double($0.replacingOccurrences(of: ",", with: ".")) }),
      let memory = group(4).flatMap({ Int($0) }),
      let path = group(5)
    else { return nil }

    let entry = ProcessEntry(pid: pid, parentPid: parentPid, cpu: cpu, memoryKilobytes: memory, path: path)
    return entry.name.isEmpty ? nil : entry
  }
}
