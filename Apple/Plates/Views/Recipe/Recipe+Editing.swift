import CulinaryIntelligence
import SwiftUI

extension Recipe {
    /// The cards one of the four lists shows. The shopping list is written in two sections but
    /// read as one, so both come back together.
    func items(in list: RecipeList) -> [TileInfo] {
        list.isIngredients
            ? ingredientList(in: list).map(TileInfo.init)
            : toolList(in: list).map(TileInfo.init)
    }

    /// Writes a list of ingredients back. The required list is split into the two sections the
    /// schema keeps, and an entry that was already in one of them stays where it was, so
    /// editing an amount never shuffles the file around.
    mutating func setIngredients(_ list: [Ingredient], in target: RecipeList) {
        switch target {
        case .optionalIngredients:
            ingredients.optional = list.isEmpty ? nil : list
        case .ingredients:
            let wasSupermarket = Set((ingredients.supermarket ?? []).map(\.icon))
            let wasGeneral = Set((ingredients.general ?? []).map(\.icon))
            var supermarket: [Ingredient] = []
            var general: [Ingredient] = []
            for entry in list {
                if wasSupermarket.contains(entry.icon) {
                    supermarket.append(entry)
                } else if wasGeneral.contains(entry.icon) {
                    general.append(entry)
                } else if IconCatalog.iconName(for: entry.icon).map(IconCatalog.shelf(of:)) == .pantry {
                    general.append(entry)
                } else {
                    supermarket.append(entry)
                }
            }
            ingredients.supermarket = supermarket.isEmpty ? nil : supermarket
            ingredients.general = general.isEmpty ? nil : general
        default:
            break
        }
    }

    /// Writes a list of tools back, keeping the ones from the other list as they were.
    mutating func setTools(_ list: [Tool], in target: RecipeList) {
        let required = target == .tools
        let others = tools.filter { $0.required != required }
        tools = required ? list + others : others + list
    }
}
