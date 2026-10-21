import CulinaryIntelligence
import SwiftUI

/// The sheet behind one of the notes kept with a recipe: what goes wrong, and what to do
/// about it.
struct NoteEditor: View {
    let save: (Troubleshooting) -> Void
    let remove: () -> Void

    @State private var draft: Troubleshooting

    init(
        note: Troubleshooting,
        save: @escaping (Troubleshooting) -> Void,
        remove: @escaping () -> Void
    ) {
        self.save = save
        self.remove = remove
        _draft = State(initialValue: note)
    }

    var body: some View {
        EditorSheet(title: "Recipe.Edit.Note.Title", remove: remove) {
            var note = draft
            note.problem = draft.problem.trimmingCharacters(in: .whitespacesAndNewlines)
            note.solution = draft.solution.trimmingCharacters(in: .whitespacesAndNewlines)
            save(note)
        } content: {
            Section {
                TextField("Recipe.Edit.Note.Problem", text: $draft.problem, axis: .vertical)
                    .lineLimit(1...3)
            }
            Section {
                TextField("Recipe.Edit.Note.Solution", text: $draft.solution, axis: .vertical)
                    .lineLimit(2...8)
            }
        }
    }
}
