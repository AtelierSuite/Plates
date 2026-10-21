import CulinaryIntelligence
import SwiftUI

/// The field at the bottom of the screen where the cook asks for changes to a recipe in their
/// own words. It sits in a safe area bar rather than the toolbar, since a bottom toolbar stays
/// under the keyboard and draws its items on one shared glass.
struct RecipeRevisionBar: View {
    @Binding var text: String
    /// False while the model is out of reach or already at work.
    let isEnabled: Bool
    let canSend: Bool
    let send: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Edit.Ask.Label", text: $text, prompt: Text("Edit.Ask.Prompt"))
                .submitLabel(.send)
                .onSubmit { if canSend { send() } }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 48)
                .glassEffect(.regular.interactive(), in: .capsule)
                .disabled(!isEnabled)

            Button(action: send) {
                Label("Edit.Ask.Title", systemImage: "arrow.up")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
