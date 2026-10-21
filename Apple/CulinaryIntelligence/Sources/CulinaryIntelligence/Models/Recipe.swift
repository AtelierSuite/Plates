import Foundation

/// One recipe, shaped exactly like the JSON files in the One-Pan Food site's `recipes` folder.
/// Property order matters: it is the key order written back out to disk, which `Recipe.json`
/// follows. Files are read here and written there, so nothing else has to agree on the order.
public nonisolated struct Recipe: Decodable, Identifiable, Hashable {
    public var id: String
    public var title: String
    public var time: String
    public var serves: String
    /// Written only when the recipe has been cooked, always as `true`.
    public var tried: Bool?
    /// The dish the recipe's icon draws, worked out when the recipe is written and again when
    /// the cook asks for it. The site's schema has no such key; a recipe without one is drawn
    /// from a dish worked out on the spot.
    public var dish: Dish?
    public var ingredients: IngredientSections
    public var tools: [Tool]
    public var steps: [Step]
    public var troubleshooting: [Troubleshooting]

    public init(
        id: String,
        title: String,
        time: String,
        serves: String,
        tried: Bool? = nil,
        dish: Dish? = nil,
        ingredients: IngredientSections,
        tools: [Tool],
        steps: [Step],
        troubleshooting: [Troubleshooting]
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.serves = serves
        self.tried = tried
        self.dish = dish
        self.ingredients = ingredients
        self.tools = tools
        self.steps = steps
        self.troubleshooting = troubleshooting
    }

    /// The minute count behind `time`, used for sorting. Unreadable values sort last.
    public var minutes: Int {
        Recipe.minutes(in: time) ?? Int.max
    }

    /// `time` as the reader's language writes a duration: "25 min" in English, "25分" in
    /// Japanese. Recipe files carry whatever the recipe was written with, so a time nothing
    /// can be read out of is shown as it stands.
    public var formattedTime: String {
        Recipe.formatTime(time)
    }

    /// The same formatting for a time that has not been saved to a recipe yet.
    public static func formatTime(_ time: String) -> String {
        guard let minutes = minutes(in: time) else { return time }
        return Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated)
        )
    }

    /// The minutes a written time comes to, read out of text such as "25 min", "1 h 30 min",
    /// or "25分". A range keeps its later figure, so "10 to 15 min" is a quarter of an hour.
    public static func minutes(in time: String) -> Int? {
        var counts: [(value: Int, unit: String)] = []
        let text = time.lowercased()
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index].isNumber else {
                index = text.index(after: index)
                continue
            }
            let numberEnd = text[index...].firstIndex { !$0.isNumber } ?? text.endIndex
            let unitEnd = text[numberEnd...].firstIndex(where: \.isNumber) ?? text.endIndex
            counts.append((
                Int(text[index..<numberEnd]) ?? 0,
                text[numberEnd..<unitEnd].trimmingCharacters(in: .whitespaces)
            ))
            index = unitEnd
        }
        guard !counts.isEmpty else { return nil }
        let hours = counts.last { isHours($0.unit) }?.value ?? 0
        let minutes = counts.last { !isHours($0.unit) }?.value ?? 0
        return hours * 60 + minutes
    }

    /// Whether a figure was written in hours rather than minutes.
    private static func isHours(_ unit: String) -> Bool {
        unit.hasPrefix("h") || unit.hasPrefix("時")
    }
}

/// The three ingredient sections. A section is written only when it holds entries.
public nonisolated struct IngredientSections: Decodable, Hashable {
    public var supermarket: [Ingredient]?
    public var general: [Ingredient]?
    public var optional: [Ingredient]?

    public init(supermarket: [Ingredient]? = nil, general: [Ingredient]? = nil, optional: [Ingredient]? = nil) {
        self.supermarket = supermarket
        self.general = general
        self.optional = optional
    }

    public var isEmpty: Bool {
        (supermarket?.isEmpty ?? true) && (general?.isEmpty ?? true) && (optional?.isEmpty ?? true)
    }
}

