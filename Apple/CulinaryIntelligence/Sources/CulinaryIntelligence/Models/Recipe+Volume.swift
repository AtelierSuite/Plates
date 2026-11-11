import Foundation

/// The lines of a recipe that were written for how much food it makes, read in code.
///
/// Amounts are scaled in code when the serving count changes, but the pan that held four
/// servings crowds with eight, and a pot with twice the water takes longer to come to a boil.
/// The pan and pot lines, and the steps that brown, fry, or bring something to a boil, are
/// flagged here, in English and Japanese, so each can be rewritten for the new size on its own.
extension Recipe {
    /// Whether a serving count changed by this factor is enough to outgrow the pans and times
    /// written for the old one. Within one and a half times either way, the same pan still does.
    public static func outgrowsPans(scaledBy factor: Double) -> Bool {
        factor >= 1.5 - 0.001 || factor <= 1 / 1.5 + 0.001
    }
}

extension Tool {
    /// Whether this is a pan, pot, or tray whose size was chosen for how much food goes in it.
    public var holdsTheFood: Bool {
        IconCatalog.iconName(for: icon).map(Self.vessels.contains) ?? false
    }

    private static let vessels: Set<String> = [
        "baking-sheet",
        "cast-iron-skillet",
        "donabe",
        "dutch-oven",
        "pan",
        "pot",
        "roasting-pan",
        "saucepan",
        "wok",
    ]
}

extension Step {
    /// Whether this step browns, fries, or brings something to a boil, the work that goes
    /// differently with more or less food in the pan. Read without the tools, so a toaster that
    /// colors the bread counts too, and it is for the caller to ask only of a recipe with a pan.
    public var dependsOnVolume: Bool {
        ([title] + points).contains(where: Self.dependsOnVolume)
    }

    /// Whether a line of a step browns, fries, or brings something to a boil. A line that says
    /// not to, such as "Do not let it brown", does not count.
    static func dependsOnVolume(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        let english = englishActions.matches(in: text, range: range).contains { match in
            guard let found = Range(match.range, in: text) else { return false }
            let clause = text[..<found.lowerBound]
                .split(whereSeparator: { ",;:".contains($0) })
                .last ?? ""
            let before = clause.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).suffix(4)
            return !before.contains { $0 == "not" || $0 == "never" || $0.hasSuffix("n't") }
        }
        if english { return true }
        return japaneseActions.matches(in: text, range: range).contains { match in
            guard let found = Range(match.range, in: text) else { return false }
            let after = text[found.upperBound...].prefix(5)
            return !["ない", "ません", "ず"].contains { after.contains($0) }
        }
    }

    private static let englishActions = try! NSRegularExpression(
        pattern: [
            #"\bbrown(s|ed|ing)?\b(?!\s+(sugar|rice|bread)\b)"#,
            #"\bsear(s|ed|ing)?\b"#,
            #"\brender(s|ed|ing)?\b"#,
            #"\b(stir[- ]|deep[- ]|pan[- ])?fr(y|ies|ying)\b"#,
            #"\bsaut(e|é)(s|ed|ing)?\b"#,
            #"\bto (a|the) ([a-z]+ )?boil\b"#,
            #"^\s*boil\b"#,
        ].joined(separator: "|"),
        options: [.caseInsensitive, .anchorsMatchLines]
    )

    private static let japaneseActions = try! NSRegularExpression(
        pattern: [
            "炒め",
            "(?<!油)揚げ",
            "焼き色",
            "焼き目",
            "焦げ目",
            "こんがり",
            "色づ",
            "きつね色",
            "狐色",
            "茶色く",
            "沸かす",
            "沸かし",
            "沸騰させ",
            "沸騰したら",
            "沸いたら",
            "煮立たせ",
        ].joined(separator: "|")
    )
}
