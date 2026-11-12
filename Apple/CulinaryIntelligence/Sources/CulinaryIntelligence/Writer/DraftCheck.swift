import Foundation

/// A check Gemma's draft is held to in code, before any model sorts it. The write prompt asks
/// for every one of these, and a model this size does not always do as it is asked. No model
/// is asked to repair a draft that fails: a read through was tried and did more harm than good,
/// so a failing draft is written again instead.
enum DraftCheck: String, CaseIterable, Sendable {
    case title
    case time
    case serves
    case steps
    case problems
    /// A listed ingredient that no step uses.
    case unusedIngredient
    /// A catalog ingredient a step uses that is not listed.
    case unlistedIngredient
    /// The cook named a dish built on a starch, and the starch is not listed.
    case missingStarch
    case salt
    case sugar
    case ovenTemperature
    /// The step times add up to well over the stated total.
    case stepTimes

    /// The checks a draft fails, in the order above. `request` is the request as Gemma was
    /// given it, in English.
    static func failures(in written: WrittenRecipe, request: GenerationRequest) -> [DraftCheck] {
        allCases.filter { !$0.passes(written, request: request) }
    }

    private func passes(_ written: WrittenRecipe, request: GenerationRequest) -> Bool {
        switch self {
        case .title: !written.title.trimmingCharacters(in: .whitespaces).isEmpty
        case .time: (Recipe.minutes(in: written.time) ?? 0) > 0
        case .serves: !RecipeGenerator.serves(from: written.serves).isEmpty
        case .steps: Self.stepRange.contains(written.steps.count)
        case .problems: Self.problemRange.contains(written.problems.count)
        case .unusedIngredient: Self.unusedIngredients(in: written).isEmpty
        case .unlistedIngredient: Self.unlistedIngredients(in: written).isEmpty
        case .missingStarch: Self.listsStarch(of: request, in: written)
        case .salt: Self.perServing(.salt, in: written) <= Self.saltLimit
        case .sugar: Self.perServing(.sugar, in: written) <= Self.sugarLimit
        case .ovenTemperature: Self.ovenTemperaturesAreSane(in: written)
        case .stepTimes: Self.stepTimesFit(written)
        }
    }

    static let stepRange = 3...8
    static let problemRange = 2...4

    /// Grams per serving. Rough on purpose: past these, a figure is a mistake rather than a
    /// taste. A teaspoon of salt is about 6 g, and a cup of sugar about 200 g.
    static let saltLimit = 8.0
    static let sugarLimit = 100.0

    // MARK: - Ingredients

    /// A line seasoned "to taste" or marked optional may go unmentioned in the method.
    private static func isLoose(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered.contains("to taste") || lowered.contains("optional")
    }

