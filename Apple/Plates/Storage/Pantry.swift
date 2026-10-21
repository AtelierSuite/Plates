import CulinaryIntelligence
import Foundation

/// What the cook says they have. The picks outlive the sheet, so the next recipe starts from
/// the same shelf rather than an empty one.
enum Pantry {
    private static let ingredientsKey = "pantryIngredients"
    private static let toolsKey = "pantryTools"

    /// Ingredient asset names last picked, minus any the catalog no longer carries.
    static var ingredients: [String] {
        get { read(ingredientsKey, in: IconCatalog.ingredients) }
        set { UserDefaults.standard.set(newValue, forKey: ingredientsKey) }
    }

    /// Tool asset names last picked, minus any the catalog no longer carries.
    static var tools: [String] {
        get { read(toolsKey, in: IconCatalog.tools) }
        set { UserDefaults.standard.set(newValue, forKey: toolsKey) }
    }

    private static func read(_ key: String, in catalog: [String]) -> [String] {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        let known = Set(catalog)
        return stored.filter(known.contains)
    }
}
