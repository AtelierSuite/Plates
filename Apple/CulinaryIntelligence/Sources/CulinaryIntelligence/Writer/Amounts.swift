import Foundation

/// An ingredient's amount read for how it is measured and how much it comes to, so a swapped
/// line can be checked against the line it replaced. A pass asked to swap 300 g of chicken
/// has written the new line with "2 tbsp", so the check is made in code.
nonisolated enum Amounts {
    /// How an amount is measured.
    enum Kind: Equatable {
        /// By weight, in grams.
        case weight(Double)
        /// By volume, in millilitres.
        case volume(Double)
        /// By the piece: a bare figure, or one counted in cloves, slices, 個, 枚, 丁 and so on.
        case count
        /// By eye: a pinch, to taste, 少々, 適量.
        case loose
    }

    /// Whether an amount written for a swapped ingredient fits the amount on the line it
    /// replaced: a weight for a weight or a count, and roughly the same size when both are
    /// weights, and a volume for a volume. A small measure may become a pinch or "to taste".
    /// An old amount that cannot be read, or that is not a weight or a volume, takes anything,
    /// and so does a new one that cannot be read.
    static func fits(_ new: String, replacing old: String) -> Bool {
        guard let old = kind(of: old) else { return true }
        guard let new = kind(of: new) else { return !isBlank(new) }
        switch (old, new) {
        case let (.weight(before), .weight(after)):
            guard before > 0, after > 0 else { return true }
            return (1 / sizeRatio...sizeRatio).contains(after / before)
        case (.weight, .count), (.volume, .volume):
            return true
        case let (.weight(grams), .loose):
            return grams <= smallWeight
        case let (.volume(millilitres), .loose):
            return millilitres <= smallVolume
        case (.weight, _), (.volume, _):
            return false
        case (.count, _), (.loose, _):
            return true
        }
    }

    /// How far apart two weights may be and still be the same size, either way.
    static let sizeRatio = 2.5

    /// A spoon measure or less, which is as often written as a pinch.
    private static let smallVolume = 15.0
    private static let smallWeight = 10.0

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// How an amount is measured, or nil when it cannot be told. A line that gives two
    /// measures, as "1 can (400 g)", is read by its weight first, then its volume.
    static func kind(of amount: String) -> Kind? {
        let text = halfWidth(amount)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let grams = measure(in: text, units: weights) { return .weight(grams) }
        if let millilitres = measure(in: text, units: volumes) { return .volume(millilitres) }
        if loose.contains(where: text.contains) { return .loose }
        if counted(text) { return .count }
        return nil
    }

    /// Text with full-width figures and letters, as "３００ｇ", written half-width. Katakana
    /// such as カップ is left as it is.
    private static func halfWidth(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0xFF01...0xFF5E: Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar
            case 0x3000: " "
            default: scalar
            }
        }))
    }

    // MARK: - Units

    private struct Unit {
        /// The unit as a pattern, written after the figure or, for a Japanese spoon or cup,
        /// before it.
        var pattern: String
        var size: Double
        var before = false
    }

    private static let weights = [
        Unit(pattern: #"kg|kilograms?|キロ(?:グラム)?"#, size: 1000),
        Unit(pattern: #"g|grams?|グラム"#, size: 1),
        Unit(pattern: #"oz|ounces?"#, size: 28),
        Unit(pattern: #"lbs?|pounds?"#, size: 454),
    ]

    private static let volumes = [
        Unit(pattern: #"大さじ|大匙"#, size: 15, before: true),
        Unit(pattern: #"小さじ|小匙"#, size: 5, before: true),
        Unit(pattern: #"カップ"#, size: 200, before: true),
        Unit(pattern: #"ml|millilit(?:er|re)s?|cc|ミリリットル"#, size: 1),
        Unit(pattern: #"l|lit(?:er|re)s?|リットル"#, size: 1000),
        Unit(pattern: #"tbsps?|tablespoons?"#, size: 15),
        Unit(pattern: #"tsps?|teaspoons?"#, size: 5),
        Unit(pattern: #"cups?"#, size: 240),
        Unit(pattern: #"カップ"#, size: 200),
        Unit(pattern: #"fl\.?\s*oz|fluid\s+ounces?"#, size: 30),
    ]

    /// A figure as written: "2", "1.5", "1/2", or "1 1/2".
    private static let figure = #"(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"#

    /// The largest amount the text gives in one of the units, in its base unit. A range is
    /// read by its larger end, as "2 to 3 tbsp" or "大さじ1から2".
    private static func measure(in text: String, units: [Unit]) -> Double? {
        var found: [Double] = []
        for unit in units {
            // A Latin unit is not the start of a longer word, so the "l" in "1 large" is not litres.
            let pattern = unit.before
                ? "(?:\(unit.pattern))\\s*" + figure + "(?:\\s*(?:to|から|〜|~|-)\\s*" + figure + ")?"
                : figure + "(?:\\s*(?:to|から|〜|~|-)\\s*" + figure + ")?\\s*(?:\(unit.pattern))(?![a-z])"
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let figures = (1..<match.numberOfRanges).compactMap { index in
                    Range(match.range(at: index), in: text).flatMap { number(String(text[$0])) }
                }
                if let largest = figures.max() { found.append(largest * unit.size) }
            }
        }
        return found.max()
    }

    private static func number(_ text: String) -> Double? {
        text.split(separator: " ").reduce(0.0 as Double?) { total, part in
            guard let total else { return nil }
            let fraction = part.split(separator: "/")
            if fraction.count == 2, let top = Double(fraction[0]), let bottom = Double(fraction[1]), bottom != 0 {
                return total + top / bottom
            }
            return Double(part).map { total + $0 }
        }
    }

    /// Amounts measured by eye.
    private static let loose = [
        "pinch", "to taste", "a little", "a few drops", "a dash", "a splash", "plenty", "as needed",
        "少々", "適量", "適宜", "ひとつまみ", "ひとふり", "数滴", "たっぷり", "少量",
    ]

    /// Whether the text counts pieces: a figure alone or with a word for a piece after it,
    /// or a piece named with "a", as "a thumb" of ginger.
    private static func counted(_ text: String) -> Bool {
        let english = #"^(?:about\s+)?(?:\d|a\s|an\s|one\s|two\s|three\s|half\s)"#
        let japanese = #"\d\s*(?:個|枚|丁|本|片|かけ|缶|束|袋|パック|尾|切れ|房|株|玉|杯|粒|匹|把|節|箱|人分)"#
        return text.range(of: english, options: .regularExpression) != nil
            || text.range(of: japanese, options: .regularExpression) != nil
            || text.range(of: #"^(?:大|中|小)?\d+$"#, options: .regularExpression) != nil
    }
}
