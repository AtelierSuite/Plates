import SwiftUI

extension OnboardingView {
    var welcomeStep: some View {
        page {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "frying.pan")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.tint)
                    .padding(.top, 80)
                Text("Onboarding.Welcome.Title")
                    .font(.largeTitle.bold())
            }

            VStack(alignment: .leading, spacing: 24) {
                featureRow(
                    icon: "wand.and.sparkles",
                    title: "Onboarding.Feature.Write",
                    description: "Onboarding.Feature.Write.Description"
                )
                featureRow(
                    icon: "text.bubble",
                    title: "Onboarding.Feature.Edit",
                    description: "Onboarding.Feature.Edit.Description"
                )
                featureRow(
                    icon: "basket",
                    title: "Onboarding.Feature.Shopping",
                    description: "Onboarding.Feature.Shopping.Description"
                )
                featureRow(
                    icon: "icloud",
                    title: "Onboarding.Feature.Files",
                    description: "Onboarding.Feature.Files.Description"
                )
            }
        } buttons: {
            primaryButton("Onboarding.Continue") { advance() }
        }
    }
}
