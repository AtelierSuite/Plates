import Foundation

nonisolated struct ChefRecipe: Codable {
    var id: String
    var title: String
    var time: String
    var serves: String
    var tried: Bool?
    var ingredients: IngredientSections
    var tools: [Tool]
    var steps: [Step]
    var troubleshooting: [Troubleshooting]
    /// The page's own lines, for the app to sort. A recipe that was already in the app's
    /// schema has none.
    var page: Page? = nil

    /// A recipe as a web page gives it, with the same keys as `SharedPage` in the app.
    nonisolated struct Page: Codable {
        var title: String
        var time: String
        var serves: String
        var ingredients: [String]
        var steps: [String]
        var url: String?
    }

    nonisolated struct IngredientSections: Codable {
        var supermarket: [Ingredient]? = nil
        var general: [Ingredient]? = nil
        var optional: [Ingredient]? = nil

        var count: Int {
            (supermarket?.count ?? 0) + (general?.count ?? 0) + (optional?.count ?? 0)
        }
    }

    nonisolated struct Ingredient: Codable, Identifiable {
        var id: UUID = UUID()
        var item: String
        var icon: String
        var amount: String
        var note: String? = nil

        enum CodingKeys: String, CodingKey { case item, icon, amount, note }
    }

    nonisolated struct Tool: Codable, Identifiable {
        var id: UUID = UUID()
        var name: String
        var icon: String
        var required: Bool
        var note: String? = nil

        enum CodingKeys: String, CodingKey { case name, icon, required, note }
    }

    nonisolated struct Step: Codable, Identifiable {
        var id: UUID = UUID()
        var title: String
        var icons: [String]? = nil
        var points: [String]

        enum CodingKeys: String, CodingKey { case title, icons, points }
    }

    nonisolated struct Troubleshooting: Codable, Identifiable {
        var id: UUID = UUID()
        var problem: String
        var solution: String

        enum CodingKeys: String, CodingKey { case problem, solution }
    }

    /// A page is sorted in the app, which works out a time the page left out, so only a
    /// recipe already in the schema needs its time and servings here.
    var canSave: Bool {
        !title.trimmed.isEmpty && (page != nil || (!time.trimmed.isEmpty && !serves.trimmed.isEmpty))
            && [ingredients.supermarket, ingredients.general, ingredients.optional]
                .compactMap { $0 }.joined().contains { !$0.item.trimmed.isEmpty }
            && !steps.isEmpty
            && steps.allSatisfy { !$0.title.trimmed.isEmpty && $0.points.contains { !$0.trimmed.isEmpty } }
    }

    mutating func tidy() {
        title = title.trimmed
        time = time.trimmed
        serves = serves.trimmed
        id = Self.makeID(from: title)
        ingredients.supermarket = ingredients.supermarket?.filter { !$0.item.trimmed.isEmpty }
        ingredients.general = ingredients.general?.filter { !$0.item.trimmed.isEmpty }
        ingredients.optional = ingredients.optional?.filter { !$0.item.trimmed.isEmpty }
        steps = steps.filter { !$0.title.trimmed.isEmpty }.map { step in
            var step = step
            step.title = step.title.trimmed
            step.points = step.points.map(\.trimmed).filter { !$0.isEmpty }
            return step
        }
    }

    static func makeID(from title: String) -> String {
        let slug = title.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }
}

extension String {
    fileprivate nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