public nonisolated struct Ingredient: Decodable, Hashable, Identifiable {
    public var item: String
    public var icon: String
    public var amount: String
    public var note: String?

    public init(item: String, icon: String, amount: String, note: String? = nil) {
        self.item = item
        self.icon = icon
        self.amount = amount
        self.note = note
    }

    public var id: String { item + amount }
}

public nonisolated struct Tool: Decodable, Hashable, Identifiable {
    public var name: String
    public var icon: String
    public var required: Bool
    public var note: String?

    public init(name: String, icon: String, required: Bool, note: String? = nil) {
        self.name = name
        self.icon = icon
        self.required = required
        self.note = note
    }

    public var id: String { name }
}

public nonisolated struct Step: Decodable, Hashable, Identifiable {
    public var title: String
    /// The ingredient and tool icon paths this step works with, shown as a strip above its points.
    public var icons: [String]?
    public var points: [String]

    public init(title: String, icons: [String]? = nil, points: [String]) {
        self.title = title
        self.icons = icons
        self.points = points
    }

    public var id: String { title }
}

public nonisolated struct Troubleshooting: Decodable, Hashable, Identifiable {
    public var problem: String
    public var solution: String

    public init(problem: String, solution: String) {
        self.problem = problem
        self.solution = solution
    }

    public var id: String { problem }
}

extension Recipe {
    /// Turns a title into the kebab-case id the schema uses for file names and image paths.
    public static func makeID(from title: String) -> String {
        let slug = title.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: "-")
        return slug.isEmpty ? "recipe-\(Int(Date.now.timeIntervalSince1970))" : slug
    }
}

extension Step {
    /// A step title with its case, spacing, and punctuation dropped, so "Brown the pork" and
    /// "Brown the pork." are read as the one step. It catches a title written twice, which is
    /// the repeat worth dropping on sight. A repeat written two different ways is left in, since
    /// deleting a step on a guess costs more than keeping one that reads close to its
    /// neighbour.
    public static func comparable(_ title: String) -> String {
        title.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Words that say nothing about which ingredient or tool a step reaches for.
    private static let ignored: Set<String> = [
        "about", "chopped", "cooking", "cut", "diced", "dried", "fine", "finely", "fresh",
        "ground", "large", "leave", "medium", "plain", "sliced", "small", "steamed", "thick",
        "thin", "whole",
    ]

    /// Words that are part of a name but too common in a method to put an icon on a step by
    /// themselves: "turn dark red" is no call for dark soy sauce, "the sauce thickens" none for
    /// soy sauce, and a baking sheet none for baking soda. Only the icons leave them out, so
    /// what an edit takes a step to name is unchanged.
    private static let unmarked: Set<String> = [
        "baking", "black", "dark", "green", "light", "red", "sauce", "white", "yellow",
    ]

    /// The icons a step's words point at, taken from the recipe's own lists so a step never
    /// shows something the recipe does not carry. Ingredients come first, then tools.
    public static func icons(
        forText text: String,
        ingredients: [Ingredient],
        tools: [Tool],
        limit: Int = 6
    ) -> [String] {
        let words = Set(terms(in: text))
        let written = text.lowercased()
        let ingredientIcons = ingredients.filter { entry in
            matches(words, in: written, name: entry.item, icon: entry.icon)
        }
        let toolIcons = tools.filter { tool in
            matches(words, in: written, name: tool.name, icon: tool.icon)
        }
        let icons = ingredientIcons.map(\.icon) + toolIcons.map(\.icon)
        return Array(NSOrderedSet(array: icons).compactMap { $0 as? String }.prefix(limit))
    }

    /// An entry is in the step when the step names it, or names the icon it carries.
    private static func matches(_ words: Set<String>, in text: String, name: String, icon: String) -> Bool {
        var names = [name]
        if let asset = IconCatalog.iconName(for: icon) {
            names.append(IconCatalog.displayName(for: asset))
        }
        if names.contains(where: { runsTogether($0) && text.contains($0.lowercased()) }) { return true }
        return names.flatMap(terms).contains { !unmarked.contains($0) && words.contains($0) }
    }

    /// Whether some text names an ingredient or tool by the name a recipe lists it under. The
    /// icon is left out of it, so a step that says "pork" is not taken to name the guanciale.
    /// A name of more than one word is only named when every word of it is, so taking out a
    /// rice cooker does not touch every step with rice in it.
    static func mentions(_ name: String, in text: String) -> Bool {
        let written = text.lowercased()
        if runsTogether(name) { return written.contains(name.lowercased()) }
        let words = Set(terms(in: text))
        let parts = terms(in: name)
        return !parts.isEmpty && parts.allSatisfy(words.contains)
    }

    /// True when a name is written without spaces, as Japanese is. Those names are looked for
    /// in the step as written, since there are no words to split them into.
    private static func runsTogether(_ name: String) -> Bool {
        !name.isEmpty && !name.contains { $0.isASCII && $0.isLetter }
    }

    /// The words worth matching on: lowercased, singular, and long enough to mean something.
    private static func terms(in text: String) -> [String] {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
            .filter { $0.count > 2 && !ignored.contains($0) }
    }
}

extension Recipe {
    /// The serving count written in `serves`, read the way a time is read: a range keeps its
    /// later figure, so "1 to 2" serves two.
    public static func servings(in serves: String) -> Double? {
        let characters = Array(serves)
        var last: Double?
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            let figure = number(in: characters, from: index)
            last = figure.value
            index = figure.end
        }
        return last.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Every ingredient amount multiplied, for when a recipe is written up or down a size.
    public mutating func scaleAmounts(by factor: Double) {
        func scale(_ list: [Ingredient]?) -> [Ingredient]? {
            list?.map { entry in
                var entry = entry
                entry.amount = Recipe.scaled(entry.amount, by: factor)
                return entry
            }
        }
        ingredients.supermarket = scale(ingredients.supermarket)
        ingredients.general = scale(ingredients.general)
        ingredients.optional = scale(ingredients.optional)
    }

