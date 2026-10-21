import SwiftUI

extension ConfirmationRecipe {
    init(_ recipe: ChefRecipe) {
        func ingredients(_ entries: [ChefRecipe.Ingredient]?) -> [ConfirmationRecipe.Item] {
            (entries ?? []).map { .init(name: $0.item, detail: $0.amount, note: $0.note ?? "", assetName: nil) }
        }
        func tools(_ required: Bool) -> [ConfirmationRecipe.Item] {
            recipe.tools.filter { $0.required == required }
                .map { .init(name: $0.name, detail: "", note: $0.note ?? "", assetName: nil) }
        }
        self.init(
            title: recipe.title,
            time: recipe.time,
            serves: recipe.serves,
            tried: recipe.tried == true,
            sections: [
                .init(title: "Recipe.Detail.Ingredients", items: ingredients(recipe.ingredients.supermarket) + ingredients(recipe.ingredients.general)),
                .init(title: "Recipe.Detail.Ingredients.Optional", items: ingredients(recipe.ingredients.optional)),
                .init(title: "Recipe.Detail.Tools", items: tools(true)),
                .init(title: "Recipe.Detail.Tools.Optional", items: tools(false)),
            ],
            steps: recipe.steps.map { .init(title: $0.title, points: $0.points) },
            problems: recipe.troubleshooting.map { .init(question: $0.problem, answer: $0.solution) }
        )
    }
}
