import CulinaryIntelligence
import SwiftUI
import UIKit

/// The top of a printed recipe: the title, the facts, and the dish from above. On a page the
/// dish sits beside the title; in a picture it is the first thing seen, centred over it.
struct RecipeHeader: View {
    let recipe: Recipe
    var isHero = false

    var body: some View {
        if isHero {
            VStack(spacing: 14) {
                DishIcon(recipe: recipe, size: 220)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                    .padding(.bottom, 4)
                title
                    .multilineTextAlignment(.center)
                PaperFacts(recipe: recipe)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        } else {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    title
                    PaperFacts(recipe: recipe)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DishIcon(recipe: recipe, size: 132)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: some View {
        Text(verbatim: recipe.title)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(Color.paperInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
