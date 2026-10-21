import CulinaryIntelligence
import SwiftUI

/// The sheet behind a card in the ingredient lists. The icon comes from the catalog, so it is
/// shown rather than typed; everything else is recipe text and is edited as written.
struct IngredientEditor: View {
    let save: (Ingredient) -> Void
    let remove: () -> Void

    @State private var draft: Ingredient

    init(ingredient: Ingredient, save: @escaping (Ingredient) -> Void, remove: @escaping () -> Void) {
        self.save = save
        self.remove = remove
        _draft = State(initialValue: ingredient)
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Ingredient.Title", remove: remove) {
            save(draft.tidied)
        } content: {
            Section {
                HStack(spacing: 12) {
                    RecipeIcon(path: draft.icon, size: 44)
                    TextField("Recipe.Edit.Name", text: $draft.item)
                }
                TextField("Recipe.Edit.Item.Amount", text: $draft.amount)
            }
            Section {
                TextField(
                    "Recipe.Edit.Item.Note",
                    text: Binding(get: { draft.note ?? "" }, set: { draft.note = $0 }),
                    axis: .vertical
                )
                .lineLimit(2...5)
            }
        }
    }
}
