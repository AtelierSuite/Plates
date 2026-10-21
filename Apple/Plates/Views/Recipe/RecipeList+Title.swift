import CulinaryIntelligence
import SwiftUI

extension RecipeList {
    /// How the list is headed on screen.
    var title: LocalizedStringResource {
        switch self {
        case .ingredients: "Recipe.Detail.Ingredients"
        case .optionalIngredients: "Recipe.Detail.Ingredients.Optional"
        case .tools: "Recipe.Detail.Tools"
        case .optionalTools: "Recipe.Detail.Tools.Optional"
        }
    }
}
