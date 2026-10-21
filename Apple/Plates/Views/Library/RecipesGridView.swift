import CulinaryIntelligence
import SwiftUI

/// The recipes as a two column grid of cards. What is in it, and in which order, is worked
/// out by whoever presents it.
struct RecipesGridView: View {
    let recipes: [Recipe]
    let delete: (Recipe) -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(recipe)
                        } label: {
                            Label("Menu.Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, .listRowInset)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