    /// The listed lines no step uses, read the same way unused picks are found.
    static func unusedIngredients(in written: WrittenRecipe) -> [String] {
        guard !written.steps.isEmpty else { return [] }
        let method = RecipeGenerator.stems(in: written.steps.joined(separator: " "))
        return written.ingredients.filter { line in
            guard !isLoose(line) else { return false }
            let name = RecipeGenerator.namedIngredient(in: line).map(IconCatalog.englishName) ?? ""
            // "1 (14 oz) can diced tomatoes" names the tomatoes after its bracket.
            let plain = line.replacing(#/\([^)]*\)/#, with: "")
            return !RecipeGenerator.isMentioned(line: plain, name: name, in: method)
        }
    }

    /// What a method may use without listing it, and names a step uses as verbs, as in "fish
    /// out the bay leaf" or "cream the butter".
    private static let unread: Set<String> = ["water", "salt", "pepper", "oil", "ice", "fish", "cream"]

    /// The groups a step names loosely: it says "the cheese" for the pecorino, "the pasta" for
    /// the spaghetti, and "the squid" from a seafood mix.
    private static let looseCategories: Set<IngredientCategory> = [.meat, .seafood, .dairy, .grains]

    /// The catalog ingredients the steps use that the list does not. Only the catalog's own
    /// English names are read in the steps, not its other words for them, since those include
    /// dish names such as "carbonara" that a step says when it serves the dish.
    static func unlistedIngredients(in written: WrittenRecipe) -> [String] {
        guard !written.ingredients.isEmpty else { return [] }
        let listed = Set(written.ingredients.flatMap(catalogIngredients(in:)))
        let listedStems = RecipeGenerator.stems(in: written.ingredients.joined(separator: " "))
        let listedCategories = Set(listed.compactMap(category))
        var unlisted: [String] = []
        for asset in englishIngredients(in: written.steps.joined(separator: " "))
        where !unread.contains(asset) && !listed.contains(asset) && !unlisted.contains(asset) {
            let name = RecipeGenerator.stems(in: IconCatalog.englishName(for: asset))
            if name.isSubset(of: listedStems) { continue }
            if let category = category(of: asset), looseCategories.contains(category),
               listedCategories.contains(category) { continue }
            unlisted.append(asset)
        }
        return unlisted
    }

    private static func category(of asset: String) -> IngredientCategory? {
        IngredientCategory.allCases.first { $0.icons.contains(asset) }
    }

    /// The catalog ingredients some text names by their English names, a longest run of words
    /// at a time, read left to right.
    static func englishIngredients(in text: String) -> [String] {
        assets(in: text) { englishNames[$0.map(RecipeGenerator.stem).joined(separator: " ")] }
    }

    /// The catalog ingredients some text names in any of the catalog's words for them.
    static func catalogIngredients(in text: String) -> [String] {
        assets(in: text) { IconCatalog.ingredient(named: $0.joined(separator: " ")) }
    }

    private static func assets(in text: String, lookUp: ([String]) -> String?) -> [String] {
        let words = RecipeGenerator.words(in: text).filter { !RecipeGenerator.measureWords.contains($0) }
        var found: [String] = []
        var start = 0
        while start < words.count {
            var matched = 1
            for length in stride(from: min(3, words.count - start), through: 1, by: -1) {
                if let asset = lookUp(Array(words[start..<(start + length)])) {
                    found.append(asset)
                    matched = length
                    break
                }
            }
            start += matched
        }
        return found
    }

    /// Every catalog ingredient by its English name, stemmed word by word.
    private static let englishNames: [String: String] = IconCatalog.ingredients.reduce(into: [:]) { table, asset in
        let words = RecipeGenerator.words(in: IconCatalog.englishName(for: asset))
        let key = words.map(RecipeGenerator.stem).joined(separator: " ")
        if table[key] == nil { table[key] = asset }
    }

    // MARK: - Starch

    /// Dishes that say their starch without naming it.
    private static let starchDishes: [String: String] = [
        "risotto": "rice", "paella": "rice", "pilaf": "rice", "pilau": "rice", "biryani": "rice",
        "bibimbap": "rice", "donburi": "rice", "onigiri": "rice", "sushi": "rice", "congee": "rice",
        "jambalaya": "rice", "carbonara": "pasta", "lasagne": "pasta", "yakisoba": "noodles",
        "pho": "noodles", "sandwich": "bread", "toast": "bread", "panini": "bread", "bruschetta": "bread",
    ]

    /// The starches a dish's name says it is built on, such as "rice" for an egg fried rice.
    static func starches(namedIn dish: String) -> Set<String> {
        var named = Set(catalogIngredients(in: dish).compactMap { asset in
            RecipeGenerator.staples.first { $0.value.contains(asset) }?.key
        })
        for word in RecipeGenerator.words(in: dish) {
            if let starch = starchDishes[word] { named.insert(starch) }
        }
        return named
    }

    /// Whether every starch the cook's dish is built on is listed, as the picks are checked
    /// before a dish is written. A line counts when it names one of the starch's catalog
    /// ingredients, or the starch itself, as "4 slices sourdough bread" does.
    static func listsStarch(of request: GenerationRequest, in written: WrittenRecipe) -> Bool {
        let starches = starches(namedIn: request.trimmedDescription)
        guard !starches.isEmpty, !written.ingredients.isEmpty else { return true }
        let listed = Set(written.ingredients.flatMap(catalogIngredients(in:)))
        let listedStems = RecipeGenerator.stems(in: written.ingredients.joined(separator: " "))
        return starches.allSatisfy { starch in
            guard let assets = RecipeGenerator.staples[starch] else { return true }
            return !assets.isDisjoint(with: listed) || listedStems.contains(RecipeGenerator.stem(starch))
        }
    }

    // MARK: - Amounts

    enum Seasoning {
        case salt, sugar

        /// Grams in one of each measure.
        var grams: [String: Double] {
            switch self {
            case .salt: ["tsp": 6, "tbsp": 18, "cup": 290]
            case .sugar: ["tsp": 4, "tbsp": 12.5, "cup": 200]
            }
        }

        func names(_ asset: String) -> Bool {
            switch self {
            case .salt: asset == "salt"
            case .sugar: asset.hasSuffix("sugar")
            }
        }
    }

    /// The grams of salt or sugar the list gives each serving. Salt for the pasta water or a
    /// brine is not eaten, so it is left out, and so is all of it when a step salts water,
    /// since the list seldom says which line that is.
    static func perServing(_ seasoning: Seasoning, in written: WrittenRecipe) -> Double {
        let servings = written.serves.matches(of: #/\d+/#).compactMap { Double(written.serves[$0.range]) }.max() ?? 0
        guard servings > 0 else { return 0 }
        if seasoning == .salt, written.steps.flatMap(RecipeGenerator.sentences).contains(where: { sentence in
            let words = RecipeGenerator.stems(in: sentence)
            return words.contains("salt") && words.contains("water")
        }) { return 0 }
        let total = written.ingredients.reduce(0.0) { total, line in
            let lowered = line.lowercased()
            guard let asset = RecipeGenerator.namedIngredient(in: line), seasoning.names(asset),
                  !["water", "brine", "boil"].contains(where: lowered.contains),
                  let (figure, unit) = measure(in: line) else { return total }
            return total + figure * (unit == "g" ? 1 : seasoning.grams[unit] ?? 0)
        }
        return total / servings
    }

    private static let fractions: [Character: String] = ["½": " 1/2", "⅓": " 1/3", "⅔": " 2/3", "¼": " 1/4", "¾": " 3/4"]

    /// The figure a line opens with and the measure it is in, as "tsp", "tbsp", "cup" or "g".
    /// A range is read at its lower figure.
    static func measure(in line: String) -> (Double, String)? {
        let text = line.reduce(into: "") { text, character in text += fractions[character] ?? String(character) }
        let figure = #/^\s*(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)(?:\s*(?:to|-)\s*(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?))?\s*(teaspoons?|tsps?|tablespoons?|tbsps?|cups?|grams?|g|kilograms?|kg|ounces?|oz)\b/#
            .ignoresCase()
        guard let match = text.firstMatch(of: figure), let value = number(String(match.1)) else { return nil }
        let unit = match.2.lowercased()
        if unit.hasPrefix("t") { return (value, unit.contains("ble") || unit.hasPrefix("tb") ? "tbsp" : "tsp") }
        if unit.hasPrefix("c") { return (value, "cup") }
        if unit.hasPrefix("k") { return (value * 1000, "g") }
        if unit.hasPrefix("o") { return (value * 28, "g") }
        return (value, "g")
    }

    /// A figure as written: "2", "1.5", "1/2", or "1 1/2".
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

    // MARK: - Heat and time

    /// Whether every oven temperature the steps give is one an oven is set to. Only sentences
    /// about the oven are read, and not those about how hot the food gets inside, so the heat
    /// a piece of chicken is cooked to is left alone.
    static func ovenTemperaturesAreSane(in written: WrittenRecipe) -> Bool {
        let temperature = #/(\d{2,3})\s*(°|º|degrees?)?\s*(fahrenheit|celsius|F|C)?\b/#.ignoresCase()
        for step in written.steps {
            for sentence in RecipeGenerator.sentences(in: step) {
                let lowered = sentence.lowercased()
                guard ["oven", "preheat", "bake", "roast"].contains(where: lowered.contains),
                      !["inside", "internal", "thermometer", "reaches"].contains(where: lowered.contains)
                else { continue }
                for match in sentence.matches(of: temperature) where match.2 != nil || match.3 != nil {
                    guard let degrees = Double(match.1) else { continue }
                    let scale = match.3?.lowercased().first
                    let range: ClosedRange<Double> = switch scale {
                    case "f": 200...550
                    case "c": 90...290
                    default: 90...550
                    }
                    if !range.contains(degrees) { return false }
                }
            }
        }
        return true
    }

    /// Whether the step times add up close to the stated total. A method seldom times the
    /// prep, so steps that come to less are fine. Steps that come to well over it mean the
    /// total, or a step, is wrong.
    static func stepTimesFit(_ written: WrittenRecipe) -> Bool {
        guard let total = Recipe.minutes(in: written.time), total > 0 else { return true }
        let seconds = written.steps.reduce(0) { sum, text in
            sum + Step(title: "", points: [text]).durations.reduce(0) { $0 + Int($1.components.seconds) }
        }
        return Double(seconds) / 60 <= Double(total) + max(15, Double(total) / 2)
    }
}
