import CulinaryIntelligence
import SwiftUI

/// The same sheet for a tool, which carries a note but no amount.
struct ToolEditor: View {
    let save: (Tool) -> Void
    let remove: () -> Void

    @State private var draft: Tool

    init(tool: Tool, save: @escaping (Tool) -> Void, remove: @escaping () -> Void) {
        self.save = save
        self.remove = remove
        _draft = State(initialValue: tool)
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Tool.Title", remove: remove) {
            save(draft.tidied)
        } content: {
            Section {
                HStack(spacing: 12) {
                    RecipeIcon(path: draft.icon, size: 44)
                    TextField("Recipe.Edit.Name", text: $draft.name)
                }
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
