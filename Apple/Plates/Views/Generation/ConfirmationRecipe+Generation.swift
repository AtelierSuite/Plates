import CulinaryIntelligence
import SwiftUI

extension ConfirmationRecipe {
    init(_ recipe: Recipe) {
        let sections = RecipeList.allCases.map { list in
            ConfirmationRecipe.Section(
                title: list.title,
                items: list.isIngredients
                    ? recipe.ingredientList(in: list).map {
                        .init(name: $0.item, detail: $0.amount, note: $0.note ?? "", assetName: IconCatalog.assetName(for: $0.icon))
                    }
                    : recipe.toolList(in: list).map {
                        .init(name: $0.name, detail: "", note: $0.note ?? "", assetName: IconCatalog.assetName(for: $0.icon))
                    }
            )
        }
        self.init(
            title: recipe.title,
            time: recipe.formattedTime,
            serves: recipe.serves,
            tried: recipe.tried == true,
            sections: sections,
            steps: recipe.steps.map { .init(title: $0.title, points: $0.points) },
            problems: recipe.troubleshooting.map { .init(question: $0.problem, answer: $0.solution) }
        )
    }
}
