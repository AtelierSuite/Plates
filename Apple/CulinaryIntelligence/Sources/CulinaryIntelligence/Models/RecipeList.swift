import Foundation

/// Which of a recipe's four card lists something sits in, so an edit knows where to write back.
public nonisolated enum RecipeList: String, Identifiable, CaseIterable, Sendable {
    case ingredients
    case optionalIngredients
    case tools
    case optionalTools

    public var id: String { rawValue }

    /// Whether the list holds ingredients rather than tools.
    public var isIngredients: Bool { self == .ingredients || self == .optionalIngredients }
}

extension Recipe {
    /// The ingredients one of the lists shows. The shopping list is written in two sections but
    /// read as one, so both come back together.
    public func ingredientList(in list: RecipeList) -> [Ingredient] {
        switch list {
        case .ingredients: (ingredients.supermarket ?? []) + (ingredients.general ?? [])
        case .optionalIngredients: ingredients.optional ?? []
        default: []
        }
    }

    public func toolList(in list: RecipeList) -> [Tool] {
        tools.filter { $0.required == (list == .tools) }
    }
}
