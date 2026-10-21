import CulinaryIntelligence
import SwiftUI

/// What a new install shows first: what Plates does, where a request goes, and a way into the first recipe.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome
        case consent
        case firstRecipe
    }

    /// Called when the cook is done, with the dish they asked for when they asked for one.
    let onComplete: (String?) -> Void

    @State var step = Step.welcome
    @State var dish = ""
    @FocusState var isDishFocused: Bool
    /// Whether the first recipe is generated, or started blank for the cook to write.
    @AppStorage(PlatesCloud.allowedKey) var isGenerationAllowed = false

    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                if step != .welcome {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .padding(4)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(Text("Onboarding.Back"))
                    .padding()
                }
            }
            .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .consent: consentStep
        case .firstRecipe: firstRecipeStep
        }
    }

    // MARK: - Navigation

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.smooth.speed(2)) { step = previous }
    }

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(.smooth.speed(2)) { step = next }
    }
}

#Preview {
    OnboardingView { _ in }
}
