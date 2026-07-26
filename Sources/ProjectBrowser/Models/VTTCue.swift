import Foundation

struct VTTCue: Equatable {
  let startTime: Double
  let endTime: Double
  let text: String

  func isActive(at time: Double) -> Bool {
    time >= startTime && time < endTime
  }
}

enum VTTParser {
  static func parse(url: URL) throws -> [VTTCue] {
    let content = try String(contentsOf: url, encoding: .utf8)
    return parse(content: content)
  }

  static func parse(content: String) -> [VTTCue] {
    var cues: [VTTCue] = []

    // Skip the WEBVTT header
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var i = 0

    // Skip header and metadata
    while i < lines.count && !lines[i].contains("-->") {
      i += 1
    }

    // Parse cues
    while i < lines.count {
      let line = lines[i].trimmingCharacters(in: .whitespaces)

      if line.contains("-->") {
        if let (start, end) = parseTimingLine(line) {
          var text = ""
          i += 1

          // Collect text lines until empty line
          while i < lines.count {
            let textLine = lines[i]
            if textLine.trimmingCharacters(in: .whitespaces).isEmpty {
              break
            }
            if !text.isEmpty {
              text += "\n"
            }
            text += textLine
            i += 1
          }

          if !text.isEmpty {
            cues.append(VTTCue(startTime: start, endTime: end, text: text))
          }
        } else {
          i += 1
        }
      } else {
        i += 1
      }
    }

    return cues
  }

  private static func parseTimingLine(_ line: String) -> (start: Double, end: Double)? {
    let components = line.split(separator: "-->", omittingEmptySubsequences: true).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    guard components.count == 2 else { return nil }

    guard let start = parseTimeString(String(components[0])) else { return nil }
    guard let end = parseTimeString(String(components[1])) else { return nil }

    return (start, end)
  }

  private static func parseTimeString(_ timeString: String) -> Double? {
    // Handle format: HH:MM:SS.mmm or MM:SS.mmm
    let components = timeString.split(separator: ":", omittingEmptySubsequences: false).map(
      String.init)

    switch components.count {
    case 2:
      guard let minutes = Double(components[0]), let seconds = parseSeconds(components[1]) else {
        return nil
      }
      return minutes * 60 + seconds
    case 3:
      guard let hours = Double(components[0]), let minutes = Double(components[1]),
        let seconds = parseSeconds(components[2])
      else { return nil }
      return hours * 3600 + minutes * 60 + seconds
    default:
      return nil
    }
  }

  private static func parseSeconds(_ secondsString: String) -> Double? {
    // Handle both SS.mmm and just SS format
    Double(secondsString)
  }
}