    /// One written amount multiplied: "200 g" doubles to "400 g", "1/2 tsp" to "1 tsp". Every
    /// figure in the text is scaled, so "2 to 3 tbsp" keeps both ends of its range, and the
    /// units it is written with are left as they stand.
    public static func scaled(_ amount: String, by factor: Double) -> String {
        guard factor > 0, abs(factor - 1) > 0.0001 else { return amount }
        let characters = Array(amount)
        var result = ""
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                result.append(characters[index])
                index += 1
                continue
            }
            let figure = number(in: characters, from: index)
            result.append(format(figure.value * factor))
            index = figure.end
        }
        return result
    }

    /// The figure written at `start` and where it ends. A figure is a whole number or a
    /// decimal, a fraction such as "1/2", or the two together as "1 1/2".
    private static func number(in characters: [Character], from start: Int) -> (value: Double, end: Int) {
        var index = start

        func digits() -> Double? {
            let begin = index
            while index < characters.count, characters[index].isNumber { index += 1 }
            if index + 1 < characters.count, characters[index] == ".", characters[index + 1].isNumber {
                index += 1
                while index < characters.count, characters[index].isNumber { index += 1 }
            }
            guard index > begin else { return nil }
            return Double(String(characters[begin..<index]))
        }

        guard var value = digits() else { return (0, start + 1) }
        if index < characters.count, characters[index] == "/" {
            let slash = index
            index += 1
            if let denominator = digits(), denominator != 0 {
                value /= denominator
            } else {
                index = slash
            }
        } else if index + 1 < characters.count, characters[index] == " ", characters[index + 1].isNumber {
            let space = index
            let whole = value
            index += 1
            if let numerator = digits(), index < characters.count, characters[index] == "/" {
                index += 1
                if let denominator = digits(), denominator != 0 {
                    value = whole + numerator / denominator
                } else {
                    index = space
                }
            } else {
                index = space
            }
        }
        return (value, index)
    }

    /// A scaled figure written back out: whole where it lands on one, and cut to two places
    /// where it does not, so a third of a teaspoon does not run to six decimals.
    private static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if abs(rounded.rounded() - rounded) < 0.001 {
            return String(Int(rounded.rounded()))
        }
        return rounded.formatted(.number.precision(.fractionLength(0...2)))
    }
}
