import Foundation

extension Step {
    /// The waits a step names, read out of its title and points in the order they are written:
    /// "4 minutes", "1 hour 20 minutes", "6分から8分". A range keeps its earlier figure, so a
    /// timer set from it goes off when the food is first worth checking. Anything under ten
    /// seconds is a count rather than a wait, and is left out.
    public var durations: [Duration] {
        var found: [Duration] = []
        for text in [title] + points {
            for seconds in Step.seconds(in: text) where seconds >= 10 && seconds <= 12 * 3600 {
                let duration = Duration.seconds(seconds)
                if !found.contains(duration) { found.append(duration) }
            }
        }
        return found
    }

    /// How many seconds each unit a step can be timed in stands for.
    private static func unitSeconds(_ unit: String) -> Int {
        let unit = unit.lowercased()
        if unit.hasPrefix("h") || unit == "時間" { return 3600 }
        if unit.hasPrefix("m") || unit == "分" { return 60 }
        return 1
    }

    private static let number = #"(\d+(?:\.\d+)?)"#
    private static let rangeWord = #"(?:to|-|–|~|〜|～|から)"#
    private static let unit = #"(hours?|hrs?|h|minutes?|mins?|seconds?|secs?|時間|分|秒)(?![A-Za-z])"#

    /// A figure, or a range of two, and the unit it is written in.
    private static let amount = try! NSRegularExpression(
        pattern: number + #"(?:\s*"# + rangeWord + #"\s*"# + number + #")?[\s-]*"# + unit,
        options: [.caseInsensitive]
    )

    /// The seconds each wait in some text comes to. Figures written one after another in
    /// falling units, as in "1 hour 20 minutes", are one wait. Two figures in the same unit
    /// with a range word between them, as in "6分から8分", are one range.
    private static func seconds(in text: String) -> [Int] {
        let whole = NSRange(text.startIndex..., in: text)
        var waits: [(seconds: Int, unit: Int, end: String.Index)] = []
        for match in amount.matches(in: text, range: whole) {
            guard let figureRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 3), in: text),
                  let matchRange = Range(match.range, in: text),
                  let figure = Double(text[figureRange]) else { continue }
            let unit = unitSeconds(String(text[unitRange]))
            let seconds = Int(figure * Double(unit))

            if let last = waits.last {
                let gap = text[last.end..<matchRange.lowerBound]
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                if last.unit == unit, ["to", "-", "–", "~", "〜", "～", "から"].contains(gap) {
                    waits[waits.count - 1].end = matchRange.upperBound
                    continue
                }
                if last.unit > unit, ["", "and", ","].contains(gap) {
                    waits[waits.count - 1] = (last.seconds + seconds, unit, matchRange.upperBound)
                    continue
                }
            }
            waits.append((seconds, unit, matchRange.upperBound))
        }
        return waits.map(\.seconds)
    }
}
