import CulinaryIntelligence
import SwiftUI

/// What every editing sheet is built out of: a form, a way back out without saving, and a way
/// to drop the thing being edited.
struct EditorSheet<Content: View>: View {
    let title: LocalizedStringResource
    let remove: () -> Void
    let save: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                content
                Section {
                    Button(role: .destructive) {
                        remove()
                        dismiss()
                    } label: {
                        // The role reddens the text on its own; the symbol is told to match.
                        Label("Shared.Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Shared.Save") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }
}
