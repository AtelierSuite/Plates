import CulinaryIntelligence
import SwiftUI
import UIKit

/// A recipe drawn as one picture: the same content the detail view shows, in one column and in
/// ink rather than in the reader's appearance, on a card set in a warm frame. Recipe text is
/// shown as written.
struct RecipePage: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeHeader(recipe: recipe, isHero: true)
            ForEach(RecipeList.allCases) { list in
                let items = recipe.items(in: list)
                if !items.isEmpty {
                    PaperSection(title: list.title) {
                        ForEach(Array(PaperItemPair.pairs(items).enumerated()), id: \.offset) { _, pair in
                            PaperItemPair(items: pair)
                        }
                    }
                }
            }
            if !recipe.steps.isEmpty {
                PaperSection(title: "Recipe.Detail.Steps") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        PaperStepRow(number: index + 1, step: step)
                    }
                }
            }
            if !recipe.troubleshooting.isEmpty {
                PaperSection(title: "Recipe.Detail.Troubleshooting") {
                    ForEach(recipe.troubleshooting) { PaperNoteRow(note: $0) }
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 40)
        // The shadow is cast by the card alone, not by everything drawn on it.
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        }
        .padding(24)
        .frame(width: RecipeExport.pageWidth, alignment: .leading)
        .background(Color.paperTint)
        .environment(\.colorScheme, .light)
    }
}
