import Foundation

/// The pans and pots of a recipe, sized in code when its serving count changes.
///
/// Asked to write a pan's note again for a new count, the on-device model wrote "Food goes in it
/// in batches" over every note, pots included, and dropped what the notes said. Asked to write
/// the steps that fry or boil again, it left them as they were, or cut a frying time the step
/// said not to cut. A size and a number of batches are arithmetic, so code works them out from
/// the size the note gives, and the note itself is left as written.
extension Recipe {
    /// The pans and pots sized for a new serving count, read against the count the recipe is
    /// written for now. Each pan or pot whose size changes gets a line at the end of its note,
    /// and a pan that needs more than one batch adds a point to the first step that uses it.
    /// Lines written by an earlier change are taken out first, and a size is always worked out
    /// from the count the note was written for, so going back to that count gives the recipe
    /// back as it was.
    ///
    /// A pan whose note already speaks of a serving count in other words is left alone: an
    /// older build's model may have reworded the line while changing the pan, and a second line
    /// beside it would contradict the first. A step that already cooks in batches gets no point.
    public mutating func resizePans(to serves: String) {
        guard let target = Recipe.servings(in: serves) else { return }
        let language = writtenLanguage
        steps = steps.map(\.withoutPanLines)
        for index in tools.indices {
            guard let vessel = tools[index].vessel else { continue }
            let (note, writtenFor) = Self.withoutSizeLine(tools[index].note)
            if writtenFor == nil, let note, Self.mentionsServings(note) { continue }
            let base = writtenFor ?? self.serves
            guard let count = Recipe.servings(in: base) else { continue }
            let size = note.flatMap(Self.centimeters)
            let fit = vessel.fit(size, from: count, to: target)
            tools[index].note = note
            guard let line = Self.sizeLine(
                fit, from: size, serves: Self.figure(target), writtenFor: Self.figure(count), in: language
            ) else { continue }
            tools[index].note = Self.appending(line, to: note)
            guard fit.batches > 1, let step = firstStep(using: tools[index]) else { continue }
            let point = PanLine.batches.written(in: language, String(fit.batches))
            if !steps[step].points.contains(where: Self.mentionsBatches) {
                steps[step].points.append(point)
            }
        }
    }

    /// The line a pan or pot's note ends with for the new count, or none when the same pan does.
    private static func sizeLine(
        _ fit: Vessel.Fit,
        from size: Double?,
        serves: String,
        writtenFor base: String,
        in language: Bundle
    ) -> String? {
        let batches = String(fit.batches)
        switch (fit.size, fit.batches > 1) {
        case let (new?, false) where new != size:
            return PanLine.size.written(in: language, serves, base, centimeters(new))
        case let (new?, true) where new != size:
            return PanLine.sizeAndBatches.written(in: language, serves, base, centimeters(new), batches)
        case (_, true):
            return PanLine.batchesOnly.written(in: language, serves, base, batches)
        default:
            return nil
        }
    }

    /// The note with a size line from an earlier change taken out, and the count the note was
    /// written for, which that line names.
    static func withoutSizeLine(_ note: String?) -> (note: String?, writtenFor: String?) {
        guard let note else { return (nil, nil) }
        for line in [PanLine.size, .sizeAndBatches, .batchesOnly] {
            guard let found = line.firstMatch(in: note) else { continue }
            var rest = note
            rest.removeSubrange(found.range)
            let trimmed = rest.trimmingCharacters(in: .whitespaces)
            return (trimmed.isEmpty ? nil : trimmed, found.arguments[2])
        }
        return (note, nil)
    }

