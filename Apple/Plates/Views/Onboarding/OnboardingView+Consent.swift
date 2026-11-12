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
                description: provider == .claude
                    ? "Onboarding.Consent.Description.Claude"
                    : "Onboarding.Consent.Description"
            )

            VStack(alignment: .leading, spacing: 24) {
                switch provider {
                case .plates:
                    featureRow(
                        icon: "text.page",
                        title: "Consent.Gemma",
                        description: "Consent.Gemma.Description",
                        spacing: 8
                    )
                    featureRow(
                        icon: "dice",
                        title: "Consent.Clef",
                        description: "Consent.Clef.Description",
                        spacing: 8
                    )
                case .claude:
                    featureRow(
                        icon: "text.page",
                        title: "Consent.Claude",
                        description: "Consent.Claude.Description",
                        spacing: 8
                    )
                    featureRow(
                        icon: "key",
                        title: "Consent.Claude.Key",
                        description: "Consent.Claude.Key.Description",
                        spacing: 8
                    )
                }
                featureRow(
                    icon: "lock.shield",
                    title: "Consent.Private",
                    description: provider == .claude
                        ? "Consent.Private.Description.Claude"
                        : "Consent.Private.Description",
                    spacing: 8
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                switch provider {
                case .plates:
                    Link("Consent.Policy.Cloudflare", destination: AIProcessingView.cloudflarePolicy)
                case .claude:
                    Link("Consent.Policy.Anthropic", destination: AIProcessingView.anthropicPolicy)
                }
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
