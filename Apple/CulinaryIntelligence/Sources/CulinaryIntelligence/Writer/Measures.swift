import Foundation

/// Gemma's measures put the way the reader cooks, before any model sees them. Gemma writes
/// in US cups, ounces, pounds, and Fahrenheit, and a model asked to convert them does the
/// arithmetic wrong about as often as right, so the arithmetic is done here and the sorting
/// passes only have words to translate.
nonisolated enum Measures {
    /// Whether the reader measures in metric. Taken from the region, so a reader in the United
    /// States keeps their cups whatever language they read in.
    static var readsMetric: Bool { Locale.current.measurementSystem != .us }

    /// Whether the package is being read in Japanese, where a spoon measure is written before
    /// its figure and "to taste" has a word of its own.
    static var readsJapanese: Bool { Bundle.module.preferredLocalizations.first == "ja" }

    /// A line of Gemma's with its measures put the reader's way.
    static func forReader(_ line: String) -> String {
        var text = line
        if readsMetric { text = metric(text) }
        if readsJapanese { text = japanese(text) }
        return text
    }

    // MARK: - Metric

    private static let figure = #"(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"#

    /// Each US measure and what one of it comes to in metric.
    private static let conversions: [(pattern: String, factor: Double, unit: String)] = [
        (#"fl\.?\s*oz\.?|fluid\s+ounces?"#, 30, "ml"),
        (#"cups?"#, 240, "ml"),
        (#"pints?"#, 475, "ml"),
        (#"quarts?"#, 950, "ml"),
        (#"ounces?|oz\.?"#, 28, "g"),
        (#"pounds?|lbs?\.?"#, 454, "g"),
        (#"inch(?:es)?"#, 2.5, "cm"),
    ]

    static func metric(_ line: String) -> String {
        var text = line
        // When Gemma gives the metric beside a US measure, as in "1 lb (450g)" or
        // "28 oz/800g", its figure is kept and the US one dropped rather than converted, since
        // it is usually the size the packet is sold in.
        let us = conversions.map(\.pattern).joined(separator: "|")
        let given = #"(\d+(?:\.\d+)?\s*(?:g|kg|ml|l)\b)"#
        text = replacing(figure + #"\s*(?:"# + us + #")\s*\(\s*"# + given + #"\s*\)"#, in: text) { $0[1] }
        text = replacing(figure + #"\s*(?:"# + us + #")\s*/\s*"# + given, in: text) { $0[1] }
        for conversion in conversions {
            // A range such as "1 to 2 cups" converts both ends.
            let pattern = figure + #"(?:\s*(?:-|to)\s*"# + figure + #")?(?:\s+of)?\s*(?:"# + conversion.pattern + #")\b"#
            text = replacing(pattern, in: text) { groups in
                let low = number(groups[0]).map { format($0 * conversion.factor, unit: conversion.unit) }
                let high = number(groups[1]).map { format($0 * conversion.factor, unit: conversion.unit) }
                guard let low else { return nil }
                return high.map { "\(low) to \($0)" } ?? low
            }
        }
        text = replacing(#"(\d+)\s*(?:°\s*F|degrees\s+F(?:ahrenheit)?)\b"#, in: text) { groups in
            guard let fahrenheit = number(groups[0]) else { return nil }
            let celsius = ((fahrenheit - 32) * 5 / 9 / 5).rounded() * 5
            return "\(Int(celsius))°C"
        }
        // Gemma often gives the metric beside the US measure, which now says it twice.
        text = replacing(#"(\d+(?:\.\d+)? (?:g|ml)) \(\s*(?:about\s+)?\d+(?:\.\d+)?\s*(?:g|ml|grams|milliliters)\s*\)"#, in: text) {
            $0[0]
        }
        return text
    }

    /// A metric figure rounded the way a cook measures: to 5 under a hundred, to 10 above.
    private static func format(_ value: Double, unit: String) -> String {
        if unit == "cm" {
            let halves = (value * 2).rounded() / 2
            return halves == halves.rounded() ? "\(Int(halves)) cm" : "\(halves) cm"
        }
        let step: Double = value < 100 ? 5 : 10
        return "\(Int(max(step, (value / step).rounded() * step))) \(unit)"
    }

    // MARK: - Japanese

    static func japanese(_ line: String) -> String {
        var text = line
        for (pattern, word) in [(#"tablespoons?|tbsps?\.?"#, "大さじ"), (#"teaspoons?|tsps?\.?"#, "小さじ")] {
            text = replacing(figure + #"\s*(?:"# + pattern + #")(?:\s+of)?"#, in: text) { groups in
                "\(word)\(groups[0] ?? "")"
            }
        }
        text = replacing(#"(?i)\bto taste\b"#, in: text) { _ in "適量" }
        for (pattern, word) in [
            (#"slices?"#, "枚"), (#"cloves?"#, "片"), (#"stalks?|sticks?"#, "本"), (#"cans?"#, "缶"),
        ] {
            text = replacing(figure + #"\s*(?:"# + pattern + #")\b"#, in: text) { groups in
                "\(groups[0] ?? "")\(word)"
            }
        }
        return text
    }

    /// Text a sorting pass wrote, put right in the ways a pass has been seen to get wrong: a
    /// spoon measure written back after its figure, as "2大さじ", and a range written with a
    /// dash or a wave dash rather than the word the house style asks for.
    static func tidied(_ text: String) -> String {
        var text = text
        if readsJapanese {
            text = replacing(figure + #"\s*(大さじ|大匙|小さじ|小匙)"#, in: text) { groups in
                let spoon = (groups[1] ?? "").hasPrefix("大") ? "大さじ" : "小さじ"
                return "\(spoon)\(groups[0] ?? "")"
            }
            text = text.replacingOccurrences(of: "大匙", with: "大さじ").replacingOccurrences(of: "小匙", with: "小さじ")
        }
        let word = readsJapanese ? "から" : " to "
        text = replacing(#"(\d)\s*[-–〜～~]\s*(\d)"#, in: text) { groups in
            "\(groups[0] ?? "")\(word)\(groups[1] ?? "")"
        }
        return text
    }

    // MARK: - Reading figures

    /// A figure as written: "2", "1.5", "1/2", or "1 1/2".
    private static func number(_ text: String?) -> Double? {
        guard let text else { return nil }
        let parts = text.split(separator: " ")
        return parts.reduce(0.0 as Double?) { total, part in
            guard let total else { return nil }
            let fraction = part.split(separator: "/")
            if fraction.count == 2, let top = Double(fraction[0]), let bottom = Double(fraction[1]), bottom != 0 {
                return total + top / bottom
            }
            return Double(part).map { total + $0 }
        }
    }

    /// Every match of a pattern replaced by what the closure makes of its groups. A match the
    /// closure has nothing for is left as it was.
    private static func replacing(
        _ pattern: String,
        in text: String,
        with replacement: ([String?]) -> String?
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        var result = text
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            let groups = (1..<max(1, match.numberOfRanges)).map { index -> String? in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
            guard let range = Range(match.range, in: result),
                  let replaced = replacement(groups)
            else { continue }
            result.replaceSubrange(range, with: replaced)
        }
        return result
    }
}

extension String {
    /// Text a sorting pass wrote, with any JSON the model let slip into the end of it taken off.
    /// The on-device model sometimes carries on past a Japanese string into the syntax around
    /// it, leaving the likes of `」} ```json{` or `」} <ctrl46>` behind, and the result is put
    /// right through `Measures.tidied`.
    nonisolated var withoutLeakedSyntax: String {
        var text = self
        // Recipe text never holds a brace, a code fence, or a model's control token, so the
        // first of any of them is where the leak starts.
        for marker in ["```", "}", "{", "<ctrl"] {
            if let start = text.range(of: marker) { text = String(text[..<start.lowerBound]) }
        }
        // A closing bracket stays when an opening one is there for it.
        func unmatched() -> Bool { text.filter { $0 == "」" }.count > text.filter { $0 == "「" }.count }
        while let last = text.last, "}\"{".contains(last) || (last == "」" && unmatched()) || last.isWhitespace {
            text.removeLast()
        }
        return Measures.tidied(text)
    }
}