    /// Whether a note gives a serving count, as a size line reworded by hand or by a model
    /// would: "For 6 servings, a 30 cm pan" or "6人分なら30cmのフライパン". A count has a
    /// figure, so the wok's "cook one portion at a time" and "一人分ずつ" are not one.
    static func mentionsServings(_ text: String) -> Bool {
        text.contains(#/(?i)[0-9]+\s*(servings?|people|persons|人分|人前)|\bserves?\s+[0-9]+/#)
    }

    /// Whether a step already says to cook in batches: "Fry it in two batches" or "2回に分けて".
    static func mentionsBatches(_ text: String) -> Bool {
        text.contains(#/(?i)\bbatch(es)?\b|回に分けて|数回に分け/#)
    }

    /// The size a note gives in centimeters: "About 24 cm." or "24cmほど。".
    static func centimeters(in note: String) -> Double? {
        guard let match = note.firstMatch(of: #/(\d+(?:\.\d+)?)\s*(?:cm|センチ)/#) else { return nil }
        return Double(match.1)
    }

    private static func centimeters(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// A serving count on its own, since a recipe may say "2人分" where the line wants "2".
    private static func figure(_ count: Double) -> String {
        count == count.rounded() ? String(Int(count)) : String(count)
    }

    /// The catalog of the language the recipe is written in, which is not always the app's:
    /// a line in the app's language would read oddly in the middle of a note in the other.
    private var writtenLanguage: Bundle {
        let text = ([title] + steps.flatMap { [$0.title] + $0.points }).joined()
        let japanese = text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
        return japanese ? .japaneseModule : .englishModule
    }

    /// A line put after a note, with a space after English and none after Japanese.
    private static func appending(_ line: String, to note: String?) -> String {
        guard let note, let last = note.last else { return line }
        return last.isASCII ? note + " " + line : note + line
    }

    /// The first step that cooks in the tool: the first whose icons show it, or failing that,
    /// the first that names it.
    private func firstStep(using tool: Tool) -> Int? {
        let icon = IconCatalog.iconName(for: tool.icon)
        if let index = steps.firstIndex(where: { step in
            step.icons?.contains { IconCatalog.iconName(for: $0) == icon } == true
        }) {
            return index
        }
        return steps.firstIndex { step in
            ([step.title] + step.points).contains { $0.localizedCaseInsensitiveContains(tool.name) }
        }
    }
}

extension Step {
    /// The step without the batches code wrote into it for a new serving count.
    var withoutPanLines: Step {
        var step = self
        step.points.removeAll(where: PanLine.batches.matches)
        return step
    }
}

extension Tool {
    /// The kind of pan or pot this is, when its size was chosen for how much food goes in it.
    var vessel: Vessel? {
        switch IconCatalog.iconName(for: icon) {
        case "pan", "cast-iron-skillet", "wok": .pan
        case "pot", "saucepan", "dutch-oven", "donabe": .pot
        default: nil
        }
    }
}

/// A pan or pot, and how its size follows the amount of food in it.
enum Vessel {
    /// A frying pan, skillet, or wok. Food has to lie in one layer, so the area follows the food.
    case pan
    /// A pot or saucepan. The food fills it, so the volume follows the food.
    case pot

    struct Fit: Equatable {
        /// The diameter in centimeters, or none when the note gave no size to start from.
        var size: Double?
        var batches: Int
    }

    /// The largest pan or pot most kitchens have, and the smallest worth naming.
    private var largest: Double { 30 }
    private var smallest: Double { self == .pan ? 20 : 14 }

    /// How many servings the largest pan fries at once, for a pan that gives no size. The
    /// sample recipes fry two servings in a 24 cm pan, which is three in a 30 cm one. It is
    /// counted from the servings alone, since the count the recipe was first written for is
    /// gone once a change that needed no line has been made.
    private static let servingsInLargestPan: Double = 3

    /// The pan or pot for `target` servings, from one `size` across that held `count`. Sizes
    /// are rounded to the even centimeters pans are sold in. A pan past the largest size cooks
    /// in batches instead, each in a pan just big enough. A pot is never split, and one that
    /// gives no size is left as it is.
    func fit(_ size: Double?, from count: Double, to target: Double) -> Fit {
        let smallest = min(self.smallest, size ?? self.smallest)
        let largest = max(self.largest, size ?? self.largest)
        func rounded(_ value: Double) -> Double {
            min(max((value / 2).rounded() * 2, smallest), largest)
        }
        switch self {
        case .pan:
            guard let size else {
                let batches = (target / Self.servingsInLargestPan - 0.001).rounded(.up)
                return Fit(size: nil, batches: max(1, Int(batches)))
            }
            let area = size * size * target / count
            let batches = max(1, Int((area / (largest * largest) - 0.001).rounded(.up)))
            let each = rounded((area / Double(batches)).squareRoot())
            return Fit(size: each, batches: batches)
        case .pot:
            guard let size else { return Fit(size: nil, batches: 1) }
            return Fit(size: rounded(size * cbrt(target / count)), batches: 1)
        }
    }
}

/// The lines code writes into a recipe for a new serving count, and how to find them again in
/// either language.
struct PanLine {
    static let size = PanLine("Edit.Scale.Tool.Size")
    static let sizeAndBatches = PanLine("Edit.Scale.Tool.SizeAndBatches")
    static let batchesOnly = PanLine("Edit.Scale.Tool.Batches")
    static let batches = PanLine("Edit.Scale.Step.Batches")

    private let key: String.LocalizationValue
    /// Each language's line as a pattern, with the argument each capture group reads.
    private let patterns: [(pattern: NSRegularExpression, groups: [Int])]

    private init(_ key: String.LocalizationValue) {
        self.key = key
        patterns = [Bundle.englishModule, .japaneseModule].map { Self.pattern(String(localized: key, bundle: $0)) }
    }

    private static func pattern(_ format: String) -> (pattern: NSRegularExpression, groups: [Int]) {
        var pattern = ""
        var groups: [Int] = []
        var rest = Substring(format)
        while let specifier = rest.firstMatch(of: #/%(\d+)\$@/#) {
            pattern += NSRegularExpression.escapedPattern(for: String(rest[..<specifier.range.lowerBound]))
            // A Japanese line opens on a figure, so a figure may not reach back past the end of
            // the sentence before it.
            pattern += "([^。]+?)"
            groups.append(Int(specifier.1) ?? 0)
            rest = rest[specifier.range.upperBound...]
        }
        pattern += NSRegularExpression.escapedPattern(for: String(rest))
        return (try! NSRegularExpression(pattern: pattern), groups)
    }

    func written(in language: Bundle, _ arguments: String...) -> String {
        String(format: String(localized: key, bundle: language), arguments: arguments)
    }

    /// Whether the whole of `text` is this line.
    func matches(_ text: String) -> Bool {
        guard let found = firstMatch(in: text) else { return false }
        return found.range == text.startIndex..<text.endIndex
    }

    /// The first place this line is written in `text`, and its arguments by number.
    func firstMatch(in text: String) -> (range: Range<String.Index>, arguments: [Int: String])? {
        for (pattern, groups) in patterns {
            guard let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { continue }
            var arguments: [Int: String] = [:]
            for (offset, number) in groups.enumerated() {
                if let found = Range(match.range(at: offset + 1), in: text) {
                    arguments[number] = String(text[found])
                }
            }
            return (range, arguments)
        }
        return nil
    }
}
