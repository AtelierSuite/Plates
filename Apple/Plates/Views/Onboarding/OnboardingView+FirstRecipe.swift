import SwiftUI

extension OnboardingView {
    /// A way into the first recipe: a dish named or picked here opens the recipe sheet with it
    /// filled in, where ingredients and tools can be added before it is written.
    var firstRecipeStep: some View {
        page {
            stepHeader(
                icon: "plus.circle",
                title: "Onboarding.FirstRecipe.Title",
                description: isGenerationAllowed
                    ? "Onboarding.FirstRecipe.Description"
                    : "Onboarding.FirstRecipe.Description.ByHand"
            )

            TextField("Onboarding.FirstRecipe.Prompt", text: $dish)
                .focused($isDishFocused)
                .submitLabel(.go)
                .onSubmit { createFirstRecipe() }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: .capsule)

            VStack(alignment: .leading, spacing: 12) {
                Text("Onboarding.FirstRecipe.Suggestions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(Self.suggestions, id: \.key) { suggestion in
                    Button {
                        dish = String(localized: suggestion)
                    } label: {
                        Text(suggestion)
                    }
                    .buttonStyle(.glass)
                }
            }
        } buttons: {
            primaryButton("Onboarding.FirstRecipe.Create") { createFirstRecipe() }
                .disabled(trimmedDish.isEmpty)
            secondaryButton("Onboarding.Skip") { onComplete(nil) }
        }
    }

    private static let suggestions: [LocalizedStringResource] = [
        "Onboarding.FirstRecipe.Suggestion.FriedRice",
        "Onboarding.FirstRecipe.Suggestion.Curry",
        "Onboarding.FirstRecipe.Suggestion.Pasta",
    ]

    private var trimmedDish: String {
        dish.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createFirstRecipe() {
        guard !trimmedDish.isEmpty else { return }
        onComplete(trimmedDish)
    }
}
