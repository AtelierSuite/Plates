import SwiftUI

extension OnboardingView {
    /// Where a request goes, asked before the first recipe. A cook who does not allow it writes
    /// their recipes by hand, and can turn generation on later from the menu.
    var consentStep: some View {
        page {
            stepHeader(
                icon: "hand.raised",
                title: "Onboarding.Consent.Title",
                description: "Onboarding.Consent.Description"
            )

            VStack(alignment: .leading, spacing: 24) {
                featureRow(
                    icon: "text.page",
                    title: "Consent.Gemma",
                    description: "Consent.Gemma.Description",
                    spacing: 8
                )
                featureRow(
                    icon: "dice",
                    title: "Consent.Jev",
                    description: "Consent.Jev.Description",
                    spacing: 8
                )
                featureRow(
                    icon: "lock.shield",
                    title: "Consent.Private",
                    description: "Consent.Private.Description",
                    spacing: 8
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Link("Consent.Policy.Cloudflare", destination: AIProcessingView.cloudflarePolicy)
                Link("Consent.Policy.TypeSafe", destination: AIProcessingView.typeSafePolicy)
            }
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
