import Foundation

/// A short recipe for a well known dish, given to Gemma beside the cook's request so it can check
/// its ingredients and method against one that is known to work, rather than writing the dish
/// from memory alone.
///
/// The references are the One-Pan Food recipes the sample recipes come from, cut down by
/// `Apple/Assets/ReferenceRecipes/export.py` to the title, the serving count, the ingredients, and
/// the method. They are in English, which is the language Gemma is asked in.
nonisolated struct ReferenceRecipe: Decodable, Equatable, Sendable {
    struct Step: Decodable, Equatable, Sendable {
        let title: String
        let points: [String]
    }

    /// The signature dish this is the reference for.
    let dish: String
    let title: String
    let serves: String
    /// Each ingredient with its amount, as one line.
    let ingredients: [String]
    let optional: [String]
    let steps: [Step]

    private static let all: [String: ReferenceRecipe] = {
        guard let url = Bundle.module.url(forResource: "ReferenceRecipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let references = try? JSONDecoder().decode([ReferenceRecipe].self, from: data)
        else { return [:] }
        return Dictionary(references.map { ($0.dish, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    /// The reference for the dish a request names, read from any of the wordings given, such as
    /// the cook's own words and their English. Only a request that names the dish and nothing
    /// more gets one: "egg fried rice" does, and "shrimp fried rice" does not, since a reference
    /// for another dish would pull the recipe away from what was asked.
    static func named(in requests: [String]) -> ReferenceRecipe? {
        for request in requests {
            let dish = withoutServings(request).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !dish.isEmpty, let id = SignatureDish.namedID(forRequest: dish) else { continue }
            if let reference = all[id] { return reference }
        }
        return nil
    }

    /// A request with the serving count at its end taken off, so "carbonara for two" and
    /// "カルボナーラ 2人分" still name the dish and nothing more.
    static func withoutServings(_ request: String) -> String {
        let patterns = [
            #"\s+for\s+(\d+|one|two|three|four|five|six|eight)(\s+(people|persons|servings|adults))?\s*$"#,
            #"\s*[0-9０-９一二三四五六]+\s*人(分|前)\s*$"#,
        ]
        return patterns.reduce(request) { text, pattern in
            text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
    }
}
