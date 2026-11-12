import CulinaryIntelligence
import SwiftUI

extension OnboardingView {
    /// Where a request goes, asked before the first recipe. A cook who does not allow it writes
    /// their recipes by hand, and can turn generation on later from the menu.
    var consentStep: some View {
        page {
            stepHeader(
                icon: "hand.raised",
                title: "Onboarding.Consent.Title",
                description: provider.onboardingDescription
            )

            VStack(alignment: .leading, spacing: 24) {
                ForEach(provider.consentRows, id: \.icon) { item in
                    featureRow(icon: item.icon, title: item.title, description: item.description, spacing: 8)
                }
                featureRow(
                    icon: "lock.shield",
                    title: "Consent.Private",
                    description: provider.privateDescription,
                    spacing: 8
                )
            }

            Link(provider.policyName, destination: provider.policy)
                .font(.subheadline)

            Text("Onboarding.Consent.Footer")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } buttons: {
            primaryButton("Onboarding.Consent.Allow") {
                isGenerationAllowed = true
                advance()
            }
            secondaryButton("Onboarding.Consent.Deny") {
                isGenerationAllowed = false
                advance()
            }
        }
    }
}
