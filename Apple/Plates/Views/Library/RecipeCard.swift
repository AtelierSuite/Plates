import CulinaryIntelligence
import SwiftUI

/// One recipe at a glance: the dish from above, then the title and how long it takes, on the
/// plain card colour so the dish is what carries the colour. Recipe data is shown as written
/// rather than looked up in the string catalog.
struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DishIcon(recipe: recipe, size: 112)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            Text(verbatim: recipe.title)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(String(format: String(localized: "Recipe.Row.Subtitle"), recipe.formattedTime, recipe.serves))
                if recipe.tried == true {
                    Image(systemName: "checkmark.seal.fill")
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground()
    }
}
